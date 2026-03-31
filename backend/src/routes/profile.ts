import { Hono } from 'hono'
import { authMiddleware } from '../middleware/auth'
import type { Env } from '../index'

const profileRoutes = new Hono<{ Bindings: Env; Variables: { user: any } }>()

// Apply auth middleware to all profile routes
profileRoutes.use('*', authMiddleware)

// Get self profile
profileRoutes.get('/', async (c) => {
  const userId = c.get('user').sub
  return getFullProfile(c, userId)
})

// Update profile (self or specific ID if authorized)
profileRoutes.put('/:id', async (c) => {
  const userId = c.get('user').sub
  const targetId = c.req.param('id')
  
  if (userId !== targetId) {
    return c.json({ error: 'Unauthorized' }, 403)
  }

  const body = await c.req.json()
  const allowedUpdates: Record<string, any> = {}
  
  if (body.username) {
    // 1. Check current username_changes limit
    const { results: userRes } = await c.env.DB.prepare('SELECT username, username_changes FROM users WHERE id = ?').bind(userId).all()
    if (userRes.length && (userRes[0].username_changes as number) >= 2) {
      return c.json({ error: 'You have reached the maximum number of name changes (2)' }, 403)
    }
    
    // 2. Only update if name is different
    if (userRes.length && userRes[0].username !== body.username) {
       allowedUpdates.username = body.username
       allowedUpdates.username_changes = (userRes[0].username_changes as number) + 1
    }
  }

  if (body.avatarUrl) allowedUpdates.avatar_url = body.avatarUrl
  if (body.isGhibli !== undefined) allowedUpdates.is_ghibli = body.isGhibli ? 1 : 0
  if (body.localAvatar !== undefined) allowedUpdates.local_avatar = body.localAvatar

  if (Object.keys(allowedUpdates).length === 0) {
    return c.json({ error: 'No valid fields to update' }, 400)
  }

  const setClauses = Object.keys(allowedUpdates).map(k => `${k} = ?`).join(', ')
  const values = Object.values(allowedUpdates)

  try {
    await c.env.DB.prepare(`UPDATE users SET ${setClauses}, updated_at = datetime('now') WHERE id = ?`)
      .bind(...values, userId)
      .run()

    let token: string | undefined = undefined;
    if (body.username) {
      const jwtPayload = c.get('user')
      const { sign } = await import('hono/jwt')
      token = await sign(
        { sub: userId, username: body.username, deviceId: jwtPayload.deviceId, exp: Math.floor(Date.now() / 1000) + 86400 * 30 },
        c.env.JWT_SECRET
      )
    }

    const res = await getFullProfile(c, userId)
    const data = await res.json()
    if (token) data.token = token
    return c.json(data)
  } catch (err: any) {
    if (err.message.includes('UNIQUE constraint failed: users.username')) {
      return c.json({ error: 'Username already taken' }, 409)
    }
    throw err
  }
})

// Update User XP & Stats
profileRoutes.post('/:id/xp', async (c) => {
  const userId = c.get('user').sub
  const targetId = c.req.param('id')
  
  if (userId !== targetId) {
    return c.json({ error: 'Unauthorized' }, 403)
  }

  const { xpDelta, stats, isOnlineMatch } = await c.req.json() as { xpDelta: number, stats: any, isOnlineMatch?: boolean }
  
  try {
    // Start transactional-like multi-command
    const batch = [
      // 1. Update User XP
      c.env.DB.prepare('UPDATE users SET xp = xp + ?, updated_at = datetime("now") WHERE id = ?')
        .bind(xpDelta, userId),
      
      // 2. Update stats
      c.env.DB.prepare(`
        UPDATE user_stats 
        SET 
          wins = wins + ?,
          losses = losses + ?,
          draws = draws + ?,
          multiplayer_wins = multiplayer_wins + ?,
          tournament_wins = tournament_wins + ?,
          total_moves = total_moves + ?,
          hints_used = hints_used + ?,
          puzzles_solved = puzzles_solved + ?,
          puzzle_rating = CASE WHEN ? > 0 THEN ? ELSE puzzle_rating END,
          updated_at = datetime('now')
        WHERE user_id = ?
      `).bind(
        stats.wins || 0,
        stats.losses || 0,
        stats.draws || 0,
        stats.multiplayer_wins || 0,
        stats.tournament_wins || 0,
        stats.total_moves || 0,
        stats.hints_used || 0,
        stats.puzzles_solved || 0,
        stats.puzzle_rating || 0,
        stats.puzzle_rating || 0,
        userId
      )
    ]
    
    await c.env.DB.batch(batch)
    
    // Check for "First Win" badge if wins == 1
    if (stats.wins > 0) {
      const { results: s } = await c.env.DB.prepare('SELECT wins FROM user_stats WHERE user_id = ?').bind(userId).all()
      if (s[0]?.wins === 1) {
        await c.env.DB.prepare('INSERT OR IGNORE INTO user_achievements (user_id, achievement_id) VALUES (?, ?)')
          .bind(userId, 'first_win')
          .run();
      }
    }

    return c.json({ success: true, xpDelta })
  } catch (err: any) {
    return c.json({ error: err.message }, 500)
  }
})

// Donate XP to another user
profileRoutes.post('/xp/transfer', async (c) => {
  const donorId = c.get('user').sub
  const { recipientId, amount } = await c.req.json() as { recipientId: string, amount: number }
  
  if (amount <= 0) return c.json({ error: 'Invalid amount' }, 400)

  // Verify donor has enough XP
  const { results: donor } = await c.env.DB.prepare('SELECT xp FROM users WHERE id = ?').bind(donorId).all()
  if (!donor.length || (donor[0].xp as number) < amount) {
    return c.json({ error: 'Insufficient XP' }, 400)
  }

  try {
    await c.env.DB.batch([
      c.env.DB.prepare('UPDATE users SET xp = xp - ? WHERE id = ?').bind(amount, donorId),
      c.env.DB.prepare('UPDATE users SET xp = xp + ? WHERE id = ?').bind(amount, recipientId),
      c.env.DB.prepare('INSERT INTO xp_transfers (donor_id, recipient_id, amount) VALUES (?, ?, ?)')
        .bind(donorId, recipientId, amount)
    ])

    // Check donation badge
    const { results: totalDonated } = await c.env.DB.prepare(
      'SELECT SUM(amount) as total FROM xp_transfers WHERE donor_id = ?'
    ).bind(donorId).all()
    
    if ((totalDonated[0]?.total as number) >= 500) {
       await c.env.DB.prepare('INSERT OR IGNORE INTO user_achievements (user_id, achievement_id) VALUES (?, ?)')
          .bind(donorId, 'generous_donor')
          .run();
    }

    return c.json({ success: true, donorId, recipientId, amount })
  } catch (err: any) {
    return c.json({ error: err.message }, 500)
  }
})

// Request XP from network
profileRoutes.post('/xp/request', async (c) => {
  const userId = c.get('user').sub
  const { amount } = await c.req.json() as { amount: number }
  
  try {
     await c.env.DB.prepare('INSERT INTO xp_requests (requester_id, amount) VALUES (?, ?)')
        .bind(userId, amount)
        .run()
     return c.json({ success: true })
  } catch (err: any) {
     return c.json({ error: err.message }, 500)
  }
})

// Get public profile by user ID
profileRoutes.get('/:id', async (c) => {
  const targetId = c.req.param('id')
  return getFullProfile(c, targetId)
})

async function getFullProfile(c: any, userId: string) {
  const { results: userRes } = await c.env.DB.prepare(
    'SELECT id, username, avatar_url, is_ghibli, local_avatar, username_changes, xp, created_at FROM users WHERE id = ?'
  ).bind(userId).all()

  if (!userRes.length) {
    return c.json({ error: 'User not found' }, 404)
  }

  const { results: statsRes } = await c.env.DB.prepare(
    'SELECT * FROM user_stats WHERE user_id = ?'
  ).bind(userId).all()

  // Fetch recent 5 games
  const { results: gamesRes } = await c.env.DB.prepare(`
    SELECT 
      g.id,
      g.created_at as date,
      CASE 
        WHEN g.mode = 'singlePlayer' THEN 'AI Master'
        WHEN g.white_user_id = ? THEN COALESCE((SELECT username FROM users WHERE id = g.black_user_id), 'Guest')
        ELSE COALESCE((SELECT username FROM users WHERE id = g.white_user_id), 'Guest')
      END as opponent,
      CASE 
        WHEN g.result = 'draw' THEN 'Draw'
        WHEN (g.white_user_id = ? AND g.result = 'white') OR (g.black_user_id = ? AND g.result = 'black') THEN 'Won'
        ELSE 'Lost'
      END as result,
      g.mode,
      g.move_count as moves
    FROM games g
    WHERE (g.white_user_id = ? OR g.black_user_id = ?) AND g.status = 'completed'
    ORDER BY g.created_at DESC
    LIMIT 5
  `).bind(userId, userId, userId, userId, userId).all()

  const profile = {
    ...userRes[0],
    stats: statsRes[0] || {},
    recent_games: gamesRes || []
  }

  return c.json(profile)
}

export { profileRoutes }
