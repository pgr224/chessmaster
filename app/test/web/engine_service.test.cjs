const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');

const source = readFileSync(join(__dirname, '../../web/engine/engine_service.js'), 'utf8');

function createHarness({ brokenWorkers = false } = {}) {
  const workers = [];
  const timers = new Map();
  let now = 0;
  let timerId = 0;
  let logicInstances = 0;
  class Worker {
    constructor(url) {
      if (brokenWorkers) throw new Error('Workers unavailable');
      this.url = url;
      this.messages = [];
      this.listeners = {};
      this.terminated = false;
      workers.push(this);
    }
    addEventListener(type, listener) { this.listeners[type] = listener; }
    postMessage(message) { this.messages.push(message); }
    terminate() { this.terminated = true; }
    emit(data) { this.listeners.message({ data }); }
    error() { this.listeners.error({ message: 'Worker failed' }); }
    get searches() { return this.messages.filter(message => message.type === 'search'); }
  }
  class ChessLogic {
    constructor() { logicInstances++; }
    validateMove() { return false; }
    getLegalMoves() { return ['e2e4']; }
    getGameState() { return { status: 'checkmate', turn: 'black' }; }
  }
  const context = vm.createContext({
    window: {}, Worker, ChessLogic,
    document: { querySelector: () => ({ getAttribute: () => '/chess/' }) },
    setTimeout(callback, delay) {
      const id = ++timerId;
      timers.set(id, { callback, time: now + delay });
      return id;
    },
    clearTimeout(id) { timers.delete(id); },
  });
  vm.runInContext(source, context);
  function advance(milliseconds) {
    const end = now + milliseconds;
    while (true) {
      const next = [...timers].sort((a, b) => a[1].time - b[1].time)[0];
      if (!next || next[1].time > end) break;
      now = next[1].time;
      timers.delete(next[0]);
      next[1].callback();
    }
    now = end;
  }
  return { service: context.window.ChessEngineService, workers, timers, advance,
    get logicInstances() { return logicInstances; } };
}

test('initialization stays lazy and human games never allocate AI workers', async () => {
  const { service, workers, timers } = createHarness();
  assert.equal(await service.getBestMove('position'), null);
  service.initEngine('singlePlayer', 'advanced');
  assert.equal(workers.length, 0);
  assert.equal(timers.size, 0);
  service.initEngine('multiplayer', 'impossible');
  assert.equal(await service.getBestMove('position'), null);
  assert.equal(workers.length, 0);
  service.dispose();
  assert.equal(timers.size, 0);
});

test('Sunfish uses the configured difficulty and reuses an idle worker', async () => {
  const { service, workers, timers } = createHarness();
  service.initEngine('singlePlayer', 'intermediate');
  const result = service.getBestMove('first');
  const worker = workers[0];
  assert.equal(worker.url, '/chess/engine/sunfish.worker.js');
  assert.equal(worker.searches[0].depth, 5);
  assert.equal(worker.searches[0].timeout, 3750);
  worker.emit({ type: 'bestmove', move: 'e2e4', id: worker.searches[0].id });
  assert.equal(await result, 'e2e4');
  assert.equal(timers.size, 0);
  const next = service.getBestMove('second');
  assert.equal(workers.length, 1);
  worker.emit({ type: 'bestmove', move: 'e7e5', id: worker.searches[1].id });
  assert.equal(await next, 'e7e5');
  service.dispose();
});

test('Stockfish waits for readiness and preserves movetime-only depth zero', async () => {
  const { service, workers, timers } = createHarness();
  service.initEngine('singlePlayer', 'advanced');
  const result = service.getBestMove('position', 2000);
  const worker = workers[0];
  assert.equal(worker.searches.length, 0);
  worker.emit({ type: 'ready' });
  assert.equal(worker.searches[0].depth, 0);
  assert.equal(worker.searches[0].timeoutMs, 1500);
  assert.equal(worker.searches[0].skillLevel, 16);
  assert.equal(worker.searches[0].multipv, 3);
  const candidates = [{ uci: 'd2d4', score: 20 }];
  worker.emit({ type: 'bestmove', move: 'd2d4', candidates, id: worker.searches[0].id });
  assert.deepEqual(JSON.parse(JSON.stringify(await result)), { move: 'd2d4', candidates });
  assert.equal(timers.size, 0);
  service.dispose();
});

test('a cold Stockfish timeout falls back once and recovers on the next request', async () => {
  const { service, workers, timers, advance } = createHarness();
  service.initEngine('singlePlayer', 'advanced');
  const result = service.getBestMove('position', 1000);
  const oldStockfish = workers[0];
  advance(5000);
  const fallback = workers[1];
  assert.equal(oldStockfish.terminated, true);
  assert.equal(fallback.searches[0].depth, 2);
  oldStockfish.emit({ type: 'ready' });
  assert.equal(oldStockfish.searches.length, 0);
  fallback.emit({ type: 'bestmove', move: 'c2c4', id: fallback.searches[0].id });
  assert.equal(await result, 'c2c4');
  assert.equal(service.getActiveEngine(), 'sunfish');
  assert.equal(timers.size, 0);
  const next = service.getBestMove('next');
  const recovered = workers[2];
  assert.match(recovered.url, /stockfish_hybrid/);
  recovered.emit({ type: 'ready' });
  recovered.emit({ type: 'bestmove', move: 'e2e4', id: recovered.searches[0].id });
  assert.equal(await next, 'e2e4');
  assert.equal(service.getActiveEngine(), 'stockfish');
  service.dispose();
});

test('superseding a busy search resolves it and rejects its stale worker results', async () => {
  const { service, workers, timers } = createHarness();
  service.initEngine('singlePlayer', 'basic');
  const first = service.getBestMove('first');
  const oldWorker = workers[0];
  const second = service.getBestMove('second');
  const currentWorker = workers[1];
  assert.equal(await first, null);
  assert.equal(oldWorker.terminated, true);
  oldWorker.emit({ type: 'bestmove', move: 'a2a4', id: oldWorker.searches[0].id });
  assert.equal(timers.size, 1);
  currentWorker.emit({ type: 'bestmove', move: 'b2b4', id: currentWorker.searches[0].id });
  assert.equal(await second, 'b2b4');
  assert.equal(timers.size, 0);
  service.dispose();
});

test('worker errors and creation failures settle without leaked timers', async () => {
  const { service, workers, timers } = createHarness();
  service.initEngine('singlePlayer', 'advanced');
  const result = service.getBestMove('position');
  workers[0].error();
  assert.equal(workers[0].terminated, true);
  workers[1].emit({ type: 'error', id: workers[1].searches[0].id, message: 'Search failed' });
  assert.equal(await result, null);
  assert.equal(workers[1].terminated, true);
  assert.equal(timers.size, 0);
  service.dispose();

  const broken = createHarness({ brokenWorkers: true });
  broken.service.initEngine('singlePlayer', 'advanced');
  assert.equal(await broken.service.getBestMove('position'), null);
  assert.equal(broken.timers.size, 0);
});

test('fallback is bounded and disposal cancels readiness, searches, and all timers', async () => {
  const { service, workers, timers, advance } = createHarness();
  service.initEngine('singlePlayer', 'advanced');
  const result = service.getBestMove('position', 1000);
  advance(6600);
  assert.equal(await result, null);
  assert.equal(timers.size, 0);
  assert.equal(workers.every(worker => worker.terminated), true);

  const pending = service.getBestMove('next');
  const loadingWorker = workers[2];
  service.dispose();
  assert.equal(await pending, null);
  assert.equal(timers.size, 0);
  loadingWorker.emit({ type: 'ready' });
  advance(30000);
  assert.equal(loadingWorker.searches.length, 0);
  assert.equal(service.getActiveEngine(), null);
  assert.equal(await service.getBestMove('after disposal'), null);
});

test('changing to multiplayer releases existing engine memory', async () => {
  const { service, workers, timers } = createHarness();
  service.initEngine('singlePlayer', 'basic');
  const result = service.getBestMove('position');
  service.initEngine('multiplayer', 'basic');
  assert.equal(await result, null);
  assert.equal(workers[0].terminated, true);
  assert.equal(timers.size, 0);
  assert.equal(await service.getBestMove('position'), null);
});

test('validation reuses a rules instance and fails closed when rules are missing', () => {
  const harness = createHarness();
  const { service } = harness;
  assert.equal(service.validateMove('position', 'e2', 'e5'), false);
  assert.deepEqual(service.getLegalMoves('position', 'e2'), ['e2e4']);
  assert.equal(service.getGameState('position').status, 'checkmate');
  assert.equal(harness.logicInstances, 1);
  const context = vm.createContext({ window: {} });
  vm.runInContext(source, context);
  assert.equal(context.window.ChessEngineService.validateMove('position', 'e2', 'e5'), false);
});


test('style analysis returns the Promise expected by the Dart JS bridge', async () => {
  const { service, workers, timers } = createHarness();
  const result = service.analyzeStyle('position', []);
  assert.equal(typeof result.then, 'function');
  assert.equal((await result).style, 'unknown');
  assert.equal((await service.analyzeStyle('position', ['e4', 'Nf3'])).confidence > 0, true);
  assert.equal(workers.length, 0);
  assert.equal(timers.size, 0);
});

test('all difficulty depths, time budgets, skill levels and MultiPV remain unchanged', async () => {
  for (const [difficulty, depth, budget, skill] of [
    ['basic', 3, 2250, null], ['intermediate', 5, 4000, null],
    ['advanced', 0, 7000, 16], ['impossible', 0, 12000, 20], ['aiMode', 0, 18000, 20],
  ]) {
    const { service, workers, timers } = createHarness();
    service.initEngine('singlePlayer', difficulty);
    const result = service.getBestMove('position');
    const worker = workers[0];
    if (skill !== null) worker.emit({ type: 'ready' });
    const search = worker.searches[0];
    assert.equal(search.depth, depth);
    if (skill !== null) {
      assert.equal(search.timeoutMs, budget - 500);
      assert.equal(search.skillLevel, skill);
      assert.equal(search.multipv, 3);
    } else assert.equal(search.timeout, budget - 250);
    worker.emit({ type: 'bestmove', move: 'e2e4', id: search.id });
    assert.equal(await result, 'e2e4');
    assert.equal(timers.size, 0);
    service.dispose();
  }
});

test('untagged results cannot resolve the current search and completed games do not retain timers', async () => {
  const { service, workers, timers } = createHarness();
  service.initEngine('singlePlayer', 'basic');
  for (let i = 0; i < 100; i++) {
    const result = service.getBestMove('position');
    const worker = workers[0], search = worker.searches.at(-1);
    worker.emit({ type: 'bestmove', move: 'a2a4' });
    assert.equal(timers.size, 1);
    worker.emit({ type: 'bestmove', move: 'e2e4', id: search.id });
    assert.equal(await result, 'e2e4');
    assert.equal(timers.size, 0);
  }
  assert.equal(workers.length, 1);
  service.dispose();
});


test('cold Stockfish preparation has its own allowance and preserves the full search budget', async () => {
  const { service, workers, timers, advance } = createHarness();
  service.initEngine('singlePlayer', 'advanced');
  const result = service.getBestMove('cold position');
  const worker = workers[0];
  advance(4000);
  assert.equal(worker.terminated, false);
  assert.equal(worker.searches.length, 0);
  worker.emit({ type: 'ready' });
  assert.equal(worker.searches[0].timeoutMs, 6500);
  assert.equal(worker.searches[0].depth, 0);
  assert.equal(worker.searches[0].skillLevel, 16);
  advance(6999);
  assert.equal(worker.terminated, false);
  assert.equal(workers.length, 1);
  worker.emit({ type: 'bestmove', move: 'e2e4', id: worker.searches[0].id });
  assert.equal(await result, 'e2e4');
  assert.equal(timers.size, 0);

  const warm = service.getBestMove('warm position');
  assert.equal(worker.searches.length, 2); // No new preparation wait.
  assert.equal(worker.searches[1].timeoutMs, 6500);
  advance(7000);
  assert.equal(worker.terminated, true); // Warm request times out at 7s, not 12s.
  const fallback = workers[1];
  fallback.emit({ type: 'bestmove', move: 'd2d4', id: fallback.searches[0].id });
  assert.equal(await warm, 'd2d4');
  assert.equal(timers.size, 0);
  service.dispose();
});
