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
    advanced: 20,
    impossible: 40,
    aiMode: 64,
  };

  // Timeout budget per difficulty (ms)
  // Dynamically capped to ensure players don't wait too long
  const TIMEOUT_CONFIG = {
    basic: 2250,
    intermediate: 4000,
    advanced: 5000,
    impossible: 10000, // Grandmaster level (10s)
    aiMode: 15000,     // Max deep analysis (15s)
  };

  const FALLBACK_BUFFER_MS = 500; // Stockfish buffer before sunfish fallback
  const HEARTBEAT_TIMEOUT_MS = 12000; // Hard limit for any search
  const STOCKFISH_INIT_TIMEOUT_MS = 7000; // Max time to wait for WASM load

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
  let stockfishInitTimer = null;
  let globalHeartbeatTimer = null;

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
      
      // Init Timeout: If not ready in 4s, fallback to Sunfish for this session
      stockfishInitTimer = setTimeout(() => {
        if (!stockfishReady) {
          // Do not permanently reroute engine type; fallback is handled per request.
          console.warn('[EngineService] Stockfish Init Timeout - Temporary per-request fallback will be used');
        }
      }, STOCKFISH_INIT_TIMEOUT_MS);

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
        if (stockfishInitTimer) clearTimeout(stockfishInitTimer);
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
      if (msg.id !== undefined && msg.id !== requestId) {
        console.warn(`[EngineService] Ignoring stale resolve for request ${msg.id}`);
        return; // Ignore stale resolves
      }
      clearTimeout(pendingTimeout);
      const resolve = pendingResolve;
      pendingResolve = null;
      pendingTimeout = null;

      // Return both move and candidates if available (for humanoid selection)
      if (msg.candidates && msg.candidates.length > 0) {
        resolve({ move: msg.move, candidates: msg.candidates });
      } else {
        resolve(msg.move || null);
      }
    } else if (msg.type === 'error' && pendingResolve) {
      console.warn('[EngineService] Worker error:', msg.message);
      clearTimeout(pendingTimeout);
      if (globalHeartbeatTimer) clearTimeout(globalHeartbeatTimer);
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
      } else if (difficulty === 'advanced' || difficulty === 'impossible' || difficulty === 'aiMode') {
        activeEngineType = ENGINE_STOCKFISH;
        createWorker(ENGINE_STOCKFISH);
      } else {
        activeEngineType = ENGINE_SUNFISH;
        createWorker(ENGINE_SUNFISH);
      }
    },

    async getBestMove(fen, requestedBudget) {
      lastFen = fen;
      const id = ++requestId;

      let depth = DEPTH_CONFIG[currentDifficulty] || 3;
      const defaultBudget = TIMEOUT_CONFIG[currentDifficulty] || 1500;
      const budget = requestedBudget ? Math.min(requestedBudget, defaultBudget + 2000) : defaultBudget;

      if (activeEngineType === ENGINE_VALIDATION) return null;

      if (pendingResolve) {
        pendingResolve(null);
        clearTimeout(pendingTimeout);
        if (globalHeartbeatTimer) clearTimeout(globalHeartbeatTimer);
      }

      // Hard Heartbeat: Total Search Limit 12s
      globalHeartbeatTimer = setTimeout(() => {
        if (pendingResolve) {
          console.error(`[EngineService] Global 12s Heartbeat Timeout - Killing Workers`);
          terminateWorker(ENGINE_STOCKFISH);
          terminateWorker(ENGINE_SUNFISH);
          const res = pendingResolve;
          pendingResolve = null;
          res(null);
        }
      }, HEARTBEAT_TIMEOUT_MS);

      return new Promise((resolve) => {
        const executeSearch = async (engineType, isFallback = false) => {
          pendingResolve = resolve;

          const timeoutMs = isFallback ? 1600 : budget;

          pendingTimeout = setTimeout(() => {
            console.warn(`[EngineService] Timeout (${timeoutMs}ms) for ${engineType}`);
            if (pendingResolve === resolve) {
              if (engineType === ENGINE_STOCKFISH) {
                terminateWorker(ENGINE_STOCKFISH);
                executeSearch(ENGINE_SUNFISH, true);
              } else if (engineType === ENGINE_SUNFISH) {
                // FAILSAFE: If Sunfish stalls, restart it immediately to prevent future hangs
                console.error('[EngineService] Sunfish Stalled - Restarting Worker');
                terminateWorker(ENGINE_SUNFISH);
                createWorker(ENGINE_SUNFISH); 
                
                const res = pendingResolve;
                pendingResolve = null;
                res(null);
              } else {
                const res = pendingResolve;
                pendingResolve = null;
                res(null);
              }
            }
          }, timeoutMs);

          if (engineType === ENGINE_SUNFISH) {
            const worker = createWorker(ENGINE_SUNFISH);
            worker.postMessage({ type: 'search', fen, depth: isFallback ? 3 : depth, timeout: timeoutMs - 200, id });
          } else if (engineType === ENGINE_STOCKFISH) {
            await waitForStockfishReady();
            if (pendingResolve === resolve) {
              // Enable MultiPV 3 for high difficulties
              const multipv = (currentDifficulty === 'advanced' || currentDifficulty === 'impossible' || currentDifficulty === 'aiMode') ? 3 : 1;
              const stockfishTime = Math.max(500, timeoutMs - FALLBACK_BUFFER_MS);
              stockfishWorker.postMessage({ type: 'search', fen, depth, timeoutMs: stockfishTime, multipv, id });
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
