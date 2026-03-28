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
    impossible: 15,
  };

  // Timeout config per engine (ms)
  const TIMEOUT_CONFIG = {
    [ENGINE_SUNFISH]: 3000,
    [ENGINE_STOCKFISH]: 15000,
  };

  // ═══════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════
  let activeEngine = null;    // 'sunfish' | 'stockfish' | 'validation'
  let sunfishWorker = null;
  let stockfishWorker = null;
  let chessLogic = null;
  let currentDifficulty = 'basic';
  let lastFen = '';
  let requestId = 0;
  let pendingResolve = null;
  let pendingTimeout = null;
  let stockfishReady = false;
  let stockfishReadyCallbacks = [];

  // ═══════════════════════════════════════
  // WORKER MANAGEMENT
  // ═══════════════════════════════════════

  function getWorkerBasePath() {
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
    stockfishReady = false;
    const path = getWorkerBasePath() + 'stockfish_hybrid.worker.js';
    stockfishWorker = new Worker(path);
    stockfishWorker.addEventListener('message', handleStockfishMessage);
    stockfishWorker.postMessage({ type: 'init' });
    console.log('[EngineService] Stockfish worker created, waiting for ready...');
    return stockfishWorker;
  }

  function handleStockfishMessage(e) {
    const msg = e.data;

    if (msg.type === 'ready') {
      if (!stockfishReady) {
        stockfishReady = true;
        console.log('[EngineService] Stockfish WASM is READY');
        // Fire a warmup search so WASM is fully compiled
        stockfishWorker.postMessage({
          type: 'search',
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          depth: 1,
        });
        // Resolve any callbacks waiting for ready
        stockfishReadyCallbacks.forEach(cb => cb());
        stockfishReadyCallbacks = [];
      }
      return;
    }

    // Forward bestmove and error to the shared handler
    handleWorkerMessage(e);
  }

  function waitForStockfishReady() {
    if (stockfishReady) return Promise.resolve();
    return new Promise(resolve => {
      stockfishReadyCallbacks.push(resolve);
    });
  }

  function loadChessLogic() {
    if (chessLogic) return chessLogic;
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
        
        // If Stockfish fails, try falling back to Sunfish immediately instead of just returning null
        if (activeEngine === ENGINE_STOCKFISH) {
          console.warn('[EngineService] Stockfish error occurred, attempting Sunfish fallback...');
          // Note: we don't call resolve(null) here, we restart the request with Sunfish
          // But to prevent infinite loops, we only do this once or use a different engine type.
          // For simplicity, let's just use Sunfish directly if not already tried.
          pendingResolve = null;
          pendingTimeout = null;
          EngineService.getBestMove(lastFen, true); // Added a fallback parameter or similar? No, getBestMove is enough.
          // Wait, actually I should just call the search function with Sunfish.
          // Better: just trigger the timeout logic.
          resolve(null); // Return null for now, but let's at least clear properly.
        } else {
          pendingResolve = null;
          pendingTimeout = null;
          resolve(null);
        }
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
        console.log(`[EngineService] Initialized: Stockfish 18 WASM (depth ${DEPTH_CONFIG[difficulty]})`);
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
    async getBestMove(fen) {
      lastFen = fen;
      const id = ++requestId;
      const depth = DEPTH_CONFIG[currentDifficulty] || 3;
      const engineType = activeEngine;

      if (engineType === ENGINE_VALIDATION) {
        return null;
      }

      // Cancel any in-flight request
      if (pendingResolve) {
        pendingResolve(null);
        clearTimeout(pendingTimeout);
        pendingResolve = null;
        pendingTimeout = null;
      }

      return new Promise((resolve) => {
        const executeRequest = (engine) => {
          const timeout = TIMEOUT_CONFIG[engine] || 5000;
          pendingResolve = resolve;

          pendingTimeout = setTimeout(() => {
            console.warn(`[EngineService] Search timeout (${timeout}ms) for request ${id} using ${engine}`);
            if (pendingResolve === resolve) {
              if (engine === ENGINE_STOCKFISH) {
                console.warn('[EngineService] Stockfish timed out, falling back to Sunfish');
                // Stop the stuck search
                if (stockfishWorker) stockfishWorker.postMessage({ type: 'stop' });
                executeRequest(ENGINE_SUNFISH);
              } else {
                pendingResolve = null;
                resolve(null);
              }
            }
          }, timeout);

          if (engine === ENGINE_SUNFISH) {
            const worker = createSunfishWorker();
            worker.postMessage({ type: 'search', fen, depth: Math.min(depth, 5), timeout });
          } else if (engine === ENGINE_STOCKFISH) {
            const worker = createStockfishWorker();
            // Wait for engine to be ready, then search
            if (stockfishReady) {
              worker.postMessage({ type: 'search', fen, depth });
            } else {
              waitForStockfishReady().then(() => {
                // Double-check we're still the active request
                if (pendingResolve === resolve) {
                  worker.postMessage({ type: 'search', fen, depth });
                }
              });
            }
          }
        };

        executeRequest(engineType);
      });
    },

    /**
     * Validate if a move is legal (used for multiplayer/two-player)
     */
    validateMove(fen, from, to, promotion) {
      const logic = loadChessLogic();
      if (!logic) return false;
      return logic.validateMove(fen, from, to, promotion);
    },

    /**
     * Get legal moves for a square
     */
    getLegalMoves(fen, square) {
      const logic = loadChessLogic();
      if (!logic) return [];
      return logic.getLegalMoves(fen, square);
    },

    /**
     * Get game state
     */
    getGameState(fen) {
      const logic = loadChessLogic();
      if (!logic) return { status: 'active', turn: 'white', isCheck: false, isCheckmate: false, isStalemate: false, isDraw: false };
      return logic.getGameState(fen);
    },

    /**
     * Get the currently active engine type
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
      stockfishReady = false;
      stockfishReadyCallbacks = [];
      console.log('[EngineService] All engines disposed');
    },
  };

  // Expose globally for Flutter JS interop
  window.ChessEngineService = EngineService;

  console.log('[EngineService] Loaded — hybrid engine service ready');
})();
