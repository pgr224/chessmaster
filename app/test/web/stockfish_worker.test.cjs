const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');

const source = readFileSync(join(__dirname, '../../web/engine/stockfish_hybrid.worker.js'), 'utf8');

test('Stockfish loads on demand with a 32 MB hash and a single search thread', async () => {
  const imports = [];
  const commands = [];
  const messages = [];
  let receive;
  let uciOutput;
  const engine = {
    addMessageListener(listener) { uciOutput = listener; },
    postMessage(command) { commands.push(command); },
  };
  const context = vm.createContext({
    self: {
      addEventListener(type, listener) { receive = listener; },
      postMessage(message) { messages.push(message); },
    },
    importScripts(filename) { imports.push(filename); },
    Stockfish: () => engine,
  });
  vm.runInContext(source, context);
  assert.deepEqual(imports, []);
  assert.deepEqual(commands, []);
  await receive({ data: { type: 'init' } });
  assert.deepEqual(imports, ['stockfish.wasm.js']);
  assert.equal(commands.includes('setoption name Hash value 32'), true);
  assert.equal(commands.includes('setoption name Threads value 1'), true);
  assert.equal(commands.some(command => /256|EvalFile/.test(command)), false);
  uciOutput('readyok');
  assert.equal(messages[0].type, 'ready');
  await receive({ data: { type: 'search', fen: 'position', depth: 0, timeoutMs: 1500, multipv: 3, id: 7 } });
  assert.equal(commands.at(-1), 'isready');
  uciOutput('readyok');
  assert.equal(commands.at(-1), 'go movetime 1500');
  uciOutput('info depth 10 multipv 1 score cp 35 pv e2e4');
  uciOutput('bestmove e2e4');
  assert.equal(messages.at(-1).move, 'e2e4');
  assert.equal(messages.at(-1).id, 7);
  assert.equal(messages.at(-1).candidates[0].score, 35);
  await receive({ data: { type: 'init' } });
  assert.equal(imports.length, 1);
});

function workerHarness(factory) {
  const commands = [], messages = [], listeners = new Set();
  let receive, constructions = 0, terminations = 0;
  const engine = {
    addMessageListener(listener) { listeners.add(listener); },
    removeMessageListener(listener) { listeners.delete(listener); },
    postMessage(command) { commands.push(command); },
    terminate() { terminations++; },
  };
  const context = vm.createContext({
    self: { addEventListener: (_, listener) => { receive = listener; }, postMessage: message => messages.push(message) },
    importScripts() {},
    Stockfish() { constructions++; return factory ? factory(engine) : engine; },
  });
  vm.runInContext(source, context);
  return { commands, messages, engine, receive: data => receive({ data }),
    output: line => [...listeners].forEach(listener => listener(line)),
    get constructions() { return constructions; }, get terminations() { return terminations; },
    get listenerCount() { return listeners.size; },
  };
}

test('concurrent initialization is single-flight and a pre-ready search retains difficulty options', async () => {
  let resolve;
  const h = workerHarness(engine => new Promise(done => { resolve = () => done(engine); }));
  const init = h.receive({ type: 'init' });
  const search = h.receive({ type: 'search', fen: 'position', depth: 0, timeoutMs: 1500, multipv: 3, skillLevel: 16, id: 1 });
  const duplicate = h.receive({ type: 'init' });
  await Promise.resolve();
  assert.equal(h.constructions, 1);
  resolve();
  await Promise.all([init, search, duplicate]);
  h.output('readyok');
  assert.equal(h.commands.includes('setoption name Skill Level value 16'), true);
  assert.equal(h.commands.includes('setoption name MultiPV value 3'), true);
  assert.equal(h.commands.at(-1), 'go movetime 1500');
  assert.equal(h.listenerCount, 1);
});

test('stop drains the old search before the next ID can receive UCI output', async () => {
  const h = workerHarness();
  await h.receive({ type: 'init' }); h.output('readyok');
  await h.receive({ type: 'search', fen: 'first', depth: 0, timeoutMs: 2500, multipv: 3, id: 1 }); h.output('readyok');
  await h.receive({ type: 'search', fen: 'second', depth: 0, timeoutMs: 3500, multipv: 3, id: 2 });
  assert.equal(h.commands.at(-1), 'stop');
  assert.equal(h.commands.includes('position fen second'), false);
  h.output('info depth 10 multipv 1 score cp 500 pv a2a4');
  h.output('bestmove a2a4');
  assert.equal(h.messages.some(message => message.type === 'bestmove'), false);
  assert.equal(h.commands.at(-1), 'isready');
  h.output('bestmove h2h4'); // A delayed duplicate must be discarded at the barrier.
  h.output('readyok');
  assert.equal(h.commands.at(-1), 'go movetime 3500');
  h.output('info depth 10 multipv 1 score cp 35 pv e2e4');
  h.output('bestmove e2e4');
  const result = h.messages.at(-1);
  assert.equal(result.id, 2);
  assert.equal(result.move, 'e2e4');
  assert.deepEqual(JSON.parse(JSON.stringify(result.candidates)), [{ uci: 'e2e4', score: 35 }]);
});

test('quit during asynchronous WASM load disposes its late instance and permits a clean restart', async () => {
  let resolve;
  const h = workerHarness(engine => new Promise(done => { resolve = () => done(engine); }));
  const init = h.receive({ type: 'init' });
  await Promise.resolve();
  const search = h.receive({ type: 'search', fen: 'cancelled', id: 1 });
  await h.receive({ type: 'quit' });
  resolve();
  await Promise.all([init, search]);
  assert.equal(h.terminations, 1);
  assert.equal(h.listenerCount, 0);
  assert.equal(h.commands.length, 0);
  const restarted = h.receive({ type: 'init' });
  await Promise.resolve(); resolve(); await restarted;
  h.output('readyok');
  assert.equal(h.constructions, 2);
  assert.equal(h.listenerCount, 1);
  assert.equal(h.messages.at(-1).type, 'ready');
});

test('stop while loading drops pending work and engine initialization failures can retry', async () => {
  let resolve;
  const h = workerHarness(engine => new Promise(done => { resolve = () => done(engine); }));
  const search = h.receive({ type: 'search', fen: 'cancelled', id: 1 });
  await Promise.resolve();
  await h.receive({ type: 'stop' });
  resolve(); await search; h.output('readyok');
  assert.equal(h.commands.some(command => command.startsWith('go ')), false);

  let fail = true;
  const recovering = workerHarness(engine => { if (fail) { fail = false; throw new Error('WASM load failed'); } return engine; });
  await recovering.receive({ type: 'init' });
  assert.equal(recovering.messages.at(-1).type, 'error');
  await recovering.receive({ type: 'init' }); recovering.output('readyok');
  assert.equal(recovering.constructions, 2);
  assert.equal(recovering.messages.at(-1).type, 'ready');
});

test('one hundred completed searches reuse one WASM instance and one listener', async () => {
  const h = workerHarness();
  await h.receive({ type: 'init' }); h.output('readyok');
  for (let id = 1; id <= 100; id++) {
    await h.receive({ type: 'search', fen: 'position', depth: 0, timeoutMs: 2000, multipv: 3, skillLevel: 20, id });
    h.output('readyok');
    h.output('info depth 10 multipv 1 score cp 35 pv e2e4');
    h.output('bestmove e2e4');
    assert.equal(h.messages.at(-1).id, id);
  }
  assert.equal(h.constructions, 1);
  assert.equal(h.listenerCount, 1);
  assert.equal(h.messages.filter(message => message.type === 'bestmove').length, 100);
  await h.receive({ type: 'quit' });
  assert.equal(h.terminations, 1);
  assert.equal(h.listenerCount, 0);
});
