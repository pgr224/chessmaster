// Browser builds have no Dart isolates. Primary searches still run in the
// Sunfish/Stockfish Web Workers; bounded Dart coaching/emergency work yields
// once before running locally instead of throwing UnsupportedError.
Future<T> runEngineTask<T>(T Function() task) =>
    Future<T>.delayed(Duration.zero, task);
