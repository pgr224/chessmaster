import 'dart:math' as math;

import 'candidate_model.dart';
import 'chess_engine.dart';
import 'personality_engine.dart';

class AdaptiveAIProfile {
  final String style;
  final String gameType;
  final double precision;
  final double pressure;
  final double solidity;
  final double volatility;
  final int sampleSize;
  final List<String> signatureMoves;
  final Map<String, int> signatureMoveCounts;

  const AdaptiveAIProfile({
    required this.style,
    required this.gameType,
    required this.precision,
    required this.pressure,
    required this.solidity,
    required this.volatility,
    required this.sampleSize,
    required this.signatureMoves,
    required this.signatureMoveCounts,
  });

  factory AdaptiveAIProfile.initial() => const AdaptiveAIProfile(
        style: 'positional',
        gameType: 'balanced',
        precision: 72.0,
        pressure: 0.45,
        solidity: 0.45,
        volatility: 0.25,
        sampleSize: 0,
        signatureMoves: [],
        signatureMoveCounts: {},
      );

  factory AdaptiveAIProfile.fromJson(Map<String, dynamic> json) {
    final countsRaw = json['signatureMoveCounts'];
    final counts = <String, int>{};
    if (countsRaw is Map) {
      countsRaw.forEach((key, value) {
        final parsed = value is int ? value : int.tryParse(value.toString());
        if (parsed != null && parsed > 0) counts[key.toString()] = parsed;
      });
    }

    final signaturesRaw = json['signatureMoves'];
    final signatures = signaturesRaw is List
        ? signaturesRaw.map((m) => m.toString()).where(_isUciMove).toList()
        : _topSignatureMoves(counts);

    return AdaptiveAIProfile(
      style: (json['style'] ?? 'positional').toString(),
      gameType: (json['gameType'] ?? 'balanced').toString(),
      precision:
          _readDouble(json['precision'], 72.0).clamp(0.0, 100.0).toDouble(),
      pressure: _readDouble(json['pressure'], 0.45).clamp(0.0, 1.0).toDouble(),
      solidity: _readDouble(json['solidity'], 0.45).clamp(0.0, 1.0).toDouble(),
      volatility:
          _readDouble(json['volatility'], 0.25).clamp(0.0, 1.0).toDouble(),
      sampleSize: math.max(0, _readInt(json['sampleSize'], 0)),
      signatureMoves: signatures.take(8).toList(growable: false),
      signatureMoveCounts: counts,
    );
  }

  Map<String, dynamic> toJson() => {
        'style': style,
        'gameType': gameType,
        'precision': precision,
        'pressure': pressure,
        'solidity': solidity,
        'volatility': volatility,
        'sampleSize': sampleSize,
        'signatureMoves': signatureMoves,
        'signatureMoveCounts': signatureMoveCounts,
      };

  AIPersonality get counterPersonality {
    return switch (style) {
      'aggressive' || 'pawn_storm' || 'sacrificial' => AIPersonality.defensive,
      'defensive' || 'solid' || 'passive' => AIPersonality.aggressive,
      'chaotic' || 'tactical' => AIPersonality.coach,
      'positional' || 'strategic' => AIPersonality.tricky,
      _ => AIPersonality.coach,
    };
  }

  double get capabilityScore {
    final precisionScore = precision / 100.0;
    final experienceScore = (sampleSize / 30.0).clamp(0.0, 1.0).toDouble();
    final stabilityScore = 1.0 - (volatility * 0.45);
    return ((precisionScore * 0.62) +
            (experienceScore * 0.18) +
            (stabilityScore * 0.20))
        .clamp(0.20, 1.0)
        .toDouble();
  }

  double get timeMultiplier {
    if (precision >= 92) return 1.35;
    if (precision >= 84) return 1.18;
    if (precision >= 70) return 1.0;
    if (precision >= 55) return 0.86;
    return 0.72;
  }

  double get errorChance {
    if (precision >= 90) return 0.01;
    if (precision >= 80) return 0.025;
    if (precision >= 65) return 0.05;
    return 0.08;
  }

  int get maxCentipawnLoss {
    if (precision >= 90) return 32;
    if (precision >= 80) return 45;
    if (precision >= 65) return 70;
    return 95;
  }

  String get adaptationMessage {
    final counter = counterPersonality.label.toLowerCase();
    final precisionLabel = precision >= 86
        ? 'high precision'
        : precision >= 68
            ? 'steady precision'
            : 'swingy precision';

    return 'I am reading a $style $gameType with $precisionLabel, '
        'so I will play $counter to keep you calculating.';
  }

  String? get openingMemoryMessage {
    if (signatureMoves.isEmpty) return null;
    return 'I remember your ${signatureMoves.first} pattern. I may borrow that idea this game.';
  }

  AdaptiveAIProfile observeMove({
    required Move move,
    required ChessEngine engineAfterMove,
    required PieceColor playerColor,
    required int moveNumber,
    double? moveAccuracy,
    int? centipawnLoss,
  }) {
    final movedPiece = engineAfterMove.pieceAt(move.to);
    final isCapture = move.capturedPiece != null;
    final isCheck = engineAfterMove.status == GameStatus.check;
    final isCastle = move.isCastle ||
        (movedPiece?.type == PieceType.king &&
            (move.from.file - move.to.file).abs() == 2);
    final isPromotion = move.promotion != null;
    final isQueenEarly =
        movedPiece?.type == PieceType.queen && moveNumber <= 10;
    final isCenterMove = _isCenterSquare(move.to);
    final isSidePawnPush = movedPiece?.type == PieceType.pawn &&
        (move.from.file <= 1 || move.from.file >= 6);
    final isRetreat = _isRetreat(move, playerColor);
    final isDevelopment = _isDevelopment(move, movedPiece, playerColor);
    final pawnAdvance = movedPiece?.type == PieceType.pawn
        ? (move.to.rank - move.from.rank).abs()
        : 0;

    final movePressure = _boundedScore([
      if (isCapture) 0.28,
      if (isCheck) 0.32,
      if (isPromotion) 0.42,
      if (isQueenEarly) 0.22,
      if (isSidePawnPush && pawnAdvance >= 2) 0.18,
      if (isCenterMove) 0.10,
    ], 0.12);

    final moveSolidity = _boundedScore([
      if (isCastle) 0.36,
      if (movedPiece?.type == PieceType.pawn && !isSidePawnPush) 0.10,
      if (isRetreat) 0.20,
      if (!isCapture && !isCheck && !isQueenEarly) 0.12,
      if (isDevelopment) 0.10,
    ], 0.14);

    final safeAccuracy =
        (moveAccuracy ?? precision).clamp(0.0, 100.0).toDouble();
    final cpLoss = centipawnLoss ?? ((100.0 - safeAccuracy) * 10).round();
    final moveVolatility = (cpLoss / 500.0).clamp(0.0, 1.0).toDouble();

    final nextSampleSize = sampleSize + 1;
    final alpha = sampleSize < 6 ? 0.34 : 0.22;
    final nextPrecision = _smooth(precision, safeAccuracy, alpha);
    final nextPressure = _smooth(pressure, movePressure, alpha);
    final nextSolidity = _smooth(solidity, moveSolidity, alpha);
    final nextVolatility = _smooth(volatility, moveVolatility, alpha);
    final nextCounts = Map<String, int>.from(signatureMoveCounts);

    if (_shouldRememberSignature(move, movedPiece, moveNumber, isCapture,
        isCheck, isCastle, isCenterMove, isSidePawnPush)) {
      final uci = move.toAlgebraic();
      nextCounts[uci] = (nextCounts[uci] ?? 0) + 1;
    }

    final nextSignatures = _topSignatureMoves(nextCounts);
    final nextStyle = _classifyStyle(
      pressure: nextPressure,
      solidity: nextSolidity,
      volatility: nextVolatility,
      precision: nextPrecision,
      sidePawnPush: isSidePawnPush,
    );
    final nextGameType = _classifyGameType(
      moveNumber: moveNumber,
      pieceCount: _pieceCount(engineAfterMove),
      pressure: nextPressure,
      solidity: nextSolidity,
      volatility: nextVolatility,
    );

    return AdaptiveAIProfile(
      style: nextStyle,
      gameType: nextGameType,
      precision: nextPrecision,
      pressure: nextPressure,
      solidity: nextSolidity,
      volatility: nextVolatility,
      sampleSize: nextSampleSize,
      signatureMoves: nextSignatures,
      signatureMoveCounts: nextCounts,
    );
  }

  MoveCandidate? chooseSignatureCandidate(
    List<MoveCandidate> candidates, {
    required int moveNumber,
  }) {
    if (signatureMoves.isEmpty || candidates.isEmpty || moveNumber > 16) {
      return null;
    }

    final bestScore = candidates.first.score;
    final candidatesByUci = {for (final c in candidates) c.uci: c};
    final toleratedLoss = maxCentipawnLoss + (moveNumber <= 6 ? 35 : 0);

    for (final signature in signatureMoves) {
      for (final pattern in _signaturePatterns(signature)) {
        final candidate = candidatesByUci[pattern];
        if (candidate == null) continue;
        if (candidate.score >= bestScore - toleratedLoss) return candidate;
      }
    }

    return null;
  }

  static String? mirrorMoveForOppositeColor(String uci) {
    if (!_isUciMove(uci)) return null;
    final from = _mirrorSquare(uci.substring(0, 2));
    final to = _mirrorSquare(uci.substring(2, 4));
    final promotion = uci.length > 4 ? uci.substring(4) : '';
    return '$from$to$promotion';
  }

  static Iterable<String> _signaturePatterns(String uci) sync* {
    if (!_isUciMove(uci)) return;
    yield uci;
    final mirrored = mirrorMoveForOppositeColor(uci);
    if (mirrored != null && mirrored != uci) yield mirrored;
  }

  static String _mirrorSquare(String square) {
    final file = square[0];
    final rank = int.tryParse(square[1]) ?? 1;
    return '$file${9 - rank}';
  }

  static bool _shouldRememberSignature(
    Move move,
    ChessPiece? movedPiece,
    int moveNumber,
    bool isCapture,
    bool isCheck,
    bool isCastle,
    bool isCenterMove,
    bool isSidePawnPush,
  ) {
    if (!_isUciMove(move.toAlgebraic())) return false;
    if (moveNumber <= 12) return true;
    if (isCapture || isCheck || isCastle) return true;
    if (isCenterMove && movedPiece?.type != PieceType.king) return true;
    return isSidePawnPush && movedPiece?.type == PieceType.pawn;
  }

  static List<String> _topSignatureMoves(Map<String, int> counts) {
    final entries = counts.entries
        .where((entry) => _isUciMove(entry.key) && entry.value > 0)
        .toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });

    return entries.map((entry) => entry.key).take(8).toList(growable: false);
  }

  static String _classifyStyle({
    required double pressure,
    required double solidity,
    required double volatility,
    required double precision,
    required bool sidePawnPush,
  }) {
    if (volatility > 0.58 && precision < 64) return 'chaotic';
    if (pressure > 0.66 || (pressure > 0.56 && sidePawnPush)) {
      return sidePawnPush ? 'pawn_storm' : 'aggressive';
    }
    if (solidity > 0.64 && solidity > pressure + 0.08) return 'solid';
    if (pressure < 0.34 && solidity < 0.40) return 'passive';
    return 'positional';
  }

  static String _classifyGameType({
    required int moveNumber,
    required int pieceCount,
    required double pressure,
    required double solidity,
    required double volatility,
  }) {
    final tone = pressure > solidity + 0.12
        ? 'sharp'
        : solidity > pressure + 0.12
            ? 'solid'
            : volatility > 0.55
                ? 'messy'
                : 'balanced';

    if (moveNumber <= 12) return '$tone opening';
    if (pieceCount <= 10) return '$tone endgame';
    return '$tone middlegame';
  }

  static bool _isCenterSquare(Square square) =>
      square.file >= 2 &&
      square.file <= 5 &&
      square.rank >= 2 &&
      square.rank <= 5;

  static bool _isRetreat(Move move, PieceColor color) {
    if (color == PieceColor.white) return move.to.rank < move.from.rank;
    return move.to.rank > move.from.rank;
  }

  static bool _isDevelopment(
    Move move,
    ChessPiece? movedPiece,
    PieceColor color,
  ) {
    if (movedPiece == null) return false;
    if (movedPiece.type != PieceType.knight &&
        movedPiece.type != PieceType.bishop) {
      return false;
    }
    final homeRank = color == PieceColor.white ? 0 : 7;
    return move.from.rank == homeRank && move.to.rank != homeRank;
  }

  static int _pieceCount(ChessEngine engine) {
    var count = 0;
    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        if (engine.pieceAt(Square(file, rank)) != null) count++;
      }
    }
    return count;
  }

  static double _boundedScore(List<double> signals, double baseline) {
    final total = signals.fold<double>(baseline, (sum, value) => sum + value);
    return total.clamp(0.0, 1.0).toDouble();
  }

  static double _smooth(double current, double next, double alpha) =>
      (current * (1.0 - alpha)) + (next * alpha);

  static double _readDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _readInt(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _isUciMove(Object? value) {
    final move = value?.toString();
    if (move == null || move.length < 4 || move.length > 5) return false;
    final pattern = RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$');
    return pattern.hasMatch(move.toLowerCase());
  }
}
