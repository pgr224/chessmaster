import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final bool showCoordinates;
  final bool showSquareLabels;
  final bool showLegalMoves;
  final bool autoFlipBoard;
  final String moveAnimationSpeed;
  final bool confirmResign;
  final bool confirmDrawOffer;
  final bool confirmMoves;
  final bool autoQueen;
  final String backgroundTheme;
  final bool isLoaded;

  const SettingsState({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.notificationsEnabled = true,
    this.showCoordinates = true,
    this.showSquareLabels = false,
    this.showLegalMoves = true,
    this.autoFlipBoard = false,
    this.moveAnimationSpeed = 'normal',
    this.confirmResign = true,
    this.confirmDrawOffer = true,
    this.confirmMoves = false,
    this.autoQueen = false,
    this.backgroundTheme = 'midnight',
    this.isLoaded = false,
  });

  SettingsState copyWith({
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? notificationsEnabled,
    bool? showCoordinates,
    bool? showSquareLabels,
    bool? showLegalMoves,
    bool? autoFlipBoard,
    String? moveAnimationSpeed,
    bool? confirmResign,
    bool? confirmDrawOffer,
    bool? confirmMoves,
    bool? autoQueen,
    String? backgroundTheme,
    bool? isLoaded,
  }) =>
      SettingsState(
        soundEnabled: soundEnabled ?? this.soundEnabled,
        vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        showCoordinates: showCoordinates ?? this.showCoordinates,
        showSquareLabels: showSquareLabels ?? this.showSquareLabels,
        showLegalMoves: showLegalMoves ?? this.showLegalMoves,
        autoFlipBoard: autoFlipBoard ?? this.autoFlipBoard,
        moveAnimationSpeed: moveAnimationSpeed ?? this.moveAnimationSpeed,
        confirmResign: confirmResign ?? this.confirmResign,
        confirmDrawOffer: confirmDrawOffer ?? this.confirmDrawOffer,
        confirmMoves: confirmMoves ?? this.confirmMoves,
        autoQueen: autoQueen ?? this.autoQueen,
        backgroundTheme: backgroundTheme ?? this.backgroundTheme,
        isLoaded: isLoaded ?? this.isLoaded,
      );

  @override
  List<Object?> get props => [
        soundEnabled,
        vibrationEnabled,
        notificationsEnabled,
        showCoordinates,
        showSquareLabels,
        showLegalMoves,
        autoFlipBoard,
        moveAnimationSpeed,
        confirmResign,
        confirmDrawOffer,
        confirmMoves,
        autoQueen,
        backgroundTheme,
        isLoaded,
      ];
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc() : super(const SettingsState()) {
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
      (await SharedPreferences.getInstance())
          .setBool('notifications', e.enabled);
      emit(state.copyWith(notificationsEnabled: e.enabled));
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
    on<SettingsBackgroundEvent>((e, emit) async {
      (await SharedPreferences.getInstance())
          .setString('background_theme', e.theme);
      emit(state.copyWith(backgroundTheme: e.theme));
    });
  }

  Future<void> _onLoad(
      SettingsLoadEvent event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    emit(SettingsState(
      soundEnabled: prefs.getBool('sound') ?? true,
      vibrationEnabled: prefs.getBool('vibration') ?? true,
      notificationsEnabled: prefs.getBool('notifications') ?? true,
      showCoordinates: prefs.getBool('show_coordinates') ?? true,
      showSquareLabels: prefs.getBool('show_square_labels') ?? false,
      showLegalMoves: prefs.getBool('show_legal_moves') ?? true,
      autoFlipBoard: prefs.getBool('auto_flip_board') ?? false,
      moveAnimationSpeed: prefs.getString('move_animation_speed') ?? 'normal',
      confirmResign: prefs.getBool('confirm_resign') ?? true,
      confirmDrawOffer: prefs.getBool('confirm_draw_offer') ?? true,
      confirmMoves: prefs.getBool('confirm_moves') ?? false,
      autoQueen: prefs.getBool('auto_queen') ?? false,
      backgroundTheme: prefs.getString('background_theme') ?? 'midnight',
      isLoaded: true,
    ));
  }
}
