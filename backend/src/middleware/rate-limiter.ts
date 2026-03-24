import { Context, Next } from 'hono'
import type { Env } from '../index'

// In-memory rate limiter (per worker instance)
// For production, use KV-backed rate limiting
const requestCounts = new Map<string, { count: number; resetAt: number }>()

export function rateLimiter(options = { limit: 100, window: 60_000 }) {
  return async (c: Context<{ Bindings: Env }>, next: Next) => {
    const ip = c.req.header('CF-Connecting-IP') ?? 'unknown'
    const authHeader = c.req.header('Authorization')
    const key = authHeader ? `auth:${authHeader.slice(7, 20)}` : `ip:${ip}`

    const now = Date.now()
    const entry = requestCounts.get(key)

    if (!entry || entry.resetAt < now) {
      requestCounts.set(key, { count: 1, resetAt: now + options.window })
    } else {
      entry.count++
      if (entry.count > options.limit) {
        return c.json(
          { error: 'Too many requests', retryAfter: Math.ceil((entry.resetAt - now) / 1000) },
          429
        )
      }
    }

    // Add rate limit headers
    const current = requestCounts.get(key)!
    c.header('X-RateLimit-Limit', options.limit.toString())
    c.header('X-RateLimit-Remaining', Math.max(0, options.limit - current.count).toString())
    c.header('X-RateLimit-Reset', Math.ceil(current.resetAt / 1000).toString())

    await next()
  }
}
