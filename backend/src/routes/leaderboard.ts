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
              xp DESC 
          ) 
        END as rank
      FROM unified_player_scoring
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
    // 1. Get the user's primary stats
    const me = await c.env.DB.prepare(`
      SELECT u.id, u.xp,
             COALESCE(s.wins, 0) as wins,
             COALESCE(s.losses, 0) as losses,
             COALESCE(s.games_played, 0) as games_played,
             COALESCE(s.elo_rating, 1200) as elo_rating,
             COALESCE(s.longest_streak, 0) as longest_streak
      FROM users u
      LEFT JOIN user_stats s ON u.id = s.user_id
      WHERE u.id = ?
    `).bind(userId).first<{
      id: string; xp: number; wins: number; losses: number; 
      games_played: number; elo_rating: number; longest_streak: number;
    }>()

    if (!me) {
      return c.json({ rank: 0, xp: 0, wins: 0, losses: 0, games_played: 0, win_rate: 0 })
    }

    // Ineligible players (0 games) are rank 0
    if (me.games_played < 1) {
      return c.json({
        id: me.id, rank: 0, xp: me.xp, wins: me.wins, losses: me.losses, 
        games_played: me.games_played, win_rate: 0
      })
    }

    // 2. Identify what column we are ranking by
    let sortValue: number
    let sqlCondition: string
    if (type === 'wins') {
      sortValue = me.wins
      sqlCondition = 'COALESCE(s.wins, 0) > ? OR (COALESCE(s.wins, 0) = ? AND u.xp > ?)'
    } else if (type === 'streak') {
      sortValue = me.longest_streak
      sqlCondition = 'COALESCE(s.longest_streak, 0) > ? OR (COALESCE(s.longest_streak, 0) = ? AND u.xp > ?)'
    } else if (type === 'elo') {
      sortValue = me.elo_rating
      sqlCondition = 'COALESCE(s.elo_rating, 1200) > ? OR (COALESCE(s.elo_rating, 1200) = ? AND u.xp > ?)'
    } else {
      sortValue = me.xp
      sqlCondition = 'u.xp > ?'
    }

    // 3. Count how many eligible players are BETTER than me (Rank = Better + 1)
    const betterCountResult = await c.env.DB.prepare(`
      SELECT COUNT(*) as better_count
      FROM users u
      JOIN user_stats s ON u.id = s.user_id
      WHERE s.games_played >= 1 AND (${sqlCondition})
    `).bind(
      ...(type === 'xp' ? [sortValue] : [sortValue, sortValue, me.xp])
    ).first<{ better_count: number }>()

    const rank = (betterCountResult?.better_count ?? 0) + 1
    const winRate = me.games_played > 0 ? Math.round((me.wins / me.games_played) * 1000) / 10 : 0

    return c.json({
      id: me.id,
      rank,
      xp: me.xp,
      wins: me.wins,
      losses: me.losses,
      games_played: me.games_played,
      win_rate: winRate
    })
  } catch (err: any) {
    console.error(`Rank query crash for user ${userId}:`, err)
    return c.json({ 
      error: 'Query Failure', 
      message: err.message,
      rank: 0, xp: 0, wins: 0, losses: 0, games_played: 0, win_rate: 0 
    }, 500)
  }
})

export { leaderboard as leaderboardRoutes }
