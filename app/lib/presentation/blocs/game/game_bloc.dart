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
import '../../../data/services/audio_service.dart';
import '../../../data/services/elo_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/puzzle_repository.dart';
import '../../../data/services/achievement_service.dart';
import '../../../data/services/mission_service.dart';
import '../theme/theme_bloc.dart';
import '../../../domain/engine/personality_engine.dart';

// ═══════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════
abstract class GameEvent extends Equatable {
  const GameEvent();
  @override
  List<Object?> get props => [];
}

class GameStartEvent extends GameEvent {
  final GameConfig config;
  final TutorialLesson? tutorial;
  const GameStartEvent(this.config, {this.tutorial});
  @override
  List<Object?> get props => [config, tutorial];
}

class GameResumeEvent extends GameEvent {
  final String gameId;
  const GameResumeEvent(this.gameId);
  @override
  List<Object?> get props => [gameId];
}

class GameExitEvent extends GameEvent {}

class GameSelectPieceEvent extends GameEvent {
  final Square square;
  const GameSelectPieceEvent(this.square);
  @override
  List<Object?> get props => [square];
}

class GameDiscardEvent extends GameEvent {}

class GameMakeMoveEvent extends GameEvent {
  final Square from;
  final Square to;
  final PieceType? promotion;
  const GameMakeMoveEvent(this.from, this.to, {this.promotion});
  @override
  List<Object?> get props => [from, to, promotion];
}

class GameUndoEvent extends GameEvent {}

class GameRedoEvent extends GameEvent {}

class GameResignEvent extends GameEvent {}

class GameDrawOfferEvent extends GameEvent {}

class GameDrawAcceptEvent extends GameEvent {}

class GameDrawDeclineEvent extends GameEvent {}

class GameSaveEvent extends GameEvent {}

class GameRequestHintEvent extends GameEvent {
  const GameRequestHintEvent();
}

class GameSetOpponentNameEvent extends GameEvent {
  final String name;
  const GameSetOpponentNameEvent(this.name);
  @override
  List<Object?> get props => [name];
}

class GameUpdatePersonalityEvent extends GameEvent {
  final AIPersonality personality;
  final String message;
  const GameUpdatePersonalityEvent(
      {required this.personality, required this.message});
  @override
  List<Object?> get props => [personality, message];
}

class GamePromotionRequiredEvent extends GameEvent {
  final Square from;
  final Square to;
  const GamePromotionRequiredEvent(this.from, this.to);
  @override
  List<Object?> get props => [from, to];
}

class GameUpdateSettingsEvent extends GameEvent {
  final bool confirmMoves;
  final bool autoQueen;
  const GameUpdateSettingsEvent(
      {this.confirmMoves = false, this.autoQueen = false});
  @override
  List<Object?> get props => [confirmMoves, autoQueen];
}

class GameConfirmMoveEvent extends GameEvent {}

class GameDrawReceiveEvent extends GameEvent {
  final String? fromId;
  const GameDrawReceiveEvent(this.fromId);
}

class GameDismissMiniLessonEvent extends GameEvent {
  const GameDismissMiniLessonEvent();
}

class GamePuzzleRushTickEvent extends GameEvent {
  const GamePuzzleRushTickEvent();
}

class GameExplainMoveEvent extends GameEvent {
  final Move? move;
  final String? fen;
  const GameExplainMoveEvent({this.move, this.fen});
  @override
  List<Object?> get props => [move, fen];
}

class GamePuzzleGiveUpEvent extends GameEvent {
  const GamePuzzleGiveUpEvent();
}

class GamePuzzleNextEvent extends GameEvent {
  const GamePuzzleNextEvent();
}

class GameDismissCoachFeedbackEvent extends GameEvent {}

class GameDismissHintEvent extends GameEvent {
  const GameDismissHintEvent();
}

class GameClockTickEvent extends GameEvent {}

class GameTimerSyncEvent extends GameEvent {
  final double whiteTime;
  final double blackTime;
  const GameTimerSyncEvent(this.whiteTime, this.blackTime);
  @override
  List<Object?> get props => [whiteTime, blackTime];
}

class GameUpdateEvalEvent extends GameEvent {
  final double evalScore;
  const GameUpdateEvalEvent(this.evalScore);
  @override
  List<Object?> get props => [evalScore];
}

class GameUpdateCoachSettingsEvent extends GameEvent {
  final CoachSettings coachSettings;
  const GameUpdateCoachSettingsEvent(this.coachSettings);
  @override
  List<Object?> get props => [coachSettings];
}

class MpGameOverSyncEvent extends GameEvent {
  final GameResult result;
  final DrawReason? reason;
  final int xpGained;
  const MpGameOverSyncEvent(this.result, this.reason, this.xpGained);
  @override
  List<Object?> get props => [result, reason, xpGained];
}

class GameAIRequestEvent extends GameEvent {}

class GameDismissErrorEvent extends GameEvent {}

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
  final double evalScore;
  final String? aiMessage;
  final AIPersonality? activePersonality;

  // Analytics & Rewards
  final double accuracy;
  final int mistakes;
  final int blunders;
  final int missedWins;
  final int bestMoves;
  final int xpGained;
  final String? coachMessage;
  final String? analysisMessage;
  final String? engineError;
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
  final bool puzzleGaveUp;

  // Real-time Highlighting & Undo
  final Move? coachMove;
  final Set<int> hintedIndices;

  // Time Control
  final double whiteTimeMs; // milliseconds remaining
  final double blackTimeMs;
  final int incrementMs; // increment in ms per move
  final bool clockRunning;

  // Premove
  final Move? preMove;

  // Eval history for post-game analysis chart
  final List<double> evalHistory;

  // ELO rating change
  final int eloChange;

  // Undo penalty source square for bubble animation
  final Square? lastUndoPenaltySquare;

  const GameState({
    required this.board,
    required this.currentTurn,
    this.selectedSquare,
    this.legalMoves = const [],
    this.moveHistory = const [],
    this.status = GameStatus.active,
    this.result = GameResult.ongoing,
    this.aiMessage,
    this.activePersonality,
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
    this.evalScore = 0.0,
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
    this.engineError,
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
    this.puzzleGaveUp = false,
    this.coachMove,
    this.hintedIndices = const {},
    this.whiteTimeMs = 0,
    this.blackTimeMs = 0,
    this.incrementMs = 0,
    this.clockRunning = false,
    this.preMove,
    this.evalHistory = const [],
    this.eloChange = 0,
    this.lastUndoPenaltySquare,
  });

  bool get isGameOver =>
      status == GameStatus.checkmate ||
      status == GameStatus.stalemate ||
      status == GameStatus.draw;

  bool get isPlayerTurn => playerColor == null || currentTurn == playerColor;

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
    double? evalScore,
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
    String? engineError,
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
    bool? puzzleGaveUp,
    Move? coachMove,
    Set<int>? hintedIndices,
    double? whiteTimeMs,
    double? blackTimeMs,
    int? incrementMs,
    bool? clockRunning,
    bool clearSelected = false,
    bool clearHint = false,
    bool clearDrawOffer = false,
    bool clearTutorialMessage = false,
    bool clearPendingMove = false,
    bool clearCoachMessage = false,
    bool clearCoachFeedback = false,
    bool clearActiveHint = false,
    bool clearCoachMove = false,
    bool clearPreMove = false,
    bool clearEngineError = false,
    bool clearExplanation = false,
    String? aiMessage,
    AIPersonality? activePersonality,
    Move? preMove,
    List<double>? evalHistory,
    int? eloChange,
    Square? lastUndoPenaltySquare,
    bool clearUndoPenalty = false,
  }) {
    return GameState(
      board: board ?? this.board,
      currentTurn: currentTurn ?? this.currentTurn,
      selectedSquare:
          clearSelected ? null : (selectedSquare ?? this.selectedSquare),
      legalMoves: clearSelected ? [] : (legalMoves ?? this.legalMoves),
      moveHistory: moveHistory ?? this.moveHistory,
      status: status ?? this.status,
      result: result ?? this.result,
      aiMessage: aiMessage ?? this.aiMessage,
      activePersonality: activePersonality ?? this.activePersonality,
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
      drawOfferFrom:
          clearDrawOffer ? null : (drawOfferFrom ?? this.drawOfferFrom),
      tutorial: tutorial ?? this.tutorial,
      tutorialStep: tutorialStep ?? this.tutorialStep,
      tutorialMessage: clearTutorialMessage
          ? null
          : (tutorialMessage ?? this.tutorialMessage),
      puzzle: puzzle ?? this.puzzle,
      puzzleStep: puzzleStep ?? this.puzzleStep,
      isPuzzleHintUsed: isPuzzleHintUsed ?? this.isPuzzleHintUsed,
      mpUndosUsed: mpUndosUsed ?? this.mpUndosUsed,
      lastMoveTimestamp: lastMoveTimestamp ?? this.lastMoveTimestamp,
      evalScore: evalScore ?? this.evalScore,
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
      coachMessage:
          clearCoachMessage ? null : (coachMessage ?? this.coachMessage),
      engineError: clearEngineError ? null : (engineError ?? this.engineError),
      showMiniLesson: showMiniLesson ?? this.showMiniLesson,
      coachFeedback:
          clearCoachFeedback ? null : (coachFeedback ?? this.coachFeedback),
      activeHint: clearActiveHint ? null : (activeHint ?? this.activeHint),
      coachSettings: coachSettings ?? this.coachSettings,
      gameCoachHistory: gameCoachHistory ?? this.gameCoachHistory,
      puzzleStreak: puzzleStreak ?? this.puzzleStreak,
      puzzleRushStrikes: puzzleRushStrikes ?? this.puzzleRushStrikes,
      puzzleRushTime: puzzleRushTime ?? this.puzzleRushTime,
      isPuzzleRush: isPuzzleRush ?? this.isPuzzleRush,
      lastCorrectPuzzleMove:
          lastCorrectPuzzleMove ?? this.lastCorrectPuzzleMove,
      showPuzzleCelebration:
          showPuzzleCelebration ?? this.showPuzzleCelebration,
      puzzleExplanation:
          clearExplanation ? null : (puzzleExplanation ?? this.puzzleExplanation),
      totalPuzzleXP: totalPuzzleXP ?? this.totalPuzzleXP,
      puzzleGaveUp: puzzleGaveUp ?? this.puzzleGaveUp,
      coachMove: clearCoachMove ? null : (coachMove ?? this.coachMove),
      hintedIndices: hintedIndices ?? this.hintedIndices,
      whiteTimeMs: whiteTimeMs ?? this.whiteTimeMs,
      blackTimeMs: blackTimeMs ?? this.blackTimeMs,
      incrementMs: incrementMs ?? this.incrementMs,
      clockRunning: clockRunning ?? this.clockRunning,
      preMove: clearPreMove ? null : (preMove ?? this.preMove),
      evalHistory: evalHistory ?? this.evalHistory,
      eloChange: eloChange ?? this.eloChange,
      lastUndoPenaltySquare: clearUndoPenalty
          ? null
          : (lastUndoPenaltySquare ?? this.lastUndoPenaltySquare),
    );
  }

  @override
  List<Object?> get props => [
        status,
        result,
        isAIThinking,
        hintMove,
        hintsUsed,
        currentFEN,
        selectedSquare,
        legalMoves,
        currentTurn,
        moveHistory,
        showPromotionDialog,
        tutorial,
        tutorialStep,
        tutorialMessage,
        pieceShape,
        pieceStyle,
        lastMoveTimestamp,
        opponentName,
        confirmMoves,
        autoQueen,
        pendingMove,
        accuracy,
        mistakes,
        blunders,
        missedWins,
        bestMoves,
        xpGained,
        coachMessage,
        showMiniLesson,
        analysisMessage,
        coachFeedback,
        activeHint,
        coachSettings,
        gameCoachHistory,
        puzzleStreak,
        puzzleRushStrikes,
        puzzleRushTime,
        isPuzzleRush,
        lastCorrectPuzzleMove,
        showPuzzleCelebration,
        puzzleExplanation,
        totalPuzzleXP,
        coachMove,
        hintedIndices,
        whiteTimeMs,
        blackTimeMs,
        incrementMs,
        clockRunning,
        preMove,
        evalScore,
        aiMessage,
        activePersonality,
        evalHistory,
        eloChange,
        lastUndoPenaltySquare,
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
  final AchievementService _achievementService;
  final MissionService _missionService;
  String? _gameId;
  int _aiRequestEpoch = 0;
  Timer? _rushTimer;
  Timer? _clockTimer;
  DateTime? _lastClockTickTime;

  ChessEngine get engine => _engine;
  AIEngineController get engineController => _engineController;
  CoachController get coachController => _coachController;

  GameBloc(this._gameRepository, this._authRepository, this._puzzleRepository,
      this._themeBloc, this._achievementService, this._missionService)
      : super(GameState(
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
    on<GameUpdateSettingsEvent>((e, emit) => emit(
        state.copyWith(confirmMoves: e.confirmMoves, autoQueen: e.autoQueen)));
    on<GameSetOpponentNameEvent>(
        (event, emit) => emit(state.copyWith(opponentName: event.name)));
    on<GameDiscardEvent>(_onDiscard);
    on<GamePuzzleRushTickEvent>(_onPuzzleRushTick);
    on<GameExplainMoveEvent>(_onExplainMove);
    on<GamePuzzleGiveUpEvent>(_onPuzzleGiveUp);
    on<GamePuzzleNextEvent>(_onPuzzleNext);
    on<GameUpdateEvalEvent>(_onUpdateEval);
    on<GameDismissCoachFeedbackEvent>(
        (e, emit) => emit(state.copyWith(clearCoachFeedback: true)));
    on<GameDismissHintEvent>(
        (e, emit) => emit(state.copyWith(clearActiveHint: true)));
    on<GameUpdateCoachSettingsEvent>((e, emit) {
      _coachController.updateSettings(e.coachSettings);
      emit(state.copyWith(coachSettings: e.coachSettings));
    });
    on<GameAIRequestEvent>(_onAIRequest);
    on<GameDismissErrorEvent>(
        (e, emit) => emit(state.copyWith(clearEngineError: true)));
    on<MpGameOverSyncEvent>((e, emit) {
      _stopClock();
      final status =
          e.result == GameResult.draw ? GameStatus.draw : GameStatus.checkmate;
      emit(state.copyWith(
        status: status,
        result: e.result,
        drawReason: e.reason,
        xpGained: e.xpGained,
        clockRunning: false,
      ));
    });
    on<GameClockTickEvent>(_onClockTick);
    on<GameUpdatePersonalityEvent>(_onUpdatePersonality);
    on<GameTimerSyncEvent>((e, emit) => emit(state.copyWith(
          whiteTimeMs: e.whiteTime,
          blackTimeMs: e.blackTime,
        )));
  }

  void _onUpdatePersonality(
      GameUpdatePersonalityEvent event, Emitter<GameState> emit) {
    emit(state.copyWith(
      activePersonality: event.personality,
      aiMessage: event.message,
    ));
  }

  Future<void> _onDiscard(
      GameDiscardEvent event, Emitter<GameState> emit) async {
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

    _engine = ChessEngine.fromFEN(event.config.puzzle?.initialFEN ??
        event.tutorial?.initialFEN ??
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
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

    final playerColor =
        config.playerColor == 'black' ? PieceColor.black : PieceColor.white;

    final initialState = GameState(
      board: _engine.board,
      currentTurn: _engine.currentTurn,
      playerColor: (config.mode == GameMode.singlePlayer ||
              config.mode == GameMode.multiplayer ||
              config.mode == GameMode.practice)
          ? playerColor
          : null,
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

    // Initialize time control
    if (config.timeControl != null && config.timeControl! > 0) {
      final timeMs = config.timeControl!.toDouble() * 1000;
      final incMs = config.incrementSeconds * 1000;
      emit(state.copyWith(
        whiteTimeMs: timeMs,
        blackTimeMs: timeMs,
        incrementMs: incMs,
        clockRunning: true,
      ));
      _startClock();
    }

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
      emit(state.copyWith(
          isPuzzleRush: true, puzzleRushTime: 180, puzzleRushStrikes: 0));
    }

    if (config.mode == GameMode.puzzle &&
        config.puzzle != null &&
        config.puzzle!.moves.isNotEmpty) {
      final firstMove = config.puzzle!.moves[0];
      if (firstMove.isOpponentMove) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (isClosed) return;
        final setupMove = Move.fromAlgebraic(firstMove.uciMove);
        add(GameMakeMoveEvent(setupMove.from, setupMove.to,
            promotion: setupMove.promotion));
      }
    }

    // NEW: Trigger AI if it's AI's turn to start (e.g. user plays Black)
    if (!state.isGameOver &&
        (config.mode == GameMode.singlePlayer ||
            config.mode == GameMode.practice) &&
        initialState.currentTurn != initialState.playerColor) {
      add(GameAIRequestEvent());
    }
  }

  Future<void> _onResume(GameResumeEvent event, Emitter<GameState> emit) async {
    final game = await _gameRepository.getSavedGame(event.gameId);
    if (game == null) return;

    _aiRequestEpoch++;
    _engine = ChessEngine.fromFEN(game.fen);
    _gameId = game.id;
    _gameRepository.setLastActiveGameId(game.id);

    final mode = GameMode.values.firstWhere((m) => m.name == game.mode,
        orElse: () => GameMode.singlePlayer);

    // Puzzle Rush check on resume
    if (mode == GameMode.puzzle) {
      // Usually we don't resume puzzle rush, but if we do, timer should restart
    }

    AIDifficulty difficulty = AIDifficulty.intermediate;
    if (mode == GameMode.practice) {
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

    _engineController.init(mode, difficulty);

    final playerColorStr =
        (game.whiteUserId == 'me') ? PieceColor.white : PieceColor.black;

    emit(GameState(
      board: _engine.board,
      currentTurn: _engine.currentTurn,
      playerColor: (mode == GameMode.singlePlayer ||
              mode == GameMode.multiplayer ||
              mode == GameMode.practice)
          ? playerColorStr
          : null,
      mode: mode,
      aiDifficulty: difficulty,
      moveHistory: _engine.moveHistory,
      currentFEN: game.fen,
      // Restore other properties if needed, but these are essential for turn logic
    ));

    // After resume, trigger AI if it's its turn
    if (!state.isGameOver &&
        (mode == GameMode.singlePlayer || mode == GameMode.practice) &&
        _engine.currentTurn != playerColorStr) {
      add(GameAIRequestEvent());
    }
  }

  void _onExit(GameExitEvent event, Emitter<GameState> emit) {
    _rushTimer?.cancel();
    _gameRepository.setLastActiveGameId(null);
  }

  void _onPuzzleRushTick(
      GamePuzzleRushTickEvent event, Emitter<GameState> emit) {
    if (state.puzzleRushTime <= 0 ||
        state.puzzleRushStrikes >= 3 ||
        state.isGameOver) {
      _rushTimer?.cancel();
      return;
    }
    final newTime = state.puzzleRushTime - 1;
    if (newTime <= 0) {
      _rushTimer?.cancel();
      emit(state.copyWith(
          puzzleRushTime: 0,
          status: GameStatus.draw,
          result: GameResult.ongoing));
    } else {
      emit(state.copyWith(puzzleRushTime: newTime));
    }
  }

  Future<void> _onExplainMove(
      GameExplainMoveEvent event, Emitter<GameState> emit) async {
    // If no move/fen provided, it's a "Clear" request
    if (event.move == null || event.fen == null) {
      emit(state.copyWith(clearExplanation: true));
      return;
    }

    emit(state.copyWith(puzzleExplanation: 'Analyzing position... 🧠'));

    try {
      final explanation = await _coachController.explainMove(
        fen: event.fen!,
        move: event.move!,
      );
      emit(state.copyWith(puzzleExplanation: explanation));
    } catch (e) {
      emit(state.copyWith(
          puzzleExplanation:
              'I analyzed this move and it looks solid! It focuses on board control and piece activity. 🧠'));
    }
  }

  void _onSelectPiece(GameSelectPieceEvent event, Emitter<GameState> emit) {
    final sq = event.square;
    if (state.isAIThinking) return;

    // Deselect if clicking same square
    if (state.selectedSquare == sq) {
      emit(state.copyWith(
          clearSelected: true, clearHint: true, clearPendingMove: true));
      return;
    }

    // Premove logic for multiplayer
    bool isPremove = false;
    if (state.mode == GameMode.multiplayer &&
        state.playerColor != null &&
        !state.isPlayerTurn) {
      isPremove = true;
    }

    // In multiplayer, only allow controlling your own pieces or setting premove
    if (state.mode == GameMode.multiplayer && state.playerColor != null) {
      // If no piece selected yet, only allow selecting own color
      if (state.selectedSquare == null) {
        final clickedPiece = _engine.pieceAt(sq);
        if (clickedPiece == null || clickedPiece.color != state.playerColor) {
          emit(state.copyWith(
              clearSelected: true, clearPendingMove: true, clearPreMove: true));
          return;
        }
      }
    }

    // If a piece is already selected, try to make a move (or premove)
    if (state.selectedSquare != null) {
      if (isPremove) {
        final from = state.selectedSquare!;
        emit(state.copyWith(
          preMove: Move(from: from, to: sq),
          clearSelected: true,
        ));
        return;
      }

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
    if (!isPremove) {
      if (piece == null || piece.color != _engine.currentTurn) {
        emit(state.copyWith(clearSelected: true, clearPendingMove: true));
        return;
      }
      if (!state.isPlayerTurn) return;
    } else {
      if (piece == null || piece.color != state.playerColor) {
        emit(state.copyWith(clearSelected: true, clearPendingMove: true));
        return;
      }
    }

    final moves = isPremove ? <Move>[] : _engine.legalMovesFrom(sq);
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

  Future<void> _onMakeMove(
      GameMakeMoveEvent event, Emitter<GameState> emit) async {
    final move =
        Move(from: event.from, to: event.to, promotion: event.promotion);

    // Tutorial check — wrong moves show error BUT keep instruction visible
    if (state.mode == GameMode.tutorial && state.tutorial != null) {
      final step = state.tutorial!.steps[state.tutorialStep];
      if (step.expectedMove != null &&
          step.expectedMove!.isNotEmpty &&
          move.toAlgebraic() != step.expectedMove) {
        // Show error for 2 seconds, then restore the original instruction
        final errorMsg = '❌ Not quite! Try again.\n\n${step.text}';
        emit(state.copyWith(
          tutorialMessage: errorMsg,
          clearSelected: true,
        ));
        return;
      }
    }

    // Puzzle check — only validate user moves (not opponent auto-plays)
    if (state.mode == GameMode.puzzle && state.puzzle != null) {
      final currentMove = state.puzzle!.moves[state.puzzleStep];

      // Skip validation if this is an auto-played opponent move
      if (!currentMove.isOpponentMove) {
        if (move.toAlgebraic() != currentMove.uciMove &&
            move.toAlgebraic() != currentMove.move) {
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
            tutorialMessage:
                '❌ Oopsie! That\'s not quite right. Try again little champion! 🤔',
            clearSelected: true,
          ));
          return;
        }
      }

      // CORRECT MOVE (or auto-played opponent move)
      emit(state.copyWith(
        lastCorrectPuzzleMove: move,
        puzzleStreak: currentMove.isOpponentMove
            ? state.puzzleStreak
            : state.puzzleStreak + 1,
      ));
    }

    // Capture pre-move FEN for coach analysis BEFORE making the move
    final fenBeforeMove = _engine.toFEN();

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
      showPromotionDialog: false,
      isAIThinking: false, // Disappear JUST as the move is made
      lastMoveTimestamp: DateTime.now(),
      pendingMove: null, // Clear any pending move UI
      clearHint: true,
      clearCoachMove: true,
      clearCoachMessage: true,
      clearCoachFeedback: true,
    ));

    // Update Evaluation asynchronously to not block the UI
    final isPracticeOrSingle =
        state.mode == GameMode.singlePlayer || state.mode == GameMode.practice || state.mode == GameMode.twoPlayer;
    final isMultiplayer = state.mode == GameMode.multiplayer;
    final isPuzzle = state.mode == GameMode.puzzle;

    if (!state.isGameOver && isPracticeOrSingle) {
      final fenSnapshot = _engine.toFEN();
      final currTurn = _engine.currentTurn;
      AIEngine.evaluatePosition(ChessEngine.fromFEN(fenSnapshot)).then((score) {
        if (!isClosed) {
          final absScore = currTurn == PieceColor.white ? score : -score;
          add(GameUpdateEvalEvent(absScore / 100.0));
        }
      }).catchError((_) {});
    }

    // Sound logic
    final theme = state.boardTheme ?? 'default';
    if (_engine.status == GameStatus.checkmate ||
        _engine.status == GameStatus.draw) {
      AudioService().playSound('game-end', theme);
    } else if (_engine.status == GameStatus.check) {
      AudioService().playSound('check', theme);
    } else if (move.promotion != null) {
      AudioService().playSound('promote', theme);
    } else if (move.isCastle == true) {
      // We might not have isCastle property natively here but we can check if it's capture
      // Actually let's assume move has no isCastle
      AudioService().playSound(
          (captured.$1.length + captured.$2.length) >
                  (state.capturedWhite.length + state.capturedBlack.length)
              ? 'capture'
              : 'move-self',
          theme);
    } else {
      AudioService().playSound(
          (captured.$1.length + captured.$2.length) >
                  (state.capturedWhite.length + state.capturedBlack.length)
              ? 'capture'
              : 'move-self',
          theme);
    }

    // Apply increment to the player who just moved
    if (state.incrementMs > 0 && state.whiteTimeMs > 0) {
      final justMoved = state
          .currentTurn; // currentTurn already flipped, so the OTHER color just moved
      final movedColor =
          justMoved == PieceColor.white ? PieceColor.black : PieceColor.white;
      if (movedColor == PieceColor.white) {
        emit(
            state.copyWith(whiteTimeMs: state.whiteTimeMs + state.incrementMs));
      } else {
        emit(
            state.copyWith(blackTimeMs: state.blackTimeMs + state.incrementMs));
      }
    }

    // 2. AI COACH MOVE ANALYSIS
    // Only analyze if:
    // a) It's a User Move (not Computer move)
    // b) Mode is Practice/SinglePlayer
    // c) Mode is Multiplayer/2-Player AND enabled in settings
    
    final justMovedColor = state.currentTurn == PieceColor.white ? PieceColor.black : PieceColor.white;
    final isHumanMove = (state.playerColor == null) || (justMovedColor == state.playerColor);

    bool shouldAnalyze = isHumanMove;
    if (state.mode == GameMode.multiplayer || state.mode == GameMode.twoPlayer) {
      shouldAnalyze = isHumanMove && state.coachSettings.enableMultiplayerCoaching;
    } else if (state.mode == GameMode.singlePlayer || state.mode == GameMode.practice) {
      shouldAnalyze = isHumanMove;
    } else {
      shouldAnalyze = false;
    }

    if (shouldAnalyze && state.coachSettings.enableRealTimeCoaching) {
      int mistakes = state.mistakes;
      int blunders = state.blunders;
      int bestMoves = state.bestMoves;
      int missedWins = state.missedWins;
      double accuracy = state.accuracy;

      try {
        // Use pre-move FEN captured before engine.makeMove()
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
        final double moveAccuracy =
            (100.0 - (feedback.centipawnLoss / 10.0)).clamp(0.0, 100.0);
        accuracy = (state.accuracy * (moveCountTotal - 1) + moveAccuracy) /
            moveCountTotal;

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
          aiMessage: feedback.message, // SYNC feedback message to AI talk bubble
          showMiniLesson: feedback.classification == MoveClassification.blunder,
          gameCoachHistory: updatedHistory,
          coachMove: coachMove,
          hintedIndices: newHintedIndices,
          clearActiveHint: true,
        ));

        // AUTO-CLEAR COACH FEEDBACK after 8 seconds
        Future.delayed(const Duration(seconds: 8)).then((_) {
          if (!isClosed && state.coachFeedback == feedback) {
            add(GameUpdatePersonalityEvent(
              personality: state.activePersonality ?? AIPersonality.aggressive,
              message: '', 
            ));
            emit(state.copyWith(clearCoachFeedback: true));
          }
        });
      } catch (e) {
        debugPrint('[Coach Analysis Error] $e');
      }
    }

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
          tutorialMessage:
              '🎓 Lesson Complete! ${currentStep.successMessage ?? "Well done!"}',
          status: GameStatus.draw, // Mark as finished
        ));
        _achievementService.evaluateSpecialActions('tutorial');
      } else {
        final nextStep = state.tutorial!.steps[nextIdx];
        if (nextStep.isCompletion) {
          // Next step is completion (info-only, no move needed) — show it and finish
          emit(state.copyWith(
            tutorialStep: nextIdx,
            tutorialMessage: nextStep.text,
            status: GameStatus.draw, // Mark as finished
          ));
          _achievementService.evaluateSpecialActions('tutorial');
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
        // Puzzle solved! Award 50 XP
        emit(state.copyWith(
          showPuzzleCelebration: true,
          status: GameStatus.checkmate,
          tutorialMessage: '🌟 WOW! You solved it like a real grandmaster! 🧠✨',
          totalPuzzleXP: state.totalPuzzleXP + 50,
          xpGained: state.xpGained + 50,
        ));

        // SYNC XP + adaptive puzzle rating TO SERVER
        final user = await _authRepository.getCurrentUser();
        if (user != null) {
          // Increase puzzle rating on success (adaptive difficulty)
          final puzzleRating = user.stats.puzzleRating;
          final diff = (state.puzzle!.rating ?? 1200) - puzzleRating;
          final ratingGain = (diff > 0 ? 30 : 15).clamp(5, 50);
          final newPuzzleRating = puzzleRating + ratingGain;

          await _authRepository.updateXPProgress(
            userId: user.id,
            xpDelta: 50,
            statUpdates: {
              'puzzles_solved': 1,
              'puzzle_rating': newPuzzleRating,
            },
          );
        }

        // In Puzzle Rush, automatically go to the next puzzle
        if (state.isPuzzleRush) {
          await Future.delayed(const Duration(milliseconds: 1500));
          if (isClosed || state.puzzleRushTime <= 0 || !state.isPuzzleRush) {
            return;
          }

          final userForRating = await _authRepository.getCurrentUser();
          final rating = userForRating?.stats.puzzleRating ?? 1200;
          final nextPuzzle = await _puzzleRepository.getAdaptivePuzzle(rating);
          add(GameStartEvent(GameConfig(
            mode: GameMode.puzzle,
            playerColor: nextPuzzle.playerColor ?? 'white',
            puzzle: nextPuzzle,
            isPuzzleRush: true,
          )));
        }
      } else {
        final nextIdx = state.puzzleStep + 1;
        final nextMove = state.puzzle!.moves[nextIdx];

        emit(state.copyWith(
          puzzleStep: nextIdx,
          tutorialMessage: nextMove.dialog,
        ));

        // AUTO-PLAY opponent moves after a brief delay
        if (nextMove.isOpponentMove) {
          await Future.delayed(const Duration(milliseconds: 800));
          if (isClosed || state.isGameOver) return;

          final opponentMove = Move.fromAlgebraic(nextMove.uciMove);
          add(GameMakeMoveEvent(opponentMove.from, opponentMove.to,
              promotion: opponentMove.promotion));
        }
      }
    }

    // Vibrate on check
    if (_engine.status == GameStatus.check) {
      Vibration.vibrate(duration: 200);
    }

    // Trigger AI if needed
    if (!state.isGameOver &&
        (state.mode == GameMode.singlePlayer ||
            state.mode == GameMode.practice) &&
        _engine.currentTurn != state.playerColor) {
      add(GameAIRequestEvent());
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
            final isWin = (state.result == GameResult.whiteWins &&
                    state.playerColor == PieceColor.white) ||
                (state.result == GameResult.blackWins &&
                    state.playerColor == PieceColor.black);

            if (isWin) {
              currentD += 0.5;
            } else if (state.result != GameResult.draw &&
                state.result != GameResult.ongoing) {
              currentD = math.max(1.0, currentD - 0.5);
            }
            await _authRepository.updatePracticeDifficulty(user.id, currentD);
          }
        }

        // Calculate XP Rewards & Update Stats
        int xp = 0;
        int eloChange = 0;
        final mapUpdates = <String, dynamic>{
          'games_played': 1,
        };

        if (state.mode != GameMode.practice) {
          final user = await _authRepository.getCurrentUser();
          if (user != null) {
            final isWin = (state.result == GameResult.whiteWins &&
                    state.playerColor == PieceColor.white) ||
                (state.result == GameResult.blackWins &&
                    state.playerColor == PieceColor.black);
            final isDraw = state.result == GameResult.draw;
            final hasWinner = state.result == GameResult.whiteWins ||
              state.result == GameResult.blackWins;
            final isLoss = !isWin && !isDraw && hasWinner;

            // ── XP & REWARDS CALCULATION (Robust Engine) ──
            int xpDelta = 0;

            if (isWin) {
              // 1. Mode/Difficulty based XP
              if (state.mode == GameMode.singlePlayer) {
                xpDelta += switch (state.aiDifficulty) {
                  AIDifficulty.basic => 100,
                  AIDifficulty.intermediate => 250,
                  AIDifficulty.advanced => 400,
                  AIDifficulty.impossible => 700,
                  AIDifficulty.aiMode => 1000,
                  _ => 100,
                };
              } else if (state.mode == GameMode.multiplayer) {
                xpDelta += 150; // Higher base for multiplayer
              } else if (state.mode == GameMode.practice) {
                xpDelta += 50;
              }

              // 2. Global Bonuses
              // Mate in 5 moves (10 half-moves)
              if (state.status == GameStatus.checkmate &&
                  state.moveHistory.length <= 10) {
                xpDelta += 500;
              }

              // Perfect Game (No pieces lost)
              final myCaptured = state.playerColor == PieceColor.black
                  ? state.capturedBlack
                  : state.capturedWhite;
              if (myCaptured.isEmpty && state.moveHistory.length > 10) {
                xpDelta += 1000;
              }

              // Underdog Bonus (Tiered)
              final playerElo = user.stats.eloRating;
              int? opponentElo;
              if (state.mode == GameMode.singlePlayer) {
                opponentElo = switch (state.aiDifficulty) {
                  AIDifficulty.basic => 600,
                  AIDifficulty.intermediate => 1200,
                  AIDifficulty.advanced => 1800,
                  AIDifficulty.impossible => 2400,
                  AIDifficulty.aiMode => 2800,
                  _ => 600,
                };
              } else if (state.mode == GameMode.multiplayer) {
                opponentElo = playerElo; // Simplified for now, or fetch from state if available
              }

              if (opponentElo != null) {
                final diff = opponentElo - playerElo;
                if (diff >= 1000) {
                  xpDelta += 1000;
                } else if (diff >= 500) {
                  xpDelta += 500;
                } else if (diff >= 200) {
                  xpDelta += 200;
                }
              }

              // 4. Bounty Bonus (50% Extra XP)
              if (state.mode == GameMode.multiplayer &&
                  state.opponentName == _missionService.bountyUserId) {
                // Assuming opponentName is the ID for ID matching, or fetching opponent info
                // We'll treat opponentId as a separate field if needed, but for now we'll match on bountyUserId
                xpDelta = (xpDelta * 1.5).round();
                mapUpdates['bounty_claimed'] = true; 
              }

              // 5. Streak Multiplier (10% per streak point, max 2.0x)
              double streakMultiplier =
                  1.0 + (user.stats.currentStreak * 0.1).clamp(0.0, 1.0);

              // Enhanced AI Streak Multiplier (+10% per streak point in AI mode, max 10 wins total 2.0x)
              // Since the base already covers 10% per point, we just ensure it stays consistent
              // Or if the base was different, we'd adjust here. 
              // The user specified +10% per win, which matches the base (1.0 + streak * 0.1).
              
              xpDelta = (xpDelta * streakMultiplier).round();

              mapUpdates['wins'] = 1;
              if (state.mode == GameMode.singlePlayer) mapUpdates['ai_wins'] = 1;
              if (state.mode == GameMode.multiplayer) mapUpdates['multiplayer_wins'] = 1;
            } else if (isLoss) {
              xpDelta = -20;
              mapUpdates['losses'] = 1;
            } else if (isDraw) {
              xpDelta = 10;
              mapUpdates['draws'] = 1;
            }

            // Sync XP
            final totalDelta = xpDelta + state.xpGained;

            await _authRepository.updateXPProgress(
              userId: user.id,
              xpDelta: totalDelta,
              statUpdates: mapUpdates,
              isOnlineMatch: state.mode == GameMode.multiplayer,
            );

            // ── RATING (ELO) CALCULATION ──
            // ONLY for online matches (Multiplayer)
            if (state.mode == GameMode.multiplayer) {
              final currentElo = user.stats.eloRating;
              final playerGames = user.stats.multiplayerGames;
              double score = isDraw ? 0.5 : (isWin ? 1.0 : 0.0);

              // Multiplayer: assume opponent exists in state or similar rating
              final opponentElo = currentElo; // Default fallback
              
              final result = EloService.calculateNewRatings(
                player1Rating: currentElo,
                player2Rating: opponentElo,
                score: score,
                player1Games: playerGames,
                player2Games: 30, // Opponent assumed established
              );
              
              final newElo = result.$1;
              eloChange = (newElo - currentElo).toInt();

              // Persist ELO
              await _authRepository.updateXPProgress(
                userId: user.id,
                xpDelta: 0,
                statUpdates: {'elo_rating': newElo},
                isOnlineMatch: true,
              );
            }
          }
        }

        final updatedUser = await _authRepository.getCurrentUser();
        if (updatedUser != null) {
          final isWin = (state.result == GameResult.whiteWins &&
                  state.playerColor == PieceColor.white) ||
              (state.result == GameResult.blackWins &&
                  state.playerColor == PieceColor.black);

          _achievementService.evaluatePostGame(state, updatedUser.stats);
          
          // Trigger Mission updates
          _missionService.updateProgress('daily_games');
          if (state.mode == GameMode.multiplayer && isWin) {
            _missionService.updateProgress('online_win');
          }
          if (isWin) {
            _missionService.updateProgress('streak_hunter', 
              delta: updatedUser.stats.currentStreak >= 3 ? 3 : 0); // Simplified for now
          }
        }

        // Generate Encouraging Message & Engine Suggestion
        String msg = '';
        if (state.accuracy >= 80) {
          msg = '🚀 Incredible! Your precision was professional level.';
          if (state.aiDifficulty != AIDifficulty.impossible &&
              state.aiDifficulty != AIDifficulty.aiMode) {
            msg += '\nReady to try the next level?';
          }
        } else if (state.accuracy >= 60) {
          msg = '🔥 Solid game! You had some great highlights.';
        } else {
          msg = '💎 Good effort! Keep practicing to master the patterns.';
        }

        emit(state.copyWith(
          xpGained: xp + state.xpGained,
          analysisMessage: msg,
          eloChange: eloChange,
        ));

        final game = GameModel(
          id: _gameId ?? '',
          fen: state.currentFEN,
          pgn: _engine.toPGN(),
          mode: state.mode.name,
          status: state.status.name,
          result: state.result.name,
          moveCount: state.moveHistory.length,
          playerColor:
              state.playerColor == PieceColor.black ? 'black' : 'white',
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

    // ── HUMANOID AI: BACKGROUND PLAYER ANALYSIS (AI MODE ONLY) ──
    if (!state.isGameOver &&
        state.mode == GameMode.singlePlayer &&
        state.aiDifficulty == AIDifficulty.aiMode &&
        _engine.currentTurn != state.playerColor) {
      final fenBefore = fenBeforeMove; // Captured at start of _onMakeMove
      final lastMove = move.toAlgebraic();

      // Asynchronous analysis using the unified bridge (via controller)
      _engineController
          .analyzeMoveBackground(fenBefore, nodes: 1000)
          .then((res) {
        if (res == null) return;
        final bestUci = res['move'] as String?;
        final bestScore = res['score'] as int? ?? 0;
        if (bestUci == null) return;

        // BLUNDER DETECTION LOGIC
        // We compare what the user played vs what the engine thinks was best.
        // A "Blunder" is roughly a 300 centipawn drop in the player's favor.
        
        String response = "Nice move! But check this out... ⚡";
        
        // Find if user move was among candidates to get its score
        final candidates = res['candidates'] as List<dynamic>? ?? [];
        final userMoveObj = candidates.firstWhere(
          (c) => c['uci'] == lastMove,
          orElse: () => null,
        );

        if (userMoveObj != null) {
          final userScore = userMoveObj['score'] as int? ?? 0;
          final delta = bestScore - userScore; // Loss of advantage

          if (delta > 300) {
            response = "Oh no! That was a big blunder! 😲💨";
            PersonalityEngine().forcePersonality(AIPersonality.tricky);
          } else if (delta > 100) {
            response = "Hmm, I think you missed something better. 🤔";
          } else if (delta < -50) {
            response = "Wow! You're playing like a grandmaster! 🌟";
            PersonalityEngine().forcePersonality(AIPersonality.defensive);
          } else {
             // Standard response or personality switch
             if (math.Random().nextDouble() > 0.7) {
                response = PersonalityEngine().currentPersonality.getRandomMessage(null);
             }
          }
        } else {
          // If move not in candidates, it's likely suboptimal or a blunder
          if (bestScore > 400) {
            response = "I'm coming for your King! That was a gamble! 😈🔥";
          }
        }

        if (!isClosed) {
          add(GameUpdatePersonalityEvent(
            personality: PersonalityEngine().currentPersonality,
            message: response,
          ));
        }
      }).catchError((_) {});
    }

    // After everything, check if we have a pending preMove and it's now our turn
    if (state.preMove != null && _engine.currentTurn == state.playerColor) {
      final pre = state.preMove!;
      emit(state.copyWith(clearPreMove: true)); // Clear it to avoid looping

      final legals = _engine.legalMovesFrom(pre.from);
      final legit = legals.where((m) => m.to == pre.to).firstOrNull;
      if (legit != null) {
        add(GameMakeMoveEvent(legit.from, legit.to,
            promotion:
                legit.promotion ?? (state.autoQueen ? PieceType.queen : null)));
      }
    }
  }

  Future<void> _onUndo(GameUndoEvent event, Emitter<GameState> emit) async {
    // 5-Second Rule Enforcement — only for Multiplayer (Online) to prevent frustration
    if (state.mode == GameMode.multiplayer && state.lastMoveTimestamp != null) {
      final elapsed = DateTime.now().difference(state.lastMoveTimestamp!);
      if (elapsed.inSeconds >= 5) {
        emit(state.copyWith(
          tutorialMessage: "⚠️ Thinking time passed! Cannot take back moves after 5 seconds.",
        ));
        return;
      }
    }

    if (state.mode == GameMode.multiplayer ||
        state.mode == GameMode.twoPlayer) {
      if (state.mode == GameMode.multiplayer && state.mpUndosUsed >= 2) return;
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
      _achievementService.evaluateSpecialActions('undo');
      return;
    }

    // Undo 2 moves if vs AI (Take back player's move + AI's response)
    final isVsAI = state.mode == GameMode.singlePlayer || state.mode == GameMode.practice;
    if (!isVsAI) return;

    if (_engine.moveHistory.isEmpty) return;

    // Get the square of the last move to show the penalty bubble there
    final lastMove = _engine.moveHistory.last;
    final penaltySquare = lastMove.to;

    if (state.mode == GameMode.singlePlayer) {
      // Cost 25 XP for single player modes
      final newXpDelta = state.xpGained - 25;
      emit(state.copyWith(
        xpGained: newXpDelta,
        tutorialMessage: "⏪ Take back applied! (-25 XP)",
        lastUndoPenaltySquare: penaltySquare,
      ));

      // Sync XP reduction
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        await _authRepository.updateXPProgress(
          userId: user.id,
          xpDelta: -25,
          statUpdates: {},
        );
      }
    } else {
      // Practice Mode: Free undo
      emit(state.copyWith(
        tutorialMessage: "⏪ Take back applied!",
        lastUndoPenaltySquare: penaltySquare,
      ));
    }

    final undoCount = 2; // Always 2 vs AI
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

    // Reset the penalty square after a brief delay so the bubble can animate
    await Future.delayed(const Duration(seconds: 2));
    if (!isClosed) {
      emit(state.copyWith(clearUndoPenalty: true));
    }

    _achievementService.evaluateSpecialActions('undo');
  }

  void _onResign(GameResignEvent event, Emitter<GameState> emit) {
    // Explicitly cancel any in-flight AI result.
    _aiRequestEpoch++;
    emit(state.copyWith(
      result: state.currentTurn == PieceColor.white
          ? GameResult.blackWins
          : GameResult.whiteWins,
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

  Future<void> _onRequestHint(
      GameRequestHintEvent event, Emitter<GameState> emit) async {
    // Puzzle Hint Logic — costs flat 10 XP (puzzle hint is from predefined data)
    if (state.mode == GameMode.puzzle && state.puzzle != null) {
      final currentMove = state.puzzle!.moves[state.puzzleStep];
      if (currentMove.isOpponentMove) return;

      final newXp = state.xpGained - 10;
      emit(state.copyWith(
        tutorialMessage: "💡 Psst! Here's a little hint: ${currentMove.hint}",
        isPuzzleHintUsed: true,
        xpGained: newXp,
      ));

      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        await _authRepository.updateXPProgress(
          userId: user.id,
          xpDelta: -10,
          statUpdates: {},
        );
      }
      return;
    }

    final isLocalMode = state.mode == GameMode.practice || state.mode == GameMode.twoPlayer;
    if (!isLocalMode && state.hintsRemaining <= 0) return;
    // Allow hints in local modes regardless of 'player side'
    if (!isLocalMode && !state.isPlayerTurn) return;

    // ── UPGRADE: If hint already showing, bump to next level ─────────────────
    if (state.activeHint != null) {
      final hint = state.activeHint!;
      if (!hint.canUpgrade) return; // Already at level 3, nothing more to reveal

      final nextLevel = hint.currentLevel + 1;
      final xpCost = hint.nextLevelXpCost; // Per-level cost (10 or 20 XP)

      // Deduct XP for this upgrade
      final newXp = state.xpGained - xpCost;
      final upgradedHint = hint.copyWith(currentLevel: nextLevel);

      // At level 3, highlight the actual move on the board
      Move? hintMove;
      if (nextLevel >= 3) {
        hintMove = Move.fromAlgebraic(upgradedHint.bestMoveAlgebraic);
      }

      emit(state.copyWith(
        activeHint: upgradedHint,
        hintMove: hintMove,
        xpGained: newXp,
      ));

      // Sync XP deduction to server
      if (state.mode != GameMode.practice) {
        final user = await _authRepository.getCurrentUser();
        if (user != null) {
          await _authRepository.updateXPProgress(
            userId: user.id,
            xpDelta: -xpCost,
            statUpdates: {},
          );
        }
      }
      return;
    }

    // ── INITIAL HINT REQUEST (Level 1 — costs 5 XP) ────────────────────────
    final aiRequestEpoch = ++_aiRequestEpoch;
    emit(state.copyWith(isAIThinking: true));

    final hintResult = await _coachController.getHint(_engine);

    if (isClosed || aiRequestEpoch != _aiRequestEpoch) return;
    emit(state.copyWith(isAIThinking: false));

    if (hintResult != null) {
      final isPractice = state.mode == GameMode.practice;
      final xpCost = isPractice ? 0 : hintResult.xpCostLevel1; // 5 XP for L1

      emit(state.copyWith(
        activeHint: hintResult,
        hintsUsed: state.hintsUsed + 1,
        xpGained: state.xpGained - xpCost,
      ));

      // Sync XP to server
      if (!isPractice && xpCost > 0) {
        final user = await _authRepository.getCurrentUser();
        if (user != null) {
          await _authRepository.updateXPProgress(
            userId: user.id,
            xpDelta: -xpCost,
            statUpdates: {},
          );
        }
      }
    }
  }


  void _onDismissMiniLesson(
      GameDismissMiniLessonEvent event, Emitter<GameState> emit) {
    emit(state.copyWith(showMiniLesson: false));
  }

  /// Give up puzzle — reveal solution with child-friendly message
  Future<void> _onPuzzleGiveUp(
      GamePuzzleGiveUpEvent event, Emitter<GameState> emit) async {
    if (state.mode != GameMode.puzzle || state.puzzle == null) return;
    if (state.isGameOver) return;

    // Build the solution explanation
    final puzzle = state.puzzle!;
    final remainingMoves = puzzle.moves
        .sublist(state.puzzleStep)
        .where((m) => !m.isOpponentMove)
        .toList();

    // Generate child-friendly give-up messages
    final giveUpMessages = [
      "Aww, don't worry! 🤗 Even grandmasters get stuck sometimes!",
      "Hey, that's okay! 🌈 Let me show you the secret moves!",
      "No worries champ! 🦁 This was a tricky one! Let's learn together!",
      "Oopsie daisy! 🌻 But guess what? Now you'll know this trick forever!",
      "It's okay to ask for help! 🎈 Smart players learn from solutions!",
    ];
    final randomMsg =
        giveUpMessages[DateTime.now().millisecond % giveUpMessages.length];

    // Build solution text
    final solutionSteps = <String>[];
    for (int i = 0; i < remainingMoves.length; i++) {
      solutionSteps.add('${i + 1}. ${remainingMoves[i].uciMove}');
    }

    final solutionText = solutionSteps.join(' → ');

    // Child-friendly explanation of the solution
    final explanations = [
      "If you had just played $solutionText... it was sooo simple! 😄",
      "See? The trick was $solutionText! Easy peasy lemon squeezy! 🍋",
      "All you needed was $solutionText! Now you know the magic trick! ✨",
      "The answer was $solutionText! Next time you'll spot it right away! 🔍",
      "Just $solutionText and BOOM! 💥 You would've won! Remember this pattern!",
    ];
    final explanation =
        explanations[DateTime.now().millisecond % explanations.length];

    emit(state.copyWith(
      status: GameStatus.draw,
      tutorialMessage: '$randomMsg\n\n🧩 Solution: $explanation',
      showPuzzleCelebration: false,
      puzzleGaveUp: true,
    ));

    // Decrease puzzle rating on failure (adaptive difficulty)
    final user = await _authRepository.getCurrentUser();
    if (user != null) {
      final puzzleRating = user.stats.puzzleRating;
      final diff = puzzleRating - (puzzle.rating ?? 1200);
      final ratingLoss = (diff > 0 ? 25 : 10).clamp(5, 40);
      final newPuzzleRating = (puzzleRating - ratingLoss).clamp(400, 3000);

      await _authRepository.updateXPProgress(
        userId: user.id,
        xpDelta: 0,
        statUpdates: {
          'puzzle_rating': newPuzzleRating,
        },
      );
    }
  }

  /// Load next adaptive puzzle
  Future<void> _onPuzzleNext(
      GamePuzzleNextEvent event, Emitter<GameState> emit) async {
    final user = await _authRepository.getCurrentUser();
    final rating = user?.stats.puzzleRating ?? 1200;
    final nextPuzzle = await _puzzleRepository.getAdaptivePuzzle(rating);

    add(GameStartEvent(GameConfig(
      mode: GameMode.puzzle,
      playerColor: nextPuzzle.playerColor ?? 'white',
      puzzle: nextPuzzle,
    )));
  }

  @override
  Future<void> close() {
    _engineController.dispose();
    _coachController.dispose();
    _clockTimer?.cancel();
    _rushTimer?.cancel();
    return super.close();
  }

  void _startClock() {
    _clockTimer?.cancel();
    _lastClockTickTime = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!isClosed) add(GameClockTickEvent());
    });
  }

  void _stopClock() {
    _clockTimer?.cancel();
    _clockTimer = null;
  }

  void _onClockTick(GameClockTickEvent event, Emitter<GameState> emit) {
    if (state.isGameOver || !state.clockRunning) return;
    if (state.whiteTimeMs <= 0 && state.blackTimeMs <= 0) return;

    final now = DateTime.now();
    final elapsedMs =
        now.difference(_lastClockTickTime ?? now).inMilliseconds.toDouble();
    _lastClockTickTime = now;

    double white = state.whiteTimeMs;
    double black = state.blackTimeMs;

    if (state.currentTurn == PieceColor.white) {
      white = (white - elapsedMs).clamp(0, double.infinity);
    } else {
      black = (black - elapsedMs).clamp(0, double.infinity);
    }

    // Check for timeout
    if (white <= 0) {
      _stopClock();
      emit(state.copyWith(
        whiteTimeMs: 0,
        blackTimeMs: black,
        clockRunning: false,
        status: GameStatus.checkmate,
        result: GameResult.blackWins,
      ));
      return;
    }
    if (black <= 0) {
      _stopClock();
      emit(state.copyWith(
        whiteTimeMs: white,
        blackTimeMs: 0,
        clockRunning: false,
        status: GameStatus.checkmate,
        result: GameResult.whiteWins,
      ));
      return;
    }

    emit(state.copyWith(
        whiteTimeMs: white, blackTimeMs: black, clockRunning: true));
  }

  void _onPromotionRequired(
      GamePromotionRequiredEvent event, Emitter<GameState> emit) {
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
      PieceType.pawn: 8,
      PieceType.rook: 2,
      PieceType.knight: 2,
      PieceType.bishop: 2,
      PieceType.queen: 1,
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
      capturedWhite.addAll(List.generate(
          wCount, (_) => ChessPiece(type: entry.key, color: PieceColor.white)));
      capturedBlack.addAll(List.generate(
          bCount, (_) => ChessPiece(type: entry.key, color: PieceColor.black)));
    }

    return (capturedWhite, capturedBlack);
  }

  void _onUpdateEval(GameUpdateEvalEvent event, Emitter<GameState> emit) {
    final updatedHistory = [...state.evalHistory, event.evalScore];
    emit(state.copyWith(
        evalScore: event.evalScore, evalHistory: updatedHistory));
  }

  /// Centralized AI move generation logic now correctly handled as a Bloc event.
  Future<void> _onAIRequest(
      GameAIRequestEvent event, Emitter<GameState> emit) async {
    if (state.isGameOver) return;

    final aiRequestEpoch = ++_aiRequestEpoch;
    emit(state.copyWith(
        isAIThinking: true,
        aiMessage: _engineController.aiMessage, // Set initial thinking message
    ));

    // UI Delay for "human feel"
    await Future.delayed(const Duration(milliseconds: 400));
    if (isClosed || aiRequestEpoch != _aiRequestEpoch) return;

    try {
      final moveStr = await _engineController.getBestMove(
        _engine.toFEN(),
        engine: _engine,
        moveNumber: state.moveHistory.length,
      );

      if (isClosed || aiRequestEpoch != _aiRequestEpoch) return;

      final isPlayable = _engine.status == GameStatus.active ||
          _engine.status == GameStatus.check;
      if (moveStr != null && !state.isGameOver && isPlayable) {
        // Clear AI specific message after move is decided
        _engineController.clearThinkingMessage();
        emit(state.copyWith(clearTutorialMessage: true));

        final aiMove = Move.fromAlgebraic(moveStr);
        add(GameMakeMoveEvent(aiMove.from, aiMove.to,
            promotion: aiMove.promotion));
      } else if (!state.isGameOver && isPlayable) {
        // FAILSAFE: Try fallback first
        final fallback = await _engineController.fallbackMove(_engine.toFEN(),
            engine: _engine);
        if (fallback != null) {
          final fm = Move.fromAlgebraic(fallback);
          add(GameMakeMoveEvent(fm.from, fm.to, promotion: fm.promotion));
        } else {
          // TOTAL FAILURE: Popup Error Message
          emit(state.copyWith(
            isAIThinking: false,
            engineError:
                "Ooops! I'm having a little trouble thinking right now. 😵‍💫 My engine stalled, please reload the game!",
          ));
        }
      }
    } catch (e) {
      debugPrint('[AI Execution Error] $e');
      if (!isClosed) {
        emit(state.copyWith(
          isAIThinking: false,
          engineError:
              "Sorry! Something went wrong behind the scenes. 🤯 I can't think anymore!",
        ));
      }
    }
  }
}
