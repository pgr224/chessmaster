import { Context, Next } from 'hono'
import { verify } from 'hono/jwt'
import type { Env } from '../index'
import { JWT_ALG, type AppVariables, type AuthUser } from '../auth_utils'

export async function authMiddleware(
  c: Context<{ Bindings: Env; Variables: AppVariables }>,
  next: Next
) {
  const authHeader = c.req.header('Authorization')

  if (!authHeader?.startsWith('Bearer ')) {
    return c.json({ error: 'Unauthorized - missing token' }, 401)
  }

  try {
    if (!c.env.JWT_SECRET) {
      return c.json({ error: 'Auth is not configured' }, 500)
    }

    const payload = (await verify(
      authHeader.slice(7),
      c.env.JWT_SECRET,
      JWT_ALG
    )) as AuthUser

    if (!payload.sub) {
      return c.json({ error: 'Unauthorized - invalid token payload' }, 401)
    }

    c.set('user', payload)
    await next()
  } catch {
    return c.json({ error: 'Unauthorized - invalid token' }, 401)
  }
}
