import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Audio service that plays locally bundled sound assets.
/// All sounds are stored in assets/sounds/ and loaded via AssetSource.
class AudioService {
  final AudioPlayer _player = AudioPlayer();

  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  bool _enabled = true;

  void setEnabled(bool enabled) => _enabled = enabled;
  bool get isEnabled => _enabled;

  /// Play a sound event using local asset files.
  /// [eventType] maps to a local .wav file in assets/sounds/.
  void playSound(String eventType, [String? boardTheme]) async {
    if (!_enabled) return;

    try {
      final fileName = _resolveFileName(eventType);
      await _player.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  /// Resolve event type to local asset filename.
  String _resolveFileName(String eventType) {
    return switch (eventType) {
      'capture' => 'capture.wav',
      'check' => 'check.wav',
      'castle' => 'castle.wav',
      'promote' => 'promote.wav',
      'game-start' => 'game_start.wav',
      'game-end' => 'game_end.wav',
      'move-opponent' => 'move_opponent.wav',
      'move-self' => 'move.wav',
      'move' => 'move.wav',
      'win' => 'win.wav',
      'warning' => 'warning.wav',
      'illegal' => 'illegal.wav',
      'low-time' => 'low_time.wav',
      _ => 'move.wav', // fallback
    };
  }

  void dispose() {
    _player.dispose();
  }
}
