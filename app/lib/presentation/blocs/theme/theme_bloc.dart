import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class ThemeEvent extends Equatable {
  const ThemeEvent();
  @override List<Object?> get props => [];
}
class ThemeLoadEvent extends ThemeEvent {}
class ThemeChangeEvent extends ThemeEvent {
  final String boardTheme;
  final String pieceTheme;
  const ThemeChangeEvent({required this.boardTheme, required this.pieceTheme});
  @override List<Object?> get props => [boardTheme, pieceTheme];
}

class ThemeState extends Equatable {
  final String boardTheme;
  final String pieceTheme;
  const ThemeState({this.boardTheme = 'classic', this.pieceTheme = 'classic_3d'});
  ThemeState copyWith({String? boardTheme, String? pieceTheme}) =>
      ThemeState(boardTheme: boardTheme ?? this.boardTheme, pieceTheme: pieceTheme ?? this.pieceTheme);
  @override List<Object?> get props => [boardTheme, pieceTheme];
}

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(const ThemeState()) {
    on<ThemeLoadEvent>(_onLoad);
    on<ThemeChangeEvent>(_onChange);
  }

  Future<void> _onLoad(ThemeLoadEvent event, Emitter<ThemeState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPieceTheme = prefs.getString('piece_theme') ?? 'classic_3d';
    emit(ThemeState(
      boardTheme: prefs.getString('board_theme') ?? 'classic',
      pieceTheme: (storedPieceTheme == 'classic' || storedPieceTheme == 'classic3d') ? 'classic_3d' : storedPieceTheme,
    ));
  }

  Future<void> _onChange(ThemeChangeEvent event, Emitter<ThemeState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('board_theme', event.boardTheme);
    await prefs.setString('piece_theme', event.pieceTheme);
    emit(state.copyWith(boardTheme: event.boardTheme, pieceTheme: event.pieceTheme));
  }
}
