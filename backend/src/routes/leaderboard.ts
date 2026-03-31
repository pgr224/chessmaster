import { Hono } from 'hono'
import type { Env } from '../index'
import { authMiddleware } from '../middleware/auth'

const leaderboard = new Hono<{ Bindings: Env }>()
leaderboard.use('*', authMiddleware)

// ────────────────────────────────────────
// GLOBAL LEADERBOARD
// ────────────────────────────────────────
leaderboard.get('/', async (c) => {
  const limit = Math.min(parseInt(c.req.query('limit') ?? '50'), 100)
  const type = c.req.query('type') ?? 'xp' // xp, wins, streak, elo

  const orderCol = type === 'wins' ? 's.wins' : 
                   type === 'streak' ? 's.longest_streak' : 
                   type === 'elo' ? 's.elo_rating' : 'u.xp'

  const rows = await c.env.DB.prepare(`
    SELECT u.id, u.username, u.avatar_url, u.xp, u.is_online,
           s.wins, s.losses, s.draws, s.games_played, s.longest_streak,
           s.elo_rating, s.win_rate,
           RANK() OVER (ORDER BY ${orderCol} DESC) as rank
    FROM users u
    LEFT JOIN (
      SELECT user_id,
             wins, losses, draws, games_played, longest_streak,
             CASE WHEN games_played > 0 
                  THEN ROUND(CAST(wins AS REAL) / games_played * 100, 1)
                  ELSE 0 END as win_rate
      FROM user_stats
    ) s ON u.id = s.user_id
    WHERE s.games_played >= 5
    ORDER BY ${orderCol} DESC
    LIMIT ?
  `).bind(limit).all()

  return c.json({ leaderboard: rows.results })
})

// ────────────────────────────────────────
// USER'S RANK
// ────────────────────────────────────────
leaderboard.get('/rank/:userId', async (c) => {
  const userId = c.req.param('userId')

  const rank = await c.env.DB.prepare(`
    SELECT COUNT(*) + 1 as rank
    FROM users
    WHERE xp > (SELECT xp FROM users WHERE id = ?)
    AND id IN (SELECT user_id FROM user_stats WHERE games_played >= 5)
  `).bind(userId).first<{ rank: number }>()

  const user = await c.env.DB.prepare(`
    SELECT u.xp, s.wins, s.losses, s.games_played, s.win_rate
    FROM users u
    LEFT JOIN (
      SELECT user_id, wins, losses, games_played,
             CASE WHEN games_played > 0 THEN ROUND(CAST(wins AS REAL) / games_played * 100, 1) ELSE 0 END as win_rate
      FROM user_stats
    ) s ON u.id = s.user_id
    WHERE u.id = ?
  `).bind(userId).first()

  return c.json({ rank: rank?.rank ?? 0, ...user })
})

export { leaderboard as leaderboardRoutes }
