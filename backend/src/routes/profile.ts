import { Hono } from 'hono'
import { authMiddleware } from '../middleware/auth'
import type { Env } from '../index'

const profileRoutes = new Hono<{ Bindings: Env; Variables: { user: any } }>()

// Apply auth middleware to all profile routes
profileRoutes.use('*', authMiddleware)

// Get self profile
profileRoutes.get('/', async (c) => {
  const userId = c.get('user').sub
  const { results } = await c.env.DB.prepare(
    'SELECT id, username, avatar_url, rating, created_at FROM users WHERE id = ?'
  ).bind(userId).all()

  if (!results.length) {
    return c.json({ error: 'User not found' }, 404)
  }

  // Get stats
  const { results: stats } = await c.env.DB.prepare(
    'SELECT * FROM user_stats WHERE user_id = ?'
  ).bind(userId).all()

  return c.json({ profile: results[0], stats: stats[0] || {} })
})

// Update self profile
profileRoutes.put('/', async (c) => {
  const userId = c.get('user').sub
  const body = await c.req.json()

  // Validate allowed fields
  const allowedUpdates: Record<string, string> = {}
  if (body.username) allowedUpdates.username = body.username
  if (body.avatar_url) allowedUpdates.avatar_url = body.avatar_url

  if (Object.keys(allowedUpdates).length === 0) {
    return c.json({ error: 'No valid fields to update' }, 400)
  }

  const setClauses = Object.keys(allowedUpdates)
    .map((key) => `${key} = ?`)
    .join(', ')
  const values = Object.values(allowedUpdates)

  try {
    await c.env.DB.prepare(`UPDATE users SET ${setClauses}, updated_at = datetime('now') WHERE id = ?`)
      .bind(...values, userId)
      .run()

    return c.json({ success: true, updated: allowedUpdates })
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
  const { results } = await c.env.DB.prepare(
    'SELECT id, username, avatar_url, rating, is_online, last_seen, created_at FROM users WHERE id = ?'
  ).bind(targetId).all()

  if (!results.length) {
    return c.json({ error: 'User not found' }, 404)
  }

  // Get stats
  const { results: stats } = await c.env.DB.prepare(
    'SELECT games_played, wins, losses, draws, longest_streak, current_streak FROM user_stats WHERE user_id = ?'
  ).bind(targetId).all()

  return c.json({ profile: results[0], stats: stats[0] || {} })
})

export { profileRoutes }
