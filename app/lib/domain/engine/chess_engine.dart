/// Chess Engine — Full FIDE-compliant implementation
/// Handles: legal moves, check/checkmate/stalemate, castling, en passant, pawn promotion

enum PieceType { pawn, rook, knight, bishop, queen, king }
enum PieceColor { white, black }

class ChessPiece {
  final PieceType type;
  final PieceColor color;
  bool hasMoved;

  ChessPiece({required this.type, required this.color, this.hasMoved = false});

  ChessPiece copyWith({PieceType? type, PieceColor? color, bool? hasMoved}) {
    return ChessPiece(
      type: type ?? this.type,
      color: color ?? this.color,
      hasMoved: hasMoved ?? this.hasMoved,
    );
  }

  String get symbol {
    final symbols = {
      PieceType.pawn: color == PieceColor.white ? 'P' : 'p',
      PieceType.rook: color == PieceColor.white ? 'R' : 'r',
      PieceType.knight: color == PieceColor.white ? 'N' : 'n',
      PieceType.bishop: color == PieceColor.white ? 'B' : 'b',
      PieceType.queen: color == PieceColor.white ? 'Q' : 'q',
      PieceType.king: color == PieceColor.white ? 'K' : 'k',
    };
    return symbols[type]!;
  }

  String get unicodeSymbol {
    final symbols = {
      PieceType.pawn: color == PieceColor.white ? '♙' : '♟',
      PieceType.rook: color == PieceColor.white ? '♖' : '♜',
      PieceType.knight: color == PieceColor.white ? '♘' : '♞',
      PieceType.bishop: color == PieceColor.white ? '♗' : '♝',
      PieceType.queen: color == PieceColor.white ? '♕' : '♛',
      PieceType.king: color == PieceColor.white ? '♔' : '♚',
    };
    return symbols[type]!;
  }

  String toFEN() {
    final chars = {
      PieceType.pawn: 'p', PieceType.rook: 'r', PieceType.knight: 'n',
      PieceType.bishop: 'b', PieceType.queen: 'q', PieceType.king: 'k',
    };
    final c = chars[type]!;
    return color == PieceColor.white ? c.toUpperCase() : c;
  }
}

class Square {
  final int rank; // 0-7 (0 = rank 1)
  final int file; // 0-7 (0 = file a)

  const Square(this.file, this.rank);

  factory Square.fromString(String s) {
    if (s.length != 2) throw ArgumentError('Invalid square string');
    final f = s.codeUnitAt(0) - 97;
    final r = int.parse(s[1]) - 1;
    return Square(f, r);
  }

  bool get isValid => file >= 0 && file < 8 && rank >= 0 && rank < 8;

  Square operator +(List<int> delta) => Square(file + delta[0], rank + delta[1]);

  String toAlgebraic() => '${String.fromCharCode(97 + file)}${rank + 1}';

  @override
  bool operator ==(Object other) =>
      other is Square && other.file == file && other.rank == rank;

  @override
  int get hashCode => file * 8 + rank;

  @override
  String toString() => toAlgebraic();
}

class Move {
  final Square from;
  final Square to;
  final PieceType? promotion;
  final bool isCastle;
  final bool isEnPassant;
  final ChessPiece? capturedPiece;
  String? algebraic;

  // Metadata for fast unmaking
  Square? prevEnPassant;
  bool? prevWhiteKingside;
  bool? prevWhiteQueenside;
  bool? prevBlackKingside;
  bool? prevBlackQueenside;
  int? prevHalfMoveClock;

  String toAlgebraic() {
    final s = '${from.toAlgebraic()}${to.toAlgebraic()}';
    if (promotion != null) {
      final p = {
        PieceType.queen: 'q', PieceType.rook: 'r',
        PieceType.bishop: 'b', PieceType.knight: 'n'
      }[promotion];
      return '$s$p';
    }
    return s;
  }

  Move({
    required this.from,
    required this.to,
    this.promotion,
    this.isCastle = false,
    this.isEnPassant = false,
    this.capturedPiece,
    this.algebraic,
  });

  factory Move.fromAlgebraic(String s) {
    if (s.length < 4) throw ArgumentError('Invalid algebraic move: $s');
    final from = Square.fromString(s.substring(0, 2));
    final to = Square.fromString(s.substring(2, 4));
    PieceType? promo;
    if (s.length > 4) {
      final pChar = s[4].toLowerCase();
      promo = {
        'q': PieceType.queen, 'r': PieceType.rook,
        'b': PieceType.bishop, 'n': PieceType.knight
      }[pChar];
    }
    return Move(from: from, to: to, promotion: promo);
  }

  @override
  String toString() => algebraic ?? toAlgebraic();
}

enum GameResult { ongoing, whiteWins, blackWins, draw }
enum DrawReason { stalemate, insufficientMaterial, fiftyMoveRule, threefoldRepetition, agreement }
enum GameStatus { active, check, checkmate, stalemate, draw }

class ChessEngine {
  late List<List<ChessPiece?>> _board;
  PieceColor _currentTurn = PieceColor.white;
  Square? _enPassantTarget;
  int _halfMoveClock = 0;
  int _fullMoveNumber = 1;
  List<Move> _moveHistory = [];
  List<String> _positionHistory = [];
  GameStatus _status = GameStatus.active;
  GameResult _result = GameResult.ongoing;
  DrawReason? _drawReason;

  // Castling rights
  bool _whiteKingsideCastle = true;
  bool _whiteQueensideCastle = true;
  bool _blackKingsideCastle = true;
  bool _blackQueensideCastle = true;

  ChessEngine() {
    _initBoard();
    _positionHistory.add(toFEN());
  }

  ChessEngine.fromFEN(String fen) {
    _parseFEN(fen);
  }

  // ═══════════════════════════════════════════
  // BOARD INITIALIZATION
  // ═══════════════════════════════════════════
  void _initBoard() {
    _board = List.generate(8, (_) => List.filled(8, null));
    _placePieces(PieceColor.white, 0);
    _placePieces(PieceColor.black, 7);
  }

  void _placePieces(PieceColor color, int backRank) {
    final pawnRank = color == PieceColor.white ? 1 : 6;
    final order = [
      PieceType.rook, PieceType.knight, PieceType.bishop, PieceType.queen,
      PieceType.king, PieceType.bishop, PieceType.knight, PieceType.rook,
    ];
    for (int f = 0; f < 8; f++) {
      _board[backRank][f] = ChessPiece(type: order[f], color: color);
      _board[pawnRank][f] = ChessPiece(type: PieceType.pawn, color: color);
    }
  }

  // ═══════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════
  ChessPiece? pieceAt(Square sq) => _board[sq.rank][sq.file];
  PieceColor get currentTurn => _currentTurn;
  List<Move> get moveHistory => List.unmodifiable(_moveHistory);
  GameStatus get status => _status;
  GameResult get result => _result;
  DrawReason? get drawReason => _drawReason;
  Square? get enPassantTarget => _enPassantTarget;

  List<List<ChessPiece?>> get board =>
      _board.map((r) => List<ChessPiece?>.from(r)).toList();

  /// Get all legal moves for a piece at [sq]
  List<Move> legalMovesFrom(Square sq) {
    final piece = pieceAt(sq);
    if (piece == null || piece.color != _currentTurn) return [];
    return _getLegalMoves(sq, piece);
  }

  /// Get all legal moves for current player
  List<Move> allLegalMoves() {
    final moves = <Move>[];
    for (int r = 0; r < 8; r++) {
      for (int f = 0; f < 8; f++) {
        final sq = Square(f, r);
        final piece = _board[r][f];
        if (piece != null && piece.color == _currentTurn) {
          moves.addAll(_getLegalMoves(sq, piece));
        }
      }
    }
    return moves;
  }

  /// Make a move — returns true if successful
  bool makeMove(Move move) {
    final legal = legalMovesFrom(move.from);
    final legalMove = legal.where((m) => m.to == move.to &&
        m.promotion == move.promotion).firstOrNull;
    if (legalMove == null) return false;

    // Generate algebraic representation for the UI
    final piece = pieceAt(legalMove.from)!;
    legalMove.algebraic = _buildAlgebraic(legalMove, piece);

    applyMoveInternal(legalMove);
    _updateStatus();
    return true;
  }

  /// Undo the last move instantly (O(1))
  bool undoMove() {
    if (_moveHistory.isEmpty) return false;
    final move = _moveHistory.removeLast();
    _unmakeMove(move);
    _currentTurn = _opponent(_currentTurn);
    if (_currentTurn == PieceColor.black) _fullMoveNumber--; // Redo full move count correctly
    _positionHistory.removeLast();
    _updateStatus();
    return true;
  }

  void _unmakeMove(Move move) {
    final piece = _board[move.to.rank][move.to.file]!;
    
    // Restore piece to 'from'
    final restoredPiece = move.promotion != null
        ? ChessPiece(type: PieceType.pawn, color: piece.color, hasMoved: piece.hasMoved)
        : piece;
    
    _board[move.from.rank][move.from.file] = restoredPiece;
    _board[move.to.rank][move.to.file] = move.capturedPiece;

    // Special cases
    if (move.isCastle) {
      final rank = move.from.rank;
      final kingside = move.to.file == 6;
      final rookFrom = kingside ? 7 : 0;
      final rookTo = kingside ? 5 : 3;
      _board[rank][rookFrom] = _board[rank][rookTo];
      _board[rank][rookTo] = null;
    }

    if (move.isEnPassant) {
      final captureRank = move.from.rank;
      _board[captureRank][move.to.file] = ChessPiece(type: PieceType.pawn, color: _opponent(piece.color));
      _board[move.to.rank][move.to.file] = null; // En passant 'to' was empty
    }

    // Restore state
    _enPassantTarget = move.prevEnPassant;
    _whiteKingsideCastle = move.prevWhiteKingside ?? true;
    _whiteQueensideCastle = move.prevWhiteQueenside ?? true;
    _blackKingsideCastle = move.prevBlackKingside ?? true;
    _blackQueensideCastle = move.prevBlackQueenside ?? true;
    _halfMoveClock = move.prevHalfMoveClock ?? 0;
  }

  bool get isInCheck => _isKingInCheck(_currentTurn);

  // ═══════════════════════════════════════════
  // MOVE GENERATION
  // ═══════════════════════════════════════════
  List<Move> _getLegalMoves(Square from, ChessPiece piece) {
    final pseudoLegal = _getPseudoLegalMoves(from, piece);
    return pseudoLegal.where((m) => !_wouldLeaveKingInCheck(m)).toList();
  }

  List<Move> _getPseudoLegalMoves(Square from, ChessPiece piece) {
    return switch (piece.type) {
      PieceType.pawn   => _pawnMoves(from, piece.color),
      PieceType.rook   => _slidingMoves(from, piece.color, [[0,1],[0,-1],[1,0],[-1,0]]),
      PieceType.bishop => _slidingMoves(from, piece.color, [[1,1],[1,-1],[-1,1],[-1,-1]]),
      PieceType.queen  => _slidingMoves(from, piece.color, [[0,1],[0,-1],[1,0],[-1,0],[1,1],[1,-1],[-1,1],[-1,-1]]),
      PieceType.knight => _knightMoves(from, piece.color),
      PieceType.king   => _kingMoves(from, piece.color),
    };
  }

  List<Move> _pawnMoves(Square from, PieceColor color) {
    final moves = <Move>[];
    final dir = color == PieceColor.white ? 1 : -1;
    final startRank = color == PieceColor.white ? 1 : 6;
    final promoRank = color == PieceColor.white ? 6 : 1;

    // Forward single
    final fwd = Square(from.file, from.rank + dir);
    if (fwd.isValid && _board[fwd.rank][fwd.file] == null) {
      _addPawnMove(moves, from, fwd, color, from.rank == promoRank);

      // Forward double from starting position
      if (from.rank == startRank) {
        final fwd2 = Square(from.file, from.rank + 2 * dir);
        if (fwd2.isValid && _board[fwd2.rank][fwd2.file] == null) {
          moves.add(Move(from: from, to: fwd2));
        }
      }
    }

    // Captures
    for (final df in [-1, 1]) {
      final target = Square(from.file + df, from.rank + dir);
      if (!target.isValid) continue;

      final targetPiece = _board[target.rank][target.file];
      if (targetPiece != null && targetPiece.color != color) {
        _addPawnMove(moves, from, target, color, from.rank == promoRank,
            capturedPiece: targetPiece);
      }

      // En passant
      if (_enPassantTarget == target) {
        final ep = Move(
          from: from, to: target, isEnPassant: true,
          capturedPiece: ChessPiece(type: PieceType.pawn, color: _opponent(color)),
        );
        moves.add(ep);
      }
    }
    return moves;
  }

  void _addPawnMove(List<Move> moves, Square from, Square to, PieceColor color,
      bool isPromoRank, {ChessPiece? capturedPiece}) {
    if (isPromoRank) {
      for (final promo in [PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight]) {
        moves.add(Move(from: from, to: to, promotion: promo, capturedPiece: capturedPiece));
      }
    } else {
      moves.add(Move(from: from, to: to, capturedPiece: capturedPiece));
    }
  }

  List<Move> _slidingMoves(Square from, PieceColor color, List<List<int>> dirs) {
    final moves = <Move>[];
    for (final dir in dirs) {
      var cur = from + dir;
      while (cur.isValid) {
        final p = _board[cur.rank][cur.file];
        if (p == null) {
          moves.add(Move(from: from, to: cur));
        } else {
          if (p.color != color) {
            moves.add(Move(from: from, to: cur, capturedPiece: p));
          }
          break;
        }
        cur = cur + dir;
      }
    }
    return moves;
  }

  List<Move> _knightMoves(Square from, PieceColor color) {
    final deltas = [[2,1],[2,-1],[-2,1],[-2,-1],[1,2],[1,-2],[-1,2],[-1,-2]];
    final moves = <Move>[];
    for (final d in deltas) {
      final to = from + d;
      if (!to.isValid) continue;
      final p = _board[to.rank][to.file];
      if (p == null || p.color != color) {
        moves.add(Move(from: from, to: to, capturedPiece: p));
      }
    }
    return moves;
  }

  List<Move> _kingMoves(Square from, PieceColor color) {
    final deltas = [[0,1],[0,-1],[1,0],[-1,0],[1,1],[1,-1],[-1,1],[-1,-1]];
    final moves = <Move>[];
    for (final d in deltas) {
      final to = from + d;
      if (!to.isValid) continue;
      final p = _board[to.rank][to.file];
      if (p == null || p.color != color) {
        moves.add(Move(from: from, to: to, capturedPiece: p));
      }
    }
    // Castling
    moves.addAll(_castlingMoves(from, color));
    return moves;
  }

  List<Move> _castlingMoves(Square from, PieceColor color) {
    final moves = <Move>[];
    final rank = color == PieceColor.white ? 0 : 7;
    if (from.rank != rank || from.file != 4) return moves;
    if (_isKingInCheck(color)) return moves;

    // Kingside
    final ks = color == PieceColor.white ? _whiteKingsideCastle : _blackKingsideCastle;
    if (ks && _board[rank][5] == null && _board[rank][6] == null &&
        !_isSquareAttacked(Square(5, rank), _opponent(color)) &&
        !_isSquareAttacked(Square(6, rank), _opponent(color))) {
      moves.add(Move(from: from, to: Square(6, rank), isCastle: true));
    }

    // Queenside
    final qs = color == PieceColor.white ? _whiteQueensideCastle : _blackQueensideCastle;
    if (qs && _board[rank][3] == null && _board[rank][2] == null && _board[rank][1] == null &&
        !_isSquareAttacked(Square(3, rank), _opponent(color)) &&
        !_isSquareAttacked(Square(2, rank), _opponent(color))) {
      moves.add(Move(from: from, to: Square(2, rank), isCastle: true));
    }

    return moves;
  }

  // ═══════════════════════════════════════════
  // MOVE APPLICATION
  // ═══════════════════════════════════════════
  void applyMoveInternal(Move move) {
    final piece = _board[move.from.rank][move.from.file]!;
    
    // Capture state for unmaking
    move.prevEnPassant = _enPassantTarget;
    move.prevWhiteKingside = _whiteKingsideCastle;
    move.prevWhiteQueenside = _whiteQueensideCastle;
    move.prevBlackKingside = _blackKingsideCastle;
    move.prevBlackQueenside = _blackQueensideCastle;
    move.prevHalfMoveClock = _halfMoveClock;

    _enPassantTarget = null;

    // Handle castling rook
    if (move.isCastle) {
      final rank = move.from.rank;
      final kingside = move.to.file == 6;
      final rookFromFile = kingside ? 7 : 0;
      final rookToFile = kingside ? 5 : 3;
      _board[rank][rookToFile] = _board[rank][rookFromFile];
      _board[rank][rookFromFile] = null;
      _board[rank][rookToFile]!.hasMoved = true;
    }

    // En passant capture
    if (move.isEnPassant) {
      final captureRank = move.from.rank;
      _board[captureRank][move.to.file] = null;
    }

    // Promotion
    final movedPiece = move.promotion != null
        ? ChessPiece(type: move.promotion!, color: piece.color, hasMoved: true)
        : piece..hasMoved = true;

    _board[move.to.rank][move.to.file] = movedPiece;
    _board[move.from.rank][move.from.file] = null;

    // Double pawn push → set en passant target
    if (piece.type == PieceType.pawn && (move.to.rank - move.from.rank).abs() == 2) {
      _enPassantTarget = Square(move.from.file, (move.from.rank + move.to.rank) ~/ 2);
    }

    // Update castling rights
    _updateCastlingRights(move, piece);

    // Clock updates
    if (piece.type == PieceType.pawn || move.capturedPiece != null) {
      _halfMoveClock = 0;
    } else {
      _halfMoveClock++;
    }
    
    if (_currentTurn == PieceColor.black) _fullMoveNumber++;

    _moveHistory.add(move);
    _currentTurn = _opponent(_currentTurn);
    _positionHistory.add(toFEN());
  }

  void _updateCastlingRights(Move move, ChessPiece piece) {
    if (piece.type == PieceType.king) {
      if (piece.color == PieceColor.white) {
        _whiteKingsideCastle = false;
        _whiteQueensideCastle = false;
      } else {
        _blackKingsideCastle = false;
        _blackQueensideCastle = false;
      }
    }
    if (piece.type == PieceType.rook) {
      if (move.from == const Square(7, 0)) _whiteKingsideCastle = false;
      if (move.from == const Square(0, 0)) _whiteQueensideCastle = false;
      if (move.from == const Square(7, 7)) _blackKingsideCastle = false;
      if (move.from == const Square(0, 7)) _blackQueensideCastle = false;
    }
  }

  void _resetCastlingRights() {
    _whiteKingsideCastle = true;
    _whiteQueensideCastle = true;
    _blackKingsideCastle = true;
    _blackQueensideCastle = true;
  }

  // ═══════════════════════════════════════════
  // STATUS CHECKS
  // ═══════════════════════════════════════════
  void _updateStatus() {
    final legal = allLegalMoves();
    final inCheck = _isKingInCheck(_currentTurn);

    if (legal.isEmpty) {
      if (inCheck) {
        _status = GameStatus.checkmate;
        _result = _currentTurn == PieceColor.white
            ? GameResult.blackWins : GameResult.whiteWins;
      } else {
        _status = GameStatus.stalemate;
        _result = GameResult.draw;
        _drawReason = DrawReason.stalemate;
      }
      return;
    }

    if (_halfMoveClock >= 100) {
      _status = GameStatus.draw;
      _result = GameResult.draw;
      _drawReason = DrawReason.fiftyMoveRule;
      return;
    }

    if (_isThreefoldRepetition()) {
      _status = GameStatus.draw;
      _result = GameResult.draw;
      _drawReason = DrawReason.threefoldRepetition;
      return;
    }

    if (_isInsufficientMaterial()) {
      _status = GameStatus.draw;
      _result = GameResult.draw;
      _drawReason = DrawReason.insufficientMaterial;
      return;
    }

    _status = inCheck ? GameStatus.check : GameStatus.active;
  }

  bool _isKingInCheck(PieceColor color) {
    Square? kingSquare;
    for (int r = 0; r < 8; r++) {
      for (int f = 0; f < 8; f++) {
        final p = _board[r][f];
        if (p != null && p.type == PieceType.king && p.color == color) {
          kingSquare = Square(f, r);
          break;
        }
      }
      if (kingSquare != null) break;
    }
    if (kingSquare == null) return false;
    return _isSquareAttacked(kingSquare, _opponent(color));
  }

  bool _isSquareAttacked(Square sq, PieceColor byColor) {
    // Check pawn attacks
    final pawnDir = byColor == PieceColor.white ? -1 : 1;
    for (final df in [-1, 1]) {
      final from = Square(sq.file + df, sq.rank + pawnDir);
      if (from.isValid) {
        final p = _board[from.rank][from.file];
        if (p != null && p.type == PieceType.pawn && p.color == byColor) return true;
      }
    }

    // Knight attacks
    for (final d in [[2,1],[2,-1],[-2,1],[-2,-1],[1,2],[1,-2],[-1,2],[-1,-2]]) {
      final from = sq + d;
      if (from.isValid) {
        final p = _board[from.rank][from.file];
        if (p != null && p.type == PieceType.knight && p.color == byColor) return true;
      }
    }

    // Sliding attacks (rook/queen)
    for (final dir in [[0,1],[0,-1],[1,0],[-1,0]]) {
      var cur = sq + dir;
      while (cur.isValid) {
        final p = _board[cur.rank][cur.file];
        if (p != null) {
          if (p.color == byColor && (p.type == PieceType.rook || p.type == PieceType.queen)) return true;
          break;
        }
        cur = cur + dir;
      }
    }

    // Diagonal attacks (bishop/queen)
    for (final dir in [[1,1],[1,-1],[-1,1],[-1,-1]]) {
      var cur = sq + dir;
      while (cur.isValid) {
        final p = _board[cur.rank][cur.file];
        if (p != null) {
          if (p.color == byColor && (p.type == PieceType.bishop || p.type == PieceType.queen)) return true;
          break;
        }
        cur = cur + dir;
      }
    }

    // King attacks
    for (final d in [[0,1],[0,-1],[1,0],[-1,0],[1,1],[1,-1],[-1,1],[-1,-1]]) {
      final from = sq + d;
      if (from.isValid) {
        final p = _board[from.rank][from.file];
        if (p != null && p.type == PieceType.king && p.color == byColor) return true;
      }
    }
    return false;
  }

  bool _wouldLeaveKingInCheck(Move move) {
    // Simulate the move
    final savedBoard = _board.map((r) => List<ChessPiece?>.from(r)).toList();
    final savedEP = _enPassantTarget;

    _simulateMove(move);
    // Validate that the moving side does not leave its own king in check.
    final inCheck = _isKingInCheck(_currentTurn);

    // Restore
    _board = savedBoard;
    _enPassantTarget = savedEP;
    return inCheck;
  }

  void _simulateMove(Move move) {
    final piece = _board[move.from.rank][move.from.file]!;
    if (move.isEnPassant) {
      _board[move.from.rank][move.to.file] = null;
    }
    if (move.isCastle) {
      final rank = move.from.rank;
      final kingside = move.to.file == 6;
      _board[rank][kingside ? 5 : 3] = _board[rank][kingside ? 7 : 0];
      _board[rank][kingside ? 7 : 0] = null;
    }
    _board[move.to.rank][move.to.file] =
        move.promotion != null ? ChessPiece(type: move.promotion!, color: piece.color) : piece;
    _board[move.from.rank][move.from.file] = null;
  }

  bool _isThreefoldRepetition() {
    if (_positionHistory.length < 9) return false;
    final current = _positionHistory.last;
    int count = _positionHistory.where((p) => p == current).length;
    return count >= 3;
  }

  bool _isInsufficientMaterial() {
    final pieces = <ChessPiece>[];
    for (int r = 0; r < 8; r++) {
      for (int f = 0; f < 8; f++) {
        if (_board[r][f] != null) pieces.add(_board[r][f]!);
      }
    }
    if (pieces.length == 2) return true; // K vs K
    if (pieces.length == 3) {
      return pieces.any((p) => p.type == PieceType.knight || p.type == PieceType.bishop);
    }
    return false;
  }

  Square _findKing(PieceColor color) {
    for (int r = 0; r < 8; r++) {
      for (int f = 0; f < 8; f++) {
        final p = _board[r][f];
        if (p != null && p.type == PieceType.king && p.color == color) {
          return Square(f, r);
        }
      }
    }
    throw StateError('King not found');
  }

  PieceColor _opponent(PieceColor color) =>
      color == PieceColor.white ? PieceColor.black : PieceColor.white;

  // ═══════════════════════════════════════════
  // ALGEBRAIC NOTATION
  // ═══════════════════════════════════════════
  String _buildAlgebraic(Move move, ChessPiece piece) {
    if (move.isCastle) {
      return move.to.file == 6 ? 'O-O' : 'O-O-O';
    }
    final buf = StringBuffer();
    if (piece.type != PieceType.pawn) {
      buf.write(piece.toFEN().toUpperCase());
    }
    if (move.capturedPiece != null || move.isEnPassant) {
      if (piece.type == PieceType.pawn) buf.write(move.from.toAlgebraic()[0]);
      buf.write('x');
    }
    buf.write(move.to.toAlgebraic());
    if (move.promotion != null) {
      buf.write('=${ChessPiece(type: move.promotion!, color: piece.color).toFEN().toUpperCase()}');
    }
    return buf.toString();
  }

  // ═══════════════════════════════════════════
  // FEN
  // ═══════════════════════════════════════════
  String toFEN() {
    final buf = StringBuffer();
    for (int r = 7; r >= 0; r--) {
      int empty = 0;
      for (int f = 0; f < 8; f++) {
        final p = _board[r][f];
        if (p == null) {
          empty++;
        } else {
          if (empty > 0) { buf.write(empty); empty = 0; }
          buf.write(p.toFEN());
        }
      }
      if (empty > 0) buf.write(empty);
      if (r > 0) buf.write('/');
    }
    buf.write(' ');
    buf.write(_currentTurn == PieceColor.white ? 'w' : 'b');
    buf.write(' ');

    final castle = StringBuffer();
    if (_whiteKingsideCastle) castle.write('K');
    if (_whiteQueensideCastle) castle.write('Q');
    if (_blackKingsideCastle) castle.write('k');
    if (_blackQueensideCastle) castle.write('q');
    buf.write(castle.isEmpty ? '-' : castle.toString());

    buf.write(' ');
    buf.write(_enPassantTarget?.toAlgebraic() ?? '-');
    buf.write(' $_halfMoveClock $_fullMoveNumber');
    return buf.toString();
  }

  void _parseFEN(String fen) {
    _board = List.generate(8, (_) => List.filled(8, null));
    final parts = fen.split(' ');
    final rows = parts[0].split('/');

    for (int r = 0; r < 8; r++) {
      int f = 0;
      for (final c in rows[7 - r].split('')) {
        if (RegExp(r'\d').hasMatch(c)) {
          f += int.parse(c);
        } else {
          final color = c == c.toUpperCase() ? PieceColor.white : PieceColor.black;
          final type = switch (c.toLowerCase()) {
            'p' => PieceType.pawn,
            'r' => PieceType.rook,
            'n' => PieceType.knight,
            'b' => PieceType.bishop,
            'q' => PieceType.queen,
            'k' => PieceType.king,
            _ => throw ArgumentError('Invalid FEN piece: $c'),
          };
          _board[r][f] = ChessPiece(type: type, color: color);
          f++;
        }
      }
    }

    _currentTurn = parts[1] == 'w' ? PieceColor.white : PieceColor.black;

    final castle = parts[2];
    _whiteKingsideCastle = castle.contains('K');
    _whiteQueensideCastle = castle.contains('Q');
    _blackKingsideCastle = castle.contains('k');
    _blackQueensideCastle = castle.contains('q');

    _enPassantTarget = parts[3] != '-' ? _parseAlgebraic(parts[3]) : null;
    _halfMoveClock = int.parse(parts[4]);
    _fullMoveNumber = int.parse(parts[5]);
  }

  Square _parseAlgebraic(String s) =>
      Square(s.codeUnitAt(0) - 97, int.parse(s[1]) - 1);

  /// Export game as PGN string
  String toPGN({
    String? white, String? black, String? event, String? date,
  }) {
    final buf = StringBuffer();
    buf.writeln('[Event "${event ?? "Chess Master Game"}"]');
    buf.writeln('[Date "${date ?? DateTime.now().toString().substring(0, 10)}"]');
    buf.writeln('[White "${white ?? "White"}"]');
    buf.writeln('[Black "${black ?? "Black"}"]');
    buf.writeln('[Result "${_pgnResult()}"]');
    buf.writeln();

    int moveNum = 1;
    for (int i = 0; i < _moveHistory.length; i++) {
      if (i % 2 == 0) buf.write('$moveNum. ');
      buf.write('${_moveHistory[i].algebraic ?? "?"} ');
      if (i % 2 == 1) moveNum++;
    }
    buf.write(_pgnResult());
    return buf.toString();
  }

  String _pgnResult() => switch (_result) {
    GameResult.whiteWins => '1-0',
    GameResult.blackWins => '0-1',
    GameResult.draw => '1/2-1/2',
    GameResult.ongoing => '*',
  };
}
