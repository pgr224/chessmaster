# Loading and consistency cleanup — 15 November 2026

## Game loading and final position

- Practice games reuse the user already loaded at game start instead of reading
  it twice. Theme choices are already stored locally, and Flutter caches decoded
  SVGs in memory.
- Cloudflare Pages tells browsers to cache piece and theme assets for five
  minutes. Flutter asset manifests and application code are not covered by this
  rule, so a deployment can still update them normally. Asset URLs are not
  versioned, so updated piece/theme artwork can take up to five minutes to
  appear. Native app assets are already bundled on the device.
- A checkmate leaves the final board visible for 1.2 seconds after it is
  rendered before displaying the result. Online game-over messages also carry
  their final server position into the board.

The implementation plans describe local and online chess, Sunfish for lower AI difficulties, Stockfish for stronger play, tutorials, puzzles, adaptive coaching, and XP. The cleanup keeps those features and loads their code only when needed.

## Changes

- Split 18 screens into six deferred feature libraries, with loading and retry UI. Related screens share downloads.
- Start web workers on the first AI search, reuse idle workers, and release busy searches on cancellation, game changes, or disposal. Human games allocate no AI worker.
- Reduce the web Stockfish hash setting from 256 MB to 32 MB. Search budgets remain bounded; stale results cannot update a newer position.
- Use the bundled NotoSans fallback font instead of fetching another copy at runtime.
- Replace four onboarding images with WebP at their original dimensions. Exclude unused sprite sheets from the asset manifest while keeping every selectable piece theme.
- Remove 11 unused runtime dependencies, two unused development dependencies, and an invalid, unused chess font.
- Initialize independent storage services together, register secondary services lazily, cache the app theme, and stop rebuilding MaterialApp on every settings/theme update. Load preferences eagerly so saved selections remain available.
- Navigate when authentication finishes, including when it finishes before the splash listener attaches. Remove the extra 1.2-second wait and unused animation controller.
- Trigger sounds, celebrations, draw/save prompts, and network notices on transitions instead of repeating them on clock updates. Keep multiplayer move/undo/result synchronization independently subscribed.
- Consolidate push setup, respect notification preferences, ask permission only after an explicit notification action, and correct notification deep links and icon files.
- Replace the missing runtime `.env` asset with public build-time endpoint configuration. `WS_URL` follows `API_URL` unless explicitly overridden.

## Release measurements

Measured locally with Flutter 3.50.0 / Dart 3.14.0 using the same release compiler for both builds. Gzip sizes use Python gzip level 9; production transfer sizes depend on server compression. These are download/build measurements, not a promise of a particular mobile load time.

| Measurement | Before | After | Reduction |
|---|---:|---:|---:|
| Startup JavaScript | 4,428,611 B | 3,569,502 B | 19.4% |
| Startup JavaScript, gzip | 1,313,262 B | 1,059,605 B | 19.3% |
| Release assets including notices | 16,130,116 B | 6,583,041 B | 59.2% |
| Complete web output including renderer variants | 59,327,822 B | 49,772,076 B | 16.1% |

The optimized build has 41 referenced deferred chunks totaling 896,374 bytes, fetched only for the relevant feature. Startup requests contain none of these chunks. The complete output size includes all supported Flutter renderer variants; a browser downloads only its selected renderer.


Onboarding image payload: 8,039,603 → 691,540 bytes (91.4% smaller). Declared assets and fonts: 14,376,950 → 4,903,154 bytes (65.9% smaller). Stockfish transposition-table setting: 256 → 32 MB (87.5% lower); total process memory includes the runtime and other allocations.

## Validation

- Release web compilation.
- Flutter regression suite: 31 tests, including engine lifecycle, deferred loading/retry, tutorial legality, feedback transitions, multiplayer results and undo propagation.
- JavaScript: 22 behavior checks covering engine cancellation/fallback, actual worker UCI settings, push preferences/permission, and service-worker navigation.
- Flutter analysis: no errors. Existing warnings and informational lints remain; the newer SDK also deprecates legacy Material imports.
- Headless Chromium: onboarding, guest sign-in, ten deferred routes, and the game board load without page errors; no AI worker starts before a move is requested. Live account API requests are intercepted during this check. A guest move (`e4`) received a legal Sunfish reply (`Nc6`).
- Browser recovery: blocked deferred downloads showed Retry; after restoring the connection and clicking it, the same Settings route loaded all 23 required chunks with HTTP 200 and no page errors.
- Real Stockfish on an isolated local server: ready, legal move and three candidates, active engine `stockfish`. The plain HTTP smoke server lacks isolation headers, so it correctly uses the Sunfish fallback.

## Build and deployment

```sh
cd app
flutter pub get
flutter test
node --test test/web/*.test.cjs
flutter build web --release --dart-define=API_URL=https://chess-master-api.pp942920.workers.dev
python3 ../scripts/prune_web_chunks.py
```

Serve the complete `app/build/web` directory, including all referenced `.part.js` files. Keep the custom bootstrap so the push worker owns its scope. Run the pruning command after building: Flutter’s incremental compiler cache can otherwise copy obsolete deferred chunks back into an otherwise clean output directory. It verifies that every referenced chunk exists before removing unreferenced generated chunks. No production deployment was performed.

## Workspace recovery

This workspace initially lacked its Flutter manifest and many imported Dart files, JS workers, icons, and asset files. Missing tracked source/configuration/assets were recovered from the upstream repository after confirming that its 969 index entries exactly matched the local Git index. Existing source files were preserved. The original Git metadata also lacks HEAD/refs; it was left unchanged. Generated historical build logs and unrelated worktree files were not copied into the source tree.

## Gameplay/notification follow-up verification

The subsequent gameplay and notification repairs retain deferred loading and lazy AI startup. The current optimized main.dart.js is 3,592,480 bytes (about 3.59 MB) and has 41 referenced deferred chunks. The release web build succeeds. The expanded checks pass 51 Flutter tests, 36 backend unit tests, 3 real local Worker/D1/DO/WebSocket integration tests and 25 JavaScript checks. Backend TypeScript checks pass. Device push delivery remains unverified until owner configuration; see NOTIFICATIONS.md for the Firebase-free PWA path and optional native FCM setup. No deployment was performed.
