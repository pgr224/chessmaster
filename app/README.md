# chess_master

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Release loading

Build with Flutter 3.50.0 (the version used for validation):

```sh
flutter pub get
flutter test
node --test test/web/*.test.cjs
flutter build web --release --dart-define=API_URL=https://chess-master-api.pp942920.workers.dev
python3 ../scripts/prune_web_chunks.py
```

The WebSocket endpoint follows `API_URL`; pass `--dart-define=WS_URL=...` only for a separate endpoint. Configuration is public and compiled in, so no `.env` asset or startup request is required. Serve the whole `build/web` directory, including the deferred JavaScript files. Keep `web/flutter_bootstrap.js`: it avoids registering a second worker over the push notification worker.

See [the performance report](../docs/PERFORMANCE.md) for size measurements and checks.
