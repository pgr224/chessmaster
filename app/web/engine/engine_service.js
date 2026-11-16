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
  const diagnosticEvents = [];
  let lastRequest = null;
  let lastFault = null;
  let lastCancel = null;
  const now = () => typeof performance !== 'undefined' && typeof performance.now === 'function'
    ? performance.now() : Date.now();

  function requestSnapshot(request) {
    if (!request) return null;
    return {
      id: request.id, phase: request.phase, engine: request.engine,
      difficulty: request.difficulty, budgetMs: request.budget,
      elapsedMs: Math.max(0, now() - request.createdAt),
      phaseElapsedMs: Math.max(0, now() - request.phaseStartedAt),
      fallback: !!request.fallback,
    };
  }

  function event(name, request, details = {}) {
    const entry = { event: name, atMs: now(), ...requestSnapshot(request), ...details };
    diagnosticEvents.push(entry);
    if (diagnosticEvents.length > 10) diagnosticEvents.shift();
    return entry;
  }

  function fault(request, engine, reason, error) {
    let message = typeof error === 'string' ? error
      : error?.message || error?.error?.message || (error ? String(error) : reason);
    // Never retain a position if a lower-level exception happens to quote it.
    message = String(message);
    if (request?.fen) message = message.split(request.fen).join('[position]');
    lastFault = { ...event('fault', request, {
      engine, phase: request?.phase || 'idle', reason, message: message.slice(0, 400),
    }) };
  }


  function terminate(type) {
    const record = workers.get(type);
    if (record) {
      workers.delete(type);
      record.worker.terminate();
      event('worker-terminated', pending, { engine: type });
    }
  }

  function finish(request, value, outcome = 'completed') {
    if (pending !== request) return;
    clearTimeout(request.timer);
    event(outcome, request, { hasMove: !!(typeof value === 'string' ? value : value?.move) });
    request.phase = outcome;
    lastRequest = requestSnapshot(request);
    pending = null;
    request.resolve(value);
  }

  function cancel(reason = 'cancelled') {
    if (!pending) return;
    const request = pending;
    // A synchronous engine search cannot consume a stop message until it ends.
    // Terminate busy workers so an old search cannot queue ahead of a new one.
    reason = typeof reason === 'string' ? reason.split(request.fen).join('[position]').slice(0, 120) : 'cancelled';
    lastCancel = { ...event('cancelled', request, { reason }) };
    if (request.started) terminate(request.engine);
    finish(request, null, 'cancelled');
  }

  function fail(request, reason = 'search-timeout', error) {
    if (pending !== request) return;
    clearTimeout(request.timer);
    fault(request, request.engine, reason, error);
    terminate(request.engine);
    if (request.engine === STOCKFISH) {
      event('fallback', request, { nextEngine: SUNFISH });
      search(request, SUNFISH, FALLBACK_BUDGET);
    } else {
      finish(request, null, 'failed');
    }
  }

  function getWorker(type) {
    if (workers.has(type)) return workers.get(type);
    const base = document.querySelector('base');
    const href = base ? base.getAttribute('href') : '/';
    const filename = type === STOCKFISH ? 'stockfish_hybrid.worker.js' : 'sunfish.worker.js';
    const record = { worker: new Worker(href + 'engine/' + filename), ready: type !== STOCKFISH };
    workers.set(type, record);
    event('worker-created', pending, { engine: type });

    record.worker.addEventListener('message', ({ data }) => {
      if (workers.get(type) !== record || !data) return;
      if (data.type === 'ready') {
        record.ready = true;
        event('worker-ready', pending, { engine: type });
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
        fail(request, 'worker-error', data.message || data.error);
      }
    });
    const onError = error => {
      if (workers.get(type) !== record) return;
      const reason = error?.type === 'messageerror' ? 'message-error' : 'worker-error';
      if (pending && pending.record === record) fail(pending, reason, error);
      else {
        fault(null, type, reason, error);
        terminate(type);
      }
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
    request.phase = 'searching';
    request.phaseStartedAt = now();
    event('search-started', request);
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
    } catch (error) {
      fail(request, 'post-message-failed', error);
    }
  }

  function search(request, type, budget) {
    if (pending !== request) return;
    request.fallback = type !== activeEngine;
    request.engine = type;
    request.budget = budget;
    request.started = false;
    request.phase = 'preparing';
    request.phaseStartedAt = now();
    try {
      request.record = getWorker(type);
      if (request.record.ready) sendSearch(request);
      else request.timer = setTimeout(() => fail(request, 'readiness-timeout'), STOCKFISH_READY_TIMEOUT);
    } catch (error) {
      fail(request, 'worker-start-failed', error);
    }
  }

  function getLogic() {
    if (!chessLogic && typeof ChessLogic !== 'undefined') chessLogic = new ChessLogic();
    return chessLogic;
  }

  const EngineService = {
    initEngine(mode, requestedDifficulty) {
      cancel('mode-change');
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
      cancel('superseded');
      if (!activeEngine || activeEngine === VALIDATION) return Promise.resolve(null);
      const defaultBudget = BUDGET[difficulty] ?? 1500;
      const budget = Number.isFinite(requestedBudget) && requestedBudget > 0
        ? Math.min(requestedBudget, defaultBudget + 2000) : defaultBudget;
      return new Promise(resolve => {
        const createdAt = now();
        const request = { id: ++nextRequestId, fen, resolve, started: false,
          difficulty, createdAt, phaseStartedAt: createdAt, phase: 'requested' };
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

    getDiagnostics() {
      return {
        capabilities: {
          secureContext: typeof isSecureContext === 'boolean' ? isSecureContext : null,
          crossOriginIsolated: typeof crossOriginIsolated === 'boolean' ? crossOriginIsolated : null,
          sharedArrayBuffer: typeof SharedArrayBuffer === 'function',
          worker: typeof Worker === 'function',
        },
        difficulty, selectedEngine: activeEngine, activeEngine: lastSearchEngine || activeEngine,
        currentRequest: requestSnapshot(pending),
        lastRequest: lastRequest ? { ...lastRequest } : null,
        lastFault: lastFault ? { ...lastFault } : null,
        lastCancel: lastCancel ? { ...lastCancel } : null,
        workers: [...workers].map(([engine, record]) => ({ engine, ready: record.ready })),
        recentEvents: diagnosticEvents.map(entry => ({ ...entry })),
      };
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
      cancel('dispose');
      for (const type of workers.keys()) terminate(type);
      activeEngine = null;
      lastSearchEngine = null;
      chessLogic = null;
    },
  };

  window.ChessEngineService = EngineService;
})();
