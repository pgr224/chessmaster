import { Hono } from 'hono'
import { authMiddleware } from '../middleware/auth'
import type { Env } from '../index'

import { v4 as uuidv4 } from 'uuid'

const tournamentRoutes = new Hono<{ Bindings: Env; Variables: { user: any } }>()

// Apply auth middleware to all tournament routes
tournamentRoutes.use('*', authMiddleware)

// List upcoming and active tournaments
tournamentRoutes.get('/', async (c) => {
  const { results } = await c.env.DB.prepare(
    `SELECT * FROM tournaments 
     WHERE status IN ('upcoming', 'registration', 'active') 
     ORDER BY start_time ASC LIMIT 50`
  ).all()

  return c.json({ tournaments: results })
})

// Get specific tournament
tournamentRoutes.get('/:id', async (c) => {
  const tournamentId = c.req.param('id')
  
  const { results: tournaments } = await c.env.DB.prepare(
    'SELECT * FROM tournaments WHERE id = ?'
  ).bind(tournamentId).all()

  if (!tournaments.length) {
    return c.json({ error: 'Tournament not found' }, 404)
  }

  // Get participants
  const { results: participants } = await c.env.DB.prepare(
    `SELECT u.id, u.username, u.rating, tp.seed, tp.status, tp.points 
     FROM tournament_participants tp 
     JOIN users u ON tp.user_id = u.id 
     WHERE tp.tournament_id = ? 
     ORDER BY tp.points DESC, tp.seed ASC`
  ).bind(tournamentId).all()

  return c.json({ 
    tournament: tournaments[0], 
    participants 
  })
})

// Create a new tournament (admin or premium user)
tournamentRoutes.post('/', async (c) => {
  const userId = c.get('user').sub
  const body = await c.req.json()
  const id = uuidv4()
  
  try {
    await c.env.DB.prepare(
      `INSERT INTO tournaments (id, name, description, format, start_time, time_control, created_by) 
       VALUES (?, ?, ?, ?, ?, ?, ?)`
    ).bind(
      id, 
      body.name || 'New Tournament', 
      body.description || '', 
      body.format || 'single_elimination',
      body.start_time || new Date().toISOString(),
      body.time_control || '10+0',
      userId
    ).run()

    return c.json({ success: true, id }, 201)
  } catch (err: any) {
    return c.json({ error: 'Failed to create tournament', details: err.message }, 400)
  }
})

// Join a tournament
tournamentRoutes.post('/:id/join', async (c) => {
  const userId = c.get('user').sub
  const tournamentId = c.req.param('id')

  try {
    // Check if tournament exists and is open
    const { results } = await c.env.DB.prepare(
      'SELECT status, max_players, current_players FROM tournaments WHERE id = ?'
    ).bind(tournamentId).all()

    if (!results.length) return c.json({ error: 'Tournament not found' }, 404)
    
    const t = results[0] as any
    if (t.status !== 'upcoming' && t.status !== 'registration') {
      return c.json({ error: 'Tournament registration is closed' }, 400)
    }
    if (t.current_players >= t.max_players) {
      return c.json({ error: 'Tournament is full' }, 400)
    }

    // Insert participant and update count
    await c.env.DB.batch([
      c.env.DB.prepare(
        'INSERT INTO tournament_participants (tournament_id, user_id) VALUES (?, ?)'
      ).bind(tournamentId, userId),
      c.env.DB.prepare(
        'UPDATE tournaments SET current_players = current_players + 1 WHERE id = ?'
      ).bind(tournamentId)
    ])

    return c.json({ success: true, message: 'Successfully joined tournament' })
  } catch (err: any) {
    if (err.message.includes('UNIQUE constraint failed')) {
      return c.json({ error: 'Already joined this tournament' }, 400)
    }
    return c.json({ error: 'Failed to join tournament' }, 500)
  }
})

export { tournamentRoutes }
