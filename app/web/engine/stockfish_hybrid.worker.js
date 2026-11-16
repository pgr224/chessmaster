/** Stockfish UCI worker. Searches are serialized across stop/readiness barriers. */
let stockfishEngine = null;
let loading = null;
let generation = 0;
let isReady = false;
let awaitingReady = false;
let activeSearch = null;
let pendingSearch = null;
let candidates = [];
let outputListener = null;

function sendUCI(command) {
  if (stockfishEngine?.postMessage) stockfishEngine.postMessage(command);
}

function disposeEngine(engine, listener) {
  if (!engine) return;
  try {
    if (listener && engine.removeMessageListener) engine.removeMessageListener(listener);
    if (engine.terminate) engine.terminate();
    else if (engine.postMessage) engine.postMessage('quit');
  } catch (_) { /* A failed WASM instance may already have torn down its threads. */ }
}

function reset() {
  generation++;
  const engine = stockfishEngine, listener = outputListener;
  stockfishEngine = null;
  loading = null;
  isReady = false;
  awaitingReady = false;
  activeSearch = null;
  pendingSearch = null;
  candidates = [];
  outputListener = null;
  disposeEngine(engine, listener);
}

function reportError(error) {
  const id = activeSearch?.id ?? pendingSearch?.id;
  reset();
  self.postMessage({ type: 'error', message: error.message || String(error), id });
}

function parseInfoLine(line) {
  if (!activeSearch || activeSearch.cancelled) return;
  const parts = line.split(/\s+/);
  const multipv = Number(parts[parts.indexOf('multipv') + 1]);
  const move = parts[parts.indexOf('pv') + 1];
  const scoreIndex = parts.indexOf('score');
  const score = parts[scoreIndex + 1] === 'mate' ? 10000 : Number(parts[scoreIndex + 2]);
  if (!Number.isInteger(multipv) || multipv < 1 || multipv > activeSearch.multipv ||
      !Number.isFinite(score) || !/^[a-h][1-8][a-h][1-8][qrbn]?$/.test(move)) return;
  candidates[multipv - 1] = { uci: move, score };
}

function executeSearch(search) {
  activeSearch = search;
  candidates = [];
  const { fen, depth, timeoutMs, multipv, skillLevel } = search;
  sendUCI(`setoption name Skill Level value ${skillLevel}`);
  sendUCI(`setoption name MultiPV value ${multipv}`);
  sendUCI(`position fen ${fen}`);
  // Keep the existing difficulty's depth and time limits unchanged.
  if (!depth || depth <= 0) sendUCI(`go movetime ${timeoutMs || 5000}`);
  else if (timeoutMs) sendUCI(`go depth ${depth} movetime ${timeoutMs}`);
  else sendUCI(`go depth ${depth}`);
}

function preparePendingSearch() {
  if (!stockfishEngine || !isReady || activeSearch || !pendingSearch || awaitingReady) return;
  // Flush output from the previous search before assigning a new request ID.
  awaitingReady = true;
  sendUCI('isready');
}

function handleUCIOutput(line) {
  if (typeof line !== 'string') return;
  if (line.startsWith('info depth') && line.includes('multipv')) parseInfoLine(line);
  if (line === 'readyok') {
    const initialReady = !isReady;
    isReady = true;
    awaitingReady = false;
    if (initialReady) self.postMessage({ type: 'ready' });
    if (!activeSearch && pendingSearch) {
      const search = pendingSearch;
      pendingSearch = null;
      executeSearch(search);
    }
  } else if (line.startsWith('bestmove')) {
    const search = activeSearch;
    if (!search) return; // Unsolicited/late output cannot complete another search.
    activeSearch = null;
    if (!search.cancelled) {
      const raw = line.split(/\s+/)[1];
      const move = raw === '(none)' || raw === '0000' ? null : raw || null;
      self.postMessage({ type: 'bestmove', move, candidates: candidates.filter(Boolean), id: search.id });
    }
    candidates = [];
    preparePendingSearch();
  }
}

function loadStockfish() {
  if (loading) return loading;
  if (stockfishEngine) return Promise.resolve();
  const loadGeneration = generation;
  loading = Promise.resolve().then(async () => {
    try {
      self.mainScriptUrlOrBlob = 'stockfish.wasm.js';
      importScripts('stockfish.wasm.js');
      if (typeof Stockfish !== 'function') throw new Error('Stockfish constructor not found');
      const engine = await Stockfish();
      if (generation !== loadGeneration) {
        disposeEngine(engine);
        return;
      }
      stockfishEngine = engine;
      outputListener = line => {
        if (generation === loadGeneration && stockfishEngine === engine) {
          handleUCIOutput(typeof line === 'string' ? line : line.data);
        }
      };
      if (engine.addMessageListener) engine.addMessageListener(outputListener);
      else engine.onmessage = outputListener;
      sendUCI('uci');
      sendUCI('setoption name Threads value 1');
      sendUCI('setoption name Hash value 32');
      sendUCI('ucinewgame');
      awaitingReady = true;
      sendUCI('isready');
    } catch (error) {
      if (generation === loadGeneration) reportError(error);
    }
  });
  return loading;
}

self.addEventListener('message', async ({ data: message }) => {
  if (!message || typeof message !== 'object') return;
  try {
    switch (message.type) {
      case 'init':
        await loadStockfish();
        break;
      case 'search':
        pendingSearch = {
          fen: message.fen, depth: message.depth ?? 12,
          timeoutMs: message.timeoutMs ?? 14000, multipv: message.multipv ?? 1,
          id: message.id, skillLevel: message.skillLevel ?? 20,
        };
        if (activeSearch && !activeSearch.cancelled) {
          activeSearch.cancelled = true;
          sendUCI('stop');
        }
        await loadStockfish();
        preparePendingSearch();
        break;
      case 'stop':
        pendingSearch = null;
        if (activeSearch && !activeSearch.cancelled) {
          activeSearch.cancelled = true;
          sendUCI('stop');
        }
        break;
      case 'quit':
        reset();
        break;
      default:
        self.postMessage({ type: 'error', message: `Unknown message type: ${message.type}`, id: message.id });
    }
  } catch (error) {
    reportError(error);
  }
});
