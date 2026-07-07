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
    basic: 3,
    intermediate: 5,
    advanced: 0,      // 0 = use movetime only (no artificial depth cap)
    impossible: 0,    // 0 = use movetime only
    aiMode: 0,        // 0 = use movetime only
  };

  // Timeout budget per difficulty (ms)
  // Dynamically capped to ensure players don't wait too long
  const TIMEOUT_CONFIG = {
    basic: 2250,
    intermediate: 4000,
    advanced: 7000,      // Strong club player (7s)
    impossible: 12000,   // Near-master level (12s)
    aiMode: 18000,       // GM-level deep analysis (18s)
  };

  const FALLBACK_BUFFER_MS = 500; // Stockfish buffer before sunfish fallback
  const HEARTBEAT_TIMEOUT_MS = 22000; // Hard limit for any search (must exceed aiMode timeout)
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
      if (globalHeartbeatTimer) clearTimeout(globalHeartbeatTimer);
      const resolve = pendingResolve;
      pendingResolve = null;
      pendingTimeout = null;
      globalHeartbeatTimer = null;

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
      globalHeartbeatTimer = null;
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

      // Hard heartbeat: total search limit for any engine request.
      globalHeartbeatTimer = setTimeout(() => {
        if (pendingResolve) {
          console.error(`[EngineService] Global ${HEARTBEAT_TIMEOUT_MS}ms Heartbeat Timeout - Killing Workers`);
          terminateWorker(ENGINE_STOCKFISH);
          terminateWorker(ENGINE_SUNFISH);
          const res = pendingResolve;
          pendingResolve = null;
          globalHeartbeatTimer = null;
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
                if (globalHeartbeatTimer) clearTimeout(globalHeartbeatTimer);
                globalHeartbeatTimer = null;
                res(null);
              } else {
                const res = pendingResolve;
                pendingResolve = null;
                if (globalHeartbeatTimer) clearTimeout(globalHeartbeatTimer);
                globalHeartbeatTimer = null;
                res(null);
              }
            }
          }, timeoutMs);

          if (engineType === ENGINE_SUNFISH) {
            const worker = createWorker(ENGINE_SUNFISH);
            const sunfishDepth = isFallback ? 2 : Math.max(1, Math.min(depth, 3));
            worker.postMessage({ type: 'search', fen, depth: sunfishDepth, timeout: Math.max(250, timeoutMs - 250), id });
          } else if (engineType === ENGINE_STOCKFISH) {
            await waitForStockfishReady();
            if (pendingResolve === resolve) {
              // Enable MultiPV 3 for high difficulties
              const multipv = (currentDifficulty === 'advanced' || currentDifficulty === 'impossible' || currentDifficulty === 'aiMode') ? 3 : 1;
              const stockfishTime = Math.max(500, timeoutMs - FALLBACK_BUFFER_MS);
              // Graded Skill Level: Advanced=16 (slight imprecisions), Impossible/AI=20 (full strength)
              const skillLevel = currentDifficulty === 'advanced' ? 16 : 20;
              stockfishWorker.postMessage({ type: 'search', fen, depth, timeoutMs: stockfishTime, multipv, id, skillLevel });
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

    analyzeStyle(fen, recentMoves) {
      if (!recentMoves || recentMoves.length === 0) {
        return { style: 'unknown', confidence: 0, suggested_personality: 'balanced' };
      }

      let aggressiveCount = 0;
      let captureCount = 0;
      let checkCount = 0;
      let pawnMoveCount = 0;

      recentMoves.forEach(m => {
        if (m.includes('+') || m.includes('#')) checkCount++;
        if (m.includes('x')) captureCount++;
        // Detect moves into enemy territory (Rank 5-8 for white, 1-4 for black)
        if (/[a-h][5-8]/.test(m) || /[a-h][1-4]/.test(m)) aggressiveCount++;
        // Detect early pawn pushes
        if (/^[a-h][3-6]/.test(m) && !m.includes('x')) pawnMoveCount++;
      });

      const total = recentMoves.length;
      const aggressionScore = (checkCount * 3 + captureCount * 1.5 + aggressiveCount);
      const pawnStormScore = pawnMoveCount / total;

      let style = 'positional';
      let confidence = 0.5;

      if (pawnStormScore > 0.4 && aggressionScore > 5) {
        style = 'pawn_storm';
        confidence = 0.85;
      } else if (aggressionScore > (total * 1.2)) {
        style = 'aggressive';
        confidence = 0.8;
      } else if (aggressionScore < (total * 0.4)) {
        style = 'solid';
        confidence = 0.7;
      }

      return {
        style,
        confidence,
        aggressionScore
      };
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
