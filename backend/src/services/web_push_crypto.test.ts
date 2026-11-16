import assert from 'node:assert/strict'
import test from 'node:test'
import { base64url, createVapidJwt, decodeBase64url, encryptWebPush } from './web_push_crypto'

const encoder = new TextEncoder()
const join = (...parts: Uint8Array[]) => new Uint8Array(Buffer.concat(parts))
async function hkdf(input: Uint8Array, salt: Uint8Array, info: Uint8Array, bits: number) {
  const key = await crypto.subtle.importKey('raw', input, 'HKDF', false, ['deriveBits'])
  return new Uint8Array(await crypto.subtle.deriveBits({ name: 'HKDF', hash: 'SHA-256', salt, info }, key, bits))
}

test('encrypted Web Push decrypts with the subscriber key using RFC 8291 HKDF', async () => {
  const receiver = await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']) as CryptoKeyPair
  const receiverPublic = new Uint8Array(await crypto.subtle.exportKey('raw', receiver.publicKey))
  const auth = crypto.getRandomValues(new Uint8Array(16))
  const message = JSON.stringify({ title: 'Your turn ♟', data: { category: 'games', gameId: 'match-1' } })
  const body = await encryptWebPush(message, base64url(receiverPublic), base64url(auth))
  assert.equal(new DataView(body.buffer).getUint32(16), 4096)
  assert.equal(body[20], 65)
  const senderPublic = body.slice(21, 86)
  const sender = await crypto.subtle.importKey('raw', senderPublic, { name: 'ECDH', namedCurve: 'P-256' }, false, [])
  const shared = new Uint8Array(await crypto.subtle.deriveBits({ name: 'ECDH', public: sender }, receiver.privateKey, 256))
  // Deliberately use Web Crypto HKDF instead of the encoder's HMAC helpers.
  const ikm = await hkdf(shared, auth, join(encoder.encode('WebPush: info\0'), receiverPublic, senderPublic), 256)
  const keyBytes = await hkdf(ikm, body.slice(0, 16), encoder.encode('Content-Encoding: aes128gcm\0'), 128)
  const nonce = await hkdf(ikm, body.slice(0, 16), encoder.encode('Content-Encoding: nonce\0'), 96)
  const key = await crypto.subtle.importKey('raw', keyBytes, 'AES-GCM', false, ['decrypt'])
  const plaintext = new Uint8Array(await crypto.subtle.decrypt({ name: 'AES-GCM', iv: nonce }, key, body.slice(86)))
  assert.equal(plaintext.at(-1), 2, 'final record delimiter')
  assert.equal(new TextDecoder().decode(plaintext.slice(0, -1)), message)
  assert.notDeepEqual(await encryptWebPush(message, base64url(receiverPublic), base64url(auth)), body)
  body[body.length - 1] ^= 1
  await assert.rejects(crypto.subtle.decrypt({ name: 'AES-GCM', iv: nonce }, key, body.slice(86)))
})

test('Web Push rejects oversized UTF-8 content and malformed subscription keys', async () => {
  await assert.rejects(encryptWebPush('♟'.repeat(1400), '', ''), /3993 bytes/)
  await assert.rejects(encryptWebPush('message', base64url(new Uint8Array(65)), base64url(new Uint8Array(16))), /Invalid push/)
})

test('VAPID tokens verify as ES256 and bind audience to the push service origin', async () => {
  const pair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']) as CryptoKeyPair
  const pub = base64url(new Uint8Array(await crypto.subtle.exportKey('raw', pair.publicKey)))
  const jwk = await crypto.subtle.exportKey('jwk', pair.privateKey)
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey('pkcs8', pair.privateKey))
  const pem = `-----BEGIN PRIVATE KEY-----\n${Buffer.from(pkcs8).toString('base64')}\n-----END PRIVATE KEY-----`
  for (const privateKey of [jwk.d!, pem]) {
    const token = await createVapidJwt('https://push.example:8443/send/secret-id', pub, privateKey, 'mailto:owner@example.com')
    const [header, payload, signature] = token.split('.')
    assert.deepEqual(JSON.parse(new TextDecoder().decode(decodeBase64url(header))), { typ: 'JWT', alg: 'ES256' })
    const claims = JSON.parse(new TextDecoder().decode(decodeBase64url(payload)))
    assert.equal(claims.aud, 'https://push.example:8443')
    assert.equal(claims.sub, 'mailto:owner@example.com')
    const ttl = claims.exp - Math.floor(Date.now() / 1000)
    assert.ok(ttl > 43190 && ttl <= 43200)
    assert.equal(await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, pair.publicKey,
      decodeBase64url(signature), encoder.encode(`${header}.${payload}`)), true)
  }
})
