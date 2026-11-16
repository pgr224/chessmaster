import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Retries transport failures without replaying moves or other player actions.
class ReconnectingSocket {
  ReconnectingSocket({
    required this.connect,
    required this.onMessage,
    required this.onStatus,
    this.retryDelays = const [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ],
    this.connectTimeout = const Duration(seconds: 5),
  });

  final WebSocketChannel Function(Uri) connect;
  final void Function(dynamic) onMessage;
  final void Function(bool connected, bool retrying, String? error) onStatus;
  final List<Duration> retryDelays;
  final Duration connectTimeout;
  WebSocketChannel? channel;
  bool connected = false;
  Future<Uri> Function()? _address;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  Timer? _stable;
  int _generation = 0;
  int _attempt = 0;

  Future<void> open(Future<Uri> Function() address) {
    disconnect();
    _address = address;
    return _open(_generation);
  }

  Future<void> reconnect() async {
    final address = _address;
    if (address != null && !connected) await open(address);
  }

  Future<void> _open(int generation) async {
    WebSocketChannel? candidate;
    try {
      final uri = await _address!();
      if (generation != _generation || _address == null) return;
      candidate = connect(uri);
      channel = candidate;
      final current = candidate;
      _subscription = current.stream.listen(
        (message) {
          if (generation != _generation || channel != current) return;
          onMessage(message);
        },
        onDone: () => _lost(generation, current, null),
        onError: (Object error) => _lost(generation, current, error.toString()),
        cancelOnError: true,
      );
      await current.ready.timeout(connectTimeout);
      if (generation != _generation || channel != current) return;
      connected = true;
      _stable?.cancel();
      _stable = Timer(const Duration(seconds: 30), () {
        if (generation == _generation && channel == current) _attempt = 0;
      });
      onStatus(true, false, null);
    } catch (error) {
      if (generation != _generation) return;
      if (candidate == null || channel == candidate) {
        _lost(generation, candidate, error.toString());
      }
    }
  }

  void _lost(int generation, WebSocketChannel? failed, String? error) {
    if (generation != _generation || channel != failed || _retry != null)
      return;
    connected = false;
    _stable?.cancel();
    _stable = null;
    channel = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      failed?.sink.close();
    } catch (_) {}
    if (_address == null) return;
    final retrying = _attempt < retryDelays.length;
    onStatus(false, retrying, error);
    if (!retrying) return;
    _retry = Timer(retryDelays[_attempt++], () {
      _retry = null;
      if (generation == _generation && _address != null) {
        unawaited(_open(generation));
      }
    });
  }

  bool send(dynamic message) {
    final current = channel;
    if (!connected || current == null) return false;
    try {
      current.sink.add(message);
      return true;
    } catch (error) {
      _lost(_generation, current, error.toString());
      return false;
    }
  }

  void disconnect() {
    _generation++;
    _address = null;
    _attempt = 0;
    _retry?.cancel();
    _retry = null;
    _stable?.cancel();
    _stable = null;
    connected = false;
    final old = channel;
    channel = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      old?.sink.close();
    } catch (_) {}
  }
}
