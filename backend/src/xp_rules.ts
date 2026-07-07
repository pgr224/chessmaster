/**
 * XP Rules Module
 * Defines exact XP earning rules for all game modes/difficulties
 * Must align with what is displayed in user profile settings
 */

export interface XPRule {
  condition: string
  xp: number
}

export const XP_RULES = {
  // MULTIPLAYER (VS Other Players)
  multiplayer: {
    win: 100,
    draw: 30,
    loss: -20,
  },

  // TOURNAMENT (Multi-round)
  tournament: {
    win: 100,
    draw: 30,
    loss: -20,
    // Bonus for placing 1st overall
    tournamentWinBonus: 200,
  },

  // VS COMPUTER (Difficulty-based)
  computerAI: {
    // Easy
    easyWin: 100,
    // Medium
    mediumWin: 250,
    // Hard
    hardWin: 400,
    // Impossible
    impossibleWin: 700,
    // AI Mode (hardest)
    aiModeWin: 1000,
  },

  // SPECIAL ACHIEVEMENTS
  milestones: {
    mateIn5: 500,
    perfectGame: 1000,
    every100thWin: 1000,
  },

  // PENALTIES
  penalties: {
    takeback: -25,
    hintUsage: -10,
  },
}

/**
 * Calculate XP for a completed multiplayer/tournament game
 */
export function calculateMultiplayerXP(
  result: 'win' | 'loss' | 'draw'
): number {
  switch (result) {
    case 'win':
      return XP_RULES.multiplayer.win
    case 'draw':
      return XP_RULES.multiplayer.draw
    case 'loss':
      return XP_RULES.multiplayer.loss
    default:
      return 0
  }
}

/**
 * Calculate XP for a tournament game with optional overall winner bonus
 */
export function calculateTournamentXP(
  result: 'win' | 'loss' | 'draw',
  isTournamentWinner?: boolean
): number {
  const baseXP = calculateMultiplayerXP(result)
  const bonus = isTournamentWinner ? XP_RULES.tournament.tournamentWinBonus : 0
  return baseXP + bonus
}

/**
 * Calculate XP for vs computer game based on difficulty
 */
export function calculateAIGameXP(difficulty: string): number {
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return XP_RULES.computerAI.easyWin
    case 'medium':
      return XP_RULES.computerAI.mediumWin
    case 'hard':
      return XP_RULES.computerAI.hardWin
    case 'impossible':
      return XP_RULES.computerAI.impossibleWin
    case 'ai':
    case 'aimode':
      return XP_RULES.computerAI.aiModeWin
    default:
      return 0
  }
}

/**
 * Get all XP rules for display/documentation
 */
export function getAllXPRules() {
  return {
    multiplayer: XP_RULES.multiplayer,
    tournament: XP_RULES.tournament,
    computerAI: XP_RULES.computerAI,
    milestones: XP_RULES.milestones,
    penalties: XP_RULES.penalties,
  }
}
