# Real browser gameplay soak

`ai_gameplay_soak.dart` is a standalone Flutter test application that renders the production `GameScreen` and uses the real `GameBloc`, `AIEngineController`, coach, JS bridge, and Sunfish/Stockfish workers. It injects only in-memory account/storage/progression services and drives legal human `GameMakeMoveEvent` inputs. No backend account or remote mutation is involved.

The default run requires 20 legal applied replies at **intermediate** and 20 at **advanced**, retaining production time budgets, levels, and worker settings. It verifies selected worker source and resulting FEN for every reply. It requires one game to reach 20 replies, then saves/exits/resumes and verifies another actual reply. The external reply counter survives resume because the current resume implementation restores FEN but not complete move history.

```sh
cd app
flutter build web --release --target=test/browser/ai_gameplay_soak.dart --output=/tmp/chess-browser-soak
cd ..
PLAYWRIGHT_MODULE=/path/to/playwright \
CHROME_EXECUTABLE=/path/to/chrome \
node app/test/browser/run_gameplay_soak.cjs /tmp/chess-browser-soak
```

The runner creates an isolated headless Chrome profile, serves the generated app locally with production COOP/COEP headers, captures worker URLs and runtime errors, and writes `/tmp/chess-browser-soak-result.json` plus a screenshot. `SOAK_OUTPUT` changes the result path. A successful run exits zero; an engine error, illegal reply, source mismatch, or timeout fails the run.

For a shorter smoke check, add `--dart-define=SOAK_REPLIES=2` to the build. `--dart-define=SOAK_DIFFICULTIES=advanced` selects a subset. Only the test target changes; engine budgets are never overridden. Use the default 20-reply build for the long-game result.

These are untimed games with programmatically injected human moves, not pointer-input, authentication, native-engine, network-reconnection, or physical-device tests. The test's human policy uses local bounded Dart analysis, so browser heartbeat gaps include that intentional work. If a game ends early, the harness records its ending and game number; the run cannot pass on many short games because it requires a 20-reply continuous game. Do not deploy this test application as the real site.
