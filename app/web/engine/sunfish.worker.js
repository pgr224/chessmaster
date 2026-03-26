/**
 * Sunfish Web Worker — Runs Sunfish AI search off the main thread
 * Communication via postMessage:
 *   IN:  { type: 'search', fen: string, depth: number }
 *   OUT: { type: 'bestmove', move: string, score: number }
 *   OUT: { type: 'ready' }
 */

importScripts('sunfish_engine.js');

self.addEventListener('message', (e) => {
  const msg = e.data;

  switch (msg.type) {
    case 'init':
      self.postMessage({ type: 'ready' });
      break;

    case 'search': {
      const { fen, depth = 3, timeout = 3000 } = msg;
      try {
        const result = self.searchBestMove(fen, depth, timeout);
        if (result) {
          self.postMessage({ type: 'bestmove', move: result.move, score: result.score });
        } else {
          self.postMessage({ type: 'bestmove', move: null, score: 0 });
        }
      } catch (err) {
        self.postMessage({ type: 'error', message: err.message || 'Search failed' });
      }
      break;
    }

    default:
      self.postMessage({ type: 'error', message: `Unknown message type: ${msg.type}` });
  }
});

// Signal ready on load
self.postMessage({ type: 'ready' });
