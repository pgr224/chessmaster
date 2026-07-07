import { sign } from 'hono/jwt'
import { z } from 'zod'
import type { Context } from 'hono'
import type { Env } from './index'

export type AuthUser = {
  sub: string
  username?: string
  deviceId?: string
  exp?: number
}

export type AppVariables = {
  user: AuthUser
}

export type AppContext = Context<{ Bindings: Env; Variables: AppVariables }>

export const TOKEN_TTL_SECONDS = 86400 * 30
export const JWT_ALG = 'HS256'

export function createId() {
  return crypto.randomUUID()
}

export function normalizeUsername(username: string) {
  return username.trim().replace(/\s+/g, '_')
}

export function tokenExpiresAt() {
  return Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS
}

export async function createAuthToken(
  env: Env,
  payload: Pick<AuthUser, 'sub' | 'username' | 'deviceId'>
) {
  if (!env.JWT_SECRET || env.JWT_SECRET.length < 16) {
    throw new Error('JWT_SECRET is missing or too short')
  }

  return sign(
    {
      ...payload,
      exp: tokenExpiresAt(),
    },
    env.JWT_SECRET,
    JWT_ALG
  )
}

export async function readJson(c: Context) {
  try {
    return await c.req.json()
  } catch {
    return null
  }
}

export function validationError(error: z.ZodError) {
  return {
    error: 'Validation failed',
    details: error.flatten(),
  }
}
