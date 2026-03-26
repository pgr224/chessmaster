import { Context, Next } from 'hono'
import { verify } from 'hono/jwt'
import type { Env } from '../index'

export async function authMiddleware(c: Context<{ Bindings: Env; Variables: { user: any } }>, next: Next) {
  const authHeader = c.req.header('Authorization')

  if (!authHeader?.startsWith('Bearer ')) {
    return c.json({ error: 'Unauthorized — missing token' }, 401)
  }

  try {
    const payload = await verify(authHeader.slice(7), c.env.JWT_SECRET, 'HS256')
    c.set('user', payload)
    await next()
  } catch {
    return c.json({ error: 'Unauthorized — invalid token' }, 401)
  }
}
