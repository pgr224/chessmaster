/// XP Rules for all game modes
/// Aligned with what is displayed in profile settings

const xpRules = {
  // Multiplayer vs other players
  multiplayer: {
    win: 100,
    draw: 30,
    loss: -20,
  },

  // Tournament
  tournament: {
    win: 100,
    draw: 30,
    loss: -20,
    tournamentWinBonus: 200,
  },

  // Penalties
  penalties: {
    takeback: -25,
    hintUsage: -10,
  },
};

/// Calculate XP for a multiplayer game result
int calculateMultiplayerXP(String result) {
  switch (result) {
    case 'win':
      return xpRules['multiplayer']['win'] as int;
    case 'draw':
      return xpRules['multiplayer']['draw'] as int;
    case 'loss':
      return xpRules['multiplayer']['loss'] as int;
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
