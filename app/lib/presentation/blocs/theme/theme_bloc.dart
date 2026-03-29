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
  final String pieceShape;
  final String pieceStyle;
  const ThemeChangeEvent({
    required this.boardTheme,
    required this.pieceShape,
    required this.pieceStyle,
  });
  @override List<Object?> get props => [boardTheme, pieceShape, pieceStyle];
}

class ThemeShuffleEvent extends ThemeEvent {}

class ThemeState extends Equatable {
  final String boardTheme;
  final String pieceShape;
  final String pieceStyle;
  const ThemeState({
    this.boardTheme = 'classic',
    this.pieceShape = 'classic',
    this.pieceStyle = '3d',
  });
  ThemeState copyWith({String? boardTheme, String? pieceShape, String? pieceStyle}) =>
      ThemeState(
        boardTheme: boardTheme ?? this.boardTheme,
        pieceShape: pieceShape ?? this.pieceShape,
        pieceStyle: pieceStyle ?? this.pieceStyle,
      );
  @override List<Object?> get props => [boardTheme, pieceShape, pieceStyle];
}

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(const ThemeState()) {
    on<ThemeLoadEvent>(_onLoad);
    on<ThemeChangeEvent>(_onChange);
    on<ThemeShuffleEvent>(_onShuffle);
  }

  static const List<String> _pychessShapes = [
    'alfonso', 'alila', 'alpha', 'atopdown', 'california', 'cardinal', 'cburnett',
    'celtic', 'chess7', 'chessicons', 'chessmonk', 'chessnut', 'companion',
    'dubrovny', 'eyes', 'fantasy', 'fantasy_alt', 'freak', 'freestaunton',
    'fresca', 'gioco', 'governor', 'horsey', 'icpieces', 'kilfiger', 'kosal',
    'leipzig', 'letter', 'libra', 'maestro', 'magnetic', 'makruk', 'maya',
    'merida', 'merida_new', 'metaltops', 'pirat', 'pirouetti', 'pixel', 'prmi',
    'regular', 'reillycraig', 'riohacha', 'shapes', 'sittuyin', 'skulls',
    'spatial', 'staunty', 'tatiana'
  ];

  void _onShuffle(ThemeShuffleEvent event, Emitter<ThemeState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final isShuffled = (prefs.getString('piece_shape') ?? 'classic') == 'shuffled';
    if (isShuffled) {
      final randomShape = _pychessShapes[DateTime.now().millisecondsSinceEpoch % _pychessShapes.length];
      emit(state.copyWith(pieceShape: randomShape));
    }
  }

  Future<void> _onLoad(ThemeLoadEvent event, Emitter<ThemeState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final storedShape = prefs.getString('piece_shape') ?? 'classic';
    final storedStyle = prefs.getString('piece_style') ?? '3d';
    
    emit(ThemeState(
      boardTheme: prefs.getString('board_theme') ?? 'classic',
      pieceShape: storedShape,
      pieceStyle: storedStyle,
    ));
  }

  Future<void> _onChange(ThemeChangeEvent event, Emitter<ThemeState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('board_theme', event.boardTheme);
    await prefs.setString('piece_shape', event.pieceShape);
    await prefs.setString('piece_style', event.pieceStyle);
    emit(state.copyWith(
      boardTheme: event.boardTheme,
      pieceShape: event.pieceShape,
      pieceStyle: event.pieceStyle,
    ));
  }
}

