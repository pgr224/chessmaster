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
  if (body.username) allowedUpdates.username = body.username
  if (body.avatarUrl) allowedUpdates.avatar_url = body.avatarUrl

  if (Object.keys(allowedUpdates).length === 0) {
    return c.json({ error: 'No valid fields to update' }, 400)
  }

  const setClauses = Object.keys(allowedUpdates).map(k => `${k} = ?`).join(', ')
  const values = Object.values(allowedUpdates)

  try {
    await c.env.DB.prepare(`UPDATE users SET ${setClauses}, updated_at = datetime('now') WHERE id = ?`)
      .bind(...values, userId)
      .run()

    return getFullProfile(c, userId)
  } catch (err: any) {
    if (err.message.includes('UNIQUE constraint failed: users.username')) {
      return c.json({ error: 'Username already taken' }, 409)
    }
    throw err
  }
})

// Get public profile by user ID
profileRoutes.get('/:id', async (c) => {
  const targetId = c.req.param('id')
  return getFullProfile(c, targetId)
})

async function getFullProfile(c: any, userId: string) {
  const { results: userRes } = await c.env.DB.prepare(
    'SELECT id, username, avatar_url, xp, created_at FROM users WHERE id = ?'
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
        WHEN g.white_user_id = ? THEN (SELECT username FROM users WHERE id = g.black_user_id)
        ELSE (SELECT username FROM users WHERE id = g.white_user_id)
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
