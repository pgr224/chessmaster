/**
 * Stockfish Web Worker — Runs Stockfish WASM via UCI protocol
 * Communication via postMessage:
 *   IN:  { type: 'init' }
 *   IN:  { type: 'search', fen: string, depth: number }
 *   OUT: { type: 'ready' }
 *   OUT: { type: 'bestmove', move: string }
 *   OUT: { type: 'error', message: string }
 *
 * Stockfish WASM is lazy-loaded on first 'init' or 'search' call.
 */

let stockfishEngine = null;
let isReady = false;
let pendingSearch = null;

/**
 * Load Stockfish WASM engine
 * Expects stockfish.js (from official Stockfish WASM build) in the same directory
 */
async function loadStockfish() {
  if (stockfishEngine) return;

  try {
    // Load Stockfish WASM from CDN for better reliability in web version
    // Using cdnjs for a stable v10.0.2 build
    importScripts('https://cdnjs.cloudflare.com/ajax/libs/stockfish.js/10.0.2/stockfish.js');

    if (typeof Stockfish === 'function') {
      stockfishEngine = Stockfish();
    } else if (typeof INIT_ENGINE === 'function') {
      stockfishEngine = await INIT_ENGINE();
    } else {
      // Fallback: try the global postMessage-based Stockfish
      stockfishEngine = {
        postMessage: (cmd) => self.postMessage({ type: 'uci_cmd', cmd }),
        addMessageListener: () => {},
      };
    }

    // Set up UCI listener
    if (stockfishEngine && stockfishEngine.addMessageListener) {
      stockfishEngine.addMessageListener((line) => {
        handleUCIOutput(line);
      });
    }

    // Initialize UCI
    sendUCI('uci');
    sendUCI('isready');
    sendUCI('setoption name Threads value 1');
    sendUCI('setoption name Hash value 16');

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

  if (line === 'readyok') {
    isReady = true;
    self.postMessage({ type: 'ready' });

    // If there's a pending search, execute it now
    if (pendingSearch) {
      const { fen, depth } = pendingSearch;
      pendingSearch = null;
      executeSearch(fen, depth);
    }
  }

  if (line.startsWith('bestmove')) {
    const parts = line.split(' ');
    const move = parts[1] || null;
    self.postMessage({ type: 'bestmove', move });
  }
}

function executeSearch(fen, depth) {
  sendUCI(`position fen ${fen}`);
  sendUCI(`go depth ${depth}`);
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
      const { fen, depth = 15 } = msg;

      if (!stockfishEngine) {
        await loadStockfish();
      }

      if (isReady) {
        executeSearch(fen, depth);
      } else {
        // Queue until ready
        pendingSearch = { fen, depth };
        sendUCI('isready');
      }
      break;
    }

    case 'stop':
      sendUCI('stop');
      break;

    case 'quit':
      sendUCI('quit');
      stockfishEngine = null;
      isReady = false;
      break;

    default:
      self.postMessage({ type: 'error', message: `Unknown message type: ${msg.type}` });
  }
});
