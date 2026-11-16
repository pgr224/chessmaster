import assert from 'node:assert/strict'
import test from 'node:test'
import { Hono } from 'hono'
import { sign } from 'hono/jwt'
import type { Env } from '../index'
import { testDB } from '../test_support/sqlite'
import { pushRoutes } from './push'
import { PushService, notificationAllowed } from '../services/push_service'
import { base64url, decodeBase64url } from '../services/web_push_crypto'

const schema = `
CREATE TABLE users(id TEXT PRIMARY KEY,push_enabled INTEGER DEFAULT 1);
CREATE TABLE user_notification_preferences(user_id TEXT PRIMARY KEY,game_notifications INTEGER DEFAULT 1,
 challenge_notifications INTEGER DEFAULT 1,community_notifications INTEGER DEFAULT 1,
 tournament_notifications INTEGER DEFAULT 1,system_notifications INTEGER DEFAULT 1,updated_at TEXT);
CREATE TABLE user_subscriptions(id TEXT PRIMARY KEY,user_id TEXT,endpoint TEXT,p256dh TEXT,auth TEXT,device_id TEXT);
CREATE TABLE native_push_tokens(token TEXT PRIMARY KEY,user_id TEXT,platform TEXT,device_id TEXT,updated_at TEXT);
INSERT INTO users(id) VALUES('alice'),('bob');`
const secret = 'notification-test-secret-with-enough-entropy'
async function setup() {
  const env = { DB: testDB(schema), JWT_SECRET: secret } as Env
  const token = await sign({ sub: 'alice', exp: Math.floor(Date.now() / 1000) + 60 }, secret, 'HS256')
  const app = new Hono().route('/push', pushRoutes)
  return { env, request: (path: string, method = 'GET', body?: unknown) => app.request(`/push${path}`, {
    method, headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  }, env) }
}

test('master preference and all five category preferences gate delivery', () => {
  for (const disabled of [0, false, null, undefined, '1']) assert.equal(notificationAllowed(disabled, null, 'games'), false)
  for (const [category, column] of Object.entries({ challenges: 'challenge_notifications', games: 'game_notifications', community: 'community_notifications', tournaments: 'tournament_notifications', system: 'system_notifications' })) {
    assert.equal(notificationAllowed(1, null, category as any), true)
    assert.equal(notificationAllowed(true, { [column]: 0 }, category as any), false)
    assert.equal(notificationAllowed(true, { [column]: false }, category as any), false)
  }
})

test('partial preferences belong to JWT account and preserve every unspecified setting', async () => {
  const { env, request } = await setup()
  assert.equal((await request('/settings', 'PUT', { userId: 'bob', enabled: false, categories: { games: false } })).status, 200)
  assert.equal((await request('/settings', 'PUT', { categories: { tournaments: false } })).status, 200)
  const response = await request('/settings')
  assert.deepEqual(await response.json(), { enabled: false, categories: { games: false, challenges: true, community: true, tournaments: false, system: true } })
  assert.equal((await env.DB.prepare('SELECT push_enabled FROM users WHERE id=?').bind('bob').first<any>())!.push_enabled, 1)
  assert.equal((await request('/settings', 'PUT', { enabled: 'false' })).status, 400)
  assert.equal((await request('/settings', 'PUT', { categories: { unknown: false } })).status, 400)
})

test('browser and native token transfer removes the previous account association', async () => {
  const { env, request } = await setup()
  await env.DB.prepare('INSERT INTO user_subscriptions VALUES(?,?,?,?,?,?)').bind('old', 'bob', 'https://push.example/one', 'old-key', 'old-auth', 'browser').run()
  const subscription = { endpoint: 'https://push.example/one', keys: { p256dh: 'public-key', auth: 'auth-secret' } }
  assert.equal((await request('/subscribe', 'POST', { userId: 'bob', subscription })).status, 201)
  assert.equal((await request('/subscribe', 'POST', { subscription })).status, 201)
  const rows = await env.DB.prepare('SELECT user_id FROM user_subscriptions').all<any>()
  assert.deepEqual(rows.results.map(row => row.user_id), ['alice'])
  const token = 'test-device-token-long-enough'
  await env.DB.prepare('INSERT INTO native_push_tokens(token,user_id,platform) VALUES(?,?,?)').bind(token, 'bob', 'android').run()
  assert.equal((await request('/native-token', 'POST', { userId: 'bob', token, platform: 'ios' })).status, 200)
  assert.equal((await env.DB.prepare('SELECT user_id FROM native_push_tokens WHERE token=?').bind(token).first<any>())!.user_id, 'alice')
  await request('/native-token', 'DELETE', { token })
  assert.equal(await env.DB.prepare('SELECT * FROM native_push_tokens WHERE token=?').bind(token).first(), null)
})

test('push endpoints require JWT while configuration status distinguishes unset providers', async () => {
  const app = new Hono().route('/push', pushRoutes)
  const { env, request } = await setup()
  assert.equal((await app.request('/push/settings', {}, env)).status, 401)
  assert.equal((await app.request('/push/vapid-public-key', {}, env)).status, 503)
  assert.deepEqual(await (await request('/status')).json(), { webConfigured: false, nativeConfigured: false })
})

test('disabled users and categories never make outbound provider calls', async () => {
  const { env, request } = await setup()
  const originalFetch = globalThis.fetch
  let calls = 0
  globalThis.fetch = async () => { calls++; throw new Error('Unexpected network request') }
  try {
    await request('/settings', 'PUT', { enabled: false })
    assert.deepEqual(await PushService.notifyUser('alice', { title: 'Turn', body: 'Your turn' }, env, 'games'), { sent: 0, disabled: true })
    await request('/settings', 'PUT', { enabled: true, categories: { games: false } })
    assert.deepEqual(await PushService.notifyUser('alice', { title: 'Turn', body: 'Your turn' }, env, 'games'), { sent: 0, disabled: true })
    assert.equal(calls, 0)
  } finally { globalThis.fetch = originalFetch }
})

test('Web Push sends encrypted content with VAPID and prunes an expired account endpoint', async () => {
  const { env } = await setup()
  const vapid = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']) as CryptoKeyPair
  env.VAPID_PUBLIC_KEY = base64url(new Uint8Array(await crypto.subtle.exportKey('raw', vapid.publicKey)))
  env.VAPID_PRIVATE_KEY = (await crypto.subtle.exportKey('jwk', vapid.privateKey)).d!
  const receiver = await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']) as CryptoKeyPair
  const publicKey = base64url(new Uint8Array(await crypto.subtle.exportKey('raw', receiver.publicKey)))
  const auth = base64url(crypto.getRandomValues(new Uint8Array(16)))
  await env.DB.prepare('INSERT INTO user_subscriptions VALUES(?,?,?,?,?,?)').bind('endpoint-1', 'alice', 'https://push.example/expired', publicKey, auth, 'web').run()
  const originalFetch = globalThis.fetch
  let calls = 0
  globalThis.fetch = async (input, init) => {
    calls++
    assert.equal(input, 'https://push.example/expired')
    const headers = new Headers(init!.headers)
    assert.equal(headers.get('Content-Encoding'), 'aes128gcm')
    const match = /^vapid t=([^,]+), k=(.+)$/.exec(headers.get('Authorization')!)!
    assert.ok(match)
    assert.equal(match[2], env.VAPID_PUBLIC_KEY)
    const claims = JSON.parse(new TextDecoder().decode(decodeBase64url(match[1].split('.')[1])))
    assert.equal(claims.aud, 'https://push.example')
    assert.ok((init!.body as Uint8Array).length > 86)
    return new Response(null, { status: 410 })
  }
  try {
    assert.deepEqual(await PushService.notifyUser('alice', { title: 'Turn', body: 'Your turn' }, env, 'games'), { sent: 0, disabled: false })
    assert.equal(calls, 1)
    assert.equal(await env.DB.prepare('SELECT * FROM user_subscriptions WHERE id=?').bind('endpoint-1').first(), null)
  } finally { globalThis.fetch = originalFetch }
})

test('FCM authenticates, sets category channels and removes unregistered native tokens', async () => {
  const { env } = await setup()
  const rsa = await crypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['sign', 'verify']) as CryptoKeyPair
  const key = Buffer.from(await crypto.subtle.exportKey('pkcs8', rsa.privateKey)).toString('base64')
  env.FCM_SERVICE_ACCOUNT = JSON.stringify({ project_id: 'chess-test', client_email: 'sender@chess-test.iam.gserviceaccount.com',
    private_key: `-----BEGIN PRIVATE KEY-----\n${key}\n-----END PRIVATE KEY-----` })
  for (const [token, platform] of [['expired-token', 'ios'], ['working-token', 'android']]) {
    await env.DB.prepare('INSERT INTO native_push_tokens(token,user_id,platform) VALUES(?,?,?)').bind(token, 'alice', platform).run()
  }
  const originalFetch = globalThis.fetch
  const messages: any[] = []
  globalThis.fetch = async (input, init) => {
    if (input === 'https://oauth2.googleapis.com/token') {
      const form = init!.body as URLSearchParams
      assert.equal(form.get('grant_type'), 'urn:ietf:params:oauth:grant-type:jwt-bearer')
      const assertion = form.get('assertion')!.split('.')
      const claims = JSON.parse(Buffer.from(assertion[1], 'base64url').toString())
      assert.equal(claims.aud, 'https://oauth2.googleapis.com/token')
      assert.equal(claims.scope, 'https://www.googleapis.com/auth/firebase.messaging')
      assert.equal(await crypto.subtle.verify('RSASSA-PKCS1-v1_5', rsa.publicKey,
        Buffer.from(assertion[2], 'base64url'), new TextEncoder().encode(assertion.slice(0, 2).join('.'))), true)
      return Response.json({ access_token: 'test-access-token' })
    }
    assert.equal(input, 'https://fcm.googleapis.com/v1/projects/chess-test/messages:send')
    assert.equal(new Headers(init!.headers).get('Authorization'), 'Bearer test-access-token')
    const { message } = JSON.parse(init!.body as string)
    messages.push(message)
    return message.token === 'expired-token'
      ? Response.json({ error: { details: [{ errorCode: 'UNREGISTERED' }] } }, { status: 404 })
      : Response.json({ name: 'projects/chess-test/messages/sent' })
  }
  try {
    assert.deepEqual(await PushService.notifyUser('alice', { title: 'Invitation', body: 'Join this tournament',
      data: { tournamentId: 'event-1', round: 2 } }, env, 'tournaments'), { sent: 1, disabled: false })
    assert.equal(messages.length, 2)
    assert.equal(messages[1].android.notification.channel_id, 'chess_tournaments')
    assert.deepEqual(messages[1].data, { tournamentId: 'event-1', round: '2', category: 'tournaments' })
    assert.equal(await env.DB.prepare('SELECT * FROM native_push_tokens WHERE token=?').bind('expired-token').first(), null)
  } finally { globalThis.fetch = originalFetch }
})
