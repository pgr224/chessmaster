import 'dart:async';

import 'package:chess_master/data/services/reconnecting_socket.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _Channel extends Mock implements WebSocketChannel {}

class _Sink extends Mock implements WebSocketSink {}

(_Channel, StreamController<dynamic>) channel({Future<void>? ready}) {
  final socket = _Channel();
  final sink = _Sink();
  final input = StreamController<dynamic>.broadcast(sync: true);
  when(() => socket.stream).thenAnswer((_) => input.stream);
  when(() => socket.sink).thenReturn(sink);
  when(() => socket.ready).thenAnswer((_) => ready ?? Future<void>.value());
  when(() => sink.close()).thenAnswer((_) async {});
  return (socket, input);
}

void main() {
  test('failed handshakes use a bounded retry budget and never replay actions',
      () async {
    var attempts = 0;
    final statuses = <(bool, bool)>[];
    final socket = ReconnectingSocket(
      connect: (_) {
        attempts++;
        return channel(ready: Future.error(StateError('offline'))).$1;
      },
      retryDelays: const [Duration(milliseconds: 1), Duration(milliseconds: 1)],
      onMessage: (_) {},
      onStatus: (connected, retrying, _) => statuses.add((connected, retrying)),
    );
    await socket.open(() async => Uri.parse('wss://test/room'));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(attempts, 3);
    expect(statuses.last, (false, false));
    expect(socket.connected, false);
    socket.disconnect();
  });

  test('reconnect keeps incoming server snapshots and ignores replaced sockets',
      () async {
    final old = channel();
    final fresh = channel();
    var attempts = 0;
    final messages = <dynamic>[];
    final socket = ReconnectingSocket(
      connect: (_) => attempts++ == 0 ? old.$1 : fresh.$1,
      retryDelays: const [Duration(milliseconds: 1)],
      onMessage: messages.add,
      onStatus: (_, __, ___) {},
    );
    await socket.open(() async => Uri.parse('wss://test/room'));
    old.$2.add('initial snapshot');
    await old.$2.close();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    fresh.$2.add('restored snapshot');
    expect(messages, ['initial snapshot', 'restored snapshot']);
    expect(socket.connected, true);
    socket.disconnect();
    await fresh.$2.close();
  });

  test(
      'explicit disconnect cancels retry and delayed credential/handshake callbacks',
      () async {
    var attempts = 0;
    final credentials = Completer<Uri>();
    final socket = ReconnectingSocket(
      connect: (_) {
        attempts++;
        return channel().$1;
      },
      retryDelays: const [Duration(milliseconds: 1)],
      onMessage: (_) {},
      onStatus: (_, __, ___) {},
    );
    final opening = socket.open(() => credentials.future);
    socket.disconnect();
    credentials.complete(Uri.parse('wss://test/room'));
    await opening;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(attempts, 0);
    expect(socket.connected, false);
  });

  test('explicit leave while a retry is pending prevents reconnection',
      () async {
    final connection = channel();
    var attempts = 0;
    final socket = ReconnectingSocket(
      connect: (_) {
        attempts++;
        return connection.$1;
      },
      retryDelays: const [Duration(milliseconds: 20)],
      onMessage: (_) {},
      onStatus: (_, __, ___) {},
    );
    await socket.open(() async => Uri.parse('wss://test/room'));
    await connection.$2.close();
    socket.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(attempts, 1);
  });
  test(
      'late callbacks from a replaced handshake cannot replace the new connection',
      () async {
    final ready = Completer<void>();
    final old = channel(ready: ready.future);
    final fresh = channel();
    var attempts = 0;
    var connectedEvents = 0;
    final socket = ReconnectingSocket(
      connect: (_) => attempts++ == 0 ? old.$1 : fresh.$1,
      onMessage: (_) {},
      onStatus: (connected, _, __) {
        if (connected) connectedEvents++;
      },
    );
    final previousOpen = socket.open(() async => Uri.parse('wss://test/old'));
    await Future<void>.delayed(Duration.zero);
    await socket.open(() async => Uri.parse('wss://test/new'));
    ready.complete();
    await previousOpen;
    expect(socket.channel, same(fresh.$1));
    expect(connectedEvents, 1);
    socket.disconnect();
    await old.$2.close();
    await fresh.$2.close();
  });
}
