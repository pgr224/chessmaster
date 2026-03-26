import { Hono } from 'hono'
import { sign, verify } from 'hono/jwt'
import { z } from 'zod'
import { v4 as uuidv4 } from 'uuid'
import type { Env } from '../index'

const auth = new Hono<{ Bindings: Env }>()

// ────────────────────────────────────────
// SCHEMAS
// ────────────────────────────────────────
const RegisterSchema = z.object({
  username: z.string().min(2).max(30).regex(/^[a-zA-Z0-9_]+$/),
  deviceId: z.string().min(8).max(256),   // device fingerprint
  deviceModel: z.string().optional(),
  avatarUrl: z.string().url().optional(),
  isGhibli: z.boolean().optional(),
  localAvatar: z.string().optional(),
})

const LoginSchema = z.object({
  deviceId: z.string(),
})

// Check if username is already taken
auth.get('/check-username', async (c) => {
  const username = c.req.query('username')
  if (!username) return c.json({ error: 'Username required' }, 400)
  
  const existing = await c.env.DB.prepare(
    'SELECT id FROM users WHERE username = ?'
  ).bind(username).first()
  
  return c.json({ available: !existing })
})

// ────────────────────────────────────────
// REGISTER (Device Binding)
// ────────────────────────────────────────
auth.post('/register', async (c) => {
  const body = await c.req.json()
  const parsed = RegisterSchema.safeParse(body)
  if (!parsed.success) {
    return c.json({ error: 'Validation failed', details: parsed.error.flatten() }, 400)
  }

  const { username, deviceId, deviceModel, avatarUrl, isGhibli, localAvatar } = parsed.data
  const db = c.env.DB

  // Check if device already registered
  const existing = await db.prepare(
    'SELECT id, username FROM users WHERE device_id = ?'
  ).bind(deviceId).first<{ id: string; username: string }>()

  if (existing) {
    // Device already registered — return JWT
    const token = await sign(
      { sub: existing.id, username: existing.username, deviceId, exp: Math.floor(Date.now() / 1000) + 86400 * 30 },
      c.env.JWT_SECRET
    )
    return c.json({ token, userId: existing.id, username: existing.username })
  }

  // Check username uniqueness
  const usernameExists = await db.prepare(
    'SELECT id FROM users WHERE username = ?'
  ).bind(username).first()
  if (usernameExists) {
    return c.json({ error: 'Username already taken' }, 409)
  }

  const userId = uuidv4()
  const now = new Date().toISOString()

  // Create user
  await db.prepare(`
    INSERT INTO users (id, username, device_id, device_model, avatar_url, is_ghibli, local_avatar, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).bind(userId, username, deviceId, deviceModel ?? null, avatarUrl ?? null, isGhibli ? 1 : 0, localAvatar ?? null, now, now).run()

  // Create stats record
  await db.prepare(
    'INSERT INTO user_stats (user_id) VALUES (?)'
  ).bind(userId).run()

  const token = await sign(
    { sub: userId, username, deviceId, exp: Math.floor(Date.now() / 1000) + 86400 * 30 },
    c.env.JWT_SECRET
  )

  return c.json({ token, userId, username }, 201)
})

// ────────────────────────────────────────
// LOGIN (Device ID)
// ────────────────────────────────────────
auth.post('/login', async (c) => {
  const body = await c.req.json()
  const parsed = LoginSchema.safeParse(body)
  if (!parsed.success) {
    return c.json({ error: 'Validation failed' }, 400)
  }

  const user = await c.env.DB.prepare(
    'SELECT id, username FROM users WHERE device_id = ?'
  ).bind(parsed.data.deviceId).first<{ id: string; username: string }>()

  if (!user) {
    return c.json({ error: 'Device not registered' }, 404)
  }

  const token = await sign(
    { sub: user.id, username: user.username, deviceId: parsed.data.deviceId,
      exp: Math.floor(Date.now() / 1000) + 86400 * 30 },
    c.env.JWT_SECRET
  )

  // Update online status
  await c.env.DB.prepare(
    'UPDATE users SET is_online = 1, last_seen = ? WHERE id = ?'
  ).bind(new Date().toISOString(), user.id).run()

  return c.json({ token, userId: user.id, username: user.username })
})

// ────────────────────────────────────────
// REFRESH TOKEN
// ────────────────────────────────────────
auth.post('/refresh', async (c) => {
  const authHeader = c.req.header('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return c.json({ error: 'Missing token' }, 401)
  }

  try {
    const payload = await verify(authHeader.slice(7), c.env.JWT_SECRET, 'HS256')
    const newToken = await sign(
      { sub: payload.sub, username: payload.username, deviceId: payload.deviceId,
        exp: Math.floor(Date.now() / 1000) + 86400 * 30 },
      c.env.JWT_SECRET
    )
    return c.json({ token: newToken })
  } catch {
    return c.json({ error: 'Invalid token' }, 401)
  }
})

// ────────────────────────────────────────
// LOGOUT
// ────────────────────────────────────────
auth.post('/logout', async (c) => {
  const authHeader = c.req.header('Authorization')
  if (!authHeader?.startsWith('Bearer ')) return c.json({ ok: true })

  try {
    const payload = await verify(authHeader.slice(7), c.env.JWT_SECRET, 'HS256')
    await c.env.DB.prepare(
      'UPDATE users SET is_online = 0, last_seen = ? WHERE id = ?'
    ).bind(new Date().toISOString(), payload.sub).run()
  } catch (_) {}

  return c.json({ ok: true })
})

export { auth as authRoutes }
