import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/models/user_model.dart';

// ═══════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override List<Object?> get props => [];
}

class AuthInitializeEvent extends AuthEvent {}

class AuthRegisterEvent extends AuthEvent {
  final String username;
  final String? avatarPath;
  const AuthRegisterEvent({required this.username, this.avatarPath});
  @override List<Object?> get props => [username, avatarPath];
}

class AuthUpdateProfileEvent extends AuthEvent {
  final String? username;
  final String? avatarPath;
  final String? localAvatar;
  final bool? isGhibli;
  const AuthUpdateProfileEvent({this.username, this.avatarPath, this.localAvatar, this.isGhibli});
  @override List<Object?> get props => [username, avatarPath, localAvatar, isGhibli];
}

class AuthSignOutEvent extends AuthEvent {}

class AuthClearAllDataEvent extends AuthEvent {
  /// Debug event: clears all session + device data and returns to unauthenticated state
  const AuthClearAllDataEvent();
}

// ═══════════════════════════════════════════
// STATES
// ═══════════════════════════════════════════
abstract class AuthState extends Equatable {
  const AuthState();
  @override List<Object?> get props => [];
}

class AuthInitialState extends AuthState {}
class AuthLoadingState extends AuthState {}
class AuthUnauthenticatedState extends AuthState {}

class AuthAuthenticatedState extends AuthState {
  final UserModel user;
  const AuthAuthenticatedState(this.user);
  @override List<Object?> get props => [user];
}

class AuthErrorState extends AuthState {
  final String message;
  const AuthErrorState(this.message);
  @override List<Object?> get props => [message];
}

// ═══════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repository;

  AuthBloc(this._repository) : super(AuthInitialState()) {
    on<AuthInitializeEvent>(_onInitialize);
    on<AuthRegisterEvent>(_onRegister);
    on<AuthUpdateProfileEvent>(_onUpdateProfile);
    on<AuthSignOutEvent>(_onSignOut);
    on<AuthClearAllDataEvent>(_onClearAllData);
  }

  Future<void> _onInitialize(AuthInitializeEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoadingState());
    try {
      final user = await _repository.getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticatedState(user));
      } else {
        emit(AuthUnauthenticatedState());
      }
    } catch (e) {
      emit(AuthErrorState(e.toString()));
    }
  }

  Future<void> _onRegister(AuthRegisterEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoadingState());
    try {
      final user = await _repository.register(
        username: event.username,
        avatarPath: event.avatarPath,
      );
      emit(AuthAuthenticatedState(user));
    } catch (e) {
      emit(AuthErrorState(e.toString()));
    }
  }

  Future<void> _onUpdateProfile(AuthUpdateProfileEvent event, Emitter<AuthState> emit) async {
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
      emit(AuthAuthenticatedState(updated));
    } catch (e) {
      emit(AuthErrorState(e.toString()));
    }
  }

  Future<void> _onSignOut(AuthSignOutEvent event, Emitter<AuthState> emit) async {
    await _repository.signOut();
    emit(AuthUnauthenticatedState());
  }

  Future<void> _onClearAllData(AuthClearAllDataEvent event, Emitter<AuthState> emit) async {
    /// Debug handler: clears all stored user session, device fingerprint, and auth token
    /// Forces app to show onboarding on next restart
    /// Useful for testing session persistence and cleanup flows
    await _repository.clearAllData();
    emit(AuthUnauthenticatedState());
  }
}
