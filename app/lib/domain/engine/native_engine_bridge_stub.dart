/// Native Engine Bridge Stub — Used on webplatform (no-ops)
/// This file is loaded via conditional import when dart:io is NOT available.
library;

void jsEngineInit(String mode, String difficulty, {int? difficultyLevel}) {}
Future<Map<String, dynamic>> jsEngineAnalyzeStyle(
    String fen,
    List<String> recentMoves,
) async =>
        {
            'style': 'unknown',
            'confidence': 0.0,
            'suggested_personality': 'defensive',
        };
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
