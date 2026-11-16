import 'package:chess_master/domain/engine/chess_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void play(ChessEngine engine, List<String> moves) {
  for (final move in moves) {
    expect(engine.makeMove(Move.fromAlgebraic(move)), isTrue, reason: move);
  }
}

void main() {
  test('undoing checkmate restores a live result and a playable board', () {
    final engine = ChessEngine();
    play(engine, ['f2f3', 'e7e5', 'g2g4', 'd8h4']);
    expect(engine.status, GameStatus.checkmate);
    expect(engine.result, GameResult.blackWins);
    expect(engine.undoMove(), isTrue);
    expect(engine.status, GameStatus.active);
    expect(engine.result, GameResult.ongoing);
    expect(engine.drawReason, isNull);
    expect(engine.allLegalMoves(), isNotEmpty);
    expect(engine.makeMove(Move.fromAlgebraic('g8f6')), isTrue);
    expect(engine.result, GameResult.ongoing);
  });

  test('undoing a repetition draw clears its result and reason', () {
    final engine = ChessEngine();
    play(engine,
        ['g1f3', 'g8f6', 'f3g1', 'f6g8', 'g1f3', 'g8f6', 'f3g1', 'f6g8']);
    expect(engine.status, GameStatus.draw);
    expect(engine.drawReason, DrawReason.threefoldRepetition);
    expect(engine.undoMove(), isTrue);
    expect(engine.status, GameStatus.active);
    expect(engine.result, GameResult.ongoing);
    expect(engine.drawReason, isNull);
  });

  test(
      'imported checkmate, stalemate and dead positions expose terminal status',
      () {
    final mate = ChessEngine.fromFEN(
        'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3');
    expect(mate.status, GameStatus.checkmate);
    expect(mate.result, GameResult.blackWins);
    expect(mate.allLegalMoves(), isEmpty);
    final stalemate = ChessEngine.fromFEN('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
    expect(stalemate.status, GameStatus.stalemate);
    expect(stalemate.result, GameResult.draw);
    expect(stalemate.drawReason, DrawReason.stalemate);
    final dead = ChessEngine.fromFEN('7k/8/8/8/8/8/8/K7 w - - 0 1');
    expect(dead.status, GameStatus.draw);
    expect(dead.result, GameResult.draw);
    expect(dead.drawReason, DrawReason.insufficientMaterial);
    final live = ChessEngine.fromFEN(ChessEngine().toFEN());
    expect(live.status, GameStatus.active);
    expect(live.result, GameResult.ongoing);
    expect(live.drawReason, isNull);
  });

  test(
      'capturing a corner rook removes its right and cannot create a phantom rook',
      () {
    final engine = ChessEngine.fromFEN('4k3/8/8/8/8/8/P5b1/4K2R b K - 0 1');
    play(engine, ['g2h1', 'a2a3', 'h1f3']);
    expect(engine.toFEN().split(' ')[2], '-');
    final before = engine.toFEN();
    expect(
        engine
            .legalMovesFrom(Square.fromString('e1'))
            .any((move) => move.toAlgebraic() == 'e1g1'),
        isFalse);
    expect(engine.makeMove(Move.fromAlgebraic('e1g1')), isFalse);
    expect(engine.toFEN(), before);
    expect(engine.pieceAt(Square.fromString('f1')), isNull);
  });

  test('all four captured corner-rook rights clear and return after undo', () {
    for (final entry in [
      ('4k3/8/8/8/8/8/1b6/R3K3 b Q - 0 1', 'b2a1', 'Q'),
      ('4k3/8/8/8/8/8/6b1/4K2R b K - 0 1', 'g2h1', 'K'),
      ('r3k3/1B6/8/8/8/8/8/4K3 w q - 0 1', 'b7a8', 'q'),
      ('4k2r/6B1/8/8/8/8/8/4K3 w k - 0 1', 'g7h8', 'k'),
    ]) {
      final engine = ChessEngine.fromFEN(entry.$1);
      expect(engine.makeMove(Move.fromAlgebraic(entry.$2)), isTrue);
      expect(engine.toFEN().split(' ')[2], '-');
      expect(engine.undoMove(), isTrue);
      expect(engine.toFEN().split(' ')[2], entry.$3);
    }
  });

  test('stale FEN rights cannot castle with a missing or enemy rook', () {
    for (final fen in [
      '4k3/8/8/8/8/8/8/4K3 w KQ - 0 1',
      '4k3/8/8/8/8/8/8/b3K2b w KQ - 0 1',
      '4k3/8/8/8/8/8/8/4K2N w K - 0 1',
      '4k3/8/8/8/8/8/8/4K2r w K - 0 1',
    ]) {
      final engine = ChessEngine.fromFEN(fen);
      expect(
          engine
              .legalMovesFrom(Square.fromString('e1'))
              .where((move) => move.isCastle),
          isEmpty,
          reason: fen);
    }
  });

  test('legal castling still works on both wings and survives undo', () {
    for (final destination in ['g1', 'c1']) {
      final engine =
          ChessEngine.fromFEN('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      final before = engine.toFEN();
      expect(engine.makeMove(Move.fromAlgebraic('e1$destination')), isTrue);
      expect(
          engine.pieceAt(Square.fromString(destination))?.type, PieceType.king);
      expect(
          engine
              .pieceAt(Square.fromString(destination == 'g1' ? 'f1' : 'd1'))
              ?.type,
          PieceType.rook);
      expect(engine.undoMove(), isTrue);
      expect(engine.toFEN(), before);
      expect(engine.makeMove(Move.fromAlgebraic('e1$destination')), isTrue);
    }
  });
}
