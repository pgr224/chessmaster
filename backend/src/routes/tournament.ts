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

  const type = body.type === 'private' ? 'private' : 'public'
  const totalRounds = Math.min(Math.max(parseInt(body.total_rounds ?? body.totalRounds ?? '3'), 1), 15)
  const invitedPlayers: string[] = Array.isArray(body.invited_players) ? body.invited_players : []

  try {
    await c.env.DB.prepare(
      `INSERT INTO tournaments (id, name, description, format, start_time, time_control, created_by, type, total_rounds) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(
      id,
      body.name || 'New Tournament',
      body.description || '',
      body.format || (type === 'private' ? 'best_of' : 'swiss'),
      body.start_time || new Date().toISOString(),
      body.time_control || '10+0',
      userId,
      type,
      totalRounds,
    ).run()

    // Auto-join creator
    await c.env.DB.prepare(
      'INSERT INTO tournament_participants (tournament_id, user_id) VALUES (?, ?)'
    ).bind(id, userId).run()

    // invited_players: future push-notification hook (not yet implemented)
    if (invitedPlayers.length > 0) {
      console.log(`[tournament] ${invitedPlayers.length} players invited to ${id}`)
    }

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

// Start a tournament (creator only)
tournamentRoutes.post('/:id/start', async (c) => {
  const userId = c.get('user').sub
  const tournamentId = c.req.param('id')

  const { results } = await c.env.DB.prepare(
    'SELECT * FROM tournaments WHERE id = ?'
  ).bind(tournamentId).all()
  if (!results.length) return c.json({ error: 'Tournament not found' }, 404)

  const t = results[0] as any
  if (t.created_by !== userId) return c.json({ error: 'Only the creator can start the tournament' }, 403)
  if (t.status !== 'upcoming' && t.status !== 'registration') {
    return c.json({ error: 'Tournament already started' }, 400)
  }

  await c.env.DB.prepare(
    `UPDATE tournaments SET status = 'active', current_round = 1 WHERE id = ?`
  ).bind(tournamentId).run()

  return c.json({ success: true, message: 'Tournament started' })
})

// Report a match result within a tournament
tournamentRoutes.post('/:id/result', async (c) => {
  const userId = c.get('user').sub
  const tournamentId = c.req.param('id')
  const body = await c.req.json()
  const { game_id, result } = body  // result: 'player1' | 'player2' | 'draw'

  if (!game_id || !result) return c.json({ error: 'game_id and result are required' }, 400)

  const { results: matchRows } = await c.env.DB.prepare(
    'SELECT * FROM tournament_matches WHERE tournament_id = ? AND game_id = ?'
  ).bind(tournamentId, game_id).all()
  if (!matchRows.length) return c.json({ error: 'Match not found' }, 404)

  const match = matchRows[0] as any
  const winnerId = result === 'player1' ? match.player1_id
    : result === 'player2' ? match.player2_id
    : null

  await c.env.DB.prepare(
    `UPDATE tournament_matches SET result = ?, winner_id = ?, status = 'completed' WHERE tournament_id = ? AND game_id = ?`
  ).bind(result, winnerId, tournamentId, game_id).run()

  // Update participant points
  const scoreIncr = result === 'draw' ? 0.5 : 1.0
  if (winnerId) {
    await c.env.DB.prepare(
      'UPDATE tournament_participants SET points = points + ? WHERE tournament_id = ? AND user_id = ?'
    ).bind(scoreIncr, tournamentId, winnerId).run()
  } else {
    // draw: both get 0.5
    await c.env.DB.batch([
      c.env.DB.prepare(
        'UPDATE tournament_participants SET points = points + 0.5 WHERE tournament_id = ? AND user_id = ?'
      ).bind(tournamentId, match.player1_id),
      c.env.DB.prepare(
        'UPDATE tournament_participants SET points = points + 0.5 WHERE tournament_id = ? AND user_id = ?'
      ).bind(tournamentId, match.player2_id),
    ])
  }

  return c.json({ success: true })
})

// Get current standings
tournamentRoutes.get('/:id/standings', async (c) => {
  const tournamentId = c.req.param('id')

  const { results } = await c.env.DB.prepare(
    `SELECT u.id, u.username, u.rating, tp.points, tp.status
     FROM tournament_participants tp
     JOIN users u ON tp.user_id = u.id
     WHERE tp.tournament_id = ?
     ORDER BY tp.points DESC, u.rating DESC`
  ).bind(tournamentId).all()

  return c.json({ standings: results })
})

// Invite a player to a private tournament
tournamentRoutes.post('/:id/invite', async (c) => {
  const userId = c.get('user').sub
  const tournamentId = c.req.param('id')
  const body = await c.req.json()
  const { invited_user_id } = body

  if (!invited_user_id) return c.json({ error: 'invited_user_id is required' }, 400)

  const { results } = await c.env.DB.prepare(
    'SELECT * FROM tournaments WHERE id = ? AND created_by = ?'
  ).bind(tournamentId, userId).all()
  if (!results.length) return c.json({ error: 'Tournament not found or access denied' }, 403)

  try {
    await c.env.DB.prepare(
      'INSERT INTO tournament_participants (tournament_id, user_id, status) VALUES (?, ?, ?)'
    ).bind(tournamentId, invited_user_id, 'invited').run()
    return c.json({ success: true })
  } catch (err: any) {
    if (err.message.includes('UNIQUE')) return c.json({ error: 'Already invited' }, 400)
    return c.json({ error: 'Failed to invite player' }, 500)
  }
})

// Accept a tournament invitation
tournamentRoutes.post('/:id/accept-invite', async (c) => {
  const userId = c.get('user').sub
  const tournamentId = c.req.param('id')

  const { results } = await c.env.DB.prepare(
    `SELECT * FROM tournament_participants WHERE tournament_id = ? AND user_id = ? AND status = 'invited'`
  ).bind(tournamentId, userId).all()
  if (!results.length) return c.json({ error: 'No pending invitation found' }, 404)

  await c.env.DB.prepare(
    `UPDATE tournament_participants SET status = 'active' WHERE tournament_id = ? AND user_id = ?`
  ).bind(tournamentId, userId).run()

  return c.json({ success: true })
})

export { tournamentRoutes }
