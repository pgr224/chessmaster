import { Hono } from 'hono'
import { z } from 'zod'
import { v4 as uuidv4 } from 'uuid'
import type { Env } from '../index'
import { authMiddleware } from '../middleware/auth'
import { normalizeTimeControl, DEFAULT_TIME_CONTROL } from '../time_control'
import { calculateMultiplayerXP, calculateAIGameXP } from '../xp_rules'
import { StatsService } from '../services/stats_service'

const game = new Hono<{ Bindings: Env; Variables: { user: any } }>()
game.use('*', authMiddleware)

// ────────────────────────────────────────
// CREATE GAME
// ────────────────────────────────────────
const CreateGameSchema = z.object({
  gameId: z.string().optional(),
  mode: z.enum(['singlePlayer', 'twoPlayer', 'multiplayer', 'tournament', 'tutorial', 'puzzle', 'practice']),
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

  const { gameId: clientGameId, mode, opponentId, timeControl, color, aiDifficulty, tournamentId, initialFen } = parsed.data
  const gameId = clientGameId ?? uuidv4()
  const now = new Date().toISOString()
  const normalizedTimeControl = normalizeTimeControl(timeControl ?? DEFAULT_TIME_CONTROL)

  // Determine colors
  let whiteId: string | null = null
  let blackId: string | null = null

  const userId = user.sub || user.id || null
  if (!userId) return c.json({ error: 'User ID missing from token' }, 401)

  // Prevent foreign-key insert failures from surfacing as 500 by validating
  // that the authenticated user still exists in the users table.
  const userRow = await c.env.DB.prepare('SELECT id FROM users WHERE id = ?')
    .bind(userId)
    .first<{ id: string }>()
  if (!userRow?.id) {
    return c.json({ error: 'Authenticated user not found. Please login again.' }, 401)
  }
  
  const resolvedColor = color === 'random' ? (Math.random() > 0.5 ? 'white' : 'black') : color
  
  if (resolvedColor === 'white') {
    whiteId = userId;
    blackId = opponentId ?? null;
  } else {
    whiteId = opponentId ?? null;
    blackId = userId;
  }

  // Guard against missing modes or fallback to singlePlayer for custom modes if necessary
  const validModes = ['singlePlayer', 'twoPlayer', 'multiplayer', 'tournament', 'tutorial', 'puzzle', 'practice'];
  const dbMode = validModes.includes(mode) ? mode : 'singlePlayer';

  try {
    const res = await c.env.DB.prepare(`
      INSERT OR IGNORE INTO games (id, white_user_id, black_user_id, mode, status, time_control,
                         ai_difficulty, tournament_id, initial_fen, created_at, updated_at)
      VALUES (?, ?, ?, ?, 'active', ?, ?, ?, ?, ?, ?)
    `).bind(
      gameId, whiteId, blackId, dbMode, normalizedTimeControl,
      aiDifficulty ?? null, tournamentId ?? null,
      initialFen ?? 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      now, now
    ).run()

    return c.json({ gameId, whiteId, blackId, color: resolvedColor }, 201)
  } catch (err: any) {
    console.error('Game creation primary insert failed, trying fallback:', err)
    try {
      await c.env.DB.prepare(`
        INSERT OR IGNORE INTO games (id, white_user_id, black_user_id, mode, time_control, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `).bind(
        gameId,
        whiteId,
        blackId,
        dbMode,
        normalizedTimeControl,
        now,
        now
      ).run()

      return c.json({ gameId, whiteId, blackId, color: resolvedColor }, 201)
    } catch (fallbackErr: any) {
      console.error('Game creation fallback insert failed:', fallbackErr)
      const msg = fallbackErr?.message?.toString() ?? ''
      if (msg.toLowerCase().includes('foreign key')) {
        return c.json({ error: 'Game create failed due to invalid player reference. Please login again.' }, 401)
      }
      return c.json({ error: 'Failed to create game', details: fallbackErr.message, stack: fallbackErr.stack }, 500)
    }
  }
})

// ────────────────────────────────────────
// SAVE MOVE (server-side validation)
// ────────────────────────────────────────
const MoveSchema = z.object({
  gameId: z.string(),
  from: z.string().length(2),
  to: z.string().length(2),
  promotion: z.union([
    z.enum(['q', 'r', 'b', 'n']),
    z.enum(['queen', 'rook', 'bishop', 'knight']),
  ]).optional(),
  fenAfter: z.string(),
  algebraic: z.string(),
  timeSpent: z.number().optional(),
})

game.post('/move', async (c) => {
  const user = c.get('user')
  const body = await c.req.json()
  const parsed = MoveSchema.safeParse(body)
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400)

  const { gameId, from, to, promotion: rawPromotion, fenAfter, algebraic, timeSpent } = parsed.data
  const promotion = rawPromotion === 'queen' || rawPromotion === 'q'
    ? 'q'
    : rawPromotion === 'rook' || rawPromotion === 'r'
    ? 'r'
    : rawPromotion === 'bishop' || rawPromotion === 'b'
    ? 'b'
    : rawPromotion === 'knight' || rawPromotion === 'n'
    ? 'n'
    : undefined

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

  // Update XP — Expand to singlePlayer and tournament
  const supportedModes = ['multiplayer', 'tournament', 'singlePlayer'];
  if (supportedModes.includes(gameRow.mode as string) && gameRow.rated !== 0) {
    await updateXP(c.env.DB, gameRow, result)
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
      wu.username as white_username, wu.avatar_url as white_avatar, wu.xp as white_xp,
      bu.username as black_username, bu.avatar_url as black_avatar, bu.xp as black_xp
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
           g.white_user_id, g.black_user_id,
           g.time_control, g.created_at, g.completed_at,
           wu.username as white_username, bu.username as black_username
    FROM games g
    LEFT JOIN users wu ON g.white_user_id = wu.id
    LEFT JOIN users bu ON g.black_user_id = bu.id
    WHERE (g.white_user_id = ? OR g.black_user_id = ?)
    AND g.status IN ('completed', 'abandoned')
    ORDER BY g.completed_at DESC
    LIMIT ? OFFSET ?
  `).bind(c.req.param('userId'), c.req.param('userId'), limit, offset).all()

  return c.json({ games: games.results })
})

// ────────────────────────────────────────
// ABANDON GAME (network/app crash or disconnect)
// ────────────────────────────────────────
const AbandonSchema = z.object({
  gameId: z.string(),
  cause: z.string().default('network_disconnect_or_app_crash'),
})

game.post('/abandon', async (c) => {
  const body = await c.req.json()
  const parsed = AbandonSchema.safeParse(body)
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400)

  const { gameId, cause } = parsed.data
  const now = new Date().toISOString()

  await c.env.DB.prepare(`
    UPDATE games
    SET status = 'abandoned',
        termination = ?,
        completed_at = ?,
        updated_at = ?
    WHERE id = ? AND status = 'active'
  `).bind(cause, now, now, gameId).run()

  return c.json({ ok: true })
})

// ────────────────────────────────────────
// HELPERS
// ────────────────────────────────────────
async function updateXP(db: D1Database, gameRow: Record<string, unknown>, result: string) {
  const mode = gameRow.mode as any;
  const whiteId = gameRow.white_user_id as string | null;
  const blackId = gameRow.black_user_id as string | null;

  if (whiteId) {
    await StatsService.updateAll(db, {
      userId: whiteId,
      gameId: gameRow.id as string,
      outcome: result === 'white' ? 'win' : (result === 'black' ? 'loss' : 'draw'),
      mode,
      aiDifficulty: gameRow.ai_difficulty as string
    })
  }

  if (blackId) {
    await StatsService.updateAll(db, {
      userId: blackId,
      gameId: gameRow.id as string,
      outcome: result === 'black' ? 'win' : (result === 'white' ? 'loss' : 'draw'),
      mode,
      aiDifficulty: gameRow.ai_difficulty as string
    })
  }
}

async function updateStats(db: D1Database, userId: string, outcome: 'win' | 'loss' | 'draw', mode: string) {
  // Stats are now handled by updateXP via StatsService.updateAll
  // This function is kept for backward compatibility if needed, but its logic is now redundant helper-wise.
  // We can leave it as a no-op if updateXP is now the primary entry point.
}

export { game as gameRoutes }
