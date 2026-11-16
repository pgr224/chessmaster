# VS-AI stall audit — 2026-11-16

The audit found reproducible timeout, lifecycle and platform errors. It did not establish an out-of-memory failure on a physical device. The fixes preserve the configured Sunfish/Stockfish difficulty presets, depth targets, randomness, Stockfish skill settings, MultiPV, primary search budgets, thread counts and hash settings.

| Area | Finding | Correction |
| --- | --- | --- |
| Sunfish timeout | The worker checked elapsed time between depths, but recursive alpha-beta/quiescence and the final candidate pass could continue without a deadline. Opening positions could seem fine while later positions exceeded their budget. | One deadline covers recursion and candidate analysis. Preserve a completed legal result when it expires. Use a monotonic clock so device clock adjustments cannot extend a search. |
| Stockfish cold startup | Worker initialization was included in the search watchdog, leaving less time than the requested `go movetime`. A slow cold load could kill an otherwise healthy search. | Separate bounded five-second readiness allowance, then the full unchanged search budget. Warm workers start immediately. |
| Web Stockfish protocol | Overlapping init/search could create multiple engines. An old `bestmove` could be attributed to a newer request; queued readiness lost the selected skill. | Single-flight initialization; stop/old-bestmove/readiness barrier before a new search; exact request IDs; preserve skill in queued requests; terminate/listener cleanup. |
| Native Stockfish startup | Installed stockfish 1.8.1 starts asynchronously. Sending `uci`, `stop` or `quit` while `state=starting` can throw; its singleton is released asynchronously after shutdown. | Await process and UCI readiness, settle pending futures, await old shutdown before recreating, bound preparation and response waits, isolate each request's output. |
| Native watchdog | The controller allowed only 250 ms beyond movetime, too little for startup and readiness. | Preserve requested movetime; allow five seconds total preparation plus response/scheduler grace. This is not a lower search difficulty. |
| Practice coaching | Before starting the computer reply, practice coaching could use the entire selected engine budget (7/12/18 seconds), then the reply used it again. | Separate bounded local post-move coaching, with a two-second failure guard. It does not consume the foreground engine budget. |
| AI Mode contention | Old-position background analysis shared the foreground bridge and was canceled when the actual reply started, repeatedly tearing down/reloading Stockfish. | Reuse existing move coaching/mastery instead of starting that redundant bridge search. |
| Browser fallback | Dart `Isolate.run` is unsupported in browser builds. A worker failure could therefore make the emergency Dart fallback throw too. | Native computations retain isolates. Browser Dart coaching/emergency work yields before bounded local computation. Primary Sunfish/Stockfish searches remain in Web Workers. |
| Game lifecycle | Shared singleton controller cleanup could stop a newer game. Undo did not cancel old searches, and timeout/draw paths could leave thinking flags alive. Delayed autosaves could replace the current game ID. | One controller per game with ownership of the shared bridge; epoch/FEN/turn guards; deduplicate requests; cancel on undo/terminal transitions; ignore stale saves/evaluations. Undo one ply while a reply is pending, two after it arrives. Reject taking back the opening AI move before a Black human has played. |
| Storage and resume | A failed/hanging save could prevent the first AI move. Saved AI difficulty/level was omitted and resume defaulted to Medium. | Bounded optional storage; continue in memory on failure; persist and restore selected difficulty/level. |

## Difficulty contract

These settings remain the same as at the start of this audit:

| Preset | Primary move budget | Web engine/depth target | Web Stockfish skill |
| --- | ---: | --- | ---: |
| Basic | 2250 ms | Sunfish / 3 | — |
| Intermediate | 4000 ms | Sunfish / 5 | — |
| Advanced | 7000 ms | Stockfish / movetime-only | 16 |
| Impossible | 12000 ms | Stockfish / movetime-only | 20 |
| AI Mode | up to 18000 ms, existing adaptive calculation | Stockfish / movetime-only | 20 |

Existing worker safety margins and fault fallback settings remain unchanged. Dart fallback depth/randomness settings are also unchanged (depths 1/4/5/6/8). Native numeric depth mapping and MultiPV settings are retained. Startup grace changes the outer watchdog, not the requested move search time. Actual reached depth still depends on the device and the existing time budget.

## Memory evidence and limits

- The bundled web WASM declares 64 MiB initial linear memory and a growth ceiling of 32768 pages. That ceiling is not evidence that 2 GiB is allocated.
- In real Chromium searches, its observed linear-memory capacity was **80,543,744 bytes (76.8 MiB)** and stayed constant across repeated moves. Stockfish used one engine worker and its pthread worker, sharing WASM memory; Sunfish used one worker. This is not total browser/process RSS or a physical phone RAM measurement.
- The current web settings remain Threads=1 and Hash=32 MiB. The installed native Stockfish source defaults to Threads=1 and Hash=16 MiB; this audit did not lower either setting. Native total memory includes NNUE and other allocations, so hash size alone is not total RAM usage.
- The Dart transposition table's existing intended 50,000-entry bound is now enforced for coaching as well as fallback searches.
- No Android/iOS device memory trace, low-memory kill report or native crash log was supplied. A physical-device RAM/thermal/OS suspension cause remains unverified.

One earlier full-budget endurance run completed eight legal AI replies but recorded an anomalous 908-second wall-clock interval without the page's timeout firing. That run lacks monotonic timing and cannot establish whether the cause was a clock change or environment/browser suspension. A separate isolated rerun measured both Node and page monotonic clocks: full AI Mode replies completed in 17.79, 17.51 and 17.51 seconds with the same memory capacity and no engine switch. The anomalous wall-clock interval is not used as latency evidence.

## Validation

- Flutter suite covers controller ownership, cancellation, undo, duplicate requests, draw/clock termination, failed storage, slow coaching, stale autosaves, opening as Black, and saved difficulty round trips.
- Native lifecycle tests use a fake stockfish process to reproduce asynchronous readiness, stale output, crash/cancel/shutdown and watchdog failures. Actual Android/iOS binary execution was not available.
- Chromium Flutter tests verify Dart fallback/coaching and a missing engine-service fallback without unsupported isolates.
- JavaScript tests cover bounded Sunfish recursion/candidates, monotonic deadlines, cold/warm Stockfish budget separation, initialization/interrupt ordering and 100 consecutive requests without accumulating instances/listeners/timers.
- Real browser workers completed **120 legal plies across all five presets** without an engine switch or page error. The first request used each preset's default budget; later requests used an explicit 1000 ms protocol-test budget. This verifies sustained protocol/legality, not playing strength. The separate full-budget AI Mode rerun used the unchanged default budget for all three replies.

Machine-readable browser results are in `docs/AI_ENGINE_STABILITY_RESULTS.json`.

```sh
cd app
flutter test
flutter test --platform chrome test/ai_web_fallback_test.dart
node --test --test-isolation=none test/web/*.test.cjs
flutter analyze --no-pub
flutter build web --release
python3 ../scripts/prune_web_chunks.py
```

For real worker repetition, install Playwright and the backend's chess.js dependency, then run `node app/test/browser/engine_stability.cjs` from the repository root. Set NODE_PATH if Playwright is installed outside the checkout, CHROME_EXECUTABLE if using an existing Chromium, and ENGINE_REPORT for JSON output. ENGINE_DIFFICULTIES, ENGINE_TURNS and ENGINE_FULL_BUDGET=1 select a longer full-budget run. The script starts an ephemeral isolated local HTTP server and makes no live account/API requests.

No production deployment was performed.
