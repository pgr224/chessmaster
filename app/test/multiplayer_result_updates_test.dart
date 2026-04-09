import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_master/presentation/blocs/multiplayer/multiplayer_bloc.dart';
import 'package:chess_master/presentation/blocs/game/game_bloc.dart';
import 'package:chess_master/data/services/multiplayer_service.dart';

void main() {
  group('MultiplayerBloc game over XP', () {
    blocTest<MultiplayerBloc, MultiplayerState>(
      'applies standardized win XP when result is win',
      build: () => MultiplayerBloc(MultiplayerService()),
      act: (bloc) => bloc.add(const MpGameOverEvent('win', 'checkmate')),
      expect: () => [
        isA<MultiplayerState>()
            .having((s) => s.status, 'status', MultiplayerStatus.gameOver)
            .having((s) => s.gameResult, 'result', 'win')
            .having((s) => s.xpGained, 'xpGained', 100),
      ],
    );

    blocTest<MultiplayerBloc, MultiplayerState>(
      'applies standardized loss XP when result is loss',
      build: () => MultiplayerBloc(MultiplayerService()),
      act: (bloc) => bloc.add(const MpGameOverEvent('loss', 'resign')),
      expect: () => [
        isA<MultiplayerState>()
            .having((s) => s.status, 'status', MultiplayerStatus.gameOver)
            .having((s) => s.gameResult, 'result', 'loss')
            .having((s) => s.xpGained, 'xpGained', -20),
      ],
    );

    blocTest<MultiplayerBloc, MultiplayerState>(
      'uses server XP delta override when provided',
      build: () => MultiplayerBloc(MultiplayerService()),
      act: (bloc) =>
          bloc.add(const MpGameOverEvent('draw', 'agreement', xpDelta: 45)),
      expect: () => [
        isA<MultiplayerState>()
            .having((s) => s.status, 'status', MultiplayerStatus.gameOver)
            .having((s) => s.gameResult, 'result', 'draw')
            .having((s) => s.xpGained, 'xpGained', 45),
      ],
    );
  });

  group('GameBloc multiplayer result stat updates', () {
    test('win includes multiplayer win stats and win XP fallback', () {
      final result = GameBloc.buildMultiplayerResultDelta(
        isWin: true,
        isLoss: false,
        isDraw: false,
        syncedXpDelta: 0,
      );

      expect(result.xpDelta, 100);
      expect(result.statUpdates['multiplayer_games'], 1);
      expect(result.statUpdates['wins'], 1);
      expect(result.statUpdates['multiplayer_wins'], 1);
      expect(result.statUpdates.containsKey('losses'), false);
      expect(result.statUpdates.containsKey('draws'), false);
    });

    test('loss includes multiplayer games + losses and loss XP fallback', () {
      final result = GameBloc.buildMultiplayerResultDelta(
        isWin: false,
        isLoss: true,
        isDraw: false,
        syncedXpDelta: 0,
      );

      expect(result.xpDelta, -20);
      expect(result.statUpdates['multiplayer_games'], 1);
      expect(result.statUpdates['losses'], 1);
      expect(result.statUpdates.containsKey('wins'), false);
      expect(result.statUpdates.containsKey('multiplayer_wins'), false);
      expect(result.statUpdates.containsKey('draws'), false);
    });

    test('draw includes multiplayer games + draws and draw XP fallback', () {
      final result = GameBloc.buildMultiplayerResultDelta(
        isWin: false,
        isLoss: false,
        isDraw: true,
        syncedXpDelta: 0,
      );

      expect(result.xpDelta, 30);
      expect(result.statUpdates['multiplayer_games'], 1);
      expect(result.statUpdates['draws'], 1);
      expect(result.statUpdates.containsKey('wins'), false);
      expect(result.statUpdates.containsKey('multiplayer_wins'), false);
      expect(result.statUpdates.containsKey('losses'), false);
    });

    test('uses synced multiplayer XP when provided', () {
      final result = GameBloc.buildMultiplayerResultDelta(
        isWin: true,
        isLoss: false,
        isDraw: false,
        syncedXpDelta: 62,
      );

      expect(result.xpDelta, 62);
      expect(result.statUpdates['multiplayer_games'], 1);
      expect(result.statUpdates['wins'], 1);
      expect(result.statUpdates['multiplayer_wins'], 1);
    });
  });
}
