/**
 * Engine Service — Unified façade for all chess engines
 * Exposed as window.ChessEngineService for Flutter JS interop.
 *
 * Routes to the correct engine based on mode/difficulty:
 *   - Basic/Intermediate → Sunfish Web Worker
 *   - Advanced/Impossible → Stockfish WASM Web Worker
 *   - TwoPlayer/Multiplayer → ChessLogic (validation only)
 */

(function () {
  'use strict';

  // ═══════════════════════════════════════
  // ENGINE TYPE CONSTANTS
  // ═══════════════════════════════════════
  const ENGINE_SUNFISH = 'sunfish';
  const ENGINE_STOCKFISH = 'stockfish';
  const ENGINE_VALIDATION = 'validation';

  // Depth config per difficulty
  const DEPTH_CONFIG = {
    basic: 2,
    intermediate: 4,
    advanced: 12,
    impossible: 20,
  };

  // Timeout config per engine (ms)
  const TIMEOUT_CONFIG = {
    [ENGINE_SUNFISH]: 3000,
    [ENGINE_STOCKFISH]: 8000,
  };

  // ═══════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════
  let activeEngine = null;    // 'sunfish' | 'stockfish' | 'validation'
  let sunfishWorker = null;
  let stockfishWorker = null;
  let chessLogic = null;
  let currentDifficulty = 'basic';
  let requestId = 0;
  let pendingResolve = null;
  let pendingTimeout = null;

  // ═══════════════════════════════════════
  // WORKER MANAGEMENT
  // ═══════════════════════════════════════

  function getWorkerBasePath() {
    // Resolve path relative to the current page
    const base = document.querySelector('base');
    const href = base ? base.getAttribute('href') : '/';
    return href + 'engine/';
  }

  function createSunfishWorker() {
    if (sunfishWorker) return sunfishWorker;
    const path = getWorkerBasePath() + 'sunfish.worker.js';
    sunfishWorker = new Worker(path);
    sunfishWorker.addEventListener('message', handleWorkerMessage);
    sunfishWorker.postMessage({ type: 'init' });
    return sunfishWorker;
  }

  function createStockfishWorker() {
    if (stockfishWorker) return stockfishWorker;
    const path = getWorkerBasePath() + 'stockfish.worker.js';
    stockfishWorker = new Worker(path);
    stockfishWorker.addEventListener('message', handleWorkerMessage);
    stockfishWorker.postMessage({ type: 'init' });
    return stockfishWorker;
  }

  function loadChessLogic() {
    if (chessLogic) return chessLogic;
    // chess_logic.js and sunfish_engine.js are loaded via script tags in index.html
    if (typeof ChessLogic !== 'undefined') {
      chessLogic = new ChessLogic();
    } else {
      console.warn('[EngineService] ChessLogic not loaded; validation unavailable');
    }
    return chessLogic;
  }

  function handleWorkerMessage(e) {
    const msg = e.data;
    if (msg.type === 'bestmove' && pendingResolve) {
      clearTimeout(pendingTimeout);
      const resolve = pendingResolve;
      pendingResolve = null;
      pendingTimeout = null;
      resolve(msg.move || null);
    } else if (msg.type === 'error') {
      console.error('[EngineService] Worker error:', msg.message);
      if (pendingResolve) {
        clearTimeout(pendingTimeout);
        const resolve = pendingResolve;
        pendingResolve = null;
        pendingTimeout = null;
        resolve(null);
      }
    }
  }

  // ═══════════════════════════════════════
  // PUBLIC API (exposed as window.ChessEngineService)
  // ═══════════════════════════════════════

  const EngineService = {
    /**
     * Initialize the correct engine for a game session
     * @param {string} mode - 'singlePlayer', 'twoPlayer', 'multiplayer', 'tutorial', 'puzzle'
     * @param {string} difficulty - 'basic', 'intermediate', 'advanced', 'impossible'
     */
    initEngine(mode, difficulty) {
      currentDifficulty = difficulty || 'basic';

      if (mode === 'twoPlayer' || mode === 'multiplayer') {
        activeEngine = ENGINE_VALIDATION;
        loadChessLogic();
        console.log('[EngineService] Initialized: chess_logic (validation only)');
      } else if (difficulty === 'advanced' || difficulty === 'impossible') {
        activeEngine = ENGINE_STOCKFISH;
        createStockfishWorker();
        console.log(`[EngineService] Initialized: Stockfish WASM (depth ${DEPTH_CONFIG[difficulty]})`);
      } else {
        activeEngine = ENGINE_SUNFISH;
        createSunfishWorker();
        console.log(`[EngineService] Initialized: Sunfish (depth ${DEPTH_CONFIG[difficulty]})`);
      }
    },

    /**
     * Get the best move for the current position
     * @param {string} fen - FEN position string
     * @returns {Promise<string|null>} - Move in algebraic format (e.g. "e2e4") or null
     */
    getBestMove(fen) {
      return new Promise((resolve) => {
        const id = ++requestId;
        const depth = DEPTH_CONFIG[currentDifficulty] || 3;
        const timeout = TIMEOUT_CONFIG[activeEngine] || 5000;

        if (activeEngine === ENGINE_VALIDATION) {
          // No AI for multiplayer/two-player
          resolve(null);
          return;
        }

        // Cancel any pending request
        if (pendingResolve) {
          pendingResolve(null);
          clearTimeout(pendingTimeout);
        }

        pendingResolve = resolve;

        // Set timeout fallback
        pendingTimeout = setTimeout(() => {
          console.warn(`[EngineService] Search timeout (${timeout}ms) for request ${id}`);
          if (pendingResolve === resolve) {
            pendingResolve = null;
            resolve(null);
          }
        }, timeout);

        if (activeEngine === ENGINE_SUNFISH) {
          const worker = createSunfishWorker();
          worker.postMessage({ type: 'search', fen, depth, timeout });
        } else if (activeEngine === ENGINE_STOCKFISH) {
          const worker = createStockfishWorker();
          worker.postMessage({ type: 'search', fen, depth });
        }
      });
    },

    /**
     * Validate if a move is legal (used for multiplayer/two-player)
     * @param {string} fen
     * @param {string} from
     * @param {string} to
     * @param {string|null} promotion
     * @returns {boolean}
     */
    validateMove(fen, from, to, promotion) {
      const logic = loadChessLogic();
      if (!logic) return false;
      return logic.validateMove(fen, from, to, promotion);
    },

    /**
     * Get legal moves for a square
     * @param {string} fen
     * @param {string} square
     * @returns {string[]}
     */
    getLegalMoves(fen, square) {
      const logic = loadChessLogic();
      if (!logic) return [];
      return logic.getLegalMoves(fen, square);
    },

    /**
     * Get game state
     * @param {string} fen
     * @returns {{ status: string, turn: string, isCheck: boolean, isCheckmate: boolean, isStalemate: boolean, isDraw: boolean }}
     */
    getGameState(fen) {
      const logic = loadChessLogic();
      if (!logic) return { status: 'active', turn: 'white', isCheck: false, isCheckmate: false, isStalemate: false, isDraw: false };
      return logic.getGameState(fen);
    },

    /**
     * Get the currently active engine type
     * @returns {string}
     */
    getActiveEngine() {
      return activeEngine;
    },

    /**
     * Dispose all engine resources
     */
    dispose() {
      if (pendingResolve) {
        pendingResolve(null);
        clearTimeout(pendingTimeout);
        pendingResolve = null;
        pendingTimeout = null;
      }

      if (sunfishWorker) {
        sunfishWorker.terminate();
        sunfishWorker = null;
      }
      if (stockfishWorker) {
        stockfishWorker.postMessage({ type: 'quit' });
        setTimeout(() => {
          if (stockfishWorker) {
            stockfishWorker.terminate();
            stockfishWorker = null;
          }
        }, 200);
      }
      chessLogic = null;
      activeEngine = null;
      console.log('[EngineService] All engines disposed');
    },
  };

  // Expose globally for Flutter JS interop
  window.ChessEngineService = EngineService;

  console.log('[EngineService] Loaded — hybrid engine service ready');
})();
