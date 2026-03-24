import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override List<Object?> get props => [];
}
class SettingsLoadEvent extends SettingsEvent {}
class SettingsSoundEvent extends SettingsEvent { final bool enabled; const SettingsSoundEvent(this.enabled); @override List<Object?> get props => [enabled]; }
class SettingsVibrationEvent extends SettingsEvent { final bool enabled; const SettingsVibrationEvent(this.enabled); @override List<Object?> get props => [enabled]; }
class SettingsNotificationsEvent extends SettingsEvent { final bool enabled; const SettingsNotificationsEvent(this.enabled); @override List<Object?> get props => [enabled]; }

class SettingsState extends Equatable {
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool notificationsEnabled;
  final bool isLoaded;

  const SettingsState({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.notificationsEnabled = true,
    this.isLoaded = false,
  });

  SettingsState copyWith({bool? soundEnabled, bool? vibrationEnabled, bool? notificationsEnabled, bool? isLoaded}) =>
      SettingsState(
        soundEnabled: soundEnabled ?? this.soundEnabled,
        vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        isLoaded: isLoaded ?? this.isLoaded,
      );

  @override List<Object?> get props => [soundEnabled, vibrationEnabled, notificationsEnabled];
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
      (await SharedPreferences.getInstance()).setBool('notifications', e.enabled);
      emit(state.copyWith(notificationsEnabled: e.enabled));
    });
  }

  Future<void> _onLoad(SettingsLoadEvent event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    emit(SettingsState(
      soundEnabled: prefs.getBool('sound') ?? true,
      vibrationEnabled: prefs.getBool('vibration') ?? true,
      notificationsEnabled: prefs.getBool('notifications') ?? true,
      isLoaded: true,
    ));
  }
}
