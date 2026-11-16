const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');
const source = readFileSync(join(__dirname, '../../web/engine/sunfish_engine.js'), 'utf8');
const START = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const TACTICAL = 'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1';

function harness(advanceClock) {
  let ticks = 0;
  const self = {};
  const context = vm.createContext({ self, Date: { now: () => advanceClock ? ticks++ : 0 } });
  vm.runInContext(source, context);
  return { self, context, get clockChecks() { return ticks; } };
}

test('Sunfish checks the deadline inside recursive search and returns a completed legal move', () => {
  const h = harness(true);
  const result = h.self.searchBestMove(TACTICAL, 5, 8);
  const board = new h.self.SunfishBoard(); board.loadFEN(TACTICAL);
  const legal = board.legalMoves().map(m => h.self.SunfishBoard.toAlg(m.from) + h.self.SunfishBoard.toAlg(m.to) + (m.promo ? ({5:'q',4:'r',3:'b',2:'n'}[m.promo] || '') : ''));
  assert.equal(legal.includes(result.move), true);
  assert.equal(h.clockChecks < 16, true, `clock checked ${h.clockChecks} times after an 8-tick budget`);
});

test('candidate analysis uses the same deadline and does not start an unbounded second search', () => {
  const h = harness(false);
  const result = h.self.searchBestMove(START, 2, 10000);
  assert.match(result.move, /^[a-h][1-8][a-h][1-8][qrbn]?$/);
  assert.equal(result.candidates.length, 3);
  const bounded = harness(true);
  const timed = bounded.self.searchBestMove(START, 2, 4);
  assert.match(timed.move, /^[a-h][1-8][a-h][1-8][qrbn]?$/);
  assert.equal(bounded.clockChecks < 12, true);
});

test('the same Sunfish worker remains usable for repeated budget-limited positions', () => {
  const h = harness(true);
  for (let i = 0; i < 20; i++) {
    const result = h.self.searchBestMove(i % 2 ? TACTICAL : START, 5, 5);
    assert.match(result.move, /^[a-h][1-8][a-h][1-8][qrbn]?$/);
  }
});

test('search deadlines use a monotonic clock when the device wall clock changes',()=>{
 let ticks=0;const self={};
 const context=vm.createContext({self,performance:{now:()=>ticks++},Date:{now:()=>{throw Error('wall clock must not control a search')}}});
 vm.runInContext(source,context);
 assert.match(self.searchBestMove(TACTICAL,5,8).move,/^[a-h][1-8][a-h][1-8][qrbn]?$/);
 assert.ok(ticks<16);
});
