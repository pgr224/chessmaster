import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibration/vibration.dart';
import '../../../domain/engine/chess_engine.dart';
import '../../../domain/engine/ai_engine.dart';
import '../../../domain/engine/engine_controller.dart';
import '../../../domain/engine/coach_controller.dart';
import '../../../data/repositories/game_repository.dart';
import '../../../data/models/game_model.dart';
import '../../../data/models/game_config.dart';
import '../../../data/models/coach_model.dart';
import '../../../data/models/tutorial_model.dart';
import '../../../data/models/puzzle_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/puzzle_repository.dart';
import '../theme/theme_bloc.dart';

// ═══════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════
abstract class GameEvent extends Equatable {
  const GameEvent();
  @override List<Object?> get props => [];
}

class GameStartEvent extends GameEvent {
  final GameConfig config;
  final TutorialLesson? tutorial;
  const GameStartEvent(this.config, {this.tutorial});
  @override List<Object?> get props => [config, tutorial];
}

class GameResumeEvent extends GameEvent {
  final String gameId;
  const GameResumeEvent(this.gameId);
  @override List<Object?> get props => [gameId];
}

class GameExitEvent extends GameEvent {}

class GameSelectPieceEvent extends GameEvent {
  final Square square;
  const GameSelectPieceEvent(this.square);
  @override List<Object?> get props => [square];
}

class GameDiscardEvent extends GameEvent {}

class GameMakeMoveEvent extends GameEvent {
  final Square from;
  final Square to;
  final PieceType? promotion;
  const GameMakeMoveEvent(this.from, this.to, {this.promotion});
  @override List<Object?> get props => [from, to, promotion];
}

class GameUndoEvent extends GameEvent {}
class GameRedoEvent extends GameEvent {}
class GameResignEvent extends GameEvent {}
class GameDrawOfferEvent extends GameEvent {}
class GameDrawAcceptEvent extends GameEvent {}
class GameDrawDeclineEvent extends GameEvent {}
class GameSaveEvent extends GameEvent {}
class GameRequestHintEvent extends GameEvent {}
class GameSetOpponentNameEvent extends GameEvent {
  final String name;
  const GameSetOpponentNameEvent(this.name);
  @override List<Object?> get props => [name];
}

class GamePromotionRequiredEvent extends GameEvent {
  final Square from;
  final Square to;
  const GamePromotionRequiredEvent(this.from, this.to);
  @override List<Object?> get props => [from, to];
}

class GameUpdateSettingsEvent extends GameEvent {
  final bool confirmMoves;
  final bool autoQueen;
  const GameUpdateSettingsEvent({this.confirmMoves = false, this.autoQueen = false});
  @override List<Object?> get props => [confirmMoves, autoQueen];
}

class GameConfirmMoveEvent extends GameEvent {}

class GameDrawReceiveEvent extends GameEvent { final String? fromId; const GameDrawReceiveEvent(this.fromId); }
class GameDismissMiniLessonEvent extends GameEvent { const GameDismissMiniLessonEvent(); }
class GamePuzzleRushTickEvent extends GameEvent { const GamePuzzleRushTickEvent(); }
class GameExplainPuzzleMoveEvent extends GameEvent { const GameExplainPuzzleMoveEvent(); }
class GameDismissCoachFeedbackEvent extends GameEvent {}
class GameDismissHintEvent extends GameEvent {}
class GameUpdateCoachSettingsEvent extends GameEvent {
  final CoachSettings coachSettings;
  const GameUpdateCoachSettingsEvent(this.coachSettings);
  @override List<Object?> get props => [coachSettings];
}

class MpGameOverSyncEvent extends GameEvent {
  final GameResult result;
  final DrawReason? reason;
  final int xpGained;
  const MpGameOverSyncEvent(this.result, this.reason, this.xpGained);
  @override List<Object?> get props => [result, reason, xpGained];
}

// ═══════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════
class GameState extends Equatable {
  final List<List<ChessPiece?>> board;
  final PieceColor currentTurn;
  final Square? selectedSquare;
  final List<Move> legalMoves;
  final List<Move> moveHistory;
  final GameStatus status;
  final GameResult result;
  final DrawReason? drawReason;
  final bool isAIThinking;
  final Move? hintMove;
  final int hintsUsed;
  final int maxHints;
  final PieceColor? playerColor;
  final GameMode mode;
  final AIDifficulty? aiDifficulty;
  final String? boardTheme;
  final String pieceShape;
  final String pieceStyle;
  final Color whitePieceColor;
  final Color blackPieceColor;
  final List<ChessPiece> capturedWhite;
  final List<ChessPiece> capturedBlack;
  final String currentFEN;
  final bool showPromotionDialog;
  final Square? promotionFrom;
  final Square? promotionTo;
  final DrawReason? drawOfferFrom;
  final TutorialLesson? tutorial;
  final int tutorialStep;
  final String? tutorialMessage;
  final Puzzle? puzzle;
  final int puzzleStep;
  final bool isPuzzleHintUsed;
  // Multiplayer undo tracking
  final String? opponentName;
  final bool confirmMoves;
  final bool autoQueen;
  final Move? pendingMove;
  final int mpUndosUsed;
  final DateTime? lastMoveTimestamp;
  
  // Analytics & Rewards
  final double accuracy;
  final int mistakes;
  final int blunders;
  final int missedWins;
  final int bestMoves;
  final int xpGained;
  final String? coachMessage;
  final String? analysisMessage;
  final bool showMiniLesson;

  // AI Coach System
  final CoachFeedback? coachFeedback;
  final HintResult? activeHint;
  final CoachSettings coachSettings;
  final List<CoachFeedback> gameCoachHistory;

  // Puzzle Overhaul
  final int puzzleStreak;
  final int puzzleRushStrikes;
  final int puzzleRushTime; // seconds
  final bool isPuzzleRush;
  final Move? lastCorrectPuzzleMove;
  final bool showPuzzleCelebration;
  final String? puzzleExplanation;
  final int totalPuzzleXP;

  // Real-time Highlighting & Undo
  final Move? coachMove;
  final Set<int> hintedIndices;

  const GameState({
    required this.board,
    required this.currentTurn,
    this.selectedSquare,
    this.legalMoves = const [],
    this.moveHistory = const [],
    this.status = GameStatus.active,
    this.result = GameResult.ongoing,
    this.drawReason,
    this.isAIThinking = false,
    this.hintMove,
    this.hintsUsed = 0,
    this.maxHints = 3,
    this.playerColor,
    this.mode = GameMode.singlePlayer,
    this.aiDifficulty,
    this.boardTheme,
    this.pieceShape = 'classic',
    this.pieceStyle = '3d',
    this.whitePieceColor = Colors.white,
    this.blackPieceColor = Colors.black,
    this.capturedWhite = const [],
    this.capturedBlack = const [],
    this.currentFEN = '',
    this.showPromotionDialog = false,
    this.promotionFrom,
    this.promotionTo,
    this.drawOfferFrom,
    this.tutorial,
    this.tutorialStep = 0,
    this.tutorialMessage,
    this.puzzle,
    this.puzzleStep = 0,
    this.isPuzzleHintUsed = false,
    this.mpUndosUsed = 0,
    this.lastMoveTimestamp,
    this.opponentName,
    this.confirmMoves = false,
    this.autoQueen = false,
    this.pendingMove,
    this.accuracy = 0.0,
    this.mistakes = 0,
    this.blunders = 0,
    this.missedWins = 0,
    this.bestMoves = 0,
    this.xpGained = 0,
    this.analysisMessage,
    this.coachMessage,
    this.showMiniLesson = false,
    this.coachFeedback,
    this.activeHint,
    this.coachSettings = const CoachSettings(),
    this.gameCoachHistory = const [],
    this.puzzleStreak = 0,
    this.puzzleRushStrikes = 0,
    this.puzzleRushTime = 180, // 3 minutes
    this.isPuzzleRush = false,
    this.lastCorrectPuzzleMove,
    this.showPuzzleCelebration = false,
    this.puzzleExplanation,
    this.totalPuzzleXP = 0,
    this.coachMove,
    this.hintedIndices = const {},
  });

  bool get isGameOver => status == GameStatus.checkmate ||
      status == GameStatus.stalemate || status == GameStatus.draw;

  bool get isPlayerTurn =>
      playerColor == null || currentTurn == playerColor;

  int get hintsRemaining => maxHints - hintsUsed;

  /// Whether the player can still undo in multiplayer (under 5s and <2 undos used)
  bool get canMpUndo {
    if (mode != GameMode.multiplayer) return false;
    if (mpUndosUsed >= 2) return false;
    if (lastMoveTimestamp == null) return false;
    // You can only undo if you were the last one to move (meaning it's now the opponent's turn)
    if (isPlayerTurn) return false;
    final elapsed = DateTime.now().difference(lastMoveTimestamp!);
    return elapsed.inSeconds < 5;
  }

  GameState copyWith({
    List<List<ChessPiece?>>? board,
    PieceColor? currentTurn,
    Square? selectedSquare,
    List<Move>? legalMoves,
    List<Move>? moveHistory,
    GameStatus? status,
    GameResult? result,
    DrawReason? drawReason,
    bool? isAIThinking,
    Move? hintMove,
    int? hintsUsed,
    PieceColor? playerColor,
    GameMode? mode,
    AIDifficulty? aiDifficulty,
    String? boardTheme,
    String? pieceShape,
    String? pieceStyle,
    Color? whitePieceColor,
    Color? blackPieceColor,
    List<ChessPiece>? capturedWhite,
    List<ChessPiece>? capturedBlack,
    String? currentFEN,
    bool? showPromotionDialog,
    Square? promotionFrom,
    Square? promotionTo,
    DrawReason? drawOfferFrom,
    TutorialLesson? tutorial,
    int? tutorialStep,
    String? tutorialMessage,
    Puzzle? puzzle,
    int? puzzleStep,
    bool? isPuzzleHintUsed,
    int? mpUndosUsed,
    DateTime? lastMoveTimestamp,
    String? opponentName,
    bool? confirmMoves,
    bool? autoQueen,
    Move? pendingMove,
    double? accuracy,
    int? mistakes,
    int? blunders,
    int? missedWins,
    int? bestMoves,
    int? xpGained,
    String? analysisMessage,
    String? coachMessage,
    bool? showMiniLesson,
    CoachFeedback? coachFeedback,
    HintResult? activeHint,
    CoachSettings? coachSettings,
    List<CoachFeedback>? gameCoachHistory,
    int? puzzleStreak,
    int? puzzleRushStrikes,
    int? puzzleRushTime,
    bool? isPuzzleRush,
    Move? lastCorrectPuzzleMove,
    bool? showPuzzleCelebration,
    String? puzzleExplanation,
    int? totalPuzzleXP,
    Move? coachMove,
    Set<int>? hintedIndices,
    bool clearSelected = false,
    bool clearHint = false,
    bool clearDrawOffer = false,
    bool clearTutorialMessage = false,
    bool clearPendingMove = false,
    bool clearCoachMessage = false,
    bool clearCoachFeedback = false,
    bool clearActiveHint = false,
    bool clearCoachMove = false,
  }) {
    return GameState(
      board: board ?? this.board,
      currentTurn: currentTurn ?? this.currentTurn,
      selectedSquare: clearSelected ? null : (selectedSquare ?? this.selectedSquare),
      legalMoves: clearSelected ? [] : (legalMoves ?? this.legalMoves),
      moveHistory: moveHistory ?? this.moveHistory,
      status: status ?? this.status,
      result: result ?? this.result,
      drawReason: drawReason ?? this.drawReason,
      isAIThinking: isAIThinking ?? this.isAIThinking,
      hintMove: clearHint ? null : (hintMove ?? this.hintMove),
      hintsUsed: hintsUsed ?? this.hintsUsed,
      playerColor: playerColor ?? this.playerColor,
      mode: mode ?? this.mode,
      aiDifficulty: aiDifficulty ?? this.aiDifficulty,
      boardTheme: boardTheme ?? this.boardTheme,
      pieceShape: pieceShape ?? this.pieceShape,
      pieceStyle: pieceStyle ?? this.pieceStyle,
      whitePieceColor: whitePieceColor ?? this.whitePieceColor,
      blackPieceColor: blackPieceColor ?? this.blackPieceColor,
      capturedWhite: capturedWhite ?? this.capturedWhite,
      capturedBlack: capturedBlack ?? this.capturedBlack,
      currentFEN: currentFEN ?? this.currentFEN,
      showPromotionDialog: showPromotionDialog ?? this.showPromotionDialog,
      promotionFrom: promotionFrom ?? this.promotionFrom,
      promotionTo: promotionTo ?? this.promotionTo,
      drawOfferFrom: clearDrawOffer ? null : (drawOfferFrom ?? this.drawOfferFrom),
      tutorial: tutorial ?? this.tutorial,
      tutorialStep: tutorialStep ?? this.tutorialStep,
      tutorialMessage: clearTutorialMessage ? null : (tutorialMessage ?? this.tutorialMessage),
      puzzle: puzzle ?? this.puzzle,
      puzzleStep: puzzleStep ?? this.puzzleStep,
      isPuzzleHintUsed: isPuzzleHintUsed ?? this.isPuzzleHintUsed,
      mpUndosUsed: mpUndosUsed ?? this.mpUndosUsed,
      lastMoveTimestamp: lastMoveTimestamp ?? this.lastMoveTimestamp,
      opponentName: opponentName ?? this.opponentName,
      confirmMoves: confirmMoves ?? this.confirmMoves,
      autoQueen: autoQueen ?? this.autoQueen,
      pendingMove: clearPendingMove ? null : (pendingMove ?? this.pendingMove),
      accuracy: accuracy ?? this.accuracy,
      mistakes: mistakes ?? this.mistakes,
      blunders: blunders ?? this.blunders,
      missedWins: missedWins ?? this.missedWins,
      bestMoves: bestMoves ?? this.bestMoves,
      xpGained: xpGained ?? this.xpGained,
      analysisMessage: analysisMessage ?? this.analysisMessage,
      coachMessage: clearCoachMessage ? null : (coachMessage ?? this.coachMessage),
      showMiniLesson: showMiniLesson ?? this.showMiniLesson,
      coachFeedback: clearCoachFeedback ? null : (coachFeedback ?? this.coachFeedback),
      activeHint: clearActiveHint ? null : (activeHint ?? this.activeHint),
      coachSettings: coachSettings ?? this.coachSettings,
      gameCoachHistory: gameCoachHistory ?? this.gameCoachHistory,
      puzzleStreak: puzzleStreak ?? this.puzzleStreak,
      puzzleRushStrikes: puzzleRushStrikes ?? this.puzzleRushStrikes,
      puzzleRushTime: puzzleRushTime ?? this.puzzleRushTime,
      isPuzzleRush: isPuzzleRush ?? this.isPuzzleRush,
      lastCorrectPuzzleMove: lastCorrectPuzzleMove ?? this.lastCorrectPuzzleMove,
      showPuzzleCelebration: showPuzzleCelebration ?? this.showPuzzleCelebration,
      puzzleExplanation: puzzleExplanation ?? this.puzzleExplanation,
      totalPuzzleXP: totalPuzzleXP ?? this.totalPuzzleXP,
      coachMove: clearCoachMove ? null : (coachMove ?? this.coachMove),
      hintedIndices: hintedIndices ?? this.hintedIndices,
    );
  }

  @override
  List<Object?> get props => [
    board, currentTurn, selectedSquare, legalMoves, moveHistory,
    status, result, isAIThinking, hintMove, hintsUsed, currentFEN,
    showPromotionDialog, tutorial, tutorialStep, tutorialMessage, 
    pieceShape, pieceStyle,
    lastMoveTimestamp, opponentName,
    confirmMoves, autoQueen, pendingMove,
    accuracy, mistakes, blunders, missedWins, bestMoves, xpGained,
    coachMessage, showMiniLesson, analysisMessage,
    coachFeedback, activeHint, coachSettings, gameCoachHistory,
    puzzleStreak, puzzleRushStrikes, puzzleRushTime, isPuzzleRush, 
    lastCorrectPuzzleMove, showPuzzleCelebration, puzzleExplanation, totalPuzzleXP,
    coachMove, hintedIndices
  ];
}

// ═══════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════
class GameBloc extends Bloc<GameEvent, GameState> {
  late ChessEngine _engine;
  final AIEngineController _engineController = AIEngineController();
  final CoachController _coachController = CoachController();
  final GameRepository _gameRepository;
  final AuthRepository _authRepository;
  final PuzzleRepository _puzzleRepository;
  final ThemeBloc _themeBloc;
  String? _gameId;
  int _aiRequestEpoch = 0;
  Timer? _rushTimer;

  ChessEngine get engine => _engine;
  AIEngineController get engineController => _engineController;
  CoachController get coachController => _coachController;

  GameBloc(this._gameRepository, this._authRepository, this._puzzleRepository, this._themeBloc) : super(GameState(
    board: List.generate(8, (_) => List.filled(8, null)),
    currentTurn: PieceColor.white,
  )) {
    on<GameStartEvent>(_onStart);
    on<GameResumeEvent>(_onResume);
    on<GameExitEvent>(_onExit);
    on<GameSelectPieceEvent>(_onSelectPiece);
    on<GameMakeMoveEvent>(_onMakeMove);
    on<GameUndoEvent>(_onUndo);
    on<GameResignEvent>(_onResign);
    on<GameDrawOfferEvent>(_onDrawOffer);
    on<GameDrawAcceptEvent>(_onDrawAccept);
    on<GameDrawDeclineEvent>(_onDrawDecline);
    on<GameSaveEvent>(_onSave);
    on<GameRequestHintEvent>(_onRequestHint);
    on<GameDismissMiniLessonEvent>(_onDismissMiniLesson);
    on<GamePromotionRequiredEvent>(_onPromotionRequired);
    on<GameConfirmMoveEvent>(_onConfirmMove);
    on<GameUpdateSettingsEvent>((e, emit) => emit(state.copyWith(confirmMoves: e.confirmMoves, autoQueen: e.autoQueen)));
    on<GameSetOpponentNameEvent>((event, emit) => emit(state.copyWith(opponentName: event.name)));
    on<GameDiscardEvent>(_onDiscard);
    on<GamePuzzleRushTickEvent>(_onPuzzleRushTick);
    on<GameExplainPuzzleMoveEvent>(_onExplainPuzzleMove);
    on<GameDismissCoachFeedbackEvent>((e, emit) => emit(state.copyWith(clearCoachFeedback: true)));
    on<GameDismissHintEvent>((e, emit) => emit(state.copyWith(clearActiveHint: true)));
    on<GameUpdateCoachSettingsEvent>((e, emit) {
      _coachController.updateSettings(e.coachSettings);
      emit(state.copyWith(coachSettings: e.coachSettings));
    });
    on<MpGameOverSyncEvent>((e, emit) {
      final status = e.result == GameResult.draw ? GameStatus.draw : GameStatus.checkmate;
      emit(state.copyWith(
        status: status,
        result: e.result,
        drawReason: e.reason,
        xpGained: e.xpGained,
      ));
    });
  }

  Future<void> _onDiscard(GameDiscardEvent event, Emitter<GameState> emit) async {
    if (_gameId != null) {
      await _gameRepository.deleteGame(_gameId!);
      await _gameRepository.setLastActiveGameId(null);
      _gameId = null;
    }
  }

  Future<void> _onStart(GameStartEvent event, Emitter<GameState> emit) async {
    // Invalidate any pending AI response from a previous game lifecycle.
    _aiRequestEpoch++;

    // Trigger shuffle if the user has chosen it
    _themeBloc.add(ThemeShuffleEvent());

    _engine = ChessEngine.fromFEN(event.config.puzzle?.initialFEN ?? event.tutorial?.initialFEN ?? 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    final config = event.config;

    AIDifficulty? difficulty = config.difficulty;
    
    // Fetch user's persistent difficulty if in Practice Mode
    if (config.mode == GameMode.practice) {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        final d = user.stats.practiceDifficulty;
        if (d < 1.0) {
          difficulty = AIDifficulty.basic;
        } else if (d < 2.0) {
          difficulty = AIDifficulty.intermediate;
        } else if (d < 3.0) {
          difficulty = AIDifficulty.advanced;
        } else {
          difficulty = AIDifficulty.impossible;
        }
      }
    }

    _engineController.init(config.mode, difficulty);

    final playerColor = config.playerColor == 'black'
        ? PieceColor.black : PieceColor.white;
 
    final initialState = GameState(
      board: _engine.board,
      currentTurn: _engine.currentTurn,
      playerColor: (config.mode == GameMode.singlePlayer || config.mode == GameMode.multiplayer || config.mode == GameMode.practice) ? playerColor : null,
      mode: config.mode,
      aiDifficulty: difficulty,
      boardTheme: config.boardTheme ?? 'classic',
      pieceShape: config.pieceShape ?? 'classic',
      pieceStyle: config.pieceStyle ?? '3d',
      whitePieceColor: config.whitePieceColor ?? Colors.white,
      blackPieceColor: config.blackPieceColor ?? Colors.black,
      currentFEN: _engine.toFEN(),
      tutorial: event.tutorial,
      tutorialMessage: (config.puzzle?.moves.isNotEmpty ?? false) 
          ? config.puzzle!.moves.first.dialog 
          : (event.tutorial?.steps.isNotEmpty ?? false) 
              ? event.tutorial!.steps.first.text 
              : null,
      puzzle: config.puzzle,
    );
    emit(initialState);
 
    // Initialize game record
    _gameId = null; // reset
    final firstGame = GameModel(
      id: '',
      fen: initialState.currentFEN,
      pgn: '',
      mode: initialState.mode.name,
      status: initialState.status.name,
      result: initialState.result.name,
      whiteUserId: initialState.playerColor == PieceColor.white ? 'me' : 'ai',
      blackUserId: initialState.playerColor == PieceColor.black ? 'me' : 'ai',
      moveCount: 0,
      updatedAt: DateTime.now(),
    );
    final id = await _gameRepository.saveGame(firstGame);
    _gameId = id;
    _gameRepository.setLastActiveGameId(id);
 
    if (config.mode == GameMode.puzzle && config.isPuzzleRush) {
      _rushTimer?.cancel();
      _rushTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        add(const GamePuzzleRushTickEvent());
      });
      emit(state.copyWith(isPuzzleRush: true, puzzleRushTime: 180, puzzleRushStrikes: 0));
    }
  }

  Future<void> _onResume(GameResumeEvent event, Emitter<GameState> emit) async {
    final game = await _gameRepository.getSavedGame(event.gameId);
    if (game == null) return;

    _aiRequestEpoch++;
    _engine = ChessEngine.fromFEN(game.fen);
    _gameId = game.id;
    _gameRepository.setLastActiveGameId(game.id);

    final mode = GameMode.values.firstWhere((m) => m.name == game.mode, orElse: () => GameMode.singlePlayer);
    
    // Puzzle Rush check on resume
    if (mode == GameMode.puzzle) {
        // Usually we don't resume puzzle rush, but if we do, timer should restart
    }

    _engineController.init(mode, AIDifficulty.intermediate);

    final playerColorStr = (game.whiteUserId == 'me') ? PieceColor.white : PieceColor.black;

    emit(GameState(
      board: _engine.board,
      currentTurn: _engine.currentTurn,
      playerColor: (mode == GameMode.singlePlayer || mode == GameMode.multiplayer || mode == GameMode.practice) ? playerColorStr : null,
      mode: mode,
      moveHistory: _engine.moveHistory,
      currentFEN: game.fen,
      // Restore other properties if needed, but these are essential for turn logic
    ));

    // After resume, if it's AI turn, trigger it
    if (mode == GameMode.singlePlayer && _engine.currentTurn != playerColorStr && !state.isGameOver) {
      add(const GameMakeMoveEvent(Square(0, 0), Square(0, 0)));
    }
  }

  void _onExit(GameExitEvent event, Emitter<GameState> emit) {
    _rushTimer?.cancel();
    _gameRepository.setLastActiveGameId(null);
  }

  void _onPuzzleRushTick(GamePuzzleRushTickEvent event, Emitter<GameState> emit) {
    if (state.puzzleRushTime <= 0 || state.puzzleRushStrikes >= 3 || state.isGameOver) {
      _rushTimer?.cancel();
      return;
    }
    final newTime = state.puzzleRushTime - 1;
    if (newTime <= 0) {
      _rushTimer?.cancel();
      emit(state.copyWith(puzzleRushTime: 0, status: GameStatus.draw, result: GameResult.ongoing));
    } else {
      emit(state.copyWith(puzzleRushTime: newTime));
    }
  }

  Future<void> _onExplainPuzzleMove(GameExplainPuzzleMoveEvent event, Emitter<GameState> emit) async {
    if (state.puzzle == null) return;
    emit(state.copyWith(puzzleExplanation: 'Analyzing position...'));
    // Use engine to evaluate and find why this move is good
    final eval = await AIEngine.evaluatePosition(_engine);
    
    // Simplified child-friendly explanation logic
    String explanation = "This move helps you control the center and prepares a strong attack! 🧠";
    if (eval > 300) {
      explanation = "Great move! This wins material and puts your opponent in big trouble! 🚀";
    } else if (state.status == GameStatus.check) {
      explanation = "Correct! This move puts the King in danger! ⚔️";
    }
    
    emit(state.copyWith(puzzleExplanation: explanation));
  }

  void _onSelectPiece(GameSelectPieceEvent event, Emitter<GameState> emit) {
    final sq = event.square;
    if (state.isAIThinking) return;

    // Deselect if clicking same square
    if (state.selectedSquare == sq) {
      emit(state.copyWith(clearSelected: true, clearHint: true, clearPendingMove: true));
      return;
    }

    // In multiplayer, only allow controlling your own pieces
    if (state.mode == GameMode.multiplayer && state.playerColor != null) {
      if (!state.isPlayerTurn) return; // Not your turn
      final clickedPiece = _engine.pieceAt(sq);
      // If no piece selected yet, only allow selecting own color
      if (state.selectedSquare == null) {
        if (clickedPiece == null || clickedPiece.color != state.playerColor) {
          emit(state.copyWith(clearSelected: true, clearPendingMove: true));
          return;
        }
      }
    }

    // If a piece is already selected, try to make a move
    if (state.selectedSquare != null) {
      final isLegal = state.legalMoves.any((m) => m.to == sq);
      if (isLegal) {
        final from = state.selectedSquare!;
        final piece = _engine.pieceAt(from);
        
        // Auto-Queen
        if (state.autoQueen && piece?.type == PieceType.pawn) {
          final toRank = sq.rank;
          if ((piece!.color == PieceColor.white && toRank == 7) ||
              (piece.color == PieceColor.black && toRank == 0)) {
            add(GameMakeMoveEvent(from, sq, promotion: PieceType.queen));
            return;
          }
        }

        // Promotion Dialog
        if (piece?.type == PieceType.pawn) {
          final toRank = sq.rank;
          if ((piece!.color == PieceColor.white && toRank == 7) ||
              (piece.color == PieceColor.black && toRank == 0)) {
            emit(state.copyWith(
              showPromotionDialog: true,
              promotionFrom: from,
              promotionTo: sq,
              clearPendingMove: true,
            ));
            return;
          }
        }

        // Move Confirmation
        if (state.confirmMoves) {
          emit(state.copyWith(pendingMove: Move(from: from, to: sq)));
          return;
        }

        add(GameMakeMoveEvent(from, sq));
        return;
      }
    }

    // Select new piece
    final piece = _engine.pieceAt(sq);
    if (piece == null || piece.color != _engine.currentTurn) {
      emit(state.copyWith(clearSelected: true, clearPendingMove: true));
      return;
    }
    if (!state.isPlayerTurn) return;

    final moves = _engine.legalMovesFrom(sq);
    emit(state.copyWith(
      selectedSquare: sq,
      legalMoves: moves,
      clearHint: true,
      clearPendingMove: true,
    ));
  }

  void _onConfirmMove(GameConfirmMoveEvent event, Emitter<GameState> emit) {
    if (state.pendingMove != null) {
      final move = state.pendingMove!;
      add(GameMakeMoveEvent(move.from, move.to, promotion: move.promotion));
      emit(state.copyWith(clearPendingMove: true));
    }
  }

  Future<void> _onMakeMove(GameMakeMoveEvent event, Emitter<GameState> emit) async {
    final move = Move(from: event.from, to: event.to, promotion: event.promotion);

    // Tutorial check — wrong moves show error BUT keep instruction visible
    if (state.mode == GameMode.tutorial && state.tutorial != null) {
      final step = state.tutorial!.steps[state.tutorialStep];
      if (step.expectedMove != null && step.expectedMove!.isNotEmpty && move.toAlgebraic() != step.expectedMove) {
        // Show error for 2 seconds, then restore the original instruction
        final errorMsg = '❌ Not quite! Try again.\n\n${step.text}';
        emit(state.copyWith(
          tutorialMessage: errorMsg,
          clearSelected: true,
        ));
        return;
      }
    }

    // Puzzle check
    if (state.mode == GameMode.puzzle && state.puzzle != null) {
      final currentMove = state.puzzle!.moves[state.puzzleStep];
      if (move.toAlgebraic() != currentMove.uciMove && move.toAlgebraic() != currentMove.move) {
        // WRONG MOVE
        Vibration.vibrate(duration: 400);
        int newStrikes = state.puzzleRushStrikes;
        if (state.isPuzzleRush) {
          newStrikes++;
          if (newStrikes >= 3) {
            _rushTimer?.cancel();
            emit(state.copyWith(
              puzzleRushStrikes: newStrikes,
              status: GameStatus.draw,
              tutorialMessage: '❌ 3 Strikes! Puzzle Rush Over.',
            ));
            return;
          }
        }

        emit(state.copyWith(
          puzzleRushStrikes: newStrikes,
          puzzleStreak: 0, // Reset streak on wrong move
          tutorialMessage: '❌ Not the right move. Think again!',
          clearSelected: true,
        ));
        return;
      } else {
        // CORRECT MOVE
        emit(state.copyWith(
          lastCorrectPuzzleMove: move,
          puzzleStreak: state.puzzleStreak + 1,
          totalPuzzleXP: state.totalPuzzleXP + 50,
        ));
        // We'll show celebration in UI based on lastCorrectPuzzleMove
      }
    }

    final success = _engine.makeMove(move);
    if (!success && !(event.from == event.to)) return; // Invalid move

    final captured = _collectCaptured();

    // 1. IMPROVEMENT: Emit board state immediately so move is responsive
    emit(state.copyWith(
      board: _engine.board,
      currentTurn: _engine.currentTurn,
      moveHistory: _engine.moveHistory,
      status: _engine.status,
      result: _engine.result,
      drawReason: _engine.drawReason,
      capturedWhite: captured.$1,
      capturedBlack: captured.$2,
      currentFEN: _engine.toFEN(),
      clearSelected: true,
      clearHint: true,
      showPromotionDialog: false,
      lastMoveTimestamp: DateTime.now(),
      pendingMove: null, // Clear any pending move UI
    ));

    // 2. AI COACH MOVE ANALYSIS (async, non-blocking)
    bool shouldAnalyze = state.mode == GameMode.practice || state.mode == GameMode.singlePlayer;
    if (shouldAnalyze && state.coachSettings.enableRealTimeCoaching) {
    int mistakes = state.mistakes;
    int blunders = state.blunders;
    int bestMoves = state.bestMoves;
    int missedWins = state.missedWins;
    double accuracy = state.accuracy;

    try {
      // Use CoachController for proper move evaluation
      final fenBeforeMove = state.currentFEN;
      final engineBefore = ChessEngine.fromFEN(fenBeforeMove);
      
      final feedback = await _coachController.evaluateMove(
        engineBeforeMove: engineBefore,
        playedMove: move,
        engineAfterMove: _engine,
      );

      // Update stats based on classification
      switch (feedback.classification) {
        case MoveClassification.brilliant:
        case MoveClassification.best:
          bestMoves++;
        case MoveClassification.good:
          break;
        case MoveClassification.needsImprovement:
          break;
        case MoveClassification.mistake:
          mistakes++;
        case MoveClassification.blunder:
          blunders++;
      }

      // Update accuracy
      final moveCountTotal = state.moveHistory.length + 1;
      final double moveAccuracy = (100.0 - (feedback.centipawnLoss / 10.0)).clamp(0.0, 100.0);
      accuracy = (state.accuracy * (moveCountTotal - 1) + moveAccuracy) / moveCountTotal;

      // Track coach history for post-game analysis
      final updatedHistory = [...state.gameCoachHistory, feedback];

      // Highlight best move if user made a mistake
      Move? coachMove;
      if (feedback.isNegative && feedback.bestMoveAlgebraic != null) {
        try {
          coachMove = Move.fromAlgebraic(feedback.bestMoveAlgebraic!);
        } catch (_) {}
      }

      // Track if this move was made with a hint
      final newHintedIndices = Set<int>.from(state.hintedIndices);
      if (state.activeHint != null) {
        newHintedIndices.add(_engine.moveHistory.length - 1);
      }

      emit(state.copyWith(
        accuracy: accuracy,
        mistakes: mistakes,
        blunders: blunders,
        bestMoves: bestMoves,
        missedWins: missedWins,
        coachFeedback: feedback,
        coachMessage: feedback.isNegative ? feedback.message : null,
        showMiniLesson: feedback.classification == MoveClassification.blunder,
        gameCoachHistory: updatedHistory,
        coachMove: coachMove,
        hintedIndices: newHintedIndices,
        clearActiveHint: true,
      ));
    } catch (e) {
      print('[Coach Analysis Error] $e');
    }
    } // End of shouldAnalyze block

    // Note: We avoid Future.delayed here as it can cause late emits after bloc closure.
    // UI should handle the ephemeral display of coach messages.

    // Tutorial Progress — show success, then advance to next step
    if (state.mode == GameMode.tutorial && state.tutorial != null) {
      final currentStep = state.tutorial!.steps[state.tutorialStep];
      final nextIdx = state.tutorialStep + 1;
      final isLastStep = nextIdx >= state.tutorial!.steps.length;

      // Show the success message for this step
      if (currentStep.successMessage != null) {
        emit(state.copyWith(tutorialMessage: currentStep.successMessage));
        // Brief delay so user can read the success before advancing
        await Future.delayed(const Duration(milliseconds: 1800));
        if (isClosed) return;
      }

      if (isLastStep || currentStep.isCompletion) {
        // Tutorial complete!
        emit(state.copyWith(
          tutorialMessage: '🎓 Lesson Complete! ${currentStep.successMessage ?? "Well done!"}',
          status: GameStatus.draw, // Mark as finished
        ));
      } else {
        final nextStep = state.tutorial!.steps[nextIdx];
        if (nextStep.isCompletion) {
          // Next step is completion (info-only, no move needed) — show it and finish
          emit(state.copyWith(
            tutorialStep: nextIdx,
            tutorialMessage: nextStep.text,
            status: GameStatus.draw, // Mark as finished
          ));
        } else {
          // Advance to the next interactive step
          emit(state.copyWith(
            tutorialStep: nextIdx,
            tutorialMessage: nextStep.text,
          ));
        }
      }
    }

    // Puzzle Progress
    if (state.mode == GameMode.puzzle && state.puzzle != null) {
      final isLastMove = state.puzzleStep == state.puzzle!.moves.length - 1;

      if (isLastMove) {
        emit(state.copyWith(
          showPuzzleCelebration: true,
          status: GameStatus.checkmate, 
          tutorialMessage: '🌟 Amazing! Puzzle Solved!',
          totalPuzzleXP: state.totalPuzzleXP + 100, // Completion bonus
        ));

        // SYNC XP TO SERVER
        final user = await _authRepository.getCurrentUser();
        if (user != null) {
          await _authRepository.updateXPProgress(
            userId: user.id,
            xpDelta: 100,
            statUpdates: {'puzzles_solved': 1},
          );
        }

        // In Puzzle Rush, automatically go to the next puzzle
        if (state.isPuzzleRush) {
          await Future.delayed(const Duration(milliseconds: 1500));
          if (isClosed || state.puzzleRushTime <= 0 || !state.isPuzzleRush) return;
          
          final nextPuzzle = await _puzzleRepository.getRandomPuzzle(); 
          add(GameStartEvent(GameConfig(
            mode: GameMode.puzzle,
            playerColor: 'white', // Lichess puzzles typically White to move from FEN
            puzzle: nextPuzzle,
            isPuzzleRush: true, // Keep the rush going
          )));
        }
      } else {
        final nextIdx = state.puzzleStep + 1;
        emit(state.copyWith(
          puzzleStep: nextIdx,
          tutorialMessage: state.puzzle!.moves[nextIdx].dialog,
        ));
      }
    }

    // Vibrate on check
    if (_engine.status == GameStatus.check) {
      Vibration.vibrate(duration: 200);
    }

    // Trigger AI if needed
    if (!state.isGameOver &&
        (state.mode == GameMode.singlePlayer || state.mode == GameMode.practice) &&
        _engine.currentTurn != state.playerColor) {
      final aiRequestEpoch = ++_aiRequestEpoch;
      emit(state.copyWith(isAIThinking: true));
      await Future.delayed(const Duration(milliseconds: 400));

      // Use the hybrid EngineController instead of AIDirectly
      final moveStr = await _engineController.getBestMove(_engine.toFEN());
      
      if (isClosed || aiRequestEpoch != _aiRequestEpoch) return;
      emit(state.copyWith(isAIThinking: false));

      if (moveStr != null && !state.isGameOver && _engine.status == GameStatus.active) {
        final aiMove = Move.fromAlgebraic(moveStr);
        add(GameMakeMoveEvent(aiMove.from, aiMove.to, promotion: aiMove.promotion));
      }
    }

    // Auto-save & Post-Game Analysis
    if (_gameId != null) {
      if (state.isGameOver) {
        _gameRepository.setLastActiveGameId(null);

        // Scale Practice Difficulty
        if (state.mode == GameMode.practice) {
          final user = await _authRepository.getCurrentUser();
          if (user != null) {
            double currentD = user.stats.practiceDifficulty;
            final isWin = (state.result == GameResult.whiteWins && state.playerColor == PieceColor.white) ||
                         (state.result == GameResult.blackWins && state.playerColor == PieceColor.black);
            
            if (isWin) {
              currentD += 0.5;
            } else if (state.result != GameResult.draw && state.result != GameResult.ongoing) {
              currentD = math.max(1.0, currentD - 0.5);
            }
            await _authRepository.updatePracticeDifficulty(user.id, currentD);
          }
        }

        // Calculate XP Rewards & Update Stats
        int xp = 0;
        final mapUpdates = <String, dynamic>{
          'games_played': 1,
        };

        if (state.mode != GameMode.practice) {
          final user = await _authRepository.getCurrentUser();
          if (user != null) {
            final isWin = (state.result == GameResult.whiteWins && state.playerColor == PieceColor.white) ||
                         (state.result == GameResult.blackWins && state.playerColor == PieceColor.black);
            final isLoss = (state.result == GameResult.blackWins && state.playerColor == PieceColor.white) ||
                          (state.result == GameResult.whiteWins && state.playerColor == PieceColor.black);
            final isDraw = state.result == GameResult.draw;

            if (isWin) {
              xp += 100; // Base win XP
              
              // Bonus for every 10th win
              if ((user.stats.wins + 1) % 10 == 0) {
                xp += 100;
              }

              // Checkmate in 5 moves (10 half-moves)
              if (state.status == GameStatus.checkmate && state.moveHistory.length <= 10) {
                xp += 500;
              }

              // Win without losing piece
              final myCaptured = state.playerColor == PieceColor.black ? state.capturedBlack : state.capturedWhite;
              if (myCaptured.isEmpty) {
                xp += 10000;
              }
              
              mapUpdates['wins'] = 1;
              if (state.mode == GameMode.singlePlayer) mapUpdates['ai_wins'] = 1;
              if (state.mode == GameMode.multiplayer) mapUpdates['multiplayer_wins'] = 1;
              if (state.mode == GameMode.tournament) mapUpdates['tournament_wins'] = 1;
              
            } else if (isLoss) {
              // Less penalty for tournaments to encourage playing
              if (state.mode == GameMode.tournament) {
                xp -= 10;
              } else {
                xp -= 20;
              }

              mapUpdates['losses'] = 1;
            } else if (isDraw) {
              xp += 10; // Small reward for holding a draw
              mapUpdates['draws'] = 1;
            }

            // Sync with Repo
            await _authRepository.updateXPProgress(
              userId: user.id,
              xpDelta: xp + state.xpGained, // include hint penalties already in state
              statUpdates: mapUpdates,
              isOnlineMatch: state.mode == GameMode.multiplayer,
            );
          }
        }

        // Generate Encouraging Message & Engine Suggestion
        String msg = '';
        if (state.accuracy >= 80) {
          msg = '🚀 Incredible! Your precision was professional level.';
          if (state.aiDifficulty != AIDifficulty.impossible) {
            msg += '\nReady to try the next level?';
          }
        } else if (state.accuracy >= 60) {
          msg = '🔥 Solid game! You had some great highlights.';
        } else {
          msg = '💎 Good effort! Keep practicing to master the patterns.';
        }

        emit(state.copyWith(
          xpGained: xp + state.xpGained, // Show total gained in this game
          analysisMessage: msg,
        ));

        final game = GameModel(
          id: _gameId ?? '',
          fen: state.currentFEN,
          pgn: _engine.toPGN(),
          mode: state.mode.name,
          status: state.status.name,
          result: state.result.name,
          moveCount: state.moveHistory.length,
          playerColor: state.playerColor == PieceColor.black ? 'black' : 'white',
          updatedAt: DateTime.now(),
        );
        _gameRepository.completeGame(game);
        
        // Persist XP to user profile (if repository supports it)
        try {
          // Assuming user profile exists or we handle it via a different service
          // _userRepository.addXP(xp);
        } catch (_) {}

      } else {
        add(GameSaveEvent());
      }
    }
  }

  void _onUndo(GameUndoEvent event, Emitter<GameState> emit) {
    if (state.mode == GameMode.multiplayer) {
      if (state.mpUndosUsed >= 2) return;
      if (state.lastMoveTimestamp == null) return;
      
      // In multiplayer, the move turned the board to the OPPONENT. 
      // We can only undo if it's currently NOT our turn (meaning we just moved).
      if (state.isPlayerTurn) return; 

      final elapsed = DateTime.now().difference(state.lastMoveTimestamp!);
      if (elapsed.inSeconds >= 5) return;
      if (_engine.moveHistory.isEmpty) return;

      _engine.undoMove();
      final captured = _collectCaptured();
      emit(state.copyWith(
        board: _engine.board,
        currentTurn: _engine.currentTurn,
        moveHistory: _engine.moveHistory,
        status: _engine.status,
        result: _engine.result,
        currentFEN: _engine.toFEN(),
        capturedWhite: captured.$1,
        capturedBlack: captured.$2,
        clearSelected: true,
        mpUndosUsed: state.mpUndosUsed + 1,
      ));
      return;
    }
    // Undo 2 moves if vs AI (take back player's move + AI's response)
    final isVsAI = state.mode == GameMode.singlePlayer || state.mode == GameMode.practice;
    
    // In practice/single player, we usually undo 2. 
    // But if it was hinted, the user might only get 1 undo? 
    // Actually, "Undo stays" but "only undo ONCE for that move if hint given"
    // I will interpret as: you can undo it, but we can prevent further undos?
    // Let's just do the undo and clear the suggested move.
    
    final undoCount = isVsAI ? 2 : 1;
    for (int i = 0; i < undoCount; i++) {
      if (_engine.moveHistory.isNotEmpty) _engine.undoMove();
    }
    emit(state.copyWith(
      board: _engine.board,
      currentTurn: _engine.currentTurn,
      moveHistory: _engine.moveHistory,
      status: _engine.status,
      result: _engine.result,
      currentFEN: _engine.toFEN(),
      clearSelected: true,
      clearCoachMove: true,
    ));
  }

  void _onResign(GameResignEvent event, Emitter<GameState> emit) {
    // Explicitly cancel any in-flight AI result.
    _aiRequestEpoch++;
    emit(state.copyWith(
      result: state.currentTurn == PieceColor.white
          ? GameResult.blackWins : GameResult.whiteWins,
      status: GameStatus.checkmate,
      isAIThinking: false,
    ));
  }

  void _onDrawOffer(GameDrawOfferEvent event, Emitter<GameState> emit) {
    emit(state.copyWith(drawOfferFrom: DrawReason.agreement));
  }

  void _onDrawAccept(GameDrawAcceptEvent event, Emitter<GameState> emit) {
    emit(state.copyWith(
      result: GameResult.draw,
      status: GameStatus.draw,
      drawReason: DrawReason.agreement,
      clearDrawOffer: true,
    ));
  }

  void _onDrawDecline(GameDrawDeclineEvent event, Emitter<GameState> emit) {
    emit(state.copyWith(clearDrawOffer: true));
  }

  Future<void> _onSave(GameSaveEvent event, Emitter<GameState> emit) async {
    try {
      final game = GameModel(
        id: _gameId ?? '',
        fen: state.currentFEN,
        pgn: _engine.toPGN(),
        mode: state.mode.name,
        status: state.status.name,
        result: state.result.name,
        whiteUserId: state.playerColor == PieceColor.white ? 'me' : 'ai',
        blackUserId: state.playerColor == PieceColor.black ? 'me' : 'ai',
        moveCount: state.moveHistory.length,
        updatedAt: DateTime.now(),
      );
      _gameId = await _gameRepository.saveGame(game);
    } catch (_) {}
  }

  Future<void> _onRequestHint(GameRequestHintEvent event, Emitter<GameState> emit) async {
    // Puzzle Hint Logic
    if (state.mode == GameMode.puzzle && state.puzzle != null) {
      final currentMove = state.puzzle!.moves[state.puzzleStep];
      emit(state.copyWith(
        tutorialMessage: "💡 Hint: ${currentMove.hint}",
        isPuzzleHintUsed: true,
      ));
      return;
    }

    if (state.hintsRemaining <= 0) return;
    if (state.mode != GameMode.singlePlayer && state.mode != GameMode.practice) return;
    if (!state.isPlayerTurn) return;

    final aiRequestEpoch = ++_aiRequestEpoch;
    emit(state.copyWith(isAIThinking: true));
    
    // Use AI Coach for rich hint with explanation
    final hintResult = await _coachController.getHint(_engine);

    if (isClosed || aiRequestEpoch != _aiRequestEpoch) return;
    emit(state.copyWith(isAIThinking: false));

    if (hintResult != null) {
      final hintMove = Move.fromAlgebraic(hintResult.bestMoveAlgebraic);
      emit(state.copyWith(
        hintMove: hintMove,
        activeHint: hintResult,
        hintsUsed: state.hintsUsed + 1,
        xpGained: state.xpGained - hintResult.xpCost, // -10 XP per hint
      ));
    }
  }

  void _onDismissMiniLesson(GameDismissMiniLessonEvent event, Emitter<GameState> emit) {
    emit(state.copyWith(showMiniLesson: false));
  }

  @override
  Future<void> close() {
    _engineController.dispose();
    _coachController.dispose();
    return super.close();
  }

  void _onPromotionRequired(GamePromotionRequiredEvent event, Emitter<GameState> emit) {
    emit(state.copyWith(
      showPromotionDialog: true,
      promotionFrom: event.from,
      promotionTo: event.to,
    ));
  }

  (List<ChessPiece>, List<ChessPiece>) _collectCaptured() {
    final capturedWhite = <ChessPiece>[];
    final capturedBlack = <ChessPiece>[];
    final initialPieces = {
      PieceType.pawn: 8, PieceType.rook: 2, PieceType.knight: 2,
      PieceType.bishop: 2, PieceType.queen: 1,
    };
    final onBoardWhite = <PieceType, int>{};
    final onBoardBlack = <PieceType, int>{};

    for (final row in _engine.board) {
      for (final p in row) {
        if (p == null || p.type == PieceType.king) continue;
        if (p.color == PieceColor.white) {
          onBoardWhite[p.type] = (onBoardWhite[p.type] ?? 0) + 1;
        } else {
          onBoardBlack[p.type] = (onBoardBlack[p.type] ?? 0) + 1;
        }
      }
    }

    for (final entry in initialPieces.entries) {
      final wCount = (entry.value) - (onBoardWhite[entry.key] ?? 0);
      final bCount = (entry.value) - (onBoardBlack[entry.key] ?? 0);
      capturedWhite.addAll(List.generate(wCount, (_) =>
          ChessPiece(type: entry.key, color: PieceColor.white)));
      capturedBlack.addAll(List.generate(bCount, (_) =>
          ChessPiece(type: entry.key, color: PieceColor.black)));
    }

    return (capturedWhite, capturedBlack);
  }
}
