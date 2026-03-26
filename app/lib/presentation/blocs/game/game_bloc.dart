import 'dart:async';
import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibration/vibration.dart';
import '../../../domain/engine/chess_engine.dart';
import '../../../domain/engine/ai_engine.dart';
import '../../../domain/engine/engine_controller.dart';
import '../../../data/repositories/game_repository.dart';
import '../../../data/models/game_model.dart';
import '../../../data/models/game_config.dart';
import '../../../data/models/tutorial_model.dart';
import '../../../data/models/puzzle_model.dart';

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

class GameSelectPieceEvent extends GameEvent {
  final Square square;
  const GameSelectPieceEvent(this.square);
  @override List<Object?> get props => [square];
}

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

class GamePromotionRequiredEvent extends GameEvent {
  final Square from;
  final Square to;
  const GamePromotionRequiredEvent(this.from, this.to);
  @override List<Object?> get props => [from, to];
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
  final String pieceTheme;
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
    this.pieceTheme = 'classic3d',
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
  });

  bool get isGameOver => status == GameStatus.checkmate ||
      status == GameStatus.stalemate || status == GameStatus.draw;

  bool get isPlayerTurn =>
      playerColor == null || currentTurn == playerColor;

  int get hintsRemaining => maxHints - hintsUsed;

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
    String? pieceTheme,
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
    bool clearSelected = false,
    bool clearHint = false,
    bool clearDrawOffer = false,
    bool clearTutorialMessage = false,
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
      pieceTheme: pieceTheme ?? this.pieceTheme,
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
    );
  }

  @override
  List<Object?> get props => [
    board, currentTurn, selectedSquare, legalMoves, moveHistory,
    status, result, isAIThinking, hintMove, hintsUsed, currentFEN,
    showPromotionDialog, tutorial, tutorialStep, tutorialMessage, pieceTheme,
    puzzle, puzzleStep, isPuzzleHintUsed,
  ];
}

// ═══════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════
class GameBloc extends Bloc<GameEvent, GameState> {
  late ChessEngine _engine;
  final EngineController _engineController = EngineController();
  final GameRepository _gameRepository;
  String? _gameId;
  int _aiRequestEpoch = 0;

  ChessEngine get engine => _engine;
  EngineController get engineController => _engineController;

  GameBloc(this._gameRepository) : super(GameState(
    board: List.generate(8, (_) => List.filled(8, null)),
    currentTurn: PieceColor.white,
  )) {
    on<GameStartEvent>(_onStart);
    on<GameSelectPieceEvent>(_onSelectPiece);
    on<GameMakeMoveEvent>(_onMakeMove);
    on<GameUndoEvent>(_onUndo);
    on<GameResignEvent>(_onResign);
    on<GameDrawOfferEvent>(_onDrawOffer);
    on<GameDrawAcceptEvent>(_onDrawAccept);
    on<GameDrawDeclineEvent>(_onDrawDecline);
    on<GameSaveEvent>(_onSave);
    on<GameRequestHintEvent>(_onRequestHint);
    on<GamePromotionRequiredEvent>(_onPromotionRequired);
  }

  void _onStart(GameStartEvent event, Emitter<GameState> emit) {
    // Invalidate any pending AI response from a previous game lifecycle.
    _aiRequestEpoch++;
    _engine = ChessEngine.fromFEN(event.config.puzzle?.initialFEN ?? event.tutorial?.initialFEN ?? 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    final config = event.config;

    _engineController.init(config.mode, config.difficulty);

    final playerColor = config.playerColor == 'black'
        ? PieceColor.black : PieceColor.white;

    emit(GameState(
      board: _engine.board,
      currentTurn: _engine.currentTurn,
      playerColor: config.mode == GameMode.singlePlayer ? playerColor : null,
      mode: config.mode,
      aiDifficulty: config.difficulty,
      boardTheme: config.boardTheme ?? 'classic',
      pieceTheme: _normalizePieceTheme(config.pieceTheme),
      whitePieceColor: config.whitePieceColor ?? Colors.white,
      blackPieceColor: config.blackPieceColor ?? Colors.black,
      currentFEN: _engine.toFEN(),
      tutorial: event.tutorial,
      tutorialMessage: config.puzzle?.moves.first.dialog ?? event.tutorial?.steps.first.text,
      puzzle: config.puzzle,
    ));

    // If AI plays first (player chose black)
    if (config.mode == GameMode.singlePlayer && playerColor == PieceColor.black) {
      add(GameMakeMoveEvent(Square(0, 0), Square(0, 0)));
    }
  }

  void _onSelectPiece(GameSelectPieceEvent event, Emitter<GameState> emit) {
    final sq = event.square;

    // Deselect if clicking same square
    if (state.selectedSquare == sq) {
      emit(state.copyWith(clearSelected: true, clearHint: true));
      return;
    }

    // If a piece is already selected, try to make a move
    if (state.selectedSquare != null) {
      final isLegal = state.legalMoves.any((m) => m.to == sq);
      if (isLegal) {
        // Check if pawn promotion needed
        final from = state.selectedSquare!;
        final piece = _engine.pieceAt(from);
        if (piece?.type == PieceType.pawn) {
          final toRank = sq.rank;
          if ((piece!.color == PieceColor.white && toRank == 7) ||
              (piece.color == PieceColor.black && toRank == 0)) {
            emit(state.copyWith(
              showPromotionDialog: true,
              promotionFrom: from,
              promotionTo: sq,
            ));
            return;
          }
        }
        add(GameMakeMoveEvent(from, sq));
        return;
      }
    }

    // Select new piece
    final piece = _engine.pieceAt(sq);
    if (piece == null || piece.color != _engine.currentTurn) {
      emit(state.copyWith(clearSelected: true));
      return;
    }
    if (!state.isPlayerTurn) return;

    final moves = _engine.legalMovesFrom(sq);
    emit(state.copyWith(
      selectedSquare: sq,
      legalMoves: moves,
      clearHint: true,
    ));
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

    // Puzzle check — wrong moves show error but keep the challenge text
    if (state.mode == GameMode.puzzle && state.puzzle != null) {
      final currentMove = state.puzzle!.moves[state.puzzleStep];
      if (move.toAlgebraic() != currentMove.move) {
        emit(state.copyWith(
          tutorialMessage: '❌ Not the right move. Think again!\n\n${currentMove.dialog}',
          clearSelected: true,
        ));
        return;
      }
    }

    final success = _engine.makeMove(move);
    if (!success && !(event.from == event.to)) return; // Invalid move

    final captured = _collectCaptured();

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
    ));

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
      final currentMove = state.puzzle!.moves[state.puzzleStep];
      final isLastMove = state.puzzleStep == state.puzzle!.moves.length - 1;

      if (isLastMove) {
        emit(state.copyWith(
          tutorialMessage: currentMove.successDialog,
          status: GameStatus.checkmate, // Mark as win
        ));
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
        state.mode == GameMode.singlePlayer &&
        _engine.currentTurn != state.playerColor) {
      final aiRequestEpoch = ++_aiRequestEpoch;
      emit(state.copyWith(isAIThinking: true));
      await Future.delayed(const Duration(milliseconds: 400));

      // Use the hybrid EngineController instead of AIDirectly
      final moveStr = await _engineController.getBestMove(_engine.toFEN(), engine: _engine);
      
      if (isClosed || aiRequestEpoch != _aiRequestEpoch) return;
      emit(this.state.copyWith(isAIThinking: false));

      if (moveStr != null && !this.state.isGameOver && _engine.status == GameStatus.active) {
        final aiMove = Move.fromAlgebraic(moveStr);
        add(GameMakeMoveEvent(aiMove.from, aiMove.to, promotion: aiMove.promotion));
      }
    }

    // Auto-save
    if (_gameId != null) add(GameSaveEvent());
  }

  void _onUndo(GameUndoEvent event, Emitter<GameState> emit) {
    if (state.mode == GameMode.multiplayer) return;
    // Undo 2 moves if vs AI (take back player's move + AI's response)
    final undoCount = state.mode == GameMode.singlePlayer ? 2 : 1;
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
    if (state.mode != GameMode.singlePlayer) return;
    if (!state.isPlayerTurn) return;

    final aiRequestEpoch = ++_aiRequestEpoch;
    emit(state.copyWith(isAIThinking: true));
    
    // Hints use the unified engine controller
    final moveStr = await _engineController.getBestMove(
      _engine.toFEN(), 
      engine: _engine,
    );

    if (isClosed || aiRequestEpoch != _aiRequestEpoch) return;
    emit(state.copyWith(isAIThinking: false));

    if (moveStr != null) {
      final hintMove = Move.fromAlgebraic(moveStr);
      emit(state.copyWith(
        hintMove: hintMove,
        hintsUsed: state.hintsUsed + 1,
      ));
    }
  }

  @override
  Future<void> close() {
    _engineController.dispose();
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

  String _normalizePieceTheme(String? theme) {
    if (theme == null || theme.isEmpty) return 'classic3d';
    if (theme == 'classic') return 'classic3d';
    return theme;
  }
}
