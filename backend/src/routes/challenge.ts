import { Hono } from 'hono'
import { authMiddleware } from '../middleware/auth'
import type { Env } from '../index'
import { normalizeTimeControl, DEFAULT_TIME_CONTROL } from '../time_control'
import { PushService } from '../services/push_service'

import { v4 as uuidv4 } from 'uuid'

const challengeRoutes = new Hono<{ Bindings: Env; Variables: { user: any } }>()

challengeRoutes.use('*', authMiddleware)

// Get active challenges for the current user
challengeRoutes.get('/', async (c) => {
  const userId = c.get('user').sub
  const { results } = await c.env.DB.prepare(
    `SELECT c.*, u.username as challenger_username, u.xp as challenger_xp 
     FROM challenges c 
     JOIN users u ON c.challenger_id = u.id 
     WHERE c.challenged_id = ? AND c.status = 'pending' 
     ORDER BY c.created_at DESC`
  ).bind(userId).all()

  return c.json({ challenges: results })
})

challengeRoutes.get('/count', async (c) => {
  const userId = c.get('user').sub
  const incoming = await c.env.DB.prepare(
    `SELECT COUNT(*) as count
     FROM challenges
     WHERE challenged_id = ? AND status = 'pending'`
  ).bind(userId).first<{ count: number }>()

  const outgoing = await c.env.DB.prepare(
    `SELECT COUNT(*) as count
     FROM challenges
     WHERE challenger_id = ? AND status = 'pending'`
  ).bind(userId).first<{ count: number }>()

  return c.json({
    incoming: incoming?.count ?? 0,
    outgoing: outgoing?.count ?? 0,
    total: (incoming?.count ?? 0) + (outgoing?.count ?? 0),
  })
})

// Create a new challenge
challengeRoutes.post('/', async (c) => {
  const user = c.get('user')
  const userId = user.sub
  const usernameRow = await c.env.DB.prepare('SELECT username FROM users WHERE id = ?')
    .bind(userId)
    .first<{ username: string }>()
  const username = usernameRow?.username ?? 'Someone'
  const body = await c.req.json()
  const challenged_id = body.challenged_id ?? body.challengedId
  const time_control = body.time_control ?? body.timeControl ?? DEFAULT_TIME_CONTROL
  const mode = body.mode === 'tournament' ? 'tournament' : 'duel'
  const variant_id = body.variant_id ?? body.variantId ?? 'standard'
  const delivery_status = body.delivery_status ?? body.deliveryStatus ?? 'live'
  const color_preference = body.color_preference ?? body.colorPreference ?? 'random'
  const message = body.message ?? ''
  const requestId = body.requestId ?? uuidv4()

  if (!challenged_id) {
    return c.json({ error: 'challenged_id is required' }, 400)
  }

  try {
    await c.env.DB.prepare(
      `INSERT INTO challenges (
        id, challenger_id, challenged_id, time_control, mode, variant_id,
        delivery_status, color_preference, message
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(
      requestId,
      userId,
      challenged_id,
      normalizeTimeControl(time_control),
      mode,
      variant_id,
      delivery_status,
      color_preference,
      message,
    ).run()

    // ✨ Trigger Push Notification for the recipient
    // Background task (don't wait for it to complete)
    c.executionCtx.waitUntil(
      PushService.notifyUser(challenged_id, {
        title: '♟️ New Match Invite!',
        body: `${username} challenged you to a ${time_control} ${mode} game!`,
        icon: '/icons/Icon-192.png',
        data: {
          type: 'CHALLENGE_RECEIVED',
          requestId,
          challengerId: userId,
          challengerName: username,
            category: mode === 'tournament' ? 'tournaments' : 'challenges',
          mode,
          timeControl: normalizeTimeControl(time_control),
          variantId: variant_id,
          queued: delivery_status === 'queued',
        }
      }, c.env, mode === 'tournament' ? 'tournaments' : 'challenges')
    )

    return c.json({ success: true, id: requestId }, 201)
  } catch (err: any) {
    console.error('[Challenge Create Error]', err)
    return c.json({ error: 'Failed to create challenge' }, 500)
  }
})

// Accept a challenge
challengeRoutes.post('/:id/accept', async (c) => {
  const userId = c.get('user').sub
  const challengeId = c.req.param('id')

  const { results } = await c.env.DB.prepare(
    'SELECT * FROM challenges WHERE id = ? AND challenged_id = ? AND status = \'pending\''
  ).bind(challengeId, userId).all()

  if (!results.length) {
    return c.json({ error: 'Challenge not found or already processed' }, 404)
  }

  const challenge = results[0] as any
  const gameId = uuidv4()
  
  // Determine colors based on preference
  let whiteId = challenge.challenger_id
  let blackId = challenge.challenged_id
  if (challenge.color_preference === 'black') {
    whiteId = challenge.challenged_id
    blackId = challenge.challenger_id
  } else if (challenge.color_preference === 'random' && Math.random() > 0.5) {
    whiteId = challenge.challenged_id
    blackId = challenge.challenger_id
  }

  try {
    // We create the game and update the challenge in a batch
    await c.env.DB.batch([
      c.env.DB.prepare(
        `INSERT INTO games (id, white_user_id, black_user_id, mode, time_control) 
         VALUES (?, ?, ?, 'multiplayer', ?)`
      ).bind(gameId, whiteId, blackId, challenge.time_control),
      
      c.env.DB.prepare(
        `UPDATE challenges SET status = 'accepted', game_id = ?, updated_at = datetime('now') WHERE id = ?`
      ).bind(gameId, challengeId)
    ])

    return c.json({ success: true, gameId })
  } catch (err: any) {
    return c.json({ error: 'Failed to accept challenge' }, 500)
  }
})

// Decline a challenge
challengeRoutes.post('/:id/decline', async (c) => {
  const userId = c.get('user').sub
  const challengeId = c.req.param('id')

  const result = await c.env.DB.prepare(
    `UPDATE challenges SET status = 'declined', updated_at = datetime('now') 
     WHERE id = ? AND challenged_id = ? AND status = 'pending'`
  ).bind(challengeId, userId).run()

  if (result.meta.changes === 0) {
    return c.json({ error: 'Challenge not found or already processed' }, 404)
  }

  return c.json({ success: true })
})

export { challengeRoutes }
