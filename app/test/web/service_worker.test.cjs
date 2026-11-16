const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = readFileSync(resolve(__dirname, '../../web/sw.js'), 'utf8');

function setup(clientList = []) {
  const events = new Map();
  const opened = [];
  const clients = {
    matchAll: async () => clientList,
    openWindow: async url => { opened.push(url); },
  };
  const self = {
    registration: { scope: 'https://chess.example/games/chess/' },
    addEventListener: (name, handler) => events.set(name, handler),
  };
  vm.runInNewContext(source, { self, clients, URL, URLSearchParams });
  return {
    opened,
    async click(data, action = '') {
      let pending;
      events.get('notificationclick')({
        action,
        notification: { data, close() {} },
        waitUntil: promise => { pending = promise; },
      });
      await pending;
    },
  };
}

test('notification actions open the app base with encoded Flutter hash deep links', async () => {
  const worker = setup();
  await worker.click({ type: 'CHALLENGE_RECEIVED', requestId: 'match&other=value' }, 'accept');
  const target = new URL(worker.opened[0]);
  assert.equal(target.pathname, '/games/chess/');
  const route = new URL(target.hash.slice(1), target);
  assert.equal(route.pathname, '/lobby');
  assert.equal(route.searchParams.get('accept_challenge'), 'match&other=value');
  assert.equal(route.searchParams.get('auto_accept'), 'true');
  assert.equal(route.searchParams.has('other'), false);
});

test('dismiss notification action leaves app closed', async () => {
  const worker = setup();
  await worker.click({ type: 'CHALLENGE_RECEIVED', requestId: 'match' }, 'close');
  assert.equal(worker.opened.length, 0);
});

test('XP reject links preserve the request and action', async () => {
  const worker = setup();
  await worker.click({ type: 'XP_DIRECT_REQUEST', requestId: 'request-1' }, 'reject_xp');
  assert.equal(worker.opened[0], 'https://chess.example/games/chess/#/lobby?xp_request_id=request-1&auto_reject_xp=true');
});

test('reuse only a client within this app scope and handle notifications without data', async () => {
  const navigated = [];
  const app = {
    url: 'https://chess.example/games/chess/#/home',
    navigate: async url => { navigated.push(url); return app; },
    focus: async () => {},
  };
  const unrelatedApp = {
    url: 'https://chess.example/some-other-app/',
    navigate: async () => { throw new Error('Must not navigate a different app'); },
    focus: async () => {},
  };
  const worker = setup([unrelatedApp, app]);
  await worker.click(undefined);
  assert.deepEqual(navigated, ['https://chess.example/games/chess/']);
  assert.equal(worker.opened.length, 0);
});
