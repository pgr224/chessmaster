/// Native Engine Bridge Stub — Used on webplatform (no-ops)
/// This file is loaded via conditional import when dart:io is NOT available.
library;

void jsEngineInit(String mode, String difficulty) {}
Future<Map<String, dynamic>?> jsEngineGetBestMove(String fen,
        {int? movetime}) async =>
    null;
Future<List<dynamic>> jsEngineGetTopMoves(String fen, int depth, int count,
        {int? movetime}) async =>
    [];
bool jsEngineValidateMove(
        String fen, String from, String to, String? promotion) =>
    false;
List<String> jsEngineGetLegalMoves(String fen, String square) => [];
String jsEngineGetActiveEngine() => 'none';
void jsEngineDispose() {}
