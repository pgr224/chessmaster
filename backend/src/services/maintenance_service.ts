import type { Env } from '../index'

export class MaintenanceService {
  /**
   * Cleans up stale active games and refreshes user statistics.
   * This ensures that "zombie" games do not pollute the stats or leaderboard.
   */
  static async cleanupAndRefresh(env: Env) {
    console.log('[Maintenance] Starting automated stale game cleanup and stats refresh...')

    try {
      // 1. Mark stale active games as abandoned (older than 24 hours)
      const gamesResult = await env.DB.prepare(`
        UPDATE games 
        SET status = 'abandoned', 
            termination = 'stale_cleanup', 
            updated_at = datetime('now')
        WHERE status = 'active' 
          AND datetime(created_at) < datetime('now', '-1 day')
      `).run()

      console.log(`[Maintenance] Cleanup: Marked ${gamesResult.meta.changes || 0} stale games as abandoned.`)

      // 2. Refresh user statistics based on the latest game history
      // This is a simplified version of refresh_userdata.sql for periodic maintenance
      await env.DB.batch([
        // Recalculate basic counts
        env.DB.prepare(`
          UPDATE user_stats
          SET 
            games_played = (
              SELECT COUNT(*) FROM games 
              WHERE (white_user_id = user_stats.user_id OR black_user_id = user_stats.user_id)
                AND status IN ('completed', 'abandoned', 'draw')
            ),
            wins = (
              SELECT COUNT(*) FROM games 
              WHERE ((white_user_id = user_stats.user_id AND result = 'white') OR (black_user_id = user_stats.user_id AND result = 'black'))
                AND status IN ('completed', 'abandoned')
            ),
            losses = (
              SELECT COUNT(*) FROM games 
              WHERE ((white_user_id = user_stats.user_id AND result = 'black') OR (black_user_id = user_stats.user_id AND result = 'white'))
                AND status IN ('completed', 'abandoned')
            ),
            draws = (
              SELECT COUNT(*) FROM games 
              WHERE (white_user_id = user_stats.user_id OR black_user_id = user_stats.user_id)
                AND result = 'draw' AND status IN ('completed', 'draw')
            )
        `),
        // Recalculate XP from the master users table to keep user_stats in sync
        env.DB.prepare(`
          UPDATE user_stats 
          SET xp = (SELECT xp FROM users WHERE users.id = user_stats.user_id)
        `),
        // Update timestamp
        env.DB.prepare(`UPDATE user_stats SET updated_at = datetime('now')`)
      ])

      console.log('[Maintenance] Stats refresh completed successfully.')
    } catch (err) {
      console.error('[Maintenance] Automated task failed:', err)
    }
  }
}
