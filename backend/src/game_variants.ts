/**
 * 🎮 GAME VARIANTS SYSTEM
 * 10 engaging multiplayer chess variants to increase engagement and addictiveness
 */

export type GameVariant =
  | 'standard'
  | 'kings_gambit'
  | 'blindfold_blitz'
  | 'chess_roulette'
  | 'speed_tactics'
  | 'team_chess'
  | 'atomic_chess'
  | 'tempo_duel'
  | 'promotion_fever'
  | 'fortress_fortress'
  | 'material_handicap'

export interface VariantConfig {
  id: GameVariant
  name: string
  description: string
  icon: string
  xpMultiplier: number
  difficulty: 'easy' | 'medium' | 'hard' | 'extreme'
  rules: string[]
  maxPlayers: number
  minPlayers: number
  ratingImpact: 'normal' | 'doubled' | 'halved'
  specialFeatures: string[]
}

// ═════════════════════════════════════════════════════════════════
// VARIANT DEFINITIONS
// ═════════════════════════════════════════════════════════════════

export const GAME_VARIANTS: Record<GameVariant, VariantConfig> = {
  standard: {
    id: 'standard',
    name: 'Standard Chess',
    description: 'Classic chess with no modifications',
    icon: '♔',
    xpMultiplier: 1.0,
    difficulty: 'medium',
    rules: ['Standard FIDE rules', 'Move validation', 'Checkmate win condition'],
    maxPlayers: 2,
    minPlayers: 2,
    ratingImpact: 'normal',
    specialFeatures: [],
  },

  kings_gambit: {
    id: 'kings_gambit',
    name: "King's Gambit Mode",
    description: 'Both players start with 80% material - lose 2 pawns for immediate tactical chaos',
    icon: '♞',
    xpMultiplier: 1.2,
    difficulty: 'hard',
    rules: [
      "Both players lose a1 and h1 pawns at game start",
      'Compensation: Both players start 40 extra points (negligible)',
      'Forces immediate engagement, eliminates slow openings',
    ],
    maxPlayers: 2,
    minPlayers: 2,
    ratingImpact: 'doubled',
    specialFeatures: ['Opening-Heavy', 'Risk-Reward', 'Tactical Focus'],
  },

  blindfold_blitz: {
    id: 'blindfold_blitz',
    name: 'Blindfold Blitz',
    description: 'Board hidden every 3 seconds during opponent move - memory + pattern recognition',
    icon: '👁️',
    xpMultiplier: 1.5,
    difficulty: 'extreme',
    rules: [
      'Board becomes hidden every 3 seconds of opponent turn',
      'Players must remember piece positions',
      'Reappears after opponent move/after 3 sec',
      'Requires extreme focus and memory',
    ],
    maxPlayers: 2,
    minPlayers: 2,
    ratingImpact: 'doubled',
    specialFeatures: ['Memory Test', 'Pattern Recognition', 'Bragging Rights'],
  },

  chess_roulette: {
    id: 'chess_roulette',
    name: 'Chess Roulette',
    description: 'One random piece removed from both players - unpredictable gameplay',
    icon: '🎰',
    xpMultiplier: 1.1,
    difficulty: 'hard',
    rules: [
      'One random piece (not king/pawns) removed from both players',
      'Different piece removed in fresh games',
      'Eliminates preparation advantage',
      'Strategic adaptation required mid-game',
    ],
    maxPlayers: 2,
    minPlayers: 2,
    ratingImpact: 'normal',
    specialFeatures: [
      'Unpredictability',
      'Dynamic Strategy',
      'Fresh Every Time',
    ],
  },

  speed_tactics: {
    id: 'speed_tactics',
    name: 'Speed Tactics',
    description: 'Save embedded tactical puzzles appear at moves 10, 15, 20 - blend puzzle + game',
    icon: '🧩',
    xpMultiplier: 1.3,
    difficulty: 'hard',
    rules: [
      'At moves 10, 15, 20, 25 - puzzle overlay appears for 4 seconds',
      'Player can attempt puzzle for +5 XP or skip',
      'Puzzle difficulty based on game position',
      'Incorrect puzzle = no bonus + time loss',
    ],
    maxPlayers: 2,
    minPlayers: 2,
    ratingImpact: 'halved',
    specialFeatures: [
      'Multi-Skill Engagement',
      'Puzzle Rewards',
      'Skill Diversity',
    ],
  },

  team_chess: {
    id: 'team_chess',
    name: 'Team Chess',
    description: '2v2 multiplayer - teams share rating and alternate colors',
    icon: '👥',
    xpMultiplier: 0.9,
    difficulty: 'medium',
    rules: [
      'Player 1 plays White, Player 3 plays Black',
      'Team chat allowed (can discuss strategy)',
      'Rating shared between 2 teammates',
      'Victory counts for both team members',
    ],
    maxPlayers: 4,
    minPlayers: 4,
    ratingImpact: 'halved',
    specialFeatures: ['Social Bonding', 'Shared Rating', 'Team Communication'],
  },

  atomic_chess: {
    id: 'atomic_chess',
    name: 'Atomic Chess',
    description: 'Captures cause explosion eliminating all pieces in 1 square radius',
    icon: '💥',
    xpMultiplier: 1.3,
    difficulty: 'extreme',
    rules: [
      'King cannot be in check (normal) but captures cause explosion',
      'All pieces within 1 square of capture point are eliminated',
      'King explosion = immediate loss',
      'Completely changes tactical calculations',
    ],
    maxPlayers: 2,
    minPlayers: 2,
    ratingImpact: 'doubled',
    specialFeatures: ['Radical Tactics', 'Chaos Factor', 'Counter-Intuitive Strategy'],
  },

  tempo_duel: {
    id: 'tempo_duel',
    name: 'Tempo Duel',
    description: 'Leaderboard by move speed (MPM) not rating - speed racing with quality check',
    icon: '⏱️',
    xpMultiplier: 1.0,
    difficulty: 'hard',
    rules: [
      'Standard chess rules apply',
      'Leaderboard tracks Moves Per Minute (MPM)',
      'Accuracy bonus if >85% accuracy +5% MPM boost',
      'Blunder penalty = -10% MPM',
    ],
    maxPlayers: 2,
    minPlayers: 2,
    ratingImpact: 'normal',
    specialFeatures: ['Speed Metric', 'Quality vs Speed', 'New Leaderboard'],
  },

  promotion_fever: {
    id: 'promotion_fever',
    name: 'Promotion Fever',
    description: 'Captures add 3s to opponent time, promotions add 5s to your time',
    icon: '👸',
    xpMultiplier: 1.25,
    difficulty: 'hard',
    rules: [
      'Every capture: opponent gains +3 seconds on clock',
      'Every promotion: you gain +5 seconds on clock',
      'Forces promotion focus (alternative to taking pieces)',
      'Endgame becomes high-stakes time pressure',
    ],
    maxPlayers: 2,
    minPlayers: 2,
    ratingImpact: 'normal',
    specialFeatures: ['Dynamic Clock', 'Endgame Focus', 'Risk-Reward Endgame'],
  },

  fortress_fortress: {
    id: 'fortress_fortress',
    name: 'Fortress Fortress Challenge',
    description: 'Achieve 3 consecutive draws in a series - drawing mastery mode',
    icon: '🛡️',
    xpMultiplier: 1.1,
    difficulty: 'hard',
    rules: [
      'Best-of-3 series focused on drawing',
      'Win if: 3 consecutive draws achieved in series',
      'Draw counts toward series, loss resets counter',
      'Shows defensive mastery and technical skill',
    ],
    maxPlayers: 2,
    minPlayers: 2,
    ratingImpact: 'halved',
    specialFeatures: ['Drawing Mastery', 'Series Format', 'Technical Skill Showcase'],
  },

  material_handicap: {
    id: 'material_handicap',
    name: 'Material Handicap Mode',
    description: 'Lower-rated player starts with 1-2 extra pieces (skill balancing)',
    icon: '⚖️',
    xpMultiplier: 1.0,
    difficulty: 'easy',
    rules: [
      'ELO delta > 400: lower player gets +2 pieces (2 pawns or 1 minor)',
      'ELO delta 200-400: lower player gets +1 piece',
      'ELO delta < 200: standard chess',
      'Allows skill-disparate matches to be meaningful',
    ],
    maxPlayers: 2,
    minPlayers: 2,
    ratingImpact: 'normal',
    specialFeatures: ['Skill Balancing', 'Fair Competition', 'Inclusive Play'],
  },
}

// ═════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═════════════════════════════════════════════════════════════════

/**
 * Get variant config by ID
 */
export function getVariantConfig(variantId: GameVariant): VariantConfig {
  return GAME_VARIANTS[variantId] || GAME_VARIANTS.standard
}

/**
 * Calculate XP earned with variant multiplier
 */
export function calculateVariantXP(
  baseXP: number,
  variantId: GameVariant,
  isWin: boolean
): number {
  const variant = getVariantConfig(variantId)
  const multipliedXP = Math.round(baseXP * variant.xpMultiplier)

  if (!isWin && variant.id !== 'standard') {
    // Losing in variants still gives reduced XP (50% of multiplied)
    return Math.round(multipliedXP * 0.5)
  }

  return multipliedXP
}

/**
 * Get variant difficulty emoji
 */
export function getVariantDifficultyEmoji(
  difficulty: VariantConfig['difficulty']
): string {
  return {
    easy: '🟢',
    medium: '🟡',
    hard: '🔴',
    extreme: '💀',
  }[difficulty]
}

/**
 * List all variants sorted by difficulty
 */
export function getAllVariants(): VariantConfig[] {
  const difficultyOrder = { easy: 0, medium: 1, hard: 2, extreme: 3 }
  return Object.values(GAME_VARIANTS).sort(
    (a, b) =>
      difficultyOrder[a.difficulty] - difficultyOrder[b.difficulty]
  )
}

/**
 * Get available variants for casual play
 */
export function getCasualVariants(): VariantConfig[] {
  return [
    GAME_VARIANTS.standard,
    GAME_VARIANTS.chess_roulette,
    GAME_VARIANTS.material_handicap,
    GAME_VARIANTS.tempo_duel,
  ]
}

/**
 * Get available variants for ranked tournaments
 */
export function getRankedVariants(): VariantConfig[] {
  return [
    GAME_VARIANTS.standard,
    GAME_VARIANTS.kings_gambit,
    GAME_VARIANTS.speed_tactics,
    GAME_VARIANTS.atomic_chess,
  ]
}
