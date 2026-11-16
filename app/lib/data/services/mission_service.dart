import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mission_model.dart';
import '../repositories/auth_repository.dart';
import '../../core/services/logging_service.dart';

class MissionService {
  final SharedPreferences _prefs;
  final AuthRepository _authRepository;

  String get _missionsKey => 'user_missions_v2_$_scope';
  String get _lastResetKey => 'mission_last_reset_$_scope';
  String _scope = 'guest';
  static const String _bountyTargetKey = 'bounty_target_id';
  static const String _bountyExpiryKey = 'bounty_expiry';

  List<Mission> _activeMissions = [];
  String? _bountyUserId;
  DateTime? _bountyExpiry;

  MissionService(this._prefs, this._authRepository) {
    _ensureScope();
    _checkDailyReset();
    _checkBountyRotation();
  }

  List<Mission> get missions {
    _ensureScope();
    _checkDailyReset();
    return _activeMissions;
  }

  void _ensureScope() {
    final raw = _prefs.getString('user_data');
    final scope =
        raw == null ? 'guest' : (jsonDecode(raw) as Map)['id'].toString();
    if (_scope != scope || _activeMissions.isEmpty) {
      _scope = scope;
      _loadMissions();
      _checkDailyReset();
    }
  }

  Future<void> recordGameResult(String gameId,
      {required bool isWin,
      required bool isOnline,
      required int currentStreak}) async {
    if (_prefs.getBool(AuthRepository.guestSessionKey) == true) return;
    _ensureScope();
    _checkDailyReset();
    final key = 'mission_result_$_scope:$gameId';
    if (_prefs.getBool(key) == true) return;
    await _prefs.setBool(key, true);
    await updateProgress('daily_games');
    if (isOnline && isWin) await updateProgress('online_win');
    await updateProgress('streak_hunter', setCount: currentStreak);
  }

  String? get bountyUserId => _bountyUserId;
  Future<String?> refreshBounty() async {
    await _rotateBounty();
    return _bountyUserId;
  }

  void _loadMissions() {
    final data = _prefs.getString(_missionsKey);
    if (data != null) {
      final List decoded = jsonDecode(data);
      _activeMissions = decoded.map((m) => Mission.fromJson(m)).toList();
    } else {
      _generateDefaultMissions();
    }

    _bountyUserId = _prefs.getString(_bountyTargetKey);
    final expiryStr = _prefs.getString(_bountyExpiryKey);
    if (expiryStr != null) {
      _bountyExpiry = DateTime.parse(expiryStr);
    }
  }

  Future<void> _checkBountyRotation() async {
    final now = DateTime.now();
    if (_bountyExpiry == null || now.isAfter(_bountyExpiry!)) {
      await _rotateBounty();
    }
  }

  Future<void> _rotateBounty() async {
    if (_prefs.getBool(AuthRepository.guestSessionKey) == true) return;
    try {
      final response = await _authRepository.getBountyTarget();
      final target = response['target'] as Map?;
      if (target == null) return;
      _bountyUserId = target['id'].toString();
      _bountyExpiry = DateTime.parse(response['expiresAt'].toString());

      await _prefs.setString(_bountyTargetKey, _bountyUserId!);
      await _prefs.setString(
          _bountyExpiryKey, _bountyExpiry!.toIso8601String());
    } catch (e) {
      LoggingService.error('Bounty rotation failed', e);
    }
  }

  void _generateDefaultMissions() {
    _activeMissions = [
      const Mission(
        id: 'daily_games',
        title: 'Daily Warrior',
        description: 'Play 3 games of any type',
        rewardXP: 100,
        targetCount: 3,
      ),
      const Mission(
        id: 'puzzle_solver',
        title: 'Tactician',
        description: 'Solve 5 puzzles successfully',
        rewardXP: 150,
        targetCount: 5,
      ),
      const Mission(
        id: 'online_win',
        title: 'Competitive Spirit',
        description: 'Win 1 online multiplayer game',
        rewardXP: 250,
        targetCount: 1,
      ),
      const Mission(
        id: 'streak_hunter',
        title: 'Momentum',
        description: 'Reach a 3-win streak',
        rewardXP: 200,
        targetCount: 3,
      ),
    ];
    _saveMissions();
  }

  void _saveMissions() {
    _prefs.setString(_missionsKey,
        jsonEncode(_activeMissions.map((m) => m.toJson()).toList()));
  }

  void _checkDailyReset() {
    final now = DateTime.now();
    final lastResetStr = _prefs.getString(_lastResetKey);

    if (lastResetStr != null) {
      final lastReset = DateTime.parse(lastResetStr);
      if (now.day != lastReset.day ||
          now.month != lastReset.month ||
          now.year != lastReset.year) {
        _generateDefaultMissions();
        _prefs.setString(_lastResetKey, now.toIso8601String());
      }
    } else {
      _prefs.setString(_lastResetKey, now.toIso8601String());
    }
  }

  Future<void> updateProgress(String missionId,
      {int delta = 1, int? setCount}) async {
    if (_prefs.getBool(AuthRepository.guestSessionKey) == true) return;
    _ensureScope();
    _checkDailyReset();
    final index = _activeMissions.indexWhere((m) => m.id == missionId);
    if (index != -1 && !_activeMissions[index].isCompleted) {
      final updated = _activeMissions[index].copyWith(
        currentCount: setCount ?? _activeMissions[index].currentCount + delta,
      );
      _activeMissions[index] = updated;
      _saveMissions();

      if (updated.isCompleted) {
        // Auto-claim reward for now
        await claimReward(missionId);
      }
    }
  }

  Future<void> claimReward(String missionId) async {
    if (_prefs.getBool(AuthRepository.guestSessionKey) == true) return;
    _ensureScope();
    _checkDailyReset();
    final index = _activeMissions.indexWhere((m) => m.id == missionId);
    if (index != -1 &&
        _activeMissions[index].isCompleted &&
        !_activeMissions[index].isClaimed) {
      final mission = _activeMissions[index];

      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        await _authRepository.updateXPProgress(
          userId: user.id,
          xpDelta: mission.rewardXP,
          eventId:
              'mission:${DateTime.now().toIso8601String().substring(0, 10)}:$missionId',
          statUpdates: {},
        );

        _activeMissions[index] = mission.copyWith(isClaimed: true);
        _saveMissions();
      }
    }
  }
}
