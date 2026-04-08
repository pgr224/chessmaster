/**
 * 🎯 ENGAGEMENT MECHANICS SYSTEM
 * Notifications, stats tracking, and engagement hooks for tournament/multiplayer
 */

export interface EngagementNotification {
  id: string
  type: 'milestone' | 'position_change' | 'opponent_alert' | 'reward_unlock' | 'achievement'
  title: string
  message: string
  emoji: string
  priority: 'low' | 'medium' | 'high'
  actionUrl?: string
  createdAt: Date
  read: boolean
}

export interface TournamentStats {
  tournamentId: string
  playerId: string
  totalGames: number
  wins: number
  draws: number
  losses: number
  score: number // Total points (win=1, draw=0.5, loss=0)
  accuracy: number // Average accuracy across all games
  longestStreak: number // Consecutive wins in tournament
  ratingChange: number
  bestOpponentRating: number
  averageOpponentRating: number
  timeManagementScore: number // 0-100: how well player uses time
  aggressivenessScore: number // 0-100: piece sacrifice ratio
}

export interface PlayerEngagementMetrics {
  playerId: string
  totalMultiplayerGames: number
  winStreak: number
  activeConsecutiveDays: number
  tournamentParticipations: number
  totalTournamentVictories: number
  engagementScore: number // 0-100: overall engagement level
  preferredTimeControl: string | null
  preferredVariant: string | null
  favoriteOpponents: Array<{ playerId: string; nickname: string; headToHead: number }>
}

// ═════════════════════════════════════════════════════════════════
// MILESTONE NOTIFICATIONS
// ═════════════════════════════════════════════════════════════════

export function getMilestoneNotification(
  playerId: string,
  milestone: 'first_win' | 'win_10' | 'win_50' | 'streak_3' | 'streak_5' | 'rating_boost',
  currentValue: number
): EngagementNotification | null {
  const notifications: Record<string, EngagementNotification> = {
    first_win: {
      id: `milestone_${playerId}_first_win`,
      type: 'milestone',
      title: '🎉 First Multiplayer Win!',
      message: `You've claimed your first victory online! Welcome to the competitive arena.`,
      emoji: '🥳',
      priority: 'high',
      createdAt: new Date(),
      read: false,
    },
    win_10: {
      id: `milestone_${playerId}_win_10`,
      type: 'milestone',
      title: '🏆 10 Victories!',
      message: `You've reached 10 multiplayer wins! You're becoming a formidable opponent.`,
      emoji: '🏅',
      priority: 'high',
      createdAt: new Date(),
      read: false,
    },
    win_50: {
      id: `milestone_${playerId}_win_50`,
      type: 'milestone',
      title: '👑 50 Victories!',
      message: `An incredible achievement! 50 multiplayer wins shows true mastery.`,
      emoji: '🌟',
      priority: 'high',
      createdAt: new Date(),
      read: false,
    },
    streak_3: {
      id: `milestone_${playerId}_streak_3`,
      type: 'milestone',
      title: '🔥 Hot Streak!',
      message: `3 consecutive wins! You're in a great form. Keep it going!`,
      emoji: '⚡',
      priority: 'medium',
      createdAt: new Date(),
      read: false,
    },
    streak_5: {
      id: `milestone_${playerId}_streak_5`,
      type: 'milestone',
      title: '🌋 ON FIRE!',
      message: `5 consecutive wins! This is legendary performance. The competition awaits!`,
      emoji: '💥',
      priority: 'high',
      createdAt: new Date(),
      read: false,
    },
    rating_boost: {
      id: `milestone_${playerId}_rating_${currentValue}`,
      type: 'milestone',
      title: `📈 Rating Milestone: ${currentValue}`,
      message: `Your rating has reached ${currentValue}! You're climbing the competitive ladder.`,
      emoji: '🎯',
      priority: 'medium',
      createdAt: new Date(),
      read: false,
    },
  }

  return notifications[milestone] || null
}

// ═════════════════════════════════════════════════════════════════
// POSITION CHANGE NOTIFICATIONS
// ═════════════════════════════════════════════════════════════════

export function getPositionChangeNotification(
  playerId: string,
  currentPlace: number,
  previousPlace: number,
  tournamentName: string
): EngagementNotification {
  const improved = currentPlace < previousPlace
  const direction = improved ? '📈' : '📉'
  const emoji = currentPlace === 1 ? '🥇' : currentPlace === 2 ? '🥈' : currentPlace === 3 ? '🥉' : direction

  return {
    id: `position_${playerId}_${Date.now()}`,
    type: 'position_change',
    title: improved
      ? `🎯 You've Moved Up in ${tournamentName}!`
      : `⚠️ Position Change in ${tournamentName}`,
    message: improved
      ? `You've climbed from ${previousPlace}${getOrdinalSuffix(previousPlace)} to ${currentPlace}${getOrdinalSuffix(currentPlace)} place!`
      : `You've slipped to ${currentPlace}${getOrdinalSuffix(currentPlace)} place. Catch up in your next game!`,
    emoji,
    priority: improved ? 'high' : 'medium',
    createdAt: new Date(),
    read: false,
  }
}

// ═════════════════════════════════════════════════════════════════
// OPPONENT ALERTS
// ═════════════════════════════════════════════════════════════════

export interface OpponentAlert {
  type: 'higher_rated' | 'rival_online' | 'revenge_opportunity' | 'easy_matchup'
  opponentName: string
  opponentRating: number
  headToHeadRecord: { wins: number; losses: number; draws: number }
  message: string
  recommendation: string
}

export function getOpponentAlert(
  playerRating: number,
  opponentName: string,
  opponentRating: number,
  headToHead: { wins: number; losses: number; draws: number }
): OpponentAlert | null {
  const ratingDiff = playerRating - opponentRating

  // Higher rated opponent alert
  if (ratingDiff < -100) {
    return {
      type: 'higher_rated',
      opponentName,
      opponentRating,
      headToHeadRecord: headToHead,
      message: `⚡ Strong Opponent Ahead: ${opponentName} is rated ${Math.abs(ratingDiff)} points higher!`,
      recommendation: 'Play solid, avoid risky gambits',
    }
  }

  // Rival online alert
  if (headToHead.losses > headToHead.wins && headToHead.losses + headToHead.wins >= 3) {
    return {
      type: 'rival_online',
      opponentName,
      opponentRating,
      headToHeadRecord: headToHead,
      message: `🎯 Rival Alert: You're ${headToHead.losses - headToHead.wins} down vs ${opponentName}!`,
      recommendation: 'Time to even the score!',
    }
  }

  // Revenge opportunity
  if (headToHead.losses === 1 && headToHead.wins === 0) {
    return {
      type: 'revenge_opportunity',
      opponentName,
      opponentRating,
      headToHeadRecord: headToHead,
      message: `💪 Revenge Opportunity: Beat ${opponentName} to equalize!`,
      recommendation: 'You know their style. Use it to your advantage.',
    }
  }

  // Easy matchup if you're rated significantly higher
  if (ratingDiff > 150) {
    return {
      type: 'easy_matchup',
      opponentName,
      opponentRating,
      headToHeadRecord: headToHead,
      message: `Favorable Matchup: ${opponentName} is rated ${ratingDiff} points below you.`,
      recommendation: 'Play with confidence, push your advantage.',
    }
  }

  return null
}

// ═════════════════════════════════════════════════════════════════
// REWARD UNLOCK NOTIFICATIONS
// ═════════════════════════════════════════════════════════════════

export function getRewardUnlockNotification(
  playerId: string,
  placementReward: number,
  xpBonus: number,
  badgeTitle?: string
): EngagementNotification {
  return {
    id: `reward_${playerId}_${Date.now()}`,
    type: 'reward_unlock',
    title: badgeTitle ? `🎖️ Badge Unlocked: ${badgeTitle}` : '🎁 Tournament Rewards!',
    message: `You've earned ${placementReward} XP + ${xpBonus} bonus XP! ${badgeTitle ? `Plus the "${badgeTitle}" badge!` : ''}`,
    emoji: '🏆',
    priority: 'high',
    createdAt: new Date(),
    read: false,
  }
}

// ═════════════════════════════════════════════════════════════════
// TIME-BASED ENGAGEMENT HOOKS
// ═════════════════════════════════════════════════════════════════

export function getTimeBasedEngagementMessage(
  hoursInactive: number,
  totalMultiplayerWins: number
): string | null {
  if (hoursInactive >= 168) {
    // 1 week
    return `👋 We miss you, ${getStreakPhrase(totalMultiplayerWins)}! Come play a quick game today.`
  }
  if (hoursInactive >= 72) {
    // 3 days
    return `⚡ Your opponents are waiting! Play your next game and earn bonus XP.`
  }
  if (hoursInactive >= 48) {
    // 2 days
    return `🎯 Time to get back on the board! A new opponent is ready.`
  }
  if (hoursInactive >= 24) {
    // 1 day
    return `🔥 You're on a winning streak! Don't break it now.`
  }

  return null
}

// ═════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═════════════════════════════════════════════════════════════════

function getOrdinalSuffix(num: number): string {
  const j = num % 10
  const k = num % 100
  if (j === 1 && k !== 11) return 'st'
  if (j === 2 && k !== 12) return 'nd'
  if (j === 3 && k !== 13) return 'rd'
  return 'th'
}

function getStreakPhrase(wins: number): string {
  if (wins < 5) return 'newcomer'
  if (wins < 10) return 'rising star'
  if (wins < 20) return 'competitor'
  if (wins < 50) return 'champion'
  return 'legend'
}

/**
 * Calculate combined engagement score (0-100)
 */
export function calculateEngagementScore(metrics: {
  multiplayerGamesCount: number
  winRate: number
  tournamentParticipations: number
  consecutiveActiveDays: number
  achievementProgress: number
}): number {
  let score = 0

  // Games played (0-25 points)
  score += Math.min(25, Math.floor(metrics.multiplayerGamesCount / 4))

  // Win rate (0-25 points)
  score += Math.round(Math.min(25, metrics.winRate * 25))

  // Tournament participation (0-20 points)
  score += Math.min(20, metrics.tournamentParticipations * 2)

  // Daily streaks (0-20 points)
  score += Math.min(20, Math.floor(metrics.consecutiveActiveDays / 2))

  // Achievement hunt progression (0-10 points)
  score += Math.round(Math.min(10, metrics.achievementProgress * 10))

  return Math.min(100, score)
}

/**
 * Generate tournament performance summary
 */
export function getTournamentPerformanceSummary(stats: TournamentStats): string {
  const winRate = stats.totalGames > 0 ? (stats.wins / stats.totalGames * 100).toFixed(0) : '0'
  const ratingChangeText = stats.ratingChange > 0 ? `+${stats.ratingChange}` : `${stats.ratingChange}`

  return `Performance: ${stats.totalGames} games, ${winRate}% wins, Avg opponent: ${stats.averageOpponentRating} rating, ${ratingChangeText} rating change`
}
