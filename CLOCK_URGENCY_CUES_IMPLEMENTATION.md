# ⏰ Visual & Audio Clock Urgency Cues Enhancement

## Implementation Guide for Time Control Visual Feedback

### Goal
Add visual and optional audio feedback when players approach time trouble, creating urgency and engagement.

---

## 1. RED GLOW VISUAL CUE (< 10 seconds)

### Location: Game Board Widget
```dart
// In game_screen.dart or board_widget.dart

Widget _buildGameBoard(GameState state) {
  final timeRemaining = state.currentPlayerTimeRemaining; // in milliseconds
  final isLowTime = timeRemaining < 10000; // < 10 seconds
  
  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isLowTime ? AppTheme.accentRed : Colors.transparent,
        width: isLowTime ? 4 : 0,
      ),
      boxShadow: isLowTime
        ? [
            BoxShadow(
              color: AppTheme.accentRed.withValues(alpha: 0.5),
              blurRadius: 30,
              spreadRadius: 3,
            ),
          ]
        : [],
    ),
    child: _buildChessBoard(),
  );
}
```

### Severity Levels

| Time Range | Visual | Animation | Color |
|---|---|---|---|
| > 30s | None | Stable | Transparent |
| 10-30s | Yellow border | Pulse slow | `AppTheme.accentOrange` |
| 5-10s | Red border | Pulse medium | `AppTheme.accentRed` |
| < 5s | Red border + glow | Pulse fast | `AppTheme.accentRed` |

### Animation Code
```dart
// Add pulse animation for < 10s
class _PulseAnimation extends StatefulWidget {
  final Color color;
  final Duration duration;
  
  @override
  State<_PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<_PulseAnimation> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat(reverse: true);
  }
  
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.05).animate(_controller),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: widget.color, width: 4),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
```

---

## 2. CLOCK COLOR PROGRESSION

### Clock Display Widget Enhancement
```dart
Widget _buildClockDisplay(int timeRemainingMs) {
  final seconds = timeRemainingMs ~/ 1000;
  
  // Determine clock color based on time
  final clockColor = seconds > 30
    ? AppTheme.accentGreen       // Plenty of time
    : seconds > 10
    ? AppTheme.accentOrange      // Yellow warning
    : seconds > 5
    ? AppTheme.accentRed         // Red alarm
    : Colors.red;                // Danger, pulsing

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: clockColor.withValues(alpha: 0.15),
      border: Border.all(color: clockColor, width: 2),
      borderRadius: BorderRadius.circular(12),
      boxShadow: seconds < 10
        ? [
            BoxShadow(
              color: clockColor.withValues(alpha: 0.5),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ]
        : [],
    ),
    child: Text(
      _formatTime(timeRemainingMs),
      style: GoogleFonts.fredoka(
        color: clockColor,
        fontSize: seconds < 5 ? 32 : 24,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

String _formatTime(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
```

---

## 3. OPTIONAL AUDIO ALERTS

### Backend Time Control Configuration
```typescript
// In time_control.ts

export interface AudioAlertConfig {
  enabled: boolean
  alertAt: number[] // Alert times in seconds: [30, 10, 5, 1]
  soundType: 'bell' | 'beep' | 'alarm' | 'none'
  volume: number // 0.0 - 1.0
}

export const DEFAULT_AUDIO_ALERTS: AudioAlertConfig = {
  enabled: false,  // Opt-in only
  alertAt: [10, 5, 2],  // Alert at 10s, 5s, 2s
  soundType: 'bell',
  volume: 0.7,
}
```

### Frontend Audio Implementation
```dart
// In game_screen.dart

class GameScreen extends StatefulWidget {
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late AudioPlayer _audioPlayer;
  Set<int> _triggeredAlerts = {};
  
  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupTimeAlerts();
  }
  
  void _setupTimeAlerts() {
    // Listen to clock updates
    Timer.periodic(Duration(milliseconds: 500), (timer) {
      final timeMs = _getCurrentPlayerTime();
      final seconds = timeMs ~/ 1000;
      
      final alertTimes = [10, 5, 2];
      
      for (int alertTime in alertTimes) {
        if (seconds == alertTime && !_triggeredAlerts.contains(alertTime)) {
          _playAlertSound();
          _triggeredAlerts.add(alertTime);
        }
      }
      
      // Reset triggered alerts when time increases
      if (seconds > 10) {
        _triggeredAlerts.clear();
      }
    });
  }
  
  Future<void> _playAlertSound() async {
    if (!_userAudioAlertsEnabled()) return;
    
    try {
      await _audioPlayer.play(
        AssetSource('sounds/clock_alert.mp3'),
        volume: 0.7,
      );
    } catch (e) {
      print('Audio alert failed: $e');
    }
  }
  
  bool _userAudioAlertsEnabled() {
    return context.read<SettingsBloc>().state.audioAlertsEnabled;
  }
  
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
```

---

## 4. SETTINGS PAGE ADDITIONS

### Time Control Preferences
```dart
// In settings_screen.dart

class TimeControlSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Audio alerts toggle
        ListTile(
          leading: Icon(Icons.volume_up),
          title: Text('Audio Clock Alerts'),
          subtitle: Text('Play sound when approaching time trouble'),
          trailing: Switch(
            value: _audioAlertsEnabled,
            onChanged: (value) => _updateSetting('audioAlerts', value),
          ),
        ),
        
        // Alert timing
        if (_audioAlertsEnabled) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alert At:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _alertAt10s,
                      onChanged: (v) => _updateAlertTime(10, v ?? false),
                    ),
                    Text('10 seconds'),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: _alertAt5s,
                      onChanged: (v) => _updateAlertTime(5, v ?? false),
                    ),
                    Text('5 seconds'),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: _alertAt1s,
                      onChanged: (v) => _updateAlertTime(1, v ?? false),
                    ),
                    Text('1 second'),
                  ],
                ),
              ],
            ),
          ),
        ],
        
        // Volume control
        if (_audioAlertsEnabled) ...[
          Slider(
            label: 'Alert Volume',
            value: _alertVolume,
            max: 1.0,
            onChanged: (value) => _updateSetting('alertVolume', value),
          ),
        ],
        
        // Visual glow toggle
        SwitchListTile(
          title: Text('Red Glow on Low Time'),
          subtitle: Text('Flash board border when < 10 seconds'),
          value: _visualGlowEnabled,
          onChanged: (value) => _updateSetting('visualGlow', value),
        ),
      ],
    );
  }
}
```

---

## 5. CLOCK TEXT SIZE ADAPTATION

### Dynamic Font Sizing Based on Time
```dart
// In clock_widget.dart

double _getClockFontSize(int timeRemainingMs) {
  final seconds = timeRemainingMs ~/ 1000;
  
  return seconds < 5
    ? 36      // HUGE when in danger
    : seconds < 10
    ? 32      // Very large when low
    : seconds < 30
    ? 24      // Normal
    : 20;     // Slightly smaller when plenty of time
}
```

---

## 6. BACKGROUND FLASH (Optional Extreme)

### For < 5 seconds only
```dart
Widget _buildGameBoardWithFlash(int timeRemainingMs) {
  final seconds = timeRemainingMs ~/ 1000;
  final shouldFlash = seconds < 5;
  
  return FlashingBackground(
    isFlashing: shouldFlash,
    flashColor: AppTheme.accentRed.withValues(alpha: 0.1),
    frequency: Duration(milliseconds: 500),
    child: _buildChessBoard(),
  );
}

class FlashingBackground extends StatefulWidget {
  final bool isFlashing;
  final Color flashColor;
  final Duration frequency;
  final Widget child;
  
  const FlashingBackground({
    required this.isFlashing,
    required this.flashColor,
    required this.frequency,
    required this.child,
  });
  
  @override
  State<FlashingBackground> createState() => _FlashingBackgroundState();
}

class _FlashingBackgroundState extends State<FlashingBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.frequency,
      vsync: this,
    )..repeat(reverse: true);
  }
  
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.isFlashing ? _controller : AlwaysStoppedAnimation(0.0),
      child: Container(
        color: widget.flashColor,
        child: widget.child,
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

---

## 7. IMPLEMENTATION CHECKLIST

### Priority 1 (Critical)
- [ ] Red border glow on board when < 10s
- [ ] Clock color changes (green → yellow → red)
- [ ] Clock font size increases as time decreases

### Priority 2 (High)
- [ ] Pulse animation for urgency
- [ ] Optional audio alerts (opt-in)
- [ ] Settings toggle for visual/audio alerts

### Priority 3 (Polish)
- [ ] Background flash for < 5s (optional, may be overwhelming)
- [ ] Haptic feedback (phone vibration) when alert triggers
- [ ] Custom sound selection in settings

---

## 8. Player Impact

### Expected Benefits
- **Engagement:** Visual feedback increases tension (positive)
- **Fairness:** Clearer indication of time remaining
- **Accessibility:** Optional audio alerts for visually impaired
- **Retention:** Urgency creates flow state during critical moments

### Consideration
- Don't be TOO aggressive (flash/vibrate constantly)
- Keep animations smooth (60fps)
- Ensure audio alerts are optional (respect player control)

---

## Assets Required

### Audio Files (in `assets/sounds/`)
```
- clock_alert_bell.mp3 (soft bell sound)
- clock_alert_beep.mp3 (computer beep)
- clock_alert_alarm.mp3 (stronger alarm)
```

### Recommended Timings
- Alert at 10s: Soft notification (bell)
- Alert at 5s: Medium warning (beep)
- Alert at 2s: Urgent warning (alarm)

