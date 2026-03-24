import { Hono } from 'hono'
import { z } from 'zod'
import { v4 as uuidv4 } from 'uuid'
import type { Env } from '../index'
import { authMiddleware } from '../middleware/auth'

const game = new Hono<{ Bindings: Env }>()
game.use('*', authMiddleware)

// ────────────────────────────────────────
// CREATE GAME
// ────────────────────────────────────────
const CreateGameSchema = z.object({
  mode: z.enum(['singlePlayer', 'twoPlayer', 'multiplayer', 'tournament']),
  opponentId: z.string().optional(),
  timeControl: z.string().default('10+0'),
  color: z.enum(['white', 'black', 'random']).default('random'),
  aiDifficulty: z.enum(['basic', 'intermediate', 'advanced', 'impossible']).optional(),
  tournamentId: z.string().optional(),
  initialFen: z.string().optional(),
})

game.post('/create', async (c) => {
  const user = c.get('user')
  const body = await c.req.json()
  const parsed = CreateGameSchema.safeParse(body)
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400)

  const { mode, opponentId, timeControl, color, aiDifficulty, tournamentId, initialFen } = parsed.data
  const gameId = uuidv4()
  const now = new Date().toISOString()

  // Determine colors
  let whiteId: string | null = null
  let blackId: string | null = null

  const resolvedColor = color === 'random' ? (Math.random() > 0.5 ? 'white' : 'black') : color
  if (mode === 'singlePlayer' || mode === 'twoPlayer') {
    whiteId = resolvedColor === 'white' ? user.sub : (opponentId ?? null)
    blackId = resolvedColor === 'black' ? user.sub : (opponentId ?? null)
  } else {
    whiteId = resolvedColor === 'white' ? user.sub : (opponentId ?? null)
    blackId = resolvedColor === 'black' ? user.sub : (opponentId ?? null)
  }

  await c.env.DB.prepare(`
    INSERT INTO games (id, white_user_id, black_user_id, mode, status, time_control,
                       ai_difficulty, tournament_id, initial_fen, created_at, updated_at)
    VALUES (?, ?, ?, ?, 'active', ?, ?, ?, ?, ?, ?)
  `).bind(
    gameId, whiteId, blackId, mode, timeControl,
    aiDifficulty ?? null, tournamentId ?? null,
    initialFen ?? 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    now, now
  ).run()

  return c.json({ gameId, whiteId, blackId, color: resolvedColor }, 201)
})

// ────────────────────────────────────────
// SAVE MOVE (server-side validation)
// ────────────────────────────────────────
const MoveSchema = z.object({
  gameId: z.string(),
  from: z.string().length(2),
  to: z.string().length(2),
  promotion: z.enum(['q', 'r', 'b', 'n']).optional(),
  fenAfter: z.string(),
  algebraic: z.string(),
  timeSpent: z.number().optional(),
})

game.post('/move', async (c) => {
  const user = c.get('user')
  const body = await c.req.json()
  const parsed = MoveSchema.safeParse(body)
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400)

  const { gameId, from, to, promotion, fenAfter, algebraic, timeSpent } = parsed.data

  // Get current game state
  const gameRow = await c.env.DB.prepare(
    'SELECT * FROM games WHERE id = ? AND status = ?'
  ).bind(gameId, 'active').first<Record<string, unknown>>()

  if (!gameRow) return c.json({ error: 'Game not found' }, 404)

  // Check it's the user's turn
  const moveCount = await c.env.DB.prepare(
    'SELECT COUNT(*) as cnt FROM moves WHERE game_id = ?'
  ).bind(gameId).first<{ cnt: number }>()

  const isWhite = moveCount!.cnt % 2 === 0
  const userIsWhite = gameRow.white_user_id === user.sub
  const userIsBlack = gameRow.black_user_id === user.sub

  if ((isWhite && !userIsWhite) || (!isWhite && !userIsBlack)) {
    return c.json({ error: 'Not your turn' }, 403)
  }

  const moveNumber = Math.floor(moveCount!.cnt / 2) + 1
  const color = isWhite ? 'white' : 'black'

  // Store move
  await c.env.DB.prepare(`
    INSERT INTO moves (game_id, move_number, color, from_sq, to_sq, promotion, algebraic, fen_after, time_spent)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).bind(gameId, moveNumber, color, from, to, promotion ?? null, algebraic, fenAfter, timeSpent ?? null).run()

  // Update game
  await c.env.DB.prepare(
    'UPDATE games SET move_count = move_count + 1, final_fen = ?, updated_at = ? WHERE id = ?'
  ).bind(fenAfter, new Date().toISOString(), gameId).run()

  return c.json({ ok: true, moveNumber })
})

// ────────────────────────────────────────
// COMPLETE GAME
// ────────────────────────────────────────
const CompleteSchema = z.object({
  gameId: z.string(),
  result: z.enum(['white', 'black', 'draw']),
  termination: z.string(),
  pgn: z.string().optional(),
})

game.post('/complete', async (c) => {
  const body = await c.req.json()
  const parsed = CompleteSchema.safeParse(body)
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400)

  const { gameId, result, termination, pgn } = parsed.data
  const now = new Date().toISOString()

  const gameRow = await c.env.DB.prepare(
    'SELECT * FROM games WHERE id = ?'
  ).bind(gameId).first<Record<string, unknown>>()

  if (!gameRow) return c.json({ error: 'Game not found' }, 404)

  // Update game status
  await c.env.DB.prepare(`
    UPDATE games SET status = 'completed', result = ?, termination = ?, pgn = ?,
                     completed_at = ?, updated_at = ? WHERE id = ?
  `).bind(result, termination, pgn ?? null, now, now, gameId).run()

  // Update ELO ratings (for rated multiplayer games)
  if (gameRow.mode === 'multiplayer' && gameRow.rated) {
    await updateRatings(c.env.DB, gameRow, result)
  }

  // Update stats
  if (gameRow.white_user_id) {
    await updateStats(c.env.DB, gameRow.white_user_id as string, result === 'white' ? 'win' : result === 'black' ? 'loss' : 'draw', gameRow.mode as string)
  }
  if (gameRow.black_user_id) {
    await updateStats(c.env.DB, gameRow.black_user_id as string, result === 'black' ? 'win' : result === 'white' ? 'loss' : 'draw', gameRow.mode as string)
  }

  return c.json({ ok: true })
})

// ────────────────────────────────────────
// GET GAME
// ────────────────────────────────────────
game.get('/:id', async (c) => {
  const gameRow = await c.env.DB.prepare(`
    SELECT g.*, 
      wu.username as white_username, wu.avatar_url as white_avatar, wu.rating as white_rating,
      bu.username as black_username, bu.avatar_url as black_avatar, bu.rating as black_rating
    FROM games g
    LEFT JOIN users wu ON g.white_user_id = wu.id
    LEFT JOIN users bu ON g.black_user_id = bu.id
    WHERE g.id = ?
  `).bind(c.req.param('id')).first()

  if (!gameRow) return c.json({ error: 'Not found' }, 404)

  const moves = await c.env.DB.prepare(
    'SELECT * FROM moves WHERE game_id = ? ORDER BY move_number, color'
  ).bind(c.req.param('id')).all()

  return c.json({ game: gameRow, moves: moves.results })
})

// ────────────────────────────────────────
// GET USER GAMES
// ────────────────────────────────────────
game.get('/user/:userId', async (c) => {
  const limit = Math.min(parseInt(c.req.query('limit') ?? '20'), 50)
  const offset = parseInt(c.req.query('offset') ?? '0')

  const games = await c.env.DB.prepare(`
    SELECT g.id, g.mode, g.status, g.result, g.termination, g.move_count,
           g.time_control, g.created_at, g.completed_at,
           wu.username as white_username, bu.username as black_username
    FROM games g
    LEFT JOIN users wu ON g.white_user_id = wu.id
    LEFT JOIN users bu ON g.black_user_id = bu.id
    WHERE (g.white_user_id = ? OR g.black_user_id = ?)
    AND g.status = 'completed'
    ORDER BY g.completed_at DESC
    LIMIT ? OFFSET ?
  `).bind(c.req.param('userId'), c.req.param('userId'), limit, offset).all()

  return c.json({ games: games.results })
})

// ────────────────────────────────────────
// HELPERS
// ────────────────────────────────────────
async function updateRatings(db: D1Database, gameRow: Record<string, unknown>, result: string) {
  const white = await db.prepare('SELECT rating FROM users WHERE id = ?')
    .bind(gameRow.white_user_id).first<{ rating: number }>()
  const black = await db.prepare('SELECT rating FROM users WHERE id = ?')
    .bind(gameRow.black_user_id).first<{ rating: number }>()
  if (!white || !black) return

  const K = 32
  const expectedW = 1 / (1 + Math.pow(10, (black.rating - white.rating) / 400))
  const scoreW = result === 'white' ? 1 : result === 'draw' ? 0.5 : 0
  const newWhite = Math.round(white.rating + K * (scoreW - expectedW))
  const newBlack = Math.round(black.rating + K * ((1 - scoreW) - (1 - expectedW)))
  const now = new Date().toISOString()

  await db.prepare('UPDATE users SET rating = ? WHERE id = ?').bind(newWhite, gameRow.white_user_id).run()
  await db.prepare('UPDATE users SET rating = ? WHERE id = ?').bind(newBlack, gameRow.black_user_id).run()

  // Log rating history
  await db.prepare(`
    INSERT INTO rating_history (user_id, game_id, rating_before, rating_after, change, created_at)
    VALUES (?, ?, ?, ?, ?, ?)
  `).bind(gameRow.white_user_id, gameRow.id, white.rating, newWhite, newWhite - white.rating, now).run()
  await db.prepare(`
    INSERT INTO rating_history (user_id, game_id, rating_before, rating_after, change, created_at)
    VALUES (?, ?, ?, ?, ?, ?)
  `).bind(gameRow.black_user_id, gameRow.id, black.rating, newBlack, newBlack - black.rating, now).run()
}

async function updateStats(db: D1Database, userId: string, outcome: 'win' | 'loss' | 'draw', mode: string) {
  const field = outcome === 'win' ? 'wins' : outcome === 'loss' ? 'losses' : 'draws'
  const modeField = mode === 'multiplayer' ? 'multiplayer_games' : mode === 'tournament' ? 'tournament_games' : 'ai_games'
  const modeWinField = mode === 'multiplayer' ? 'multiplayer_wins' : mode === 'tournament' ? 'tournament_wins' : 'ai_wins'

  await db.prepare(`
    UPDATE user_stats SET 
      games_played = games_played + 1,
      ${field} = ${field} + 1,
      ${modeField} = ${modeField} + 1,
      ${outcome === 'win' ? `${modeWinField} = ${modeWinField} + 1,` : ''}
      current_streak = CASE WHEN ? = 'win' THEN current_streak + 1 ELSE 0 END,
      longest_streak = CASE WHEN current_streak + 1 > longest_streak AND ? = 'win' THEN current_streak + 1 ELSE longest_streak END,
      updated_at = ?
    WHERE user_id = ?
  `).bind(outcome, outcome, new Date().toISOString(), userId).run()
}

export { game as gameRoutes }
