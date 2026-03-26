/**
 * Chess Logic — Move validation & game state using chess.js-compatible logic
 * Used for Two Player and Multiplayer modes (no AI).
 *
 * This is a lightweight FIDE-compliant rule engine for:
 *   - Move validation
 *   - Game state detection (check, checkmate, stalemate, draw)
 *   - Legal move generation
 *
 * Implements chess.js-compatible API without external dependency.
 */

// Re-use SunfishBoard for move validation (it has full FIDE rules)
// This avoids an additional chess.js dependency while being fully compliant.

class ChessLogic {
  constructor() {
    this._board = null;
  }

  /**
   * Load a FEN position
   * @param {string} fen
   */
  load(fen) {
    if (!self.SunfishBoard) {
      // If running standalone, need sunfish_engine.js loaded
      throw new Error('SunfishBoard not available. Load sunfish_engine.js first.');
    }
    this._board = new self.SunfishBoard();
    this._board.loadFEN(fen);
  }

  /**
   * Validate if a move is legal
   * @param {string} fen - Current position FEN
   * @param {string} from - Source square (e.g. "e2")
   * @param {string} to - Target square (e.g. "e4")
   * @param {string|null} promotion - Promotion piece ('q','r','b','n') or null
   * @returns {boolean}
   */
  validateMove(fen, from, to, promotion) {
    this.load(fen);
    const legalMoves = this._board.legalMoves();
    const fromSq = self.SunfishBoard.fromAlg(from);
    const toSq = self.SunfishBoard.fromAlg(to);
    const promoType = promotion ? { q: 5, r: 4, b: 3, n: 2 }[promotion] : 0;

    return legalMoves.some(m =>
      m.from === fromSq && m.to === toSq &&
      (promoType === 0 ? (m.promo === 0 || m.promo === undefined) : m.promo === promoType)
    );
  }

  /**
   * Get all legal moves for a specific square
   * @param {string} fen
   * @param {string} square - e.g. "e2"
   * @returns {string[]} - Array of target squares
   */
  getLegalMoves(fen, square) {
    this.load(fen);
    const fromSq = self.SunfishBoard.fromAlg(square);
    const moves = this._board.legalMoves().filter(m => m.from === fromSq);
    return moves.map(m => self.SunfishBoard.toAlg(m.to));
  }

  /**
   * Get all legal moves for all pieces
   * @param {string} fen
   * @returns {string[]} - Array of "fromto" strings e.g. ["e2e4", "d2d4"]
   */
  getAllLegalMoves(fen) {
    this.load(fen);
    const moves = this._board.legalMoves();
    return moves.map(m => {
      const promo = m.promo ? ({ 5: 'q', 4: 'r', 3: 'b', 2: 'n' }[m.promo] || '') : '';
      return self.SunfishBoard.toAlg(m.from) + self.SunfishBoard.toAlg(m.to) + promo;
    });
  }

  /**
   * Get game state
   * @param {string} fen
   * @returns {{ status: string, turn: string, isCheck: boolean, isCheckmate: boolean, isStalemate: boolean, isDraw: boolean }}
   */
  getGameState(fen) {
    this.load(fen);
    const moves = this._board.legalMoves();
    const us = this._board.turn;
    const them = us === 16 ? 32 : 16; // WHITE=16, BLACK=32
    const kingSq = this._board.findKing(us);
    const inCheck = this._board.isAttacked(kingSq, them);
    const noMoves = moves.length === 0;

    let status = 'active';
    if (noMoves && inCheck) status = 'checkmate';
    else if (noMoves) status = 'stalemate';
    else if (inCheck) status = 'check';

    return {
      status,
      turn: us === 16 ? 'white' : 'black',
      isCheck: inCheck,
      isCheckmate: status === 'checkmate',
      isStalemate: status === 'stalemate',
      isDraw: status === 'stalemate',
    };
  }
}

// Export for use in Worker and engine_service.js
if (typeof self !== 'undefined') {
  self.ChessLogic = ChessLogic;
}
