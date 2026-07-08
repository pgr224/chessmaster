import 'package:chess_master/domain/engine/adaptive_ai_profile.dart';
import 'package:chess_master/domain/engine/candidate_model.dart';
import 'package:chess_master/domain/engine/chess_engine.dart';
import 'package:chess_master/domain/engine/personality_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('records opening signatures and mirrors them for the opposite color',
      () {
    final engine = ChessEngine.fromFEN(
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    );

    expect(engine.makeMove(Move.fromAlgebraic('e2e4')), isTrue);

    final profile = AdaptiveAIProfile.initial().observeMove(
      move: engine.moveHistory.last,
      engineAfterMove: engine,
      playerColor: PieceColor.white,
      moveNumber: 1,
      moveAccuracy: 96,
    );

    expect(profile.signatureMoves, contains('e2e4'));
    expect(AdaptiveAIProfile.mirrorMoveForOppositeColor('e2e4'), 'e7e5');

    final remembered = profile.chooseSignatureCandidate(
      [
        MoveCandidate(uci: 'g8f6', score: 30),
        MoveCandidate(uci: 'e7e5', score: 20),
      ],
      moveNumber: 1,
    );

    expect(remembered?.uci, 'e7e5');
  });

  test('does not copy a signature move when it falls outside capability safety',
      () {
    const profile = AdaptiveAIProfile(
      style: 'aggressive',
      gameType: 'sharp opening',
      precision: 95,
      pressure: 0.8,
      solidity: 0.2,
      volatility: 0.1,
      sampleSize: 12,
      recentMoveTypes: [],
      signatureMoves: ['e2e4'],
      signatureMoveCounts: {'e2e4': 4},
    );

    final remembered = profile.chooseSignatureCandidate(
      [
        MoveCandidate(uci: 'g8f6', score: 100),
        MoveCandidate(uci: 'e7e5', score: 0),
      ],
      moveNumber: 1,
    );

    expect(remembered, isNull);
    expect(profile.counterPersonality, AIPersonality.defensive);
  });
}
