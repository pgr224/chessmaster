import { Hono } from 'hono'
import type { Env } from '../index'
import { authMiddleware } from '../middleware/auth'
import { normalizeLeaderboardSortType } from './leaderboard.rank-utils'

const leaderboard = new Hono<{ Bindings: Env }>()
leaderboard.use('*', authMiddleware)

// ────────────────────────────────────────
// GLOBAL LEADERBOARD
// ────────────────────────────────────────
leaderboard.get('/', async (c) => {
  const limit = Math.min(parseInt(c.req.query('limit') ?? '50'), 100)
  const type = normalizeLeaderboardSortType(c.req.query('type'))

  try {
    const rows = await c.env.DB.prepare(`
      WITH player_stats AS (
        SELECT 
          u.id, 
          u.username, 
          u.avatar_url, 
          u.xp, 
          u.is_online,
          COALESCE(s.wins, 0) as wins,
          COALESCE(s.losses, 0) as losses,
          COALESCE(s.draws, 0) as draws,
          COALESCE(s.games_played, 0) as games_played,
          COALESCE(s.longest_streak, 0) as longest_streak,
          COALESCE(s.elo_rating, 1200) as elo_rating,
          CASE 
            WHEN COALESCE(s.games_played, 0) > 0 
            THEN ROUND(CAST(s.wins AS REAL) / s.games_played * 100, 1)
            ELSE 0 
          END as win_rate
        FROM users u
        LEFT JOIN user_stats s ON u.id = s.user_id
      )
      SELECT 
        *,
        CASE
          WHEN games_played < 1 THEN 0
          ELSE RANK() OVER (
            ORDER BY 
              CASE 
                WHEN ? = 'wins' THEN wins
                WHEN ? = 'streak' THEN longest_streak
                WHEN ? = 'elo' THEN elo_rating
                ELSE xp 
              END DESC,
              xp DESC -- Secondary sort by total XP for tie-breaking
          ) 
        END as rank
      FROM player_stats
      ORDER BY 
        CASE WHEN games_played >= 1 THEN 0 ELSE 1 END,
        CASE 
          WHEN ? = 'wins' THEN wins
          WHEN ? = 'streak' THEN longest_streak
          WHEN ? = 'elo' THEN elo_rating
          ELSE xp 
        END DESC,
        xp DESC
      LIMIT ?
    `).bind(type, type, type, type, type, type, limit).all()

    return c.json({ leaderboard: rows.results })
  } catch (err) {
    console.error('Leaderboard primary query failed, falling back:', err)
    try {
      const fallback = await c.env.DB.prepare(`
        SELECT u.id, u.username, u.avatar_url, u.xp, u.is_online,
               0 as wins,
               0 as losses,
               0 as draws,
               0 as games_played,
               0 as longest_streak,
               1200 as elo_rating,
               0 as win_rate,
               RANK() OVER (ORDER BY u.xp DESC) as rank
        FROM users u
        ORDER BY u.xp DESC
        LIMIT ?
      `).bind(limit).all()

      return c.json({ leaderboard: fallback.results })
    } catch (fallbackErr) {
      console.error('Leaderboard fallback query failed:', fallbackErr)
      return c.json({ leaderboard: [] })
    }
  }
})

// ────────────────────────────────────────
// USER'S RANK
// ────────────────────────────────────────
leaderboard.get('/rank/:userId', async (c) => {
  const userId = c.req.param('userId')
  const type = normalizeLeaderboardSortType(c.req.query('type'))

  try {
    const data = await c.env.DB.prepare(`
      WITH player_stats AS (
        SELECT 
          u.id, 
          u.xp,
          COALESCE(s.wins, 0) as wins,
          COALESCE(s.losses, 0) as losses,
          COALESCE(s.games_played, 0) as games_played,
          COALESCE(s.elo_rating, 1200) as elo_rating,
          CASE 
            WHEN ? = 'wins' THEN COALESCE(s.wins, 0)
            WHEN ? = 'streak' THEN COALESCE(s.longest_streak, 0)
            WHEN ? = 'elo' THEN COALESCE(s.elo_rating, 1200)
            ELSE u.xp
          END as sort_value
        FROM users u
        LEFT JOIN user_stats s ON u.id = s.user_id
        WHERE u.id = ? OR EXISTS (SELECT 1 FROM user_stats s2 WHERE s2.games_played >= 1)
      ),
      ranked_players AS (
        SELECT 
          id, xp, wins, losses, games_played,
          CASE
            WHEN games_played < 1 THEN 0
            ELSE RANK() OVER (
              ORDER BY sort_value DESC, xp DESC
            )
          END as rank
        FROM player_stats
      )
      SELECT 
        id, rank, xp, wins, losses, games_played,
        CASE WHEN games_played > 0 THEN ROUND(CAST(wins AS REAL) / games_played * 100, 1) ELSE 0 END as win_rate
      FROM ranked_players
      WHERE id = ?
      LIMIT 1
    `).bind(type, type, type, userId, userId).first()

    if (!data) {
      return c.json({ rank: 0, xp: 0, wins: 0, losses: 0, games_played: 0, win_rate: 0 })
    }

    return c.json(data)
  } catch (err: any) {
    console.error(`Error fetching rank for user ${userId}:`, err)
    return c.json({ 
      error: 'Internal Server Error', 
      message: err.message,
      rank: 0, xp: 0, wins: 0, losses: 0, games_played: 0, win_rate: 0 
    }, 500)
  }
})

export { leaderboard as leaderboardRoutes }
