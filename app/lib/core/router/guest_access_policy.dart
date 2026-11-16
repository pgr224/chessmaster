/// The same guard applies to navigation taps, deep links and restored routes.
String? guestOnlineFeature(String location, {bool onlineGame = false}) {
  if (onlineGame ||
      location == '/lobby' ||
      location == '/matchmaking' ||
      location.startsWith('/room/')) return 'Online multiplayer';
  if (location.startsWith('/tournament') || location == '/chess_world')
    return 'Tournaments and online chess';
  if (location == '/leaderboard') return 'Leaderboards';
  if (location == '/profile' || location == '/achievements')
    return 'Your player account';
  if (location.startsWith('/settings/donations')) return 'XP sharing';
  return null;
}
