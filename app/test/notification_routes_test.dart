import 'package:chess_master/core/config/notification_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification identifiers stay inside a single encoded route segment',
      () {
    expect(notificationRoute({'tournamentId': 'event/other?x=1'}),
        '/tournament/event%2Fother%3Fx%3D1');
    expect(notificationRoute({'gameId': 'match#other'}), '/room/match%23other');
    final uri = Uri.parse(notificationRoute(
        {'type': 'XP_DIRECT_REQUEST', 'requestId': 'donation&other=value'})!);
    expect(uri.path, '/lobby');
    expect(uri.queryParameters, {'xp_request_id': 'donation&other=value'});
  });

  test(
      'a cold-start notification waits for authentication and is consumed once',
      () {
    takePendingNotificationRoute();
    setNotificationRouteHandler((_) => false);
    handleNotificationData({'gameId': 'match-1'});
    expect(takePendingNotificationRoute(), '/room/match-1');
    expect(takePendingNotificationRoute(), isNull);
    String? opened;
    setNotificationRouteHandler((route) {
      opened = route;
      return true;
    });
    handleNotificationData({'tournamentId': 'event-1'});
    expect(opened, '/tournament/event-1');
    expect(takePendingNotificationRoute(), isNull);
  });
}
