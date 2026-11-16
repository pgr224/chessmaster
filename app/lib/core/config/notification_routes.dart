bool Function(String route)? _routeHandler;
String? _pendingRoute;
String? notificationRoute(Map<String, dynamic> data) {
  final tournament = data['tournamentId']?.toString();
  if (tournament != null && tournament.isNotEmpty)
    return '/tournament/${Uri.encodeComponent(tournament)}';
  final game = data['gameId']?.toString();
  if (game != null && game.isNotEmpty)
    return '/room/${Uri.encodeComponent(game)}';
  final request = data['requestId']?.toString();
  if (request != null && request.isNotEmpty) {
    final key = data['type'] == 'XP_DIRECT_REQUEST'
        ? 'xp_request_id'
        : 'accept_challenge';
    return Uri(path: '/lobby', queryParameters: {key: request}).toString();
  }
  return '/lobby';
}

void setNotificationRouteHandler(bool Function(String route) handler) =>
    _routeHandler = handler;
void handleNotificationData(Map<String, dynamic> data) {
  final route = notificationRoute(data);
  if (route != null && (_routeHandler == null || !_routeHandler!(route)))
    _pendingRoute = route;
}

String? takePendingNotificationRoute() {
  final route = _pendingRoute;
  _pendingRoute = null;
  return route;
}
