import { Hono } from 'hono'
import { authMiddleware } from '../middleware/auth'
import type { Env } from '../index'

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

// Create a new challenge
challengeRoutes.post('/', async (c) => {
  const userId = c.get('user').sub
  const body = await c.req.json()
  const { challenged_id, time_control = '10+0', color_preference = 'random', message = '' } = body

  if (!challenged_id) {
    return c.json({ error: 'challenged_id is required' }, 400)
  }

  const id = uuidv4()

  try {
    await c.env.DB.prepare(
      `INSERT INTO challenges (id, challenger_id, challenged_id, time_control, color_preference, message) 
       VALUES (?, ?, ?, ?, ?, ?)`
    ).bind(id, userId, challenged_id, time_control, color_preference, message).run()

    return c.json({ success: true, id }, 201)
  } catch (err: any) {
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
        `UPDATE challenges SET status = 'accepted', game_id = ? WHERE id = ?`
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
    `UPDATE challenges SET status = 'declined' 
     WHERE id = ? AND challenged_id = ? AND status = 'pending'`
  ).bind(challengeId, userId).run()

  if (result.meta.changes === 0) {
    return c.json({ error: 'Challenge not found or already processed' }, 404)
  }

  return c.json({ success: true })
})

export { challengeRoutes }
