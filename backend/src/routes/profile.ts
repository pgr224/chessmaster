import { Hono } from 'hono'
import { authMiddleware } from '../middleware/auth'
import type { Env } from '../index'
import { PushService } from '../services/push_service'

const profileRoutes = new Hono<{ Bindings: Env; Variables: { user: any } }>()

async function ensureXpSocialTables(c: any) {
  await c.env.DB.batch([
    c.env.DB.prepare(`
      CREATE TABLE IF NOT EXISTS xp_requests_v2 (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        requester_id TEXT NOT NULL REFERENCES users(id),
        target_user_id TEXT REFERENCES users(id),
        amount INTEGER NOT NULL,
        request_type TEXT NOT NULL CHECK(request_type IN ('broadcast','direct')),
        status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','fulfilled','rejected','expired','cancelled')),
        expires_at TEXT NOT NULL,
        fulfilled_by TEXT REFERENCES users(id),
        fulfilled_at TEXT,
        responded_at TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    `),
    c.env.DB.prepare(`
      CREATE INDEX IF NOT EXISTS idx_xp_requests_v2_open
      ON xp_requests_v2(status, request_type, expires_at)
    `),
    c.env.DB.prepare(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_xp_requests_v2_one_open_per_user
      ON xp_requests_v2(requester_id)
      WHERE status = 'open'
    `),
    c.env.DB.prepare(`
      CREATE TABLE IF NOT EXISTS xp_friendships (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_a TEXT NOT NULL REFERENCES users(id),
        user_b TEXT NOT NULL REFERENCES users(id),
        requested_by TEXT NOT NULL REFERENCES users(id),
        status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','accepted','rejected','blocked')),
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        responded_at TEXT,
        UNIQUE(user_a, user_b)
      )
    `),
    c.env.DB.prepare(`
      CREATE INDEX IF NOT EXISTS idx_xp_friendships_status
      ON xp_friendships(status, updated_at)
    `)
  ])
}

function pairUsers(a: string, b: string): [string, string] {
  return a < b ? [a, b] : [b, a]
}

async function expireStaleRequests(c: any) {
  await c.env.DB.prepare(`
    UPDATE xp_requests_v2
    SET status = 'expired', updated_at = datetime('now')
    WHERE status = 'open' AND datetime(expires_at) <= datetime('now')
  `).run()
}

// Apply auth middleware to all profile routes
profileRoutes.use('*', authMiddleware)

// Get self profile
profileRoutes.get('/', async (c) => {
  const userId = c.get('user').sub
  return getFullProfile(c, userId)
})

// Check username availability with rate limit info
profileRoutes.get('/check-username/:username', async (c) => {
  try {
    const username = (c.req.param('username') || '').trim()
    if (!username || username.length < 3 || username.length > 30) {
      return c.json({ available: false, error: 'Username must be 3-30 characters' }, 400)
    }

    const userId = c.get('user').sub

    // Check if username exists
    const existing = await c.env.DB.prepare(
      'SELECT id FROM users WHERE username = ? COLLATE NOCASE'
    ).bind(username).first<{ id: string }>()

    const userInfo = await c.env.DB.prepare(
      'SELECT username_changes, last_username_change FROM users WHERE id = ?'
    ).bind(userId).first<{ username_changes: number; last_username_change: string | null }>()

    // Calculate rate limit info
    let canChangeNow = true
    let nextChangeTime: number | null = null
    let remainingLifetimeChanges = 3

    if (userInfo) {
      remainingLifetimeChanges = Math.max(0, 3 - (userInfo.username_changes || 0))
      
      // Check 24-hour cooldown
      if (userInfo.last_username_change) {
        const lastChange = new Date(userInfo.last_username_change).getTime()
        const now = Date.now()
        const elapsed = now - lastChange
        const cooldownMs = 24 * 60 * 60 * 1000 // 24 hours
        
        if (elapsed < cooldownMs) {
          canChangeNow = false
          nextChangeTime = lastChange + cooldownMs
        }
      }
    }

    return c.json({
      available: !existing || existing.id === userId,
      username,
      canChangeNow: canChangeNow && remainingLifetimeChanges > 0,
      remainingLifetimeChanges,
      nextChangeTime,
      reason: !canChangeNow ? 'cooldown' : remainingLifetimeChanges === 0 ? 'lifetime_limit' : undefined
    })
  } catch (err) {
    console.error('[CheckUsername] Error:', err)
    return c.json({ available: false, error: 'Check failed' }, 500)
  }
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
    try {
      const userRes = await c.env.DB.prepare(
        'SELECT username, username_changes, last_username_change FROM users WHERE id = ?'
      ).bind(userId).first<{ username: string; username_changes: number; last_username_change: string | null }>()

      if (!userRes) {
        return c.json({ error: 'User not found' }, 404)
      }

      const currentName = userRes.username
      const currentChanges = userRes.username_changes || 0
      const lastChange = userRes.last_username_change

      // Only check limits if name is actually being changed
      if (body.username !== currentName) {
        // Check lifetime limit (3 total changes)
        if (currentChanges >= 3) {
          return c.json(
            {
              error: 'LIFETIME_LIMIT_REACHED',
              message: 'You have reached the maximum number of name changes (3 lifetime)',
              changesUsed: currentChanges,
              changesAllowed: 3
            },
            403
          )
        }

        // Check 24-hour cooldown
        if (lastChange) {
          const lastChangeTime = new Date(lastChange).getTime()
          const now = Date.now()
          const elapsed = now - lastChangeTime
          const cooldownMs = 24 * 60 * 60 * 1000 // 24 hours

          if (elapsed < cooldownMs) {
            const nextAllowedTime = lastChangeTime + cooldownMs
            return c.json(
              {
                error: 'COOLDOWN_ACTIVE',
                message: 'You can only change your name once every 24 hours',
                lastChangeTime,
                nextChangeTime: nextAllowedTime,
                cooldownRemainingMs: cooldownMs - elapsed,
                changesUsed: currentChanges,
                changesAllowed: 3
              },
              429
            )
          }
        }

        // Check if username is available
        const usernameExists = await c.env.DB.prepare(
          'SELECT id FROM users WHERE username = ? AND id != ?'
        ).bind(body.username, userId).first()

        if (usernameExists) {
          return c.json(
            {
              error: 'USERNAME_TAKEN',
              message: 'Username is already taken'
            },
            409
          )
        }

        allowedUpdates.username = body.username
        allowedUpdates.username_changes = currentChanges + 1
        allowedUpdates.last_username_change = new Date().toISOString()
      }
    } catch (err: any) {
      console.error('[ProfileUpdate] Username validation error:', err)
      return c.json({ error: 'Username validation failed' }, 500)
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

    // If username was changed, log it for tracking and notify systems
    if (allowedUpdates.username) {
      const oldUserRes = await c.env.DB.prepare(
        'SELECT username FROM users WHERE id = ?'
      ).bind(userId).first<{ username: string }>()
      const oldName = oldUserRes?.username || 'Unknown'
      
      console.info(
        `[ProfileUpdate] Username changed for ${userId}: ${oldName} -> ${allowedUpdates.username} (Changes: ${allowedUpdates.username_changes}/3)`
      )
    }

    let token: string | undefined = undefined;
    if (body.username) {
      const jwtPayload = c.get('user')
      const { sign } = await import('hono/jwt')
      token = await sign(
        { sub: userId, username: body.username, deviceId: jwtPayload.deviceId, exp: Math.floor(Date.now() / 1000) + 86400 * 30 },
        c.env.JWT_SECRET
      )
    }

    const data = await buildProfileData(c, userId)
    if (!data) {
      return c.json({ error: 'User not found' }, 404)
    }
    const responseData = token ? { ...data, token } : data
    return c.json(responseData)
  } catch (err: any) {
    if (err.message.includes('UNIQUE constraint failed: users.username')) {
      return c.json({ error: 'Username already taken' }, 409)
    }
    throw err
  }
})

// Unlock Achievement & Award XP
profileRoutes.post('/:id/unlock-achievement', async (c) => {
  const userId = c.get('user').sub
  const targetId = c.req.param('id')
  
  if (userId !== targetId) {
    return c.json({ error: 'Unauthorized' }, 403)
  }

  const { achievementId, points } = await c.req.json() as { achievementId: string, points: number }
  
  try {
    // 1. Check if already unlocked to prevent double-dipping XP
    const existing = await c.env.DB.prepare(
      'SELECT 1 FROM user_achievements WHERE user_id = ? AND achievement_id = ?'
    ).bind(userId, achievementId).first()

    if (existing) {
      return c.json({ success: true, message: 'Already unlocked' })
    }

    // 2. Atomic update: Record achievement and award XP
    await c.env.DB.batch([
      c.env.DB.prepare('INSERT INTO user_achievements (user_id, achievement_id) VALUES (?, ?)')
        .bind(userId, achievementId),
      c.env.DB.prepare('UPDATE users SET xp = xp + ?, updated_at = datetime("now") WHERE id = ?')
        .bind(points, userId),
      // Also update user_stats xp for consistency (though users.xp is the master)
      c.env.DB.prepare('UPDATE user_stats SET xp = xp + ?, updated_at = datetime("now") WHERE user_id = ?')
        .bind(points, userId)
    ])

    return c.json({ 
      success: true, 
      achievementId,
      xpAwarded: points 
    })
  } catch (err: any) {
    console.error('Achievement unlock failed:', err)
    return c.json({ error: 'Database error', message: err.message }, 500)
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
      
      // 2. Update stats and unified XP
      c.env.DB.prepare(`
        UPDATE user_stats 
        SET 
          wins = wins + ?,
          losses = losses + ?,
          draws = draws + ?,
          games_played = games_played + ?,
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
        (stats.wins || 0) + (stats.losses || 0) + (stats.draws || 0),
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
  await ensureXpSocialTables(c)
  await expireStaleRequests(c)

  const donorId = c.get('user').sub
  const { recipientId, amount, requestId } = await c.req.json() as { recipientId: string, amount: number, requestId?: number }
  
  if (!recipientId || recipientId === donorId) return c.json({ error: 'Invalid recipient' }, 400)
  if (!Number.isFinite(amount) || amount <= 0) return c.json({ error: 'Invalid amount' }, 400)

  const normalizedAmount = Math.floor(amount)

  const donatedAgg = await c.env.DB.prepare(`
    SELECT
      COALESCE(SUM(amount), 0) as total_donated,
      COALESCE(SUM(CASE WHEN date(created_at) = date('now') THEN amount ELSE 0 END), 0) as donated_today
    FROM xp_transfers
    WHERE donor_id = ?
  `).bind(donorId).first<{ total_donated: number; donated_today: number }>()

  const donatedToday = Number(donatedAgg?.donated_today ?? 0)
  const totalDonated = Number(donatedAgg?.total_donated ?? 0)
  if (donatedToday + normalizedAmount > 2000) {
    return c.json({ error: 'Daily donation limit (2000 XP) reached.' }, 400)
  }
  if (totalDonated + normalizedAmount > 10000) {
    return c.json({ error: 'Total donation limit (10000 XP) reached.' }, 400)
  }

  // Verify donor has enough XP and recipient exists
  const { results: donor } = await c.env.DB.prepare('SELECT xp, username FROM users WHERE id = ?').bind(donorId).all()
  const { results: recipient } = await c.env.DB.prepare('SELECT id, username FROM users WHERE id = ?').bind(recipientId).all()
  if (!donor.length || !recipient.length || (donor[0].xp as number) < normalizedAmount) {
    return c.json({ error: 'Insufficient XP' }, 400)
  }

  try {
    const donorUpdate = await c.env.DB.prepare('UPDATE users SET xp = xp - ? WHERE id = ? AND xp >= ?')
      .bind(normalizedAmount, donorId, normalizedAmount)
      .run()

    if ((donorUpdate.meta.changes || 0) === 0) {
      return c.json({ error: 'Insufficient XP' }, 400)
    }

    await c.env.DB.batch([
      c.env.DB.prepare('UPDATE users SET xp = xp + ? WHERE id = ?').bind(normalizedAmount, recipientId),
      c.env.DB.prepare('INSERT INTO xp_transfers (donor_id, recipient_id, amount) VALUES (?, ?, ?)')
        .bind(donorId, recipientId, normalizedAmount)
    ])

    if (requestId != null) {
      await c.env.DB.prepare(`
        UPDATE xp_requests_v2
        SET status = 'fulfilled', fulfilled_by = ?, fulfilled_at = datetime('now'), updated_at = datetime('now')
        WHERE id = ? AND status = 'open'
      `).bind(donorId, requestId).run()
    }

    // Check donation badge
    const { results: donatedTotals } = await c.env.DB.prepare(
      'SELECT SUM(amount) as total FROM xp_transfers WHERE donor_id = ?'
    ).bind(donorId).all()
    
    if ((donatedTotals[0]?.total as number) >= 500) {
       await c.env.DB.prepare('INSERT OR IGNORE INTO user_achievements (user_id, achievement_id) VALUES (?, ?)')
          .bind(donorId, 'generous_donor')
          .run();
    }

    const donorUser = await c.env.DB.prepare('SELECT xp FROM users WHERE id = ?')
      .bind(donorId)
      .first<{ xp: number }>()
    const recipientUser = await c.env.DB.prepare('SELECT xp FROM users WHERE id = ?')
      .bind(recipientId)
      .first<{ xp: number }>()

    const donatedAfter = await c.env.DB.prepare(`
      SELECT
        COALESCE(SUM(amount), 0) as total_donated,
        COALESCE(SUM(CASE WHEN date(created_at) = date('now') THEN amount ELSE 0 END), 0) as donated_today
      FROM xp_transfers
      WHERE donor_id = ?
    `).bind(donorId).first<{ total_donated: number; donated_today: number }>()

    c.executionCtx.waitUntil((async () => {
      try {
        const lobbyId = c.env.LOBBY.idFromName('global_lobby')
        const lobbyStub = c.env.LOBBY.get(lobbyId)
        await lobbyStub.fetch('https://internal/lobby/internal/xp-update', {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({
            donorId,
            donorName: donor[0]?.username ?? 'Player',
            donorXp: Number(donorUser?.xp ?? 0),
            recipientId,
            recipientName: recipient[0]?.username ?? 'Player',
            recipientXp: Number(recipientUser?.xp ?? 0),
            amount: normalizedAmount,
            ts: Date.now(),
          }),
        })
      } catch (err) {
        console.error('Failed to dispatch lobby XP update:', err)
      }
    })())

    return c.json({
      success: true,
      donorId,
      recipientId,
      amount: normalizedAmount,
      donorXp: Number(donorUser?.xp ?? 0),
      recipientXp: Number(recipientUser?.xp ?? 0),
      donorDonationStats: {
        dailyDonatedXP: Number(donatedAfter?.donated_today ?? 0),
        totalDonatedXP: Number(donatedAfter?.total_donated ?? 0),
        lastDonationDate: new Date().toISOString().split('T')[0],
      },
    })
  } catch (err: any) {
    return c.json({ error: err.message }, 500)
  }
})

// Request XP from network (broadcast or direct friend request)
profileRoutes.post('/xp/request', async (c) => {
  try {
    await ensureXpSocialTables(c)
    await expireStaleRequests(c)

    const userId = c.get('user').sub
    const usernameRow = await c.env.DB.prepare('SELECT username FROM users WHERE id = ?')
      .bind(userId)
      .first<{ username: string }>()
    const username = usernameRow?.username ?? 'Someone'
    const { amount, targetUserId } = await c.req.json() as { amount: number, targetUserId?: string }

    if (!Number.isFinite(amount) || amount <= 0) {
      return c.json({ error: 'Invalid amount' }, 400)
    }

    const normalizedAmount = Math.floor(amount)
    const requestType = targetUserId ? 'direct' : 'broadcast'

    const { results: existingOpen } = await c.env.DB.prepare(`
      SELECT id FROM xp_requests_v2 WHERE requester_id = ? AND status = 'open' LIMIT 1
    `).bind(userId).all()
    if (existingOpen.length) {
      return c.json({ error: 'You already have an open XP request' }, 409)
    }

    if (requestType === 'direct') {
      if (!targetUserId || targetUserId === userId) {
        return c.json({ error: 'Invalid target user' }, 400)
      }

      const [a, b] = pairUsers(userId, targetUserId)
      const { results: friendship } = await c.env.DB.prepare(`
        SELECT status FROM xp_friendships WHERE user_a = ? AND user_b = ? LIMIT 1
      `).bind(a, b).all()

      if (!friendship.length || friendship[0].status !== 'accepted') {
        return c.json({ error: 'Direct XP request requires an accepted friendship' }, 403)
      }
    }

    const expiryMinutes = requestType === 'direct' ? 24 * 60 : 10
    
    const insert = await c.env.DB.prepare(`
      INSERT INTO xp_requests_v2 (requester_id, target_user_id, amount, request_type, status, expires_at)
      VALUES (?, ?, ?, ?, 'open', datetime('now', '+' || ? || ' minutes'))
    `).bind(userId, targetUserId ?? null, normalizedAmount, requestType, expiryMinutes).run()

    const requestId = insert.meta.last_row_id as number

    if (requestType === 'direct' && targetUserId) {
      c.executionCtx.waitUntil(
        PushService.notifyUser(targetUserId, {
          title: 'XP Help Request',
          body: `${username} requested ${normalizedAmount} XP from you.`,
          icon: '/icons/Icon-192.png',
          data: {
            type: 'XP_DIRECT_REQUEST',
            requestId,
            requesterName: username,
            category: 'community',
            amount: normalizedAmount,
          }
        }, c.env, 'community')
      )
    }

    return c.json({
      success: true,
      request: {
        id: requestId,
        amount: normalizedAmount,
        requestType,
      }
    })
  } catch (err: any) {
    console.error('XP request error:', err)
    return c.json({ error: err.message || 'Internal server error' }, 500)
  }
})

// Backward-compatible broadcast endpoint used by older app clients
profileRoutes.post('/xp/broadcast-request', async (c) => {
  await ensureXpSocialTables(c)
  await expireStaleRequests(c)

  const userId = c.get('user').sub
  const { amount } = await c.req.json() as { amount: number }

  if (!Number.isFinite(amount) || amount <= 0) {
    return c.json({ error: 'Invalid amount' }, 400)
  }

  const { results: existingOpen } = await c.env.DB.prepare(`
    SELECT id FROM xp_requests_v2 WHERE requester_id = ? AND status = 'open' LIMIT 1
  `).bind(userId).all()
  if (existingOpen.length) {
    return c.json({ error: 'You already have an open XP request' }, 409)
  }

  const normalizedAmount = Math.floor(amount)
  const insert = await c.env.DB.prepare(`
    INSERT INTO xp_requests_v2 (requester_id, target_user_id, amount, request_type, status, expires_at)
    VALUES (?, NULL, ?, 'broadcast', 'open', datetime('now', '+10 minutes'))
  `).bind(userId, normalizedAmount).run()

  return c.json({
    success: true,
    request: {
      id: insert.meta.last_row_id,
      amount: normalizedAmount,
      requestType: 'broadcast',
    }
  })
})

// Active broadcast requests visible in lobby
profileRoutes.get('/xp/broadcast-requests', async (c) => {
  await ensureXpSocialTables(c)
  await expireStaleRequests(c)

  const userId = c.get('user').sub
  const { results } = await c.env.DB.prepare(`
    SELECT
      r.id,
      r.requester_id as userId,
      u.username,
      r.amount,
      r.created_at,
      r.expires_at
    FROM xp_requests_v2 r
    JOIN users u ON u.id = r.requester_id
    WHERE r.request_type = 'broadcast'
      AND r.status = 'open'
      AND datetime(r.expires_at) > datetime('now')
      AND r.requester_id != ?
    ORDER BY r.created_at DESC
  `).bind(userId).all()

  return c.json({ success: true, requests: results })
})

profileRoutes.get('/xp/request/:id', async (c) => {
  await ensureXpSocialTables(c)
  await expireStaleRequests(c)

  const userId = c.get('user').sub
  const requestId = Number(c.req.param('id'))
  if (!Number.isFinite(requestId)) return c.json({ error: 'Invalid request id' }, 400)

  const { results } = await c.env.DB.prepare(`
    SELECT r.*, u.username as requester_username
    FROM xp_requests_v2 r
    JOIN users u ON u.id = r.requester_id
    WHERE r.id = ?
      AND (r.requester_id = ? OR r.target_user_id = ?)
    LIMIT 1
  `).bind(requestId, userId, userId).all()

  if (!results.length) return c.json({ error: 'Request not found' }, 404)
  return c.json({ success: true, request: results[0] })
})

profileRoutes.post('/xp/request/:id/respond', async (c) => {
  await ensureXpSocialTables(c)
  await expireStaleRequests(c)

  const responderId = c.get('user').sub
  const responderRow = await c.env.DB.prepare('SELECT username FROM users WHERE id = ?')
    .bind(responderId)
    .first<{ username: string }>()
  const responderName = responderRow?.username ?? 'A player'
  const requestId = Number(c.req.param('id'))
  const { action } = await c.req.json() as { action: 'accept' | 'reject' }

  if (!Number.isFinite(requestId)) return c.json({ error: 'Invalid request id' }, 400)
  if (action !== 'accept' && action !== 'reject') return c.json({ error: 'Invalid action' }, 400)

  const { results } = await c.env.DB.prepare(`
    SELECT * FROM xp_requests_v2
    WHERE id = ? AND status = 'open' AND request_type = 'direct' AND target_user_id = ?
    LIMIT 1
  `).bind(requestId, responderId).all()

  if (!results.length) {
    return c.json({ error: 'Direct request not found or already processed' }, 404)
  }

  const request = results[0] as any
  if (action === 'reject') {
    await c.env.DB.prepare(`
      UPDATE xp_requests_v2
      SET status = 'rejected', responded_at = datetime('now'), updated_at = datetime('now')
      WHERE id = ?
    `).bind(requestId).run()

    c.executionCtx.waitUntil(
      PushService.notifyUser(request.requester_id, {
        title: 'XP Request Rejected',
        body: `${responderName} declined your XP request.`,
        data: { type: 'XP_REQUEST_REJECTED', requestId, category: 'community' }
      }, c.env, 'community')
    )

    return c.json({ success: true, status: 'rejected' })
  }

  const amount = Number(request.amount)
  const { results: donor } = await c.env.DB.prepare('SELECT xp FROM users WHERE id = ?').bind(responderId).all()
  if (!donor.length || Number(donor[0].xp) < amount) {
    return c.json({ error: 'Insufficient XP to fulfill request' }, 400)
  }

  const donorUpdate = await c.env.DB.prepare('UPDATE users SET xp = xp - ? WHERE id = ? AND xp >= ?')
    .bind(amount, responderId, amount)
    .run()
  if ((donorUpdate.meta.changes || 0) === 0) {
    return c.json({ error: 'Insufficient XP to fulfill request' }, 400)
  }

  await c.env.DB.batch([
    c.env.DB.prepare('UPDATE users SET xp = xp + ? WHERE id = ?').bind(amount, request.requester_id),
    c.env.DB.prepare('INSERT INTO xp_transfers (donor_id, recipient_id, amount) VALUES (?, ?, ?)')
      .bind(responderId, request.requester_id, amount),
    c.env.DB.prepare(`
      UPDATE xp_requests_v2
      SET status = 'fulfilled', fulfilled_by = ?, fulfilled_at = datetime('now'), responded_at = datetime('now'), updated_at = datetime('now')
      WHERE id = ? AND status = 'open'
    `).bind(responderId, requestId)
  ])

  c.executionCtx.waitUntil(
    PushService.notifyUser(request.requester_id, {
      title: 'XP Request Fulfilled',
      body: `${responderName} donated ${amount} XP to you.`,
      data: {
        type: 'XP_REQUEST_FULFILLED',
        requestId,
        amount,
        category: 'community',
      }
    }, c.env, 'community')
  )

  return c.json({ success: true, status: 'fulfilled', amount })
})

profileRoutes.post('/xp/friends/request', async (c) => {
  await ensureXpSocialTables(c)
  const requesterId = c.get('user').sub
  const { friendUserId } = await c.req.json() as { friendUserId: string }

  if (!friendUserId || friendUserId === requesterId) {
    return c.json({ error: 'Invalid friend user id' }, 400)
  }

  const [a, b] = pairUsers(requesterId, friendUserId)

  const { results: existing } = await c.env.DB.prepare(`
    SELECT status FROM xp_friendships WHERE user_a = ? AND user_b = ?
  `).bind(a, b).all()

  if (existing.length && existing[0].status === 'accepted') {
    return c.json({ success: true, status: 'accepted' })
  }

  await c.env.DB.prepare(`
    INSERT INTO xp_friendships (user_a, user_b, requested_by, status, created_at, updated_at)
    VALUES (?, ?, ?, 'pending', datetime('now'), datetime('now'))
    ON CONFLICT(user_a, user_b)
    DO UPDATE SET requested_by = excluded.requested_by, status = 'pending', updated_at = datetime('now'), responded_at = NULL
  `).bind(a, b, requesterId).run()

  return c.json({ success: true, status: 'pending' })
})

profileRoutes.post('/xp/friends/:friendUserId/respond', async (c) => {
  await ensureXpSocialTables(c)
  const userId = c.get('user').sub
  const friendUserId = c.req.param('friendUserId')
  const { action } = await c.req.json() as { action: 'accept' | 'reject' }

  if (action !== 'accept' && action !== 'reject') {
    return c.json({ error: 'Invalid action' }, 400)
  }

  const [a, b] = pairUsers(userId, friendUserId)
  const { results } = await c.env.DB.prepare(`
    SELECT * FROM xp_friendships WHERE user_a = ? AND user_b = ? LIMIT 1
  `).bind(a, b).all()

  if (!results.length) return c.json({ error: 'Friend request not found' }, 404)
  const row = results[0] as any
  if (row.requested_by === userId) return c.json({ error: 'Requester cannot respond to own invite' }, 403)
  if (row.status !== 'pending') return c.json({ error: 'Friend request already processed' }, 409)

  await c.env.DB.prepare(`
    UPDATE xp_friendships
    SET status = ?, responded_at = datetime('now'), updated_at = datetime('now')
    WHERE user_a = ? AND user_b = ?
  `).bind(action === 'accept' ? 'accepted' : 'rejected', a, b).run()

  return c.json({ success: true, status: action === 'accept' ? 'accepted' : 'rejected' })
})

profileRoutes.get('/xp/friends', async (c) => {
  await ensureXpSocialTables(c)
  const userId = c.get('user').sub

  const { results } = await c.env.DB.prepare(`
    SELECT
      CASE WHEN f.user_a = ? THEN f.user_b ELSE f.user_a END as user_id,
      u.username,
      u.xp,
      u.is_online,
      f.status,
      f.requested_by,
      f.updated_at
    FROM xp_friendships f
    JOIN users u ON u.id = CASE WHEN f.user_a = ? THEN f.user_b ELSE f.user_a END
    WHERE f.user_a = ? OR f.user_b = ?
    ORDER BY f.updated_at DESC
  `).bind(userId, userId, userId, userId).all()

  return c.json({ success: true, friends: results })
})

// Get public profile by user ID
profileRoutes.get('/:id', async (c) => {
  const targetId = c.req.param('id')
  return getFullProfile(c, targetId)
})

// Helper function to build profile data without returning Response
async function buildProfileData(c: any, userId: string) {
  try {
    // 1. Ensure user_stats exists (safety for new users)
    try {
      await c.env.DB.prepare(
        'INSERT OR IGNORE INTO user_stats (user_id) VALUES (?)'
      ).bind(userId).run()
    } catch (statsErr) {
      console.warn('[buildProfileData] Could not ensure user_stats:', statsErr)
    }

    // 2. Get Unified Profile & Stats — The single source of truth
    const profileResult = await c.env.DB.prepare(
      'SELECT * FROM unified_player_scoring WHERE id = ?'
    ).bind(userId).all()
    
    const rows = profileResult.results || profileResult
    if (!rows || !Array.isArray(rows) || rows.length === 0) {
      console.warn('[buildProfileData] User not found for userId:', userId)
      return null
    }

    const unified = rows[0]

    // 3. Get extra account info not in the scoring view
    const userAccount = await c.env.DB.prepare(
      'SELECT is_ghibli, local_avatar, username_changes, last_username_change, created_at FROM users WHERE id = ?'
    ).bind(userId).first<{ 
      is_ghibli: number; 
      local_avatar: string | null; 
      username_changes: number; 
      last_username_change: string | null;
      created_at: string;
    }>()

    // Get recent games (with safe defaults if fails)
    let recentGames = []
    try {
      const gamesResult = await c.env.DB.prepare(`
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
      const gamesRes = gamesResult.results || gamesResult
      if (gamesRes && Array.isArray(gamesRes)) {
        recentGames = gamesRes
      }
    } catch (gamesErr) {
      console.warn('[buildProfileData] Could not fetch recent games:', gamesErr)
    }

    // 4. Get achievements
    const achievementRes = await c.env.DB.prepare(
      'SELECT achievement_id FROM user_achievements WHERE user_id = ?'
    ).bind(userId).all<{ achievement_id: string }>()
    const achievements = (achievementRes.results || []).map(a => a.achievement_id)

    const profile = {
      id: unified.id,
      username: unified.username,
      avatarUrl: unified.avatar_url,
      isGhibli: (userAccount?.is_ghibli || 0) === 1,
      localAvatar: userAccount?.local_avatar || null,
      usernameChanges: userAccount?.username_changes || 0,
      lastUsernameChange: userAccount?.last_username_change,
      xp: unified.xp,
      createdAt: userAccount?.created_at,
      lastLogin: unified.last_login,
      deviceModel: unified.device_model,
      stats: unified, // The unified object contains all stats including wins, elo, etc.
      recentGames: recentGames,
      achievements: achievements,
      // Calculate rate limit info for frontend
      remainingNameChanges: Math.max(0, 3 - (userAccount?.username_changes || 0)),
      canChangeNameNow: !userAccount?.last_username_change || (Date.now() - new Date(userAccount.last_username_change).getTime() >= 24 * 60 * 60 * 1000)
    }
    
    return profile
  } catch (err) {
    console.error('[buildProfileData] Unexpected error:', err)
    const errorMessage = err instanceof Error ? err.message : String(err)
    console.error('[buildProfileData] Error message:', errorMessage)
    throw err
  }
}

export async function getFullProfile(c: any, userId: string) {
  try {
    const profile = await buildProfileData(c, userId)
    if (!profile) {
      return c.json({ error: 'User not found' }, 404)
    }
    return c.json(profile)
  } catch (err) {
    console.error('Error in getFullProfile:', err)
    const errorStack = err instanceof Error ? err.stack : undefined
    console.error('Stack:', errorStack)
    throw err
  }
}

export { profileRoutes, buildProfileData }
