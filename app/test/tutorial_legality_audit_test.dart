import 'package:flutter_test/flutter_test.dart';

import 'package:chess_master/data/models/tutorial_model.dart';
import 'package:chess_master/domain/engine/chess_engine.dart';

void main() {
  group('Tutorial legality audit', () {
    test('every non-completion step is legal from lesson FEN', () {
      final failures = <String>[];
      final seenLessonIds = <String>{};

      for (final lesson in tutorialLessons) {
        if (!seenLessonIds.add(lesson.id)) {
          failures.add('Duplicate lesson id: ${lesson.id}');
          continue;
        }

        final engine = ChessEngine.fromFEN(lesson.initialFEN);

        for (var i = 0; i < lesson.steps.length; i++) {
          final step = lesson.steps[i];
          final stepNumber = i + 1;
          final expectedRaw = step.expectedMove?.trim() ?? '';

          if (step.isCompletion) {
            if (expectedRaw.isNotEmpty) {
              failures.add(
                '[${lesson.id} step $stepNumber] completion step should not have expectedMove, found "$expectedRaw"',
              );
            }
            continue;
          }

          if (expectedRaw.isEmpty) {
            failures.add(
              '[${lesson.id} step $stepNumber] missing expectedMove for non-completion step',
            );
            continue;
          }

          Move expectedMove;
          try {
            expectedMove = Move.fromAlgebraic(expectedRaw);
          } catch (e) {
            failures.add(
              '[${lesson.id} step $stepNumber] invalid expectedMove "$expectedRaw": $e',
            );
            continue;
          }

          final autoReplies = <String>[];
          var autoReplyAttempts = 0;

          while (!_isExpectedMovePlayableNow(engine, expectedMove) &&
              autoReplyAttempts < 2) {
            final legal = engine.allLegalMoves();
            if (legal.isEmpty) {
              break;
            }

            final autoReply = _pickTutorialAutoReply(engine, legal);
            final applied = engine.makeMove(autoReply);
            if (!applied) {
              failures.add(
                '[${lesson.id} step $stepNumber] failed to apply tutorial auto-reply ${autoReply.toAlgebraic()}',
              );
              break;
            }

            autoReplies.add(autoReply.toAlgebraic());
            autoReplyAttempts++;
          }

          if (!_isExpectedMovePlayableNow(engine, expectedMove)) {
            failures.add(
              '[${lesson.id} step $stepNumber] expectedMove "$expectedRaw" is not legal from FEN ${engine.toFEN()} '
              '(autoReplies=${autoReplies.isEmpty ? 'none' : autoReplies.join(',')})',
            );
            continue;
          }

          final appliedExpected = engine.makeMove(expectedMove);
          if (!appliedExpected) {
            failures.add(
              '[${lesson.id} step $stepNumber] engine rejected expectedMove "$expectedRaw" despite legality pre-check',
            );
          }
        }
      }

      if (failures.isNotEmpty) {
        fail(
          'Tutorial legality audit failed (${failures.length} issues):\n\n'
          '${failures.join('\n\n')}',
        );
      }
    });
  });
}

bool _isExpectedMovePlayableNow(ChessEngine engine, Move expectedMove) {
  final piece = engine.pieceAt(expectedMove.from);
  if (piece == null || piece.color != engine.currentTurn) {
    return false;
  }

  final legalFromSquare = engine.legalMovesFrom(expectedMove.from);
  return legalFromSquare.any(
    (m) => m.to == expectedMove.to && m.promotion == expectedMove.promotion,
  );
}

Move _pickTutorialAutoReply(ChessEngine engine, List<Move> legalMoves) {
  var best = legalMoves.first;
  var bestScore = -100000;

  for (final move in legalMoves) {
    final piece = engine.pieceAt(move.from);
    if (piece == null) {
      continue;
    }

    var score = 0;

    final captureTarget = engine.pieceAt(move.to);
    if (captureTarget != null) {
      score += 30;
    }

    final targetsCenter =
        move.to.file >= 2 && move.to.file <= 5 && move.to.rank >= 2 && move.to.rank <= 5;
    if (targetsCenter) {
      score += 8;
    }

    if (piece.type == PieceType.knight || piece.type == PieceType.bishop) {
      score += 16;
    }

    if (piece.type == PieceType.pawn) {
      if (move.to.file == 3 || move.to.file == 4) {
        score += 10;
      }
      final forward = piece.color == PieceColor.white
          ? (move.to.rank - move.from.rank)
          : (move.from.rank - move.to.rank);
      if (forward > 0) {
        score += 6;
      }
    }

    if (score > bestScore) {
      bestScore = score;
      best = move;
    }
  }

  return best;
}
