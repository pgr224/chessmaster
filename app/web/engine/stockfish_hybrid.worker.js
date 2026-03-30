/**
 * Stockfish Web Worker — Runs Stockfish 18 WASM via UCI protocol
 * Communication via postMessage:
 *   IN:  { type: 'init' }
 *   IN:  { type: 'search', fen: string, depth: number }
 *   IN:  { type: 'stop' }
 *   IN:  { type: 'quit' }
 *   OUT: { type: 'ready' }
 *   OUT: { type: 'bestmove', move: string }
 *   OUT: { type: 'error', message: string }
 */

let stockfishEngine = null;
let isReady = false;
let pendingSearch = null;
let currentSearchId = null;
let isSearching = false;
let candidates = [];

/**
 * Parses info line for MultiPV candidates
 * Format: info depth 10 seldepth 14 multipv 1 score cp 45 nodes 10795 nps 215900 hashfull 207 tbhits 0 time 50 pv e2e4 e7e5
 */
function parseInfoLine(line) {
  if (!line.includes('multipv')) return;
  
  try {
    const parts = line.split(' ');
    let mp = -1, score = 0, move = '';
    
    for (let i = 0; i < parts.length; i++) {
       if (parts[i] === 'multipv') mp = parseInt(parts[i+1]);
       if (parts[i] === 'score') {
         if (parts[i+1] === 'cp') score = parseInt(parts[i+2]);
         else if (parts[i+1] === 'mate') score = 10000;
       }
       if (parts[i] === 'pv') move = parts[i+1];
    }
    
    if (mp !== -1 && move) {
      // Store or update candidate
      const index = candidates.findIndex(c => c.multipv === mp);
      if (index !== -1) {
        candidates[index] = { multipv: mp, uci: move, score: score };
      } else {
        candidates.push({ multipv: mp, uci: move, score: score });
      }
    }
  } catch (e) {}
}

async function loadStockfish() {
  if (stockfishEngine) return;

  try {
    self.mainScriptUrlOrBlob = 'stockfish.wasm.js';
    importScripts('stockfish.wasm.js');

    if (typeof Stockfish === 'function') {
      const result = Stockfish();
      stockfishEngine = result instanceof Promise ? await result : result;
    } else {
      throw new Error('Stockfish constructor not found after importScripts');
    }

    const listener = (line) => {
      const lineStr = typeof line === 'string' ? line : line.data;
      handleUCIOutput(lineStr);
    };

    if (stockfishEngine.addMessageListener) {
      stockfishEngine.addMessageListener(listener);
    } else {
      stockfishEngine.onmessage = listener;
    }

    sendUCI('uci');
    sendUCI('setoption name Threads value 1');
    sendUCI('setoption name Hash value 64');
    sendUCI('ucinewgame');
    sendUCI('isready');

  } catch (err) {
    self.postMessage({ type: 'error', message: `Failed to load Stockfish: ${err.message}` });
  }
}

function sendUCI(cmd) {
  if (stockfishEngine && stockfishEngine.postMessage) {
    stockfishEngine.postMessage(cmd);
  }
}

function handleUCIOutput(line) {
  if (typeof line !== 'string') return;

  if (line.startsWith('info depth') && line.includes('multipv')) {
    parseInfoLine(line);
  }

  if (line === 'readyok') {
    isReady = true;
    self.postMessage({ type: 'ready' });

    if (pendingSearch) {
      const { fen, depth, timeoutMs, multipv, searchId } = pendingSearch;
      pendingSearch = null;
      executeSearch(fen, depth, timeoutMs, multipv, searchId);
    }
  }

  if (line.startsWith('bestmove')) {
    isSearching = false;
    const parts = line.split(' ');
    const move = parts[1] || null;
    
    // Finalize candidates: sort by mp and remove duplicates if any
    candidates.sort((a, b) => a.multipv - b.multipv);
    const resultCandidates = candidates.map(c => ({ uci: c.uci, score: c.score }));
    
    self.postMessage({ type: 'bestmove', move, candidates: resultCandidates, id: currentSearchId });
  }
}

function executeSearch(fen, depth, timeoutMs, multipv = 1, searchId = null) {
  isSearching = true;
  currentSearchId = searchId;
  candidates = []; // Reset for new search
  
  sendUCI(`setoption name MultiPV value ${multipv}`);
  sendUCI(`position fen ${fen}`);
  if (timeoutMs) {
    sendUCI(`go depth ${depth} movetime ${timeoutMs}`);
  } else {
    sendUCI(`go depth ${depth}`);
  }
}

self.addEventListener('message', async (e) => {
  const msg = e.data;

  switch (msg.type) {
    case 'init':
      await loadStockfish();
      break;

    case 'search': {
      const { fen, depth = 12, timeoutMs = 14000, multipv = 1, id } = msg;

      if (!stockfishEngine) {
        await loadStockfish();
      }

      if (isSearching) {
        sendUCI('stop');
      }

      if (isReady) {
        executeSearch(fen, depth, timeoutMs, multipv, id);
      } else {
        pendingSearch = { fen, depth, timeoutMs, multipv, searchId: id };
        sendUCI('isready');
      }
      break;
    }

    case 'stop':
      sendUCI('stop');
      isSearching = false;
      break;

    case 'quit':
      sendUCI('quit');
      stockfishEngine = null;
      isReady = false;
      isSearching = false;
      break;

    default:
      self.postMessage({ type: 'error', message: `Unknown message type: ${msg.type}` });
  }
});
