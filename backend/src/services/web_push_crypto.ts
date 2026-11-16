/** RFC 8291/8188 single-record aes128gcm encryption using Workers Web Crypto. */
const text = new TextEncoder()
export const base64url = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
export const decodeBase64url = (value: string) => Uint8Array.from(atob(value.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - value.length % 4) % 4)), c => c.charCodeAt(0))
const concat = (...parts: Uint8Array[]) => {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0))
  let offset = 0
  for (const part of parts) { out.set(part, offset); offset += part.length }
  return out
}
const hmac = async (key: Uint8Array, data: Uint8Array) => new Uint8Array(await crypto.subtle.sign('HMAC', await crypto.subtle.importKey('raw', key, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']), data))

export async function encryptWebPush(payload: string, publicKey: string, auth: string): Promise<Uint8Array> {
  const plaintext = text.encode(payload)
  if (plaintext.length > 3993) throw new Error('Web Push payload exceeds 3993 bytes')
  const receiver = decodeBase64url(publicKey)
  const secret = decodeBase64url(auth)
  if (receiver.length !== 65 || receiver[0] !== 4 || secret.length !== 16) throw new Error('Invalid push subscription keys')
  const sender = await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']) as CryptoKeyPair
  const senderPublic = new Uint8Array(await crypto.subtle.exportKey('raw', sender.publicKey) as ArrayBuffer)
  const receiverKey = await crypto.subtle.importKey('raw', receiver, { name: 'ECDH', namedCurve: 'P-256' }, false, [])
  const shared = new Uint8Array(await crypto.subtle.deriveBits(Object.assign({ name: 'ECDH' }, { public: receiverKey }), sender.privateKey, 256))
  const keyPrk = await hmac(secret, shared)
  const ikm = await hmac(keyPrk, concat(text.encode('WebPush: info\0'), receiver, senderPublic, new Uint8Array([1])))
  const salt = crypto.getRandomValues(new Uint8Array(16))
  const prk = await hmac(salt, ikm)
  const key = (await hmac(prk, concat(text.encode('Content-Encoding: aes128gcm\0'), new Uint8Array([1])))).slice(0, 16)
  const nonce = (await hmac(prk, concat(text.encode('Content-Encoding: nonce\0'), new Uint8Array([1])))).slice(0, 12)
  const cek = await crypto.subtle.importKey('raw', key, 'AES-GCM', false, ['encrypt'])
  const encrypted = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv: nonce }, cek, concat(plaintext, new Uint8Array([2]))))
  // salt(16), record size(4), key ID length(1), sender public key(65), ciphertext.
  const header = new Uint8Array(21)
  header.set(salt)
  new DataView(header.buffer).setUint32(16, 4096)
  header[20] = senderPublic.length
  return concat(header, senderPublic, encrypted)
}

export async function createVapidJwt(endpoint: string, publicKey: string, privateKey: string, subject: string): Promise<string> {
  const pub = decodeBase64url(publicKey)
  if (pub.length !== 65 || pub[0] !== 4) throw new Error('Invalid VAPID public key')
  const raw = privateKey.includes('BEGIN')
    ? decodeBase64url(privateKey.replace(/-----[^-]+-----/g, '').replace(/\s/g, ''))
    : decodeBase64url(privateKey)
  const key = raw.length === 32
    ? await crypto.subtle.importKey('jwk', { kty: 'EC', crv: 'P-256', x: base64url(pub.slice(1, 33)), y: base64url(pub.slice(33)), d: base64url(raw) }, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'])
    : await crypto.subtle.importKey('pkcs8', raw, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'])
  const jwt = `${base64url(text.encode(JSON.stringify({ typ: 'JWT', alg: 'ES256' })))}.${base64url(text.encode(JSON.stringify({ aud: new URL(endpoint).origin, exp: Math.floor(Date.now() / 1000) + 12 * 3600, sub: subject })))}`
  const signature = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, text.encode(jwt))
  return `${jwt}.${base64url(new Uint8Array(signature))}`
}
