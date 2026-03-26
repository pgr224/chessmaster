/**
 * Sunfish Engine — Lightweight JS Chess AI
 * Used for Basic & Intermediate difficulty modes.
 * Implements mailbox board representation with alpha-beta minimax search.
 * Target: <200ms response time at depth 1-5.
 */

// ═══════════════════════════════════════════════════
// PIECE ENCODING & CONSTANTS
// ═══════════════════════════════════════════════════
const EMPTY = 0;
const PAWN = 1, KNIGHT = 2, BISHOP = 3, ROOK = 4, QUEEN = 5, KING = 6;
const WHITE = 16, BLACK = 32;

// Mailbox 10x12 board representation (border cells = -1)
const BOARD_SIZE = 120;
const A1 = 21, H1 = 28, A8 = 91, H8 = 98;

// Piece values
const PIECE_VALUES = { [PAWN]: 100, [KNIGHT]: 320, [BISHOP]: 330, [ROOK]: 500, [QUEEN]: 900, [KING]: 20000 };

// Move deltas per piece type
const PIECE_DELTAS = {
  [PAWN]: null, // handled specially
  [KNIGHT]: [-21, -19, -12, -8, 8, 12, 19, 21],
  [BISHOP]: [-11, -9, 9, 11],
  [ROOK]:   [-10, -1, 1, 10],
  [QUEEN]:  [-11, -9, -10, -1, 1, 9, 10, 11],
  [KING]:   [-11, -9, -10, -1, 1, 9, 10, 11],
};

const SLIDING = { [BISHOP]: true, [ROOK]: true, [QUEEN]: true };

// Piece-square tables (from White's perspective, indexed 0-63)
const PST_PAWN = [
  0,  0,  0,  0,  0,  0,  0,  0,
  50, 50, 50, 50, 50, 50, 50, 50,
  10, 10, 20, 30, 30, 20, 10, 10,
  5,  5, 10, 25, 25, 10,  5,  5,
  0,  0,  0, 20, 20,  0,  0,  0,
  5, -5,-10,  0,  0,-10, -5,  5,
  5, 10, 10,-20,-20, 10, 10,  5,
  0,  0,  0,  0,  0,  0,  0,  0,
];

const PST_KNIGHT = [
  -50,-40,-30,-30,-30,-30,-40,-50,
  -40,-20,  0,  0,  0,  0,-20,-40,
  -30,  0, 10, 15, 15, 10,  0,-30,
  -30,  5, 15, 20, 20, 15,  5,-30,
  -30,  0, 15, 20, 20, 15,  0,-30,
  -30,  5, 10, 15, 15, 10,  5,-30,
  -40,-20,  0,  5,  5,  0,-20,-40,
  -50,-40,-30,-30,-30,-30,-40,-50,
];

const PST_BISHOP = [
  -20,-10,-10,-10,-10,-10,-10,-20,
  -10,  0,  0,  0,  0,  0,  0,-10,
  -10,  0,  5, 10, 10,  5,  0,-10,
  -10,  5,  5, 10, 10,  5,  5,-10,
  -10,  0, 10, 10, 10, 10,  0,-10,
  -10, 10, 10, 10, 10, 10, 10,-10,
  -10,  5,  0,  0,  0,  0,  5,-10,
  -20,-10,-10,-10,-10,-10,-10,-20,
];

const PST_ROOK = [
  0,  0,  0,  0,  0,  0,  0,  0,
  5, 10, 10, 10, 10, 10, 10,  5,
 -5,  0,  0,  0,  0,  0,  0, -5,
 -5,  0,  0,  0,  0,  0,  0, -5,
 -5,  0,  0,  0,  0,  0,  0, -5,
 -5,  0,  0,  0,  0,  0,  0, -5,
 -5,  0,  0,  0,  0,  0,  0, -5,
  0,  0,  0,  5,  5,  0,  0,  0,
];

const PST_QUEEN = [
  -20,-10,-10, -5, -5,-10,-10,-20,
  -10,  0,  0,  0,  0,  0,  0,-10,
  -10,  0,  5,  5,  5,  5,  0,-10,
   -5,  0,  5,  5,  5,  5,  0, -5,
    0,  0,  5,  5,  5,  5,  0, -5,
  -10,  5,  5,  5,  5,  5,  0,-10,
  -10,  0,  5,  0,  0,  0,  0,-10,
  -20,-10,-10, -5, -5,-10,-10,-20,
];

const PST_KING_MID = [
  -30,-40,-40,-50,-50,-40,-40,-30,
  -30,-40,-40,-50,-50,-40,-40,-30,
  -30,-40,-40,-50,-50,-40,-40,-30,
  -30,-40,-40,-50,-50,-40,-40,-30,
  -20,-30,-30,-40,-40,-30,-30,-20,
  -10,-20,-20,-20,-20,-20,-20,-10,
   20, 20,  0,  0,  0,  0, 20, 20,
   20, 30, 10,  0,  0, 10, 30, 20,
];

const PST = {
  [PAWN]: PST_PAWN, [KNIGHT]: PST_KNIGHT, [BISHOP]: PST_BISHOP,
  [ROOK]: PST_ROOK, [QUEEN]: PST_QUEEN, [KING]: PST_KING_MID,
};

// ═══════════════════════════════════════════════════
// BOARD STATE
// ═══════════════════════════════════════════════════
class SunfishBoard {
  constructor() {
    this.board = new Int8Array(BOARD_SIZE).fill(-1); // -1 = off-board
    this.turn = WHITE; // WHITE or BLACK
    this.castling = { wk: true, wq: true, bk: true, bq: true };
    this.epSquare = -1;
    this.halfmove = 0;
    this.fullmove = 1;
  }

  /**
   * Convert mailbox index to 0-63 index for PST lookup
   */
  static to64(sq) {
    const r = Math.floor(sq / 10) - 2; // 0-7
    const f = (sq % 10) - 1;           // 0-7
    return (7 - r) * 8 + f;
  }

  /**
   * Convert 0-63 to mailbox index
   */
  static from64(i64) {
    const r = 7 - Math.floor(i64 / 8);
    const f = i64 % 8;
    return (r + 2) * 10 + f + 1;
  }

  /**
   * Convert algebraic (e.g. "e2") to mailbox index
   */
  static fromAlg(alg) {
    const f = alg.charCodeAt(0) - 97; // 0-7
    const r = parseInt(alg[1]) - 1;   // 0-7
    return (r + 2) * 10 + f + 1;
  }

  /**
   * Convert mailbox index to algebraic
   */
  static toAlg(sq) {
    const f = (sq % 10) - 1;
    const r = Math.floor(sq / 10) - 2;
    return String.fromCharCode(97 + f) + (r + 1);
  }

  /**
   * Load position from FEN string
   */
  loadFEN(fen) {
    this.board.fill(-1);
    const parts = fen.split(' ');
    const rows = parts[0].split('/');

    for (let rank = 0; rank < 8; rank++) {
      let file = 0;
      for (const ch of rows[7 - rank]) {
        if (ch >= '1' && ch <= '8') {
          for (let i = 0; i < parseInt(ch); i++) {
            this.board[(rank + 2) * 10 + file + 1] = EMPTY;
            file++;
          }
        } else {
          const color = ch === ch.toUpperCase() ? WHITE : BLACK;
          const pieceChar = ch.toLowerCase();
          const type = { p: PAWN, n: KNIGHT, b: BISHOP, r: ROOK, q: QUEEN, k: KING }[pieceChar];
          this.board[(rank + 2) * 10 + file + 1] = color | type;
          file++;
        }
      }
    }

    this.turn = parts[1] === 'w' ? WHITE : BLACK;
    const c = parts[2] || 'KQkq';
    this.castling = { wk: c.includes('K'), wq: c.includes('Q'), bk: c.includes('k'), bq: c.includes('q') };
    this.epSquare = parts[3] && parts[3] !== '-' ? SunfishBoard.fromAlg(parts[3]) : -1;
    this.halfmove = parseInt(parts[4] || '0');
    this.fullmove = parseInt(parts[5] || '1');
  }

  /**
   * Clone the board state
   */
  clone() {
    const b = new SunfishBoard();
    b.board = new Int8Array(this.board);
    b.turn = this.turn;
    b.castling = { ...this.castling };
    b.epSquare = this.epSquare;
    b.halfmove = this.halfmove;
    b.fullmove = this.fullmove;
    return b;
  }

  /**
   * Get the piece color at a square (WHITE, BLACK, or 0 for empty)
   */
  colorAt(sq) { return this.board[sq] & 48; }

  /**
   * Get the piece type at a square
   */
  typeAt(sq) { return this.board[sq] & 7; }

  /**
   * Generate all pseudo-legal moves for current side
   */
  generateMoves() {
    const moves = [];
    const us = this.turn;
    const them = us === WHITE ? BLACK : WHITE;

    for (let sq = A1; sq <= H8; sq++) {
      if (this.board[sq] === -1 || this.board[sq] === EMPTY) continue;
      if (this.colorAt(sq) !== us) continue;

      const type = this.typeAt(sq);

      if (type === PAWN) {
        const dir = us === WHITE ? 10 : -10;
        const startRank = us === WHITE ? 3 : 8; // mailbox rank
        const promoRank = us === WHITE ? 9 : 2;
        const rank = Math.floor(sq / 10);

        // Single push
        const fwd = sq + dir;
        if (this.board[fwd] === EMPTY) {
          if (Math.floor(fwd / 10) === promoRank) {
            for (const promo of [QUEEN, ROOK, BISHOP, KNIGHT]) {
              moves.push({ from: sq, to: fwd, promo });
            }
          } else {
            moves.push({ from: sq, to: fwd, promo: 0 });
          }
          // Double push
          if (rank === startRank) {
            const fwd2 = sq + 2 * dir;
            if (this.board[fwd2] === EMPTY) {
              moves.push({ from: sq, to: fwd2, promo: 0 });
            }
          }
        }
        // Captures
        for (const df of [dir - 1, dir + 1]) {
          const to = sq + df;
          if (this.board[to] === -1) continue;
          if ((this.board[to] !== EMPTY && this.colorAt(to) === them) || to === this.epSquare) {
            if (Math.floor(to / 10) === promoRank) {
              for (const promo of [QUEEN, ROOK, BISHOP, KNIGHT]) {
                moves.push({ from: sq, to, promo });
              }
            } else {
              moves.push({ from: sq, to, promo: 0 });
            }
          }
        }
      } else {
        const deltas = PIECE_DELTAS[type];
        for (const d of deltas) {
          let to = sq + d;
          while (true) {
            if (this.board[to] === -1) break; // off board
            if (this.board[to] !== EMPTY) {
              if (this.colorAt(to) === them) {
                moves.push({ from: sq, to, promo: 0 });
              }
              break;
            }
            moves.push({ from: sq, to, promo: 0 });
            if (!SLIDING[type]) break;
            to += d;
          }
        }
      }
    }

    // Castling
    if (us === WHITE) {
      if (this.castling.wk && this.board[26] === EMPTY && this.board[27] === EMPTY &&
          !this.isAttacked(25, them) && !this.isAttacked(26, them) && !this.isAttacked(27, them)) {
        moves.push({ from: 25, to: 27, promo: 0, castle: 'wk' });
      }
      if (this.castling.wq && this.board[24] === EMPTY && this.board[23] === EMPTY && this.board[22] === EMPTY &&
          !this.isAttacked(25, them) && !this.isAttacked(24, them) && !this.isAttacked(23, them)) {
        moves.push({ from: 25, to: 23, promo: 0, castle: 'wq' });
      }
    } else {
      if (this.castling.bk && this.board[96] === EMPTY && this.board[97] === EMPTY &&
          !this.isAttacked(95, them) && !this.isAttacked(96, them) && !this.isAttacked(97, them)) {
        moves.push({ from: 95, to: 97, promo: 0, castle: 'bk' });
      }
      if (this.castling.bq && this.board[94] === EMPTY && this.board[93] === EMPTY && this.board[92] === EMPTY &&
          !this.isAttacked(95, them) && !this.isAttacked(94, them) && !this.isAttacked(93, them)) {
        moves.push({ from: 95, to: 93, promo: 0, castle: 'bq' });
      }
    }

    return moves;
  }

  /**
   * Check if a square is attacked by the given color
   */
  isAttacked(sq, byColor) {
    // Knight attacks
    for (const d of PIECE_DELTAS[KNIGHT]) {
      const from = sq + d;
      if (this.board[from] !== -1 && this.colorAt(from) === byColor && this.typeAt(from) === KNIGHT) return true;
    }
    // King attacks
    for (const d of PIECE_DELTAS[KING]) {
      const from = sq + d;
      if (this.board[from] !== -1 && this.colorAt(from) === byColor && this.typeAt(from) === KING) return true;
    }
    // Pawn attacks
    const pawnDir = byColor === WHITE ? -10 : 10;
    for (const df of [pawnDir - 1, pawnDir + 1]) {
      const from = sq + df;
      if (this.board[from] !== -1 && this.colorAt(from) === byColor && this.typeAt(from) === PAWN) return true;
    }
    // Sliding attacks (rook/queen on ranks/files, bishop/queen on diagonals)
    for (const d of [-10, -1, 1, 10]) {
      let s = sq + d;
      while (this.board[s] !== -1) {
        if (this.board[s] !== EMPTY) {
          if (this.colorAt(s) === byColor) {
            const t = this.typeAt(s);
            if (t === ROOK || t === QUEEN) return true;
          }
          break;
        }
        s += d;
      }
    }
    for (const d of [-11, -9, 9, 11]) {
      let s = sq + d;
      while (this.board[s] !== -1) {
        if (this.board[s] !== EMPTY) {
          if (this.colorAt(s) === byColor) {
            const t = this.typeAt(s);
            if (t === BISHOP || t === QUEEN) return true;
          }
          break;
        }
        s += d;
      }
    }
    return false;
  }

  /**
   * Find king square for given color
   */
  findKing(color) {
    for (let sq = A1; sq <= H8; sq++) {
      if (this.board[sq] !== -1 && this.board[sq] !== EMPTY &&
          this.colorAt(sq) === color && this.typeAt(sq) === KING) return sq;
    }
    return -1;
  }

  /**
   * Make a move (mutates board)
   */
  makeMove(move) {
    const piece = this.board[move.from];
    const type = piece & 7;
    const us = this.turn;
    const them = us === WHITE ? BLACK : WHITE;

    // En passant capture
    if (type === PAWN && move.to === this.epSquare) {
      const capSq = move.to + (us === WHITE ? -10 : 10);
      this.board[capSq] = EMPTY;
    }

    // Move piece
    this.board[move.to] = move.promo ? (us | move.promo) : piece;
    this.board[move.from] = EMPTY;

    // Castling rook move
    if (move.castle) {
      switch (move.castle) {
        case 'wk': this.board[26] = this.board[28]; this.board[28] = EMPTY; break;
        case 'wq': this.board[24] = this.board[21]; this.board[21] = EMPTY; break;
        case 'bk': this.board[96] = this.board[98]; this.board[98] = EMPTY; break;
        case 'bq': this.board[94] = this.board[91]; this.board[91] = EMPTY; break;
      }
    }

    // Update en passant square
    if (type === PAWN && Math.abs(move.to - move.from) === 20) {
      this.epSquare = (move.from + move.to) / 2;
    } else {
      this.epSquare = -1;
    }

    // Update castling rights
    if (type === KING) {
      if (us === WHITE) { this.castling.wk = false; this.castling.wq = false; }
      else { this.castling.bk = false; this.castling.bq = false; }
    }
    if (type === ROOK) {
      if (move.from === 21) this.castling.wq = false;
      if (move.from === 28) this.castling.wk = false;
      if (move.from === 91) this.castling.bq = false;
      if (move.from === 98) this.castling.bk = false;
    }
    // If a rook is captured
    if (move.to === 21) this.castling.wq = false;
    if (move.to === 28) this.castling.wk = false;
    if (move.to === 91) this.castling.bq = false;
    if (move.to === 98) this.castling.bk = false;

    this.turn = them;
    if (us === BLACK) this.fullmove++;
  }

  /**
   * Generate only legal moves (filter out moves that leave king in check)
   */
  legalMoves() {
    const pseudo = this.generateMoves();
    const legal = [];
    const us = this.turn;
    for (const move of pseudo) {
      const clone = this.clone();
      clone.makeMove(move);
      // After making move, check if OUR king is in check
      const kingSq = clone.findKing(us);
      if (kingSq !== -1 && !clone.isAttacked(kingSq, clone.turn)) {
        legal.push(move);
      }
    }
    return legal;
  }
}

// ═══════════════════════════════════════════════════
// SEARCH ENGINE — Alpha-Beta with Iterative Deepening
// ═══════════════════════════════════════════════════

// Transposition table
const TT = new Map();
const TT_MAX = 100000;

function evaluate(board) {
  let score = 0;
  for (let sq = A1; sq <= H8; sq++) {
    if (board.board[sq] <= 0) continue;
    const color = board.colorAt(sq);
    const type = board.typeAt(sq);
    if (!type) continue;

    const val = PIECE_VALUES[type] || 0;
    const i64 = SunfishBoard.to64(sq);
    const pstIdx = color === WHITE ? i64 : (63 - i64);
    const pst = PST[type] ? (PST[type][pstIdx] || 0) : 0;

    score += color === WHITE ? (val + pst) : -(val + pst);
  }
  return board.turn === WHITE ? score : -score;
}

function quiescence(board, alpha, beta) {
  const standPat = evaluate(board);
  if (standPat >= beta) return beta;
  if (alpha < standPat) alpha = standPat;

  const moves = board.legalMoves().filter(m => board.board[m.to] !== EMPTY || m.to === board.epSquare);
  // MVV-LVA ordering for captures
  moves.sort((a, b) => {
    const va = board.board[a.to] !== EMPTY ? (PIECE_VALUES[board.typeAt(a.to)] || 0) : 0;
    const vb = board.board[b.to] !== EMPTY ? (PIECE_VALUES[board.typeAt(b.to)] || 0) : 0;
    return vb - va;
  });

  for (const move of moves) {
    const clone = board.clone();
    clone.makeMove(move);
    const score = -quiescence(clone, -beta, -alpha);
    if (score >= beta) return beta;
    if (score > alpha) alpha = score;
  }
  return alpha;
}

function alphaBeta(board, depth, alpha, beta) {
  if (depth <= 0) return { score: quiescence(board, alpha, beta), move: null };

  const moves = board.legalMoves();
  if (moves.length === 0) {
    // Check or stalemate?
    const kingSq = board.findKing(board.turn);
    const them = board.turn === WHITE ? BLACK : WHITE;
    if (board.isAttacked(kingSq, them)) {
      return { score: -100000 - depth, move: null }; // Checkmate
    }
    return { score: 0, move: null }; // Stalemate
  }

  // Move ordering: captures first, then TT move
  moves.sort((a, b) => {
    const capA = board.board[a.to] !== EMPTY ? (PIECE_VALUES[board.typeAt(a.to)] || 0) : 0;
    const capB = board.board[b.to] !== EMPTY ? (PIECE_VALUES[board.typeAt(b.to)] || 0) : 0;
    return capB - capA;
  });

  let bestMove = moves[0];
  let bestScore = -999999;

  for (const move of moves) {
    const clone = board.clone();
    clone.makeMove(move);
    const result = alphaBeta(clone, depth - 1, -beta, -alpha);
    const score = -result.score;

    if (score > bestScore) {
      bestScore = score;
      bestMove = move;
    }
    alpha = Math.max(alpha, bestScore);
    if (alpha >= beta) break; // Prune
  }

  return { score: bestScore, move: bestMove };
}

/**
 * Main search function with iterative deepening
 * @param {string} fen - FEN position string
 * @param {number} maxDepth - Maximum search depth (1-5)
 * @param {number} timeoutMs - Maximum time in ms
 * @returns {{ move: string, score: number }}
 */
function searchBestMove(fen, maxDepth = 3, timeoutMs = 3000) {
  const board = new SunfishBoard();
  board.loadFEN(fen);

  const startTime = Date.now();
  let bestResult = null;

  // Clear TT if too large
  if (TT.size > TT_MAX) TT.clear();

  // Iterative deepening
  for (let depth = 1; depth <= maxDepth; depth++) {
    const elapsed = Date.now() - startTime;
    if (elapsed > timeoutMs && depth > 1) break;

    const result = alphaBeta(board, depth, -999999, 999999);
    if (result.move) bestResult = result;
  }

  if (!bestResult || !bestResult.move) {
    // Fallback: random legal move
    const moves = board.legalMoves();
    if (moves.length === 0) return null;
    const m = moves[Math.floor(Math.random() * moves.length)];
    return {
      move: SunfishBoard.toAlg(m.from) + SunfishBoard.toAlg(m.to) + promoChar(m.promo),
      score: 0,
    };
  }

  const m = bestResult.move;
  return {
    move: SunfishBoard.toAlg(m.from) + SunfishBoard.toAlg(m.to) + promoChar(m.promo),
    score: bestResult.score,
  };
}

function promoChar(promo) {
  if (!promo) return '';
  return { [QUEEN]: 'q', [ROOK]: 'r', [BISHOP]: 'b', [KNIGHT]: 'n' }[promo] || '';
}

// Export for use in Worker
if (typeof self !== 'undefined' && typeof self.searchBestMove === 'undefined') {
  self.searchBestMove = searchBestMove;
  self.SunfishBoard = SunfishBoard;
}
