import 'dart:async';

import 'package:chess_master/core/router/deferred_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads once and builds the screen only after code arrives', (
    tester,
  ) async {
    final loaded = Completer<void>();
    var loads = 0;
    var builds = 0;
    Future<void> loadLibrary() {
      loads++;
      return loaded.future;
    }

    final screen = MaterialApp(
      home: DeferredScreen(
        loadLibrary: loadLibrary,
        builder: (_) {
          builds++;
          return const Text('Ready');
        },
      ),
    );
    await tester.pumpWidget(screen);
    await tester.pump();
    expect(loads, 1);
    expect(builds, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    loaded.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
    expect(loads, 1);
  });

  testWidgets('failed download can be retried without reloading the app', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DeferredScreen(
          loadLibrary: () {
            loads++;
            return loads == 1
                ? Future.error(StateError('offline'))
                : Future.value();
          },
          builder: (_) => const Text('Recovered'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
    expect(loads, 2);
  });
}
