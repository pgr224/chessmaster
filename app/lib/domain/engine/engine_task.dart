import 'dart:isolate';

Future<T> runEngineTask<T>(T Function() task) => Isolate.run(task);
