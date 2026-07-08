import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../core/services/logging_service.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override
  List<Object?> get props => [];
}

class SettingsLoadEvent extends SettingsEvent {}

class SettingsSoundEvent extends SettingsEvent {
  final bool enabled;
  const SettingsSoundEvent(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

class SettingsVibrationEvent extends SettingsEvent {
  final bool enabled;
  const SettingsVibrationEvent(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

class SettingsNotificationsEvent extends SettingsEvent {
  final bool enabled;
  const SettingsNotificationsEvent(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

class SettingsNotificationCategoryEvent extends SettingsEvent {
  final String category;
  final bool enabled;
  const SettingsNotificationCategoryEvent(this.category, this.enabled);

  @override
  List<Object?> get props => [category, enabled];
}

class SettingsShowCoordinatesEvent extends SettingsEvent {
  final bool enabled;
  const SettingsShowCoordinatesEvent(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

class SettingsShowSquareLabelsEvent extends SettingsEvent {
  final bool enabled;
  const SettingsShowSquareLabelsEvent(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

class SettingsShowLegalMovesEvent extends SettingsEvent {
  final bool enabled;
  const SettingsShowLegalMovesEvent(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

class SettingsAutoFlipBoardEvent extends SettingsEvent {
  final bool enabled;
  const SettingsAutoFlipBoardEvent(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

class SettingsMoveAnimationSpeedEvent extends SettingsEvent {
  final String speed;
  const SettingsMoveAnimationSpeedEvent(this.speed);
  @override
  List<Object?> get props => [speed];
}

class SettingsConfirmResignEvent extends SettingsEvent {
  final bool enabled;
  const SettingsConfirmResignEvent(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

class SettingsConfirmDrawOfferEvent extends SettingsEvent {
  final bool enabled;
  const SettingsConfirmDrawOfferEvent(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

class SettingsConfirmMovesEvent extends SettingsEvent {
  final bool enabled;
  const SettingsConfirmMovesEvent(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

class SettingsAutoQueenEvent extends SettingsEvent {
  final bool enabled;
  const SettingsAutoQueenEvent(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

class SettingsAIDifficultyLevelEvent extends SettingsEvent {
  final int level;
  const SettingsAIDifficultyLevelEvent(this.level);
  @override
  List<Object?> get props => [level];
}

/// Updates the fine-grained level for a specific difficulty mode.
class SettingsAIModeLevelEvent extends SettingsEvent {
  final String mode; // 'easy', 'medium', 'hard', 'impossible'
  final int level;
  const SettingsAIModeLevelEvent(this.mode, this.level);
  @override
  List<Object?> get props => [mode, level];
}

/// Sets which difficulty mode was last selected.
class SettingsAILastDifficultyEvent extends SettingsEvent {
  final String difficulty; // 'basic', 'intermediate', 'advanced', 'impossible'
  const SettingsAILastDifficultyEvent(this.difficulty);
  @override
  List<Object?> get props => [difficulty];
}

/// Bulk-loads AI difficulty settings from the server profile.
class SettingsLoadAIDifficultyFromProfile extends SettingsEvent {
  final int aiEasyLevel;
  final int aiMediumLevel;
  final int aiHardLevel;
  final int aiImpossibleLevel;
  final String aiLastDifficulty;
  const SettingsLoadAIDifficultyFromProfile({
    required this.aiEasyLevel,
    required this.aiMediumLevel,
    required this.aiHardLevel,
    required this.aiImpossibleLevel,
    required this.aiLastDifficulty,
  });
  @override
  List<Object?> get props => [aiEasyLevel, aiMediumLevel, aiHardLevel, aiImpossibleLevel, aiLastDifficulty];
}

class SettingsBackgroundEvent extends SettingsEvent {
  final String theme;
  const SettingsBackgroundEvent(this.theme);
  @override
  List<Object?> get props => [theme];
}

class SettingsState extends Equatable {
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool notificationsEnabled;
  final bool notificationChallenges;
  final bool notificationCommunity;
  final bool notificationTournaments;
  final bool notificationSystem;
  final bool showCoordinates;
  final bool showSquareLabels;
  final bool showLegalMoves;
  final bool autoFlipBoard;
  final String moveAnimationSpeed;
  final bool confirmResign;
  final bool confirmDrawOffer;
  final bool confirmMoves;
  final bool autoQueen;
  final int aiDifficultyLevel;
  final int aiEasyLevel;
  final int aiMediumLevel;
  final int aiHardLevel;
  final int aiImpossibleLevel;
  final String aiLastDifficulty; // 'basic', 'intermediate', 'advanced', 'impossible'
  final String backgroundTheme;
  final bool isLoaded;

  const SettingsState({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.notificationsEnabled = true,
    this.notificationChallenges = true,
    this.notificationCommunity = true,
    this.notificationTournaments = true,
    this.notificationSystem = true,
    this.showCoordinates = true,
    this.showSquareLabels = false,
    this.showLegalMoves = true,
    this.autoFlipBoard = false,
    this.moveAnimationSpeed = 'normal',
    this.confirmResign = true,
    this.confirmDrawOffer = true,
    this.confirmMoves = false,
    this.autoQueen = false,
    this.aiDifficultyLevel = 8,
    this.aiEasyLevel = 5,
    this.aiMediumLevel = 15,
    this.aiHardLevel = 35,
    this.aiImpossibleLevel = 100,
    this.aiLastDifficulty = 'intermediate',
    this.backgroundTheme = 'midnight',
    this.isLoaded = false,
  });

  /// Convenience: get the fine-grained level for the currently selected difficulty mode.
  int get activeDifficultyLevel => switch (aiLastDifficulty) {
    'basic' => aiEasyLevel,
    'intermediate' => aiMediumLevel,
    'advanced' => aiHardLevel,
    'impossible' => aiImpossibleLevel,
    _ => aiMediumLevel,
  };

  SettingsState copyWith({
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? notificationsEnabled,
    bool? notificationChallenges,
    bool? notificationCommunity,
    bool? notificationTournaments,
    bool? notificationSystem,
    bool? showCoordinates,
    bool? showSquareLabels,
    bool? showLegalMoves,
    bool? autoFlipBoard,
    String? moveAnimationSpeed,
    bool? confirmResign,
    bool? confirmDrawOffer,
    bool? confirmMoves,
    bool? autoQueen,
    int? aiDifficultyLevel,
    int? aiEasyLevel,
    int? aiMediumLevel,
    int? aiHardLevel,
    int? aiImpossibleLevel,
    String? aiLastDifficulty,
    String? backgroundTheme,
    bool? isLoaded,
  }) =>
      SettingsState(
        soundEnabled: soundEnabled ?? this.soundEnabled,
        vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        notificationChallenges:
          notificationChallenges ?? this.notificationChallenges,
        notificationCommunity: notificationCommunity ?? this.notificationCommunity,
        notificationTournaments:
          notificationTournaments ?? this.notificationTournaments,
        notificationSystem: notificationSystem ?? this.notificationSystem,
        showCoordinates: showCoordinates ?? this.showCoordinates,
        showSquareLabels: showSquareLabels ?? this.showSquareLabels,
        showLegalMoves: showLegalMoves ?? this.showLegalMoves,
        autoFlipBoard: autoFlipBoard ?? this.autoFlipBoard,
        moveAnimationSpeed: moveAnimationSpeed ?? this.moveAnimationSpeed,
        confirmResign: confirmResign ?? this.confirmResign,
        confirmDrawOffer: confirmDrawOffer ?? this.confirmDrawOffer,
        confirmMoves: confirmMoves ?? this.confirmMoves,
        autoQueen: autoQueen ?? this.autoQueen,
        aiDifficultyLevel: aiDifficultyLevel ?? this.aiDifficultyLevel,
        aiEasyLevel: aiEasyLevel ?? this.aiEasyLevel,
        aiMediumLevel: aiMediumLevel ?? this.aiMediumLevel,
        aiHardLevel: aiHardLevel ?? this.aiHardLevel,
        aiImpossibleLevel: aiImpossibleLevel ?? this.aiImpossibleLevel,
        aiLastDifficulty: aiLastDifficulty ?? this.aiLastDifficulty,
        backgroundTheme: backgroundTheme ?? this.backgroundTheme,
        isLoaded: isLoaded ?? this.isLoaded,
      );

  @override
  List<Object?> get props => [
        soundEnabled,
        vibrationEnabled,
        notificationsEnabled,
        notificationChallenges,
        notificationCommunity,
        notificationTournaments,
        notificationSystem,
        showCoordinates,
        showSquareLabels,
        showLegalMoves,
        autoFlipBoard,
        moveAnimationSpeed,
        confirmResign,
        confirmDrawOffer,
        confirmMoves,
        autoQueen,
        aiDifficultyLevel,
        aiEasyLevel,
        aiMediumLevel,
        aiHardLevel,
        aiImpossibleLevel,
        aiLastDifficulty,
        backgroundTheme,
        isLoaded,
      ];
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final Dio? dio;

  SettingsBloc({this.dio}) : super(const SettingsState()) {
    on<SettingsLoadEvent>(_onLoad);
    on<SettingsSoundEvent>((e, emit) async {
      (await SharedPreferences.getInstance()).setBool('sound', e.enabled);
      emit(state.copyWith(soundEnabled: e.enabled));
    });
    on<SettingsVibrationEvent>((e, emit) async {
      (await SharedPreferences.getInstance()).setBool('vibration', e.enabled);
      emit(state.copyWith(vibrationEnabled: e.enabled));
    });
    on<SettingsNotificationsEvent>((e, emit) async {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('notifications', e.enabled);
      emit(state.copyWith(notificationsEnabled: e.enabled));
      await _syncNotificationSettings(prefs, state.copyWith(notificationsEnabled: e.enabled));
    });
    on<SettingsNotificationCategoryEvent>((e, emit) async {
      final prefs = await SharedPreferences.getInstance();
      final next = switch (e.category) {
        'challenges' => state.copyWith(notificationChallenges: e.enabled),
        'community' => state.copyWith(notificationCommunity: e.enabled),
        'tournaments' => state.copyWith(notificationTournaments: e.enabled),
        _ => state.copyWith(notificationSystem: e.enabled),
      };

      switch (e.category) {
        case 'challenges':
          await prefs.setBool('notif_challenges', e.enabled);
          break;
        case 'community':
          await prefs.setBool('notif_community', e.enabled);
          break;
        case 'tournaments':
          await prefs.setBool('notif_tournaments', e.enabled);
          break;
        default:
          await prefs.setBool('notif_system', e.enabled);
          break;
      }

      emit(next);
      await _syncNotificationSettings(prefs, next);
    });
    on<SettingsShowCoordinatesEvent>((e, emit) async {
      (await SharedPreferences.getInstance())
          .setBool('show_coordinates', e.enabled);
      emit(state.copyWith(showCoordinates: e.enabled));
    });
    on<SettingsShowSquareLabelsEvent>((e, emit) async {
      (await SharedPreferences.getInstance())
          .setBool('show_square_labels', e.enabled);
      emit(state.copyWith(showSquareLabels: e.enabled));
    });
    on<SettingsShowLegalMovesEvent>((e, emit) async {
      (await SharedPreferences.getInstance())
          .setBool('show_legal_moves', e.enabled);
      emit(state.copyWith(showLegalMoves: e.enabled));
    });
    on<SettingsAutoFlipBoardEvent>((e, emit) async {
      (await SharedPreferences.getInstance())
          .setBool('auto_flip_board', e.enabled);
      emit(state.copyWith(autoFlipBoard: e.enabled));
    });
    on<SettingsMoveAnimationSpeedEvent>((e, emit) async {
      final normalized =
          (e.speed == 'off' || e.speed == 'fast') ? e.speed : 'normal';
      (await SharedPreferences.getInstance())
          .setString('move_animation_speed', normalized);
      emit(state.copyWith(moveAnimationSpeed: normalized));
    });
    on<SettingsConfirmResignEvent>((e, emit) async {
      (await SharedPreferences.getInstance())
          .setBool('confirm_resign', e.enabled);
      emit(state.copyWith(confirmResign: e.enabled));
    });
    on<SettingsConfirmDrawOfferEvent>((e, emit) async {
      (await SharedPreferences.getInstance())
          .setBool('confirm_draw_offer', e.enabled);
      emit(state.copyWith(confirmDrawOffer: e.enabled));
    });
    on<SettingsConfirmMovesEvent>((e, emit) async {
      (await SharedPreferences.getInstance())
          .setBool('confirm_moves', e.enabled);
      emit(state.copyWith(confirmMoves: e.enabled));
    });
    on<SettingsAutoQueenEvent>((e, emit) async {
      (await SharedPreferences.getInstance()).setBool('auto_queen', e.enabled);
      emit(state.copyWith(autoQueen: e.enabled));
    });
    on<SettingsAIDifficultyLevelEvent>((e, emit) async {
      final level = e.level.clamp(0, 100);
      (await SharedPreferences.getInstance())
          .setInt('ai_difficulty_level', level);
      emit(state.copyWith(aiDifficultyLevel: level));
    });
    on<SettingsAIModeLevelEvent>((e, emit) async {
      final prefs = await SharedPreferences.getInstance();
      
      int level = e.level;
      if (e.mode == 'easy') level = level.clamp(0, 10);
      else if (e.mode == 'medium') level = level.clamp(10, 20);
      else if (e.mode == 'hard') level = level.clamp(20, 50);
      else if (e.mode == 'impossible') level = level.clamp(50, 100);

      final next = switch (e.mode) {
        'easy' => state.copyWith(aiEasyLevel: level),
        'medium' => state.copyWith(aiMediumLevel: level),
        'hard' => state.copyWith(aiHardLevel: level),
        'impossible' => state.copyWith(aiImpossibleLevel: level),
        _ => state,
      };
      await prefs.setInt('ai_${e.mode}_level', level);
      emit(next);
      _syncDifficultySettings(prefs, next);
    });
    on<SettingsAILastDifficultyEvent>((e, emit) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_last_difficulty', e.difficulty);
      final next = state.copyWith(aiLastDifficulty: e.difficulty);
      emit(next);
      _syncDifficultySettings(prefs, next);
    });
    on<SettingsLoadAIDifficultyFromProfile>((e, emit) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ai_easy_level', e.aiEasyLevel);
      await prefs.setInt('ai_medium_level', e.aiMediumLevel);
      await prefs.setInt('ai_hard_level', e.aiHardLevel);
      await prefs.setInt('ai_impossible_level', e.aiImpossibleLevel);
      await prefs.setString('ai_last_difficulty', e.aiLastDifficulty);
      emit(state.copyWith(
        aiEasyLevel: e.aiEasyLevel,
        aiMediumLevel: e.aiMediumLevel,
        aiHardLevel: e.aiHardLevel,
        aiImpossibleLevel: e.aiImpossibleLevel,
        aiLastDifficulty: e.aiLastDifficulty,
      ));
    });
    on<SettingsBackgroundEvent>((e, emit) async {
      (await SharedPreferences.getInstance())
          .setString('background_theme', e.theme);
      emit(state.copyWith(backgroundTheme: e.theme));
    });
  }

  Future<void> _onLoad(
      SettingsLoadEvent event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    var loadedState = SettingsState(
      soundEnabled: prefs.getBool('sound') ?? true,
      vibrationEnabled: prefs.getBool('vibration') ?? true,
      notificationsEnabled: prefs.getBool('notifications') ?? true,
      notificationChallenges: prefs.getBool('notif_challenges') ?? true,
      notificationCommunity: prefs.getBool('notif_community') ?? true,
      notificationTournaments: prefs.getBool('notif_tournaments') ?? true,
      notificationSystem: prefs.getBool('notif_system') ?? true,
      showCoordinates: prefs.getBool('show_coordinates') ?? true,
      showSquareLabels: prefs.getBool('show_square_labels') ?? false,
      showLegalMoves: prefs.getBool('show_legal_moves') ?? true,
      autoFlipBoard: prefs.getBool('auto_flip_board') ?? false,
      moveAnimationSpeed: prefs.getString('move_animation_speed') ?? 'normal',
      confirmResign: prefs.getBool('confirm_resign') ?? true,
      confirmDrawOffer: prefs.getBool('confirm_draw_offer') ?? true,
      confirmMoves: prefs.getBool('confirm_moves') ?? false,
      autoQueen: prefs.getBool('auto_queen') ?? false,
      aiDifficultyLevel: prefs.getInt('ai_difficulty_level') ?? 8,
      aiEasyLevel: (prefs.getInt('ai_easy_level') ?? 5).clamp(0, 10),
      aiMediumLevel: (prefs.getInt('ai_medium_level') ?? 15).clamp(10, 20),
      aiHardLevel: (prefs.getInt('ai_hard_level') ?? 35).clamp(20, 50),
      aiImpossibleLevel: (prefs.getInt('ai_impossible_level') ?? 100).clamp(50, 100),
      aiLastDifficulty: prefs.getString('ai_last_difficulty') ?? 'intermediate',
      backgroundTheme: prefs.getString('background_theme') ?? 'midnight',
      isLoaded: true,
    );

    emit(loadedState);

    final userId = _resolveUserIdFromPrefs(prefs);
    if (dio != null && userId != null) {
      try {
        final response = await dio!.get('/api/push/settings',
            queryParameters: {'userId': userId});
        final data = response.data as Map<String, dynamic>;
        final categories = (data['categories'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value),
            ) ??
            const <String, dynamic>{};

        loadedState = loadedState.copyWith(
          notificationsEnabled: data['enabled'] == true,
          notificationChallenges: categories['challenges'] != false,
          notificationCommunity: categories['community'] != false,
          notificationTournaments: categories['tournaments'] != false,
          notificationSystem: categories['system'] != false,
        );

        await prefs.setBool('notifications', loadedState.notificationsEnabled);
        await prefs.setBool('notif_challenges', loadedState.notificationChallenges);
        await prefs.setBool('notif_community', loadedState.notificationCommunity);
        await prefs.setBool('notif_tournaments', loadedState.notificationTournaments);
        await prefs.setBool('notif_system', loadedState.notificationSystem);
        emit(loadedState);
      } catch (e) {
        LoggingService.error('Failed to fetch remote notification settings', e);
      }
    }
  }

  Future<void> _syncNotificationSettings(
    SharedPreferences prefs,
    SettingsState next,
  ) async {
    final userId = _resolveUserIdFromPrefs(prefs);
    if (userId == null || dio == null) {
      return;
    }

    try {
      await dio!.put('/api/push/settings', data: {
        'userId': userId,
        'enabled': next.notificationsEnabled,
        'categories': {
          'challenges': next.notificationChallenges,
          'community': next.notificationCommunity,
          'tournaments': next.notificationTournaments,
          'system': next.notificationSystem,
        },
      });
    } catch (e) {
      LoggingService.error('Failed to sync notification settings', e);
    }
  }

  Future<void> _syncDifficultySettings(
    SharedPreferences prefs,
    SettingsState next,
  ) async {
    final userId = _resolveUserIdFromPrefs(prefs);
    if (userId == null || dio == null) return;

    try {
      await dio!.put('/api/profile/$userId', data: {
        'aiEasyLevel': next.aiEasyLevel,
        'aiMediumLevel': next.aiMediumLevel,
        'aiHardLevel': next.aiHardLevel,
        'aiImpossibleLevel': next.aiImpossibleLevel,
        'aiLastDifficulty': next.aiLastDifficulty,
      });
    } catch (e) {
      LoggingService.error('Failed to sync difficulty settings', e);
    }
  }

  String? _resolveUserIdFromPrefs(SharedPreferences prefs) {
    final direct = prefs.getString('user_id');
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final rawUser = prefs.getString('user_data');
    if (rawUser == null || rawUser.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawUser);
      if (decoded is Map<String, dynamic>) {
        final id = decoded['id']?.toString();
        if (id != null && id.isNotEmpty) {
          return id;
        }
      }
    } catch (_) {}
    return null;
  }
}
