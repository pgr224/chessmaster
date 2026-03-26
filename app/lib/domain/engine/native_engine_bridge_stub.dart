/// Native Engine Bridge Stub — Used on web platform (no-ops)
/// This file is loaded via conditional import when dart:io is NOT available.

void jsEngineInit(String mode, String difficulty) {}
Future<String?> jsEngineGetBestMove(String fen) async => null;
bool jsEngineValidateMove(String fen, String from, String to, String? promotion) => false;
List<String> jsEngineGetLegalMoves(String fen, String square) => [];
String jsEngineGetActiveEngine() => 'none';
void jsEngineDispose() {}
