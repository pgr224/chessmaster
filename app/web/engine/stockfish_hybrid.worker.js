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
let isSearching = false;

// ════════════════════════════════════════
// STOCKFISH WASM LOADER
// ════════════════════════════════════════

async function loadStockfish() {
  if (stockfishEngine) return;

  try {
    // Tell Emscripten where the main script is so pthreads can load sub-workers correctly
    self.mainScriptUrlOrBlob = 'stockfish.wasm.js';

    // Load the local stockfish.wasm.js (which in turn fetches stockfish.wasm)
    importScripts('stockfish.wasm.js');

    // The Stockfish() constructor returns a promise or the engine directly
    if (typeof Stockfish === 'function') {
      const result = Stockfish();
      stockfishEngine = result instanceof Promise ? await result : result;
    } else {
      throw new Error('Stockfish constructor not found after importScripts');
    }

    // Set up UCI output listener
    if (stockfishEngine && stockfishEngine.addMessageListener) {
      stockfishEngine.addMessageListener((line) => {
        handleUCIOutput(line);
      });
    } else if (stockfishEngine && typeof stockfishEngine.onmessage !== 'undefined') {
      stockfishEngine.onmessage = (line) => {
        handleUCIOutput(typeof line === 'string' ? line : line.data);
      };
    }

    // Initialize UCI protocol
    sendUCI('uci');
    // Wait for 'uciok' implicitly, then configure
    sendUCI('setoption name Threads value 1');
    sendUCI('setoption name Hash value 16');
    sendUCI('ucinewgame');
    sendUCI('isready');

  } catch (err) {
    self.postMessage({ type: 'error', message: `Failed to load Stockfish: ${err.message}` });
  }
}

// ════════════════════════════════════════
// UCI COMMUNICATION
// ════════════════════════════════════════

function sendUCI(cmd) {
  if (stockfishEngine && stockfishEngine.postMessage) {
    stockfishEngine.postMessage(cmd);
  }
}

function handleUCIOutput(line) {
  if (typeof line !== 'string') return;

  // Log search progress for debugging
  if (line.includes('info depth') && line.includes(' pv ')) {
    console.log('[StockfishWorker]', line);
  }

  if (line === 'readyok') {
    isReady = true;
    self.postMessage({ type: 'ready' });

    // If there's a queued search, execute it now
    if (pendingSearch) {
      const { fen, depth, timeoutMs } = pendingSearch;
      pendingSearch = null;
      executeSearch(fen, depth, timeoutMs);
    }
  }

  if (line.startsWith('bestmove')) {
    isSearching = false;
    const parts = line.split(' ');
    const move = parts[1] || null;
    self.postMessage({ type: 'bestmove', move });
  }
}

function executeSearch(fen, depth, timeoutMs) {
  isSearching = true;
  sendUCI(`position fen ${fen}`);
  if (timeoutMs) {
    sendUCI(`go depth ${depth} movetime ${timeoutMs}`);
  } else {
    sendUCI(`go depth ${depth}`);
  }
}

// ════════════════════════════════════════
// MESSAGE HANDLER
// ════════════════════════════════════════
self.addEventListener('message', async (e) => {
  const msg = e.data;

  switch (msg.type) {
    case 'init':
      await loadStockfish();
      break;

    case 'search': {
      const { fen, depth = 12, timeoutMs = 14000 } = msg;

      if (!stockfishEngine) {
        await loadStockfish();
      }

      // If currently searching, stop previous search first
      if (isSearching) {
        sendUCI('stop');
      }

      if (isReady) {
        executeSearch(fen, depth, timeoutMs);
      } else {
        // Queue until engine is ready
        pendingSearch = { fen, depth, timeoutMs };
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
