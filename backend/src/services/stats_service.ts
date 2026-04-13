import { XP_RULES } from '../xp_rules'

export type GameOutcome = 'win' | 'loss' | 'draw'
export type GameMode = 'multiplayer' | 'tournament' | 'singlePlayer' | 'twoPlayer' | 'tutorial' | 'puzzle' | 'practice'

export interface UpdateStatsOptions {
  userId: string
  gameId?: string | null
  outcome: GameOutcome
  mode: GameMode
  aiDifficulty?: string
  eloChange?: number
}

export class StatsService {
  /**
   * Updates user stats and XP atomically in the database.
   * Handles UPSERT for user_stats and atomic increment for XP.
   */
  static async updateAll(db: D1Database, options: UpdateStatsOptions): Promise<number> {
    const { userId, gameId, outcome, mode, aiDifficulty } = options
    let { eloChange = 0 } = options
    const now = new Date().toISOString()
    
    // 1. Calculate Default Elo Change for Multiplayer if not provided
    if (eloChange === 0 && mode === 'multiplayer') {
      eloChange = outcome === 'win' ? 20 : (outcome === 'draw' ? 5 : -15)
    }

    // 2. Calculate XP Change
    let xpChange = 0
    if (mode === 'multiplayer' || mode === 'tournament') {
      xpChange = (outcome === 'win' ? XP_RULES.multiplayer.win 
                 : (outcome === 'draw' ? XP_RULES.multiplayer.draw 
                 : XP_RULES.multiplayer.loss))
    } else if (mode === 'singlePlayer' && outcome === 'win') {
      const diff = (aiDifficulty || 'medium').toLowerCase()
      xpChange = (diff === 'easy' ? XP_RULES.computerAI.easyWin
                 : diff === 'hard' ? XP_RULES.computerAI.hardWin
                 : diff === 'impossible' ? XP_RULES.computerAI.impossibleWin
                 : diff === 'ai' || diff === 'aimode' ? XP_RULES.computerAI.aiModeWin
                 : XP_RULES.computerAI.mediumWin)
    }

    // 2. Perform Stats UPSERT
    const field = outcome === 'win' ? 'wins' : outcome === 'loss' ? 'losses' : 'draws'
    const modeField = mode === 'multiplayer' ? 'multiplayer_games' : 
                      mode === 'tournament' ? 'tournament_games' : 
                      mode === 'twoPlayer' ? 'two_player_games' : 'ai_games'
    const modeWinField = mode === 'multiplayer' ? 'multiplayer_wins' : 
                         mode === 'tournament' ? 'tournament_wins' : 
                         mode === 'twoPlayer' ? 'two_player_wins' : 'ai_wins'
    
    const isWin = outcome === 'win'

    await db.prepare(`
      INSERT INTO user_stats (
        user_id, games_played, ${field}, ${modeField}, 
        ${isWin ? `${modeWinField},` : ''} 
        current_streak, longest_streak, elo_rating, updated_at
      ) 
      VALUES (?, 1, 1, 1, ${isWin ? '1, ' : ''} ?, ?, ?, ?)
      ON CONFLICT(user_id) DO UPDATE SET
        games_played = user_stats.games_played + 1,
        ${field} = user_stats.${field} + 1,
        ${modeField} = user_stats.${modeField} + 1,
        ${isWin ? `${modeWinField} = user_stats.${modeWinField} + 1,` : ''}
        current_streak = CASE WHEN ? = 'win' THEN user_stats.current_streak + 1 ELSE 0 END,
        longest_streak = CASE 
          WHEN ? = 'win' AND user_stats.current_streak + 1 > user_stats.longest_streak 
          THEN user_stats.current_streak + 1 
          ELSE user_stats.longest_streak 
        END,
        elo_rating = user_stats.elo_rating + ?,
        updated_at = EXCLUDED.updated_at
    `).bind(
      userId, 
      isWin ? 1 : 0, 
      isWin ? 1 : 0, 
      1200 + eloChange,
      now,
      outcome,
      outcome,
      eloChange
    ).run()

    // 3. Update User XP Atomically
    if (xpChange !== 0) {
      // Get current XP for logging history accurately
      const user = await db.prepare('SELECT xp FROM users WHERE id = ?').bind(userId).first<{ xp: number }>()
      const currentXp = user?.xp ?? 0
      const nextXp = Math.max(0, currentXp + xpChange)

      await db.prepare('UPDATE users SET xp = ?, updated_at = ? WHERE id = ?')
        .bind(nextXp, now, userId).run()

      // Log XP history
      await db.prepare(`
        INSERT INTO xp_history (user_id, game_id, xp_before, xp_after, change, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
      `).bind(userId, gameId ?? null, currentXp, nextXp, xpChange, now).run()
    }

    return xpChange
  }

  /**
   * Specifically for Tournament Endings to award bonuses and update ranking
   */
  static async awardTournamentBonus(db: D1Database, userId: string, bonusAmount: number, eloDelta: number) {
    const now = new Date().toISOString()
    const user = await db.prepare('SELECT xp FROM users WHERE id = ?').bind(userId).first<{ xp: number }>()
    if (user) {
      const newXp = user.xp + bonusAmount
      await db.prepare('UPDATE users SET xp = ?, updated_at = ? WHERE id = ?').bind(newXp, now, userId).run()
      await db.prepare(`
        INSERT INTO xp_history (user_id, xp_before, xp_after, change, created_at)
        VALUES (?, ?, ?, ?, ?)
      `).bind(userId, user.xp, newXp, bonusAmount, now).run()
    }
    
    // Update Elo in user_stats
    await db.prepare('UPDATE user_stats SET elo_rating = elo_rating + ?, updated_at = ? WHERE user_id = ?')
      .bind(eloDelta, now, userId).run()
  }
}
