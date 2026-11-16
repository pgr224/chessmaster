/** Lazy chess-engine façade used by Flutter's JS bridge. */
(function () {
  'use strict';

  const SUNFISH = 'sunfish';
  const STOCKFISH = 'stockfish';
  const VALIDATION = 'validation';
  const DEPTH = { basic: 3, intermediate: 5, advanced: 0, impossible: 0, aiMode: 0 };
  const BUDGET = { basic: 2250, intermediate: 4000, advanced: 7000, impossible: 12000, aiMode: 18000 };
  const FALLBACK_BUDGET = 1600;
  const STOCKFISH_READY_TIMEOUT = 5000;
  const workers = new Map();
  let activeEngine = null;
  let lastSearchEngine = null;
  let difficulty = 'basic';
  let nextRequestId = 0;
  let pending = null;
  let chessLogic = null;

  function terminate(type) {
    const record = workers.get(type);
    if (record) {
      workers.delete(type);
      record.worker.terminate();
    }
  }

  function finish(request, value) {
    if (pending !== request) return;
    clearTimeout(request.timer);
    pending = null;
    request.resolve(value);
  }

  function cancel() {
    if (!pending) return;
    const request = pending;
    // A synchronous engine search cannot consume a stop message until it ends.
    // Terminate busy workers so an old search cannot queue ahead of a new one.
    if (request.started) terminate(request.engine);
    finish(request, null);
  }

  function fail(request) {
    if (pending !== request) return;
    clearTimeout(request.timer);
    terminate(request.engine);
    if (request.engine === STOCKFISH) {
      search(request, SUNFISH, FALLBACK_BUDGET);
    } else {
      finish(request, null);
    }
  }

  function getWorker(type) {
    if (workers.has(type)) return workers.get(type);
    const base = document.querySelector('base');
    const href = base ? base.getAttribute('href') : '/';
    const filename = type === STOCKFISH ? 'stockfish_hybrid.worker.js' : 'sunfish.worker.js';
    const record = { worker: new Worker(href + 'engine/' + filename), ready: type !== STOCKFISH };
    workers.set(type, record);

    record.worker.addEventListener('message', ({ data }) => {
      if (workers.get(type) !== record || !data) return;
      if (data.type === 'ready') {
        record.ready = true;
        if (pending && pending.record === record && !pending.started) sendSearch(pending);
        return;
      }
      const request = pending;
      if (!request || request.record !== record ||
          (data.id !== undefined && data.id !== request.id)) return;
      if (data.type === 'bestmove') {
        if (data.id !== request.id) return;
        finish(request, data.candidates && data.candidates.length
          ? { move: data.move, candidates: data.candidates }
          : data.move || null);
      } else if (data.type === 'error') {
        fail(request);
      }
    });
    const onError = () => {
      if (workers.get(type) !== record) return;
      if (pending && pending.record === record) fail(pending);
      else terminate(type);
    };
    record.worker.addEventListener('error', onError);
    record.worker.addEventListener('messageerror', onError);
    try {
      record.worker.postMessage({ type: 'init' });
    } catch (error) {
      terminate(type);
      throw error;
    }
    return record;
  }

  function sendSearch(request) {
    if (pending !== request || request.started) return;
    request.started = true;
    clearTimeout(request.timer);
    // WASM preparation is separate from the existing difficulty search budget.
    request.timer = setTimeout(() => fail(request), request.budget);
    lastSearchEngine = request.engine;
    const depth = DEPTH[difficulty] ?? 3; // Zero means movetime-only search.
    const message = request.engine === STOCKFISH
      ? { type: 'search', fen: request.fen, depth, timeoutMs: Math.max(500, request.budget - 500),
          multipv: 3, skillLevel: difficulty === 'advanced' ? 16 : 20, id: request.id }
      : { type: 'search', fen: request.fen, depth: request.fallback ? 2 : depth,
          timeout: Math.max(250, request.budget - 250), id: request.id };
    try {
      request.record.worker.postMessage(message);
    } catch (_) {
      fail(request);
    }
  }

  function search(request, type, budget) {
    if (pending !== request) return;
    request.fallback = type !== activeEngine;
    request.engine = type;
    request.budget = budget;
    request.started = false;
    try {
      request.record = getWorker(type);
      if (request.record.ready) sendSearch(request);
      else request.timer = setTimeout(() => fail(request), STOCKFISH_READY_TIMEOUT);
    } catch (_) {
      fail(request);
    }
  }

  function getLogic() {
    if (!chessLogic && typeof ChessLogic !== 'undefined') chessLogic = new ChessLogic();
    return chessLogic;
  }

  const EngineService = {
    initEngine(mode, requestedDifficulty) {
      cancel();
      difficulty = requestedDifficulty || 'basic';
      const type = mode === 'twoPlayer' || mode === 'multiplayer' ? VALIDATION
        : difficulty === 'advanced' || difficulty === 'impossible' || difficulty === 'aiMode' ? STOCKFISH
        : SUNFISH;
      // Switching to a human opponent releases AI memory immediately.
      for (const existing of workers.keys()) {
        if (existing !== type) terminate(existing);
      }
      activeEngine = type;
      lastSearchEngine = null;
    },

    getBestMove(fen, requestedBudget) {
      cancel();
      if (!activeEngine || activeEngine === VALIDATION) return Promise.resolve(null);
      const defaultBudget = BUDGET[difficulty] ?? 1500;
      const budget = Number.isFinite(requestedBudget) && requestedBudget > 0
        ? Math.min(requestedBudget, defaultBudget + 2000) : defaultBudget;
      return new Promise(resolve => {
        const request = { id: ++nextRequestId, fen, resolve, started: false };
        pending = request;
        search(request, activeEngine, budget);
      });
    },

    validateMove(fen, from, to, promotion) {
      return getLogic()?.validateMove(fen, from, to, promotion) ?? false;
    },

    getLegalMoves(fen, square) {
      return getLogic()?.getLegalMoves(fen, square) ?? [];
    },

    getGameState(fen) {
      return getLogic()?.getGameState(fen) ?? { status: 'active', turn: 'white' };
    },

    getActiveEngine() {
      return lastSearchEngine || activeEngine;
    },

    cancel,

    async analyzeStyle(fen, recentMoves) {
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
      cancel();
      for (const type of workers.keys()) terminate(type);
      activeEngine = null;
      lastSearchEngine = null;
      chessLogic = null;
    },
  };

  window.ChessEngineService = EngineService;
})();
