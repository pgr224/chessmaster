import { Hono } from 'hono'
import { verify } from 'hono/jwt'
import { z } from 'zod'
import { buildProfileData } from './profile'
import type { Env } from '../index'
import {
  createAuthToken,
  createId,
  JWT_ALG,
  normalizeUsername,
  readJson,
  validationError,
  type AuthUser,
} from '../auth_utils'

const auth = new Hono<{ Bindings: Env }>()

const usernameSchema = z
  .string()
  .transform(normalizeUsername)
  .pipe(z.string().min(3).max(30).regex(/^[a-zA-Z0-9_]+$/))

const RegisterSchema = z.object({
  username: usernameSchema,
  deviceId: z.string().trim().min(8).max(256),
  deviceModel: z.string().trim().max(120).optional(),
  avatarUrl: z.string().url().optional(),
  isGhibli: z.boolean().optional(),
  localAvatar: z.string().max(512).optional(),
})

const LoginSchema = z.object({
  deviceId: z.string().trim().min(8).max(256),
})

const CompatSchema = z
  .object({
    mode: z.enum(['login', 'signin', 'sign-in', 'signup', 'register', 'sign-up']).optional(),
    action: z.enum(['login', 'signin', 'sign-in', 'signup', 'register', 'sign-up']).optional(),
    username: z.string().optional(),
    deviceId: z.string().optional(),
    deviceModel: z.string().optional(),
    avatarUrl: z.string().optional(),
    isGhibli: z.boolean().optional(),
    localAvatar: z.string().optional(),
  })
  .passthrough()

function getAuthMode(body: z.infer<typeof CompatSchema>) {
  const mode = body.mode ?? body.action
  if (mode === 'signup' || mode === 'register' || mode === 'sign-up') return 'register'
  return 'login'
}

async function existingUserByDevice(c: any, deviceId: string) {
  return c.env.DB.prepare('SELECT id, username FROM users WHERE device_id = ?')
    .bind(deviceId)
    .first<{ id: string; username: string }>()
}

async function responseForUser(c: any, userId: string, username: string, deviceId: string, status = 200) {
  const token = await createAuthToken(c.env, { sub: userId, username, deviceId })
  await c.env.DB.prepare(
    'UPDATE users SET is_online = 1, last_seen = ?, updated_at = ? WHERE id = ?'
  ).bind(new Date().toISOString(), new Date().toISOString(), userId).run()

  const profile = await buildProfileData(c, userId)
  if (!profile) {
    return c.json({ error: 'Failed to load user profile' }, 500)
  }

  return c.json({ token, userId, username, user: profile }, status)
}

auth.get('/check-username', async (c) => {
  const parsed = usernameSchema.safeParse(c.req.query('username') ?? '')
  if (!parsed.success) return c.json(validationError(parsed.error), 400)

  const existing = await c.env.DB.prepare(
    'SELECT id FROM users WHERE username = ? COLLATE NOCASE'
  ).bind(parsed.data).first()

  return c.json({ available: !existing, username: parsed.data })
})

auth.post('/', async (c) => {
  const body = await readJson(c)
  if (!body) return c.json({ error: 'Invalid JSON body' }, 400)

  const parsed = CompatSchema.safeParse(body)
  if (!parsed.success) return c.json(validationError(parsed.error), 400)

  if (getAuthMode(parsed.data) === 'register') {
    return registerWithBody(c, parsed.data)
  }

  return loginWithBody(c, parsed.data)
})

auth.post('/register', async (c) => {
  const body = await readJson(c)
  if (!body) return c.json({ error: 'Invalid JSON body' }, 400)
  return registerWithBody(c, body)
})

auth.post('/login', async (c) => {
  const body = await readJson(c)
  if (!body) return c.json({ error: 'Invalid JSON body' }, 400)
  return loginWithBody(c, body)
})

async function registerWithBody(c: any, body: unknown) {
  const parsed = RegisterSchema.safeParse(body)
  if (!parsed.success) return c.json(validationError(parsed.error), 400)

  const { username, deviceId, deviceModel, avatarUrl, isGhibli, localAvatar } = parsed.data
  const db = c.env.DB
  const now = new Date().toISOString()

  try {
    const existingBinding = await existingUserByDevice(c, deviceId)

    if (existingBinding) {
      if (existingBinding.username.toLowerCase() === username.toLowerCase()) {
        return responseForUser(c, existingBinding.id, existingBinding.username, deviceId)
      }

      await db.prepare(
        "UPDATE users SET device_id = 'unbound_' || id, updated_at = ? WHERE id = ?"
      ).bind(now, existingBinding.id).run()
    }

    const usernameOwner = await db.prepare(
      'SELECT id, username FROM users WHERE username = ? COLLATE NOCASE'
    ).bind(username).first<{ id: string; username: string }>()

    let userId: string
    let responseUsername = username
    let status = 201

    if (usernameOwner) {
      userId = usernameOwner.id
      responseUsername = usernameOwner.username
      status = 200
      await db.prepare(`
        UPDATE users
        SET device_id = ?, device_model = ?, updated_at = ?
        WHERE id = ?
      `).bind(deviceId, deviceModel ?? null, now, userId).run()
    } else {
      userId = createId()
      await db.prepare(`
        INSERT INTO users (
          id, username, device_id, device_model, avatar_url, is_ghibli,
          local_avatar, is_online, last_seen, created_at, updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)
      `).bind(
        userId,
        username,
        deviceId,
        deviceModel ?? null,
        avatarUrl ?? null,
        isGhibli ? 1 : 0,
        localAvatar ?? null,
        now,
        now,
        now
      ).run()

      await db.prepare('INSERT OR IGNORE INTO user_stats (user_id) VALUES (?)')
        .bind(userId)
        .run()
    }

    return responseForUser(c, userId, responseUsername, deviceId, status)
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    if (message.includes('UNIQUE constraint failed: users.username')) {
      return c.json({ error: 'Username already taken' }, 409)
    }
    if (message.includes('UNIQUE constraint failed: users.device_id')) {
      return c.json({ error: 'Device is already linked to another account' }, 409)
    }

    console.error('Registration error:', err)
    return c.json({ error: 'Registration failed' }, 500)
  }
}

async function loginWithBody(c: any, body: unknown) {
  const parsed = LoginSchema.safeParse(body)
  if (!parsed.success) return c.json(validationError(parsed.error), 400)

  try {
    const user = await existingUserByDevice(c, parsed.data.deviceId)
    if (!user) {
      return c.json({ error: 'Device not registered' }, 404)
    }

    return responseForUser(c, user.id, user.username, parsed.data.deviceId)
  } catch (err) {
    console.error('Login error:', err)
    return c.json({ error: 'Login failed' }, 500)
  }
}

auth.post('/refresh', async (c) => {
  const authHeader = c.req.header('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return c.json({ error: 'Missing token' }, 401)
  }

  try {
    if (!c.env.JWT_SECRET) return c.json({ error: 'Auth is not configured' }, 500)

    const payload = (await verify(authHeader.slice(7), c.env.JWT_SECRET, JWT_ALG)) as AuthUser
    if (!payload.sub) return c.json({ error: 'Invalid token payload' }, 401)

    const user = await c.env.DB.prepare('SELECT username, device_id FROM users WHERE id = ?')
      .bind(payload.sub)
      .first<{ username: string; device_id: string }>()
    if (!user?.username) return c.json({ error: 'User not found' }, 401)

    const token = await createAuthToken(c.env, {
      sub: payload.sub,
      username: user.username,
      deviceId: user.device_id ?? payload.deviceId,
    })

    return c.json({ token, username: user.username })
  } catch {
    return c.json({ error: 'Invalid token' }, 401)
  }
})

auth.post('/logout', async (c) => {
  const authHeader = c.req.header('Authorization')
  if (!authHeader?.startsWith('Bearer ')) return c.json({ ok: true })

  try {
    if (c.env.JWT_SECRET) {
      const payload = (await verify(authHeader.slice(7), c.env.JWT_SECRET, JWT_ALG)) as AuthUser
      if (payload.sub) {
        await c.env.DB.prepare(
          'UPDATE users SET is_online = 0, last_seen = ?, updated_at = ? WHERE id = ?'
        ).bind(new Date().toISOString(), new Date().toISOString(), payload.sub).run()
      }
    }
  } catch (_) {}

  return c.json({ ok: true })
})

export { auth as authRoutes }
