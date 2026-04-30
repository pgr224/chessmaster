import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/achievement_service.dart';

// ═══════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthInitializeEvent extends AuthEvent {}

class AuthRegisterEvent extends AuthEvent {
  final String username;
  final String? avatarPath;
  const AuthRegisterEvent({required this.username, this.avatarPath});
  @override
  List<Object?> get props => [username, avatarPath];
}

class AuthUpdateProfileEvent extends AuthEvent {
  final String? username;
  final String? avatarPath;
  final String? localAvatar;
  final bool? isGhibli;
  const AuthUpdateProfileEvent(
      {this.username, this.avatarPath, this.localAvatar, this.isGhibli});
  @override
  List<Object?> get props => [username, avatarPath, localAvatar, isGhibli];
}

class AuthSignOutEvent extends AuthEvent {}

class AuthClearAllDataEvent extends AuthEvent {
  /// Debug event: clears all session + device data and returns to unauthenticated state
  const AuthClearAllDataEvent();
}

class AuthCheckStatusEvent extends AuthEvent {}

class AuthSilentLoginEvent extends AuthEvent {
  const AuthSilentLoginEvent();
}

class AuthGuestLoginEvent extends AuthEvent {
  const AuthGuestLoginEvent();
}

// ═══════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitialState extends AuthState {}

class AuthLoadingState extends AuthState {}

class AuthUnauthenticatedState extends AuthState {}

class AuthAuthenticatedState extends AuthState {
  final UserModel user;
  const AuthAuthenticatedState(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthErrorState extends AuthState {
  final String message;
  const AuthErrorState(this.message);
  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repository;
  final AchievementService _achievementService;

  AuthRepository get authRepository => _repository;

  AuthBloc(this._repository, this._achievementService) : super(AuthInitialState()) {
    on<AuthInitializeEvent>(_onInitialize);
    on<AuthRegisterEvent>(_onRegister);
    on<AuthUpdateProfileEvent>(_onUpdateProfile);
    on<AuthSignOutEvent>(_onSignOut);
    on<AuthClearAllDataEvent>(_onClearAllData);
    on<AuthCheckStatusEvent>(_onCheckStatus);
    on<AuthSilentLoginEvent>(_onSilentLogin);
    on<AuthGuestLoginEvent>(_onGuestLogin);
  }

  void _syncUserAchievements(UserModel user) {
    _achievementService.syncAchievements(user.achievements);
  }

  Future<void> _onCheckStatus(
      AuthCheckStatusEvent event, Emitter<AuthState> emit) async {
    final currentState = state;
    if (currentState is! AuthAuthenticatedState) return;
    try {
      final user = await _repository.getCurrentUser();
      if (user != null) {
        _syncUserAchievements(user);
        emit(AuthAuthenticatedState(user));
      }
    } catch (e) {
      emit(AuthErrorState(e.toString()));
    }
  }

  Future<void> _onInitialize(
      AuthInitializeEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoadingState());
    try {
      final user = await _repository.getCurrentUser();
      if (user != null) {
        _syncUserAchievements(user);
        emit(AuthAuthenticatedState(user));
      } else {
        emit(AuthUnauthenticatedState());
      }
    } catch (e) {
      // Network error during init should not block login if we have cached data.
      // Try to get cached user data directly.
      try {
        final cachedUser = await _repository.getCurrentUser(forceRefresh: false);
        if (cachedUser != null) {
          _syncUserAchievements(cachedUser);
          emit(AuthAuthenticatedState(cachedUser));
          return;
        }
      } catch (_) {}
      // No cached data available — genuinely unauthenticated
      emit(AuthUnauthenticatedState());
    }
  }

  Future<void> _onSilentLogin(
      AuthSilentLoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoadingState());
    try {
      final user = await _repository.getCurrentUser(forceRefresh: true);
      if (user != null) {
        _syncUserAchievements(user);
        emit(AuthAuthenticatedState(user));
      } else {
        emit(AuthUnauthenticatedState());
      }
    } catch (e) {
      emit(AuthErrorState(e.toString()));
    }
  }

  Future<void> _onRegister(
      AuthRegisterEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoadingState());
    try {
      final user = await _repository.register(
        username: event.username,
        avatarPath: event.avatarPath,
      );
      _syncUserAchievements(user);
      emit(AuthAuthenticatedState(user));
    } catch (e) {
      emit(AuthErrorState(e.toString()));
    }
  }

  Future<void> _onGuestLogin(
      AuthGuestLoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoadingState());
    final deviceId = await _repository.getDeviceId();
    final guestUser = UserModel(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      username: 'Guest_${deviceId.substring(0, 4)}',
      xp: 0,
      isOnline: false,
      stats: const UserStats(),
      deviceId: deviceId,
      isGuest: true,
    );
    emit(AuthAuthenticatedState(guestUser));
  }


  Future<void> _onUpdateProfile(
      AuthUpdateProfileEvent event, Emitter<AuthState> emit) async {
    final current = state;
    if (current is! AuthAuthenticatedState) return;
    try {
      final updated = await _repository.updateProfile(
        userId: current.user.id,
        username: event.username,
        avatarPath: event.avatarPath,
        localAvatar: event.localAvatar,
        isGhibli: event.isGhibli,
      );
      _syncUserAchievements(updated);
      emit(AuthAuthenticatedState(updated));
    } catch (e) {
      final errorMsg = e.toString();
      
      if (errorMsg.contains('COOLDOWN_ACTIVE')) {
        emit(AuthErrorState(
          'NAME_CHANGE_COOLDOWN::You can change your name once every 24 hours. Please try again later.'
        ));
      } else if (errorMsg.contains('LIFETIME_LIMIT_REACHED')) {
        emit(AuthErrorState(
          'NAME_CHANGE_LIMIT::You have reached the maximum number of name changes (3 lifetime).'
        ));
      } else if (errorMsg.contains('Username already taken')) {
        emit(AuthErrorState('NAME_TAKEN::This username is already taken. Please choose another.'));
      } else {
        emit(AuthErrorState(errorMsg));
      }
    }
  }

  Future<void> _onSignOut(
      AuthSignOutEvent event, Emitter<AuthState> emit) async {
    await _repository.signOut();
    emit(AuthUnauthenticatedState());
  }

  Future<void> _onClearAllData(
      AuthClearAllDataEvent event, Emitter<AuthState> emit) async {
    /// Debug handler: clears all stored user session, device fingerprint, and auth token
    /// Forces app to show onboarding on next restart
    /// Useful for testing session persistence and cleanup flows
    await _repository.clearAllData();
    emit(AuthUnauthenticatedState());
  }
}
