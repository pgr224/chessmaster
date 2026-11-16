import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { logger } from 'hono/logger'
import { verify } from 'hono/jwt'
import { JWT_ALG, isGuestIdentity } from './auth_utils'
import { authRoutes } from './routes/auth'
import { profileRoutes } from './routes/profile'
import { gameRoutes } from './routes/game'
import { tournamentRoutes } from './routes/tournament'
import { leaderboardRoutes } from './routes/leaderboard'
import { contentRoutes } from './routes/content'
import { challengeRoutes } from './routes/challenge'
import { pushRoutes } from './routes/push'

// Durable Objects
export { Lobby } from './lobby'
export { GameRoom } from './room'
export { TournamentRoom } from './tournament_room'

export interface Env {
  DB: D1Database
  CHESS_KV: KVNamespace
  LOBBY: DurableObjectNamespace
  GAME_ROOM: DurableObjectNamespace
  TOURNAMENT_ROOM: DurableObjectNamespace
  JWT_SECRET: string
  ENVIRONMENT: string
  VAPID_PUBLIC_KEY: string
  VAPID_SUBJECT?: string
  FCM_SERVICE_ACCOUNT?: string
  VAPID_PRIVATE_KEY: string
}

const app = new Hono<{ Bindings: Env }>()

// ════════════════════════════════════════
// MIDDLEWARE
// ════════════════════════════════════════
app.use('*', logger((message, ...rest) => console.log(message.replace(/([?&]token=)[^&\s]+/g, '$1[redacted]'), ...rest)))
app.onError((err, c) => {
  console.error(`[Global Error] ${c.req.method} ${c.req.url}:`, err)
  return c.json({ error: 'Internal Server Error', message: err.message, stack: err.stack }, 500)
})
app.use('*', cors({
  origin: (origin) => {
    if (!origin) return null;
    if (origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:')) return origin;
    if (origin.endsWith('.chessmaster-app.pages.dev') || origin === 'https://chessmaster-app.pages.dev') return origin;
    return 'https://chessmaster-app.pages.dev';
  },
  allowHeaders: ['Content-Type', 'Authorization', 'X-Device-ID', 'Accept', 'X-Access-Token'],
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  credentials: true,
}))

// ════════════════════════════════════════
// ROUTES
// ════════════════════════════════════════
app.route('/api/auth', authRoutes)
app.route('/api/profile', profileRoutes)
app.route('/api/game', gameRoutes)
app.route('/api/tournament', tournamentRoutes)
app.route('/api/leaderboard', leaderboardRoutes)
app.route('/api/content', contentRoutes)
app.route('/api/challenge', challengeRoutes)
app.route('/api/push', pushRoutes)

// ════════════════════════════════════════
// WEBSOCKET ROUTING
// ════════════════════════════════════════

async function authenticatedSocketRequest(request:Request, env:Env):Promise<Request|null> {
  try {
    const url=new URL(request.url)
    const token=url.searchParams.get('token')??request.headers.get('Authorization')?.replace(/^Bearer /i,'')
    if(!token)return null
    const user=await verify(token,env.JWT_SECRET,JWT_ALG)
    if(typeof user.sub!=='string'||isGuestIdentity(user.sub,user))return null
    const row=await env.DB.prepare('SELECT username FROM users WHERE id=?').bind(user.sub).first<{username:string}>()
    if(!row)return null
    const headers=new Headers(request.headers)
    headers.set('X-Authenticated-User',user.sub)
    headers.set('X-Authenticated-Name',row.username)
    url.searchParams.set('userId',user.sub)
    url.searchParams.set('username',row.username)
    return new Request(url,{headers})
  }catch{return null}
}

// LOBBY (Global Presence & Matchmaking)
app.get('/multiplayer/lobby', async (c) => {
  const upgrade = c.req.header('Upgrade')
  if (upgrade !== 'websocket') return c.text('Expect WebSocket', 426)
  
  const request=await authenticatedSocketRequest(c.req.raw,c.env)
  if(!request)return c.text('Unauthorized',401)
  const id = c.env.LOBBY.idFromName('global_lobby')
  const stub = c.env.LOBBY.get(id)
  return stub.fetch(request)
})

// GAME ROOM (Individual Match)
app.get('/multiplayer/game/:gameId', async (c) => {
  const upgrade = c.req.header('Upgrade')
  if (upgrade !== 'websocket') return c.text('Expect WebSocket', 426)

  const request=await authenticatedSocketRequest(c.req.raw,c.env)
  if(!request)return c.text('Unauthorized',401)
  const gameId = c.req.param('gameId')
  const id = c.env.GAME_ROOM.idFromName(gameId)
  const stub = c.env.GAME_ROOM.get(id)
  return stub.fetch(request)
})

// TOURNAMENT ROOM (Tournament WebSocket)
app.get('/multiplayer/tournament/:tournamentId', async (c) => {
  const upgrade = c.req.header('Upgrade')
  if (upgrade !== 'websocket') return c.text('Expect WebSocket', 426)

  const request=await authenticatedSocketRequest(c.req.raw,c.env)
  if(!request)return c.text('Unauthorized',401)
  const tournamentId = c.req.param('tournamentId')
  const id = c.env.TOURNAMENT_ROOM.idFromName(tournamentId)
  const stub = c.env.TOURNAMENT_ROOM.get(id)
  return stub.fetch(request)
})

import { MaintenanceService } from './services/maintenance_service'

// ... (previous routes)

// Health check
app.get('/health', (c) => c.json({ status: 'ok', timestamp: new Date().toISOString() }))

// ════════════════════════════════════════
// CLOUDFLARE WORKER EXPORTS
// ════════════════════════════════════════
export default {
  // Handle HTTP requests via Hono
  fetch: app.fetch,

  // Handle scheduled tasks (Cron)
  async scheduled(controller: ScheduledController, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(MaintenanceService.cleanupAndRefresh(env))
  }
}
