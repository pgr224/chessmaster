import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  /// Maps a board theme to a sound theme from the github repo:
  /// https://github.com/Orivoir/scraping-sound-effects-chess.com/tree/main/assets
  String _getSoundTheme(String boardTheme) {
    final t = boardTheme.toLowerCase();
    if (t.contains('marble') || t.contains('stone')) return 'marble';
    if (t.contains('wood') || t.contains('walnut') || t.contains('classic')) return 'default';
    if (t.contains('metal') || t.contains('glass')) return 'metal';
    if (t.contains('nature') || t.contains('green')) return 'nature';
    if (t.contains('neon') || t.contains('space') || t.contains('dark')) return 'space';
    if (t.contains('newspaper') || t.contains('paper')) return 'newspaper';
    if (t.contains('lolz') || t.contains('silly') || t.contains('kids')) return 'silly';
    if (t.contains('beat')) return 'beat';
    
    return 'default'; // fallback
  }

  void playSound(String eventType, String boardTheme) async {
    try {
      final theme = _getSoundTheme(boardTheme);
      // chess.com sound files are commonly named .mp3 or .webm. We use mp3 from the repo
      String fileName = 'move-self.mp3';
      switch (eventType) {
        case 'capture': fileName = 'capture.mp3'; break;
        case 'check': fileName = 'check.mp3'; break;
        case 'castle': fileName = 'castle.mp3'; break;
        case 'promote': fileName = 'promote.mp3'; break;
        case 'game-start': fileName = 'game-start.mp3'; break;
        case 'game-end': fileName = 'game-end.mp3'; break;
        case 'move-opponent': fileName = 'move-opponent.mp3'; break;
        case 'move-self': 
        default: fileName = 'move-self.mp3'; break;
      }
      
      final url = 'https://raw.githubusercontent.com/Orivoir/scraping-sound-effects-chess.com/main/assets/$theme/$fileName';
      
      if (kIsWeb) {
         // Workaround or direct play for web
         await _player.play(UrlSource(url));
      } else {
         await _player.play(UrlSource(url));
      }
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }
}
