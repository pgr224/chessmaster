/// XP Rules for all game modes
/// Aligned with what is displayed in profile settings

const Map<String, Map<String, int>> xpRules = {
  // Multiplayer vs other players
  'multiplayer': {
    'win': 100,
    'draw': 30,
    'loss': -20,
  },

  // Tournament
  'tournament': {
    'win': 100,
    'draw': 30,
    'loss': -20,
    'tournamentWinBonus': 200,
  },

  // Penalties
  'penalties': {
    'takeback': -25,
    'hintUsage': -10,
  },
};

/// Calculate XP for a multiplayer game result
int calculateMultiplayerXP(String result) {
  final rules = xpRules['multiplayer'];
  if (rules == null) {
    return 0;
  }

  switch (result) {
    case 'win':
      return rules['win'] ?? 0;
    case 'draw':
      return rules['draw'] ?? 0;
    case 'loss':
      return rules['loss'] ?? 0;
    default:
      return 0;
  }
}

/// No longer use reason-based variations (checkmate/timeout bonuses)
/// Use standardized rules instead
int calculateGameOverXP({
  required String result, // 'win', 'draw', 'loss'
  String? reason,
}) {
  // Reason is ignored - use standardized rules
  return calculateMultiplayerXP(result);
}
