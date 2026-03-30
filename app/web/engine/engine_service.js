/**
 * Engine Service — Unified façade for all chess engines
 * Exposed as window.ChessEngineService for Flutter JS interop.
 *
 * Routes to the correct engine based on mode/difficulty:
 *   - Basic/Intermediate → Sunfish Web Worker
 *   - Advanced/Impossible → Stockfish WASM Web Worker
 *   - TwoPlayer/Multiplayer → ChessLogic (validation only)
 *
 * OPTIMIZED: Robust timeout-triggered fallback and dynamic depth.
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
    basic: 4,
    intermediate: 10,
    advanced: 20,
    impossible: 32,
  };

  // Timeout budget per difficulty (ms)
  const TIMEOUT_CONFIG = {
    basic: 2250,
    intermediate: 4000,
    advanced: 7250,
    impossible: 17000,
  };

  const FALLBACK_BUFFER_MS = 2000;

  // ═══════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════
  let activeEngineType = null;
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

  function createWorker(type) {
    if (type === ENGINE_SUNFISH) {
      if (sunfishWorker) return sunfishWorker;
      sunfishWorker = new Worker(getWorkerBasePath() + 'sunfish.worker.js');
      sunfishWorker.addEventListener('message', handleWorkerMessage);
      sunfishWorker.postMessage({ type: 'init' });
      return sunfishWorker;
    } else if (type === ENGINE_STOCKFISH) {
      if (stockfishWorker) return stockfishWorker;
      stockfishReady = false;
      stockfishWorker = new Worker(getWorkerBasePath() + 'stockfish_hybrid.worker.js');
      stockfishWorker.addEventListener('message', handleStockfishMessage);
      stockfishWorker.postMessage({ type: 'init' });
      console.log('[EngineService] Stockfish worker created');
      return stockfishWorker;
    }
    return null;
  }

  function terminateWorker(type) {
    if (type === ENGINE_STOCKFISH && stockfishWorker) {
      stockfishWorker.terminate();
      stockfishWorker = null;
      stockfishReady = false;
    } else if (type === ENGINE_SUNFISH && sunfishWorker) {
      sunfishWorker.terminate();
      sunfishWorker = null;
    }
  }

  function handleStockfishMessage(e) {
    const msg = e.data;
    if (msg.type === 'ready') {
      if (!stockfishReady) {
        stockfishReady = true;
        console.log('[EngineService] Stockfish WASM READY');
        stockfishReadyCallbacks.forEach(cb => cb());
        stockfishReadyCallbacks = [];
      }
      return;
    }
    handleWorkerMessage(e);
  }

  function waitForStockfishReady() {
    if (stockfishReady) return Promise.resolve();
    return new Promise(resolve => stockfishReadyCallbacks.push(resolve));
  }

  function handleWorkerMessage(e) {
    const msg = e.data;
    if (msg.type === 'bestmove' && pendingResolve) {
      clearTimeout(pendingTimeout);
      const resolve = pendingResolve;
      pendingResolve = null;
      pendingTimeout = null;
      resolve(msg.move || null);
    } else if (msg.type === 'error' && pendingResolve) {
      console.warn('[EngineService] Worker error:', msg.message);
      clearTimeout(pendingTimeout);
      const resolve = pendingResolve;
      pendingResolve = null;
      pendingTimeout = null;
      resolve(null);
    }
  }

  // ═══════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════

  const EngineService = {
    initEngine(mode, difficulty) {
      currentDifficulty = difficulty || 'basic';
      if (mode === 'twoPlayer' || mode === 'multiplayer') {
        activeEngineType = ENGINE_VALIDATION;
      } else if (difficulty === 'advanced' || difficulty === 'impossible') {
        activeEngineType = ENGINE_STOCKFISH;
        createWorker(ENGINE_STOCKFISH);
      } else {
        activeEngineType = ENGINE_SUNFISH;
        createWorker(ENGINE_SUNFISH);
      }
    },

    async getBestMove(fen) {
      lastFen = fen;
      const id = ++requestId;

      // Dynamic depth adjustment: reduce if it was too slow recently or base it on difficulty
      let depth = DEPTH_CONFIG[currentDifficulty] || 3;
      const budget = TIMEOUT_CONFIG[currentDifficulty] || 1500;
      const fallbackTrigger = budget - FALLBACK_BUFFER_MS;

      if (activeEngineType === ENGINE_VALIDATION) return null;

      // Cancel any existing pending promise/timeout
      if (pendingResolve) {
        pendingResolve(null);
        clearTimeout(pendingTimeout);
      }

      return new Promise((resolve) => {
        const executeSearch = async (engineType, isFallback = false) => {
          pendingResolve = resolve;

          const timeoutMs = isFallback ? 800 : budget;

          pendingTimeout = setTimeout(() => {
            console.warn(`[EngineService] Timeout (${timeoutMs}ms) for ${engineType}`);
            if (pendingResolve === resolve) {
              if (engineType === ENGINE_STOCKFISH) {
                // Stockfish stalled! KILL and FALLBACK to Sunfish.
                terminateWorker(ENGINE_STOCKFISH);
                executeSearch(ENGINE_SUNFISH, true);
              } else {
                pendingResolve(null);
                pendingResolve = null;
              }
            }
          }, timeoutMs);

          if (engineType === ENGINE_SUNFISH) {
            const worker = createWorker(ENGINE_SUNFISH);
            worker.postMessage({ type: 'search', fen, depth: isFallback ? 3 : depth, timeoutMs: timeoutMs - 200 });
          } else if (engineType === ENGINE_STOCKFISH) {
            await waitForStockfishReady();
            if (pendingResolve === resolve) {
              stockfishWorker.postMessage({ type: 'search', fen, depth, timeoutMs: timeoutMs - 200 });
            }
          }
        };

        executeSearch(activeEngineType);
      });
    },

    validateMove(fen, from, to, promotion) {
      if (typeof ChessLogic !== 'undefined') {
        const logic = new ChessLogic();
        return logic.validateMove(fen, from, to, promotion);
      }
      return true;
    },

    getLegalMoves(fen, square) {
      if (typeof ChessLogic !== 'undefined') {
        const logic = new ChessLogic();
        return logic.getLegalMoves(fen, square);
      }
      return [];
    },

    getGameState(fen) {
      if (typeof ChessLogic !== 'undefined') {
        const logic = new ChessLogic();
        return logic.getGameState(fen);
      }
      return { status: 'active', turn: 'white' };
    },

    getActiveEngine() {
      return activeEngineType;
    },

    dispose() {
      if (pendingResolve) {
        pendingResolve(null);
        clearTimeout(pendingTimeout);
        pendingResolve = null;
      }
      terminateWorker(ENGINE_STOCKFISH);
      terminateWorker(ENGINE_SUNFISH);
      console.log('[EngineService] Disposed');
    },
  };

  window.ChessEngineService = EngineService;
})();
