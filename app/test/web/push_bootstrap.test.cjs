const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = readFileSync(resolve(__dirname, '../../web/push_bootstrap.js'), 'utf8');

function setup({ permission = 'granted', subscription = { endpoint: 'https://push.example/one' }, values = {}, subscriptionFactory } = {}) {
  const listeners = new Map();
  const calls = { registrations: [], fetches: [], permission: 0, subscriptions: [], unsubscribes: 0 };
  function revocable(value) {
    return { ...value, unsubscribe: async () => { calls.unsubscribes++; subscription = null; return true; } };
  }
  if (subscription) subscription = revocable(subscription);
  let idle;
  const registration = {
    active: {},
    pushManager: {
      getSubscription: async () => subscription,
      subscribe: async options => {
        calls.subscriptions.push(options);
        subscription = revocable(subscriptionFactory ? await subscriptionFactory() : { endpoint: 'https://push.example/new' });
        return subscription;
      },
    },
  };
  const context = {
    URL, Uint8Array, atob,
    document: { baseURI: 'https://chess.example/games/chess/' },
    localStorage: { getItem: key => values[key] ?? null },
    navigator: {
      serviceWorker: {
        register: async (...args) => { calls.registrations.push(args); return registration; },
        getRegistration: async () => registration,
        ready: Promise.resolve(registration),
      },
    },
    Notification: {
      permission,
      requestPermission: async () => { calls.permission++; context.Notification.permission = 'granted'; return 'granted'; },
    },
    PushManager: function () {},
    fetch: async (...args) => {
      calls.fetches.push(args);
      return { ok: true, json: async () => ({ publicKey: 'AQID' }) };
    },
    addEventListener: (name, listener) => listeners.set(name, listener),
    requestIdleCallback: callback => { idle = callback; },
  };
  context.window = context;
  vm.runInNewContext(source, context);
  return { context, calls, listeners, runIdle: () => idle() };
}

const authenticatedValues = {
  'flutter.auth_token': JSON.stringify('Bearer actual-token'),
  'flutter.user_data': JSON.stringify(JSON.stringify({ id: 'player-1', device_id: 'device-1' })),
};

test('startup defers service worker setup and never asks for notification permission', async () => {
  const app = setup({ permission: 'default' });
  app.listeners.get('load')();
  assert.equal(app.calls.registrations.length, 0);
  app.runIdle();
  await new Promise(setImmediate);
  assert.deepEqual(JSON.parse(JSON.stringify(app.calls.registrations)), [
    ['https://chess.example/games/chess/sw.js', { scope: '/games/chess/' }],
  ]);
  assert.equal(app.calls.permission, 0);
  assert.equal(app.calls.fetches.length, 0);
});

test('an existing subscription uses configured API and decoded Flutter credentials without refetching VAPID', async () => {
  const app = setup({ values: authenticatedValues });
  app.context.ChessPush.configure('https://api.example/custom/');
  assert.equal(await app.context.ChessPush.sync(), true);
  assert.equal(app.calls.fetches.length, 1);
  const [url, options] = app.calls.fetches[0];
  assert.equal(url, 'https://api.example/custom/api/push/subscribe');
  assert.equal(options.headers.Authorization, 'Bearer actual-token');
  assert.deepEqual(JSON.parse(options.body), {
    userId: 'player-1', deviceId: 'device-1', subscription: { endpoint: 'https://push.example/one' },
  });
  assert.equal(app.calls.subscriptions.length, 0);
});

test('only explicit enable requests permission and creates an authenticated subscription', async () => {
  const app = setup({ permission: 'default', subscription: null, values: authenticatedValues });
  app.context.ChessPush.configure('https://api.example');
  assert.equal(await app.context.ChessPush.sync(), false);
  assert.equal(app.calls.permission, 0);
  assert.equal(await app.context.ChessPush.enable(), true);
  assert.equal(app.calls.permission, 1);
  assert.equal(app.calls.subscriptions.length, 1);
  assert.deepEqual(Array.from(app.calls.subscriptions[0].applicationServerKey), [1, 2, 3]);
  assert.deepEqual(app.calls.fetches.map(([url]) => url), [
    'https://api.example/api/push/vapid-public-key',
    'https://api.example/api/push/subscribe',
  ]);
});

test('concurrent auth/load sync calls share one subscription request', async () => {
  const app = setup({ values: authenticatedValues });
  app.context.ChessPush.configure('https://api.example');
  const first = app.context.ChessPush.sync();
  assert.equal(first, app.context.ChessPush.sync());
  assert.equal(await first, true);
  assert.equal(app.calls.registrations.length, 1);
  assert.equal(app.calls.fetches.length, 1);
});

test('explicit settings enable succeeds before the old disabled preference is persisted', async () => {
  const app = setup({ values: { ...authenticatedValues, 'flutter.notifications': 'false' } });
  app.context.ChessPush.configure('https://api.example');
  const passiveSync = app.context.ChessPush.sync();
  const enabled = app.context.ChessPush.enable();
  assert.equal(await passiveSync, false);
  assert.equal(await enabled, true);
  assert.equal(app.calls.fetches.length, 1);
  assert.equal(app.calls.permission, 0);
});

test('load registration never bypasses the persisted notification preference', async () => {
  const app = setup({ values: { ...authenticatedValues, 'flutter.notifications': 'false' } });
  app.context.ChessPush.configure('https://api.example');
  app.listeners.get('load')();
  app.runIdle();
  await new Promise(setImmediate);
  assert.equal(app.calls.registrations.length, 1);
  assert.equal(app.calls.fetches.length, 0);
});

test('guests, disabled notifications and unavailable storage do not block startup or call the API', async () => {
  for (const values of [
    {},
    { ...authenticatedValues, 'flutter.notifications': 'false' },
    { ...authenticatedValues, 'flutter.user_data': JSON.stringify({ id: 'guest-1', is_guest: true }) },
  ]) {
    const app = setup({ values });
    app.context.ChessPush.configure('https://api.example');
    assert.equal(await app.context.ChessPush.sync(), false);
    assert.equal(app.calls.fetches.length, 0);
  }
  const app = setup();
  app.context.ChessPush.configure('https://api.example');
  app.context.localStorage.getItem = () => { throw new Error('Storage disabled'); };
  assert.equal(await app.context.ChessPush.sync(), false);
});

test('disabling notifications revokes the browser endpoint and removes its account association', async () => {
  const app = setup({ values: { ...authenticatedValues } });
  app.context.ChessPush.configure('https://api.example');
  assert.equal(await app.context.ChessPush.sync(), true);
  await app.context.ChessPush.disable();
  assert.equal(app.calls.unsubscribes, 1);
  const [url, options] = app.calls.fetches.at(-1);
  assert.equal(url, 'https://api.example/api/push/unsubscribe');
  assert.deepEqual(JSON.parse(options.body), { endpoint: 'https://push.example/one' });
  assert.equal(options.headers.Authorization, 'Bearer actual-token');
});

test('sign-out revokes an existing endpoint even after credentials have been removed', async () => {
  const app = setup();
  app.context.ChessPush.configure('https://api.example');
  await app.context.ChessPush.disable();
  assert.equal(app.calls.unsubscribes, 1);
  assert.equal(app.calls.fetches.length, 0);
  assert.equal(app.calls.registrations.length, 0, 'must not register a new worker on sign-out');
});

test('sign-out cancels an in-flight subscription before it can be registered to an account', async () => {
  let finishSubscription;
  const app = setup({
    subscription: null,
    values: { ...authenticatedValues },
    subscriptionFactory: () => new Promise(resolve => { finishSubscription = resolve; }),
  });
  app.context.ChessPush.configure('https://api.example');
  const enabling = app.context.ChessPush.enable();
  await new Promise(setImmediate);
  assert.equal(typeof finishSubscription, 'function');
  await app.context.ChessPush.disable();
  finishSubscription({ endpoint: 'https://push.example/pending' });
  assert.equal(await enabling, false);
  assert.equal(app.calls.unsubscribes, 1);
  assert.deepEqual(app.calls.fetches.map(([url]) => url), ['https://api.example/api/push/vapid-public-key']);
});
