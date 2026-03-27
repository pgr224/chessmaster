import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { logger } from 'hono/logger'
import { authRoutes } from './routes/auth'
import { profileRoutes } from './routes/profile'
import { gameRoutes } from './routes/game'
import { tournamentRoutes } from './routes/tournament'
import { leaderboardRoutes } from './routes/leaderboard'
import { contentRoutes } from './routes/content'
import { challengeRoutes } from './routes/challenge'

// Durable Objects
export { Lobby } from './lobby'
export { GameRoom } from './room'

export interface Env {
  DB: D1Database
  CHESS_KV: KVNamespace
  LOBBY: DurableObjectNamespace
  GAME_ROOM: DurableObjectNamespace
  JWT_SECRET: string
  ENVIRONMENT: string
}

const app = new Hono<{ Bindings: Env }>()

// ════════════════════════════════════════
// MIDDLEWARE
// ════════════════════════════════════════
app.use('*', logger())
app.onError((err, c) => {
  console.error(`[Global Error] ${c.req.method} ${c.req.url}:`, err)
  return c.json({ error: 'Internal Server Error', message: err.message, stack: err.stack }, 500)
})
app.use('*', cors({
  origin: (origin) => {
    if (!origin) return null;
    if (origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:')) return origin;
    if (origin.startsWith('https://chessmaster-app.pages.dev') || origin === 'https://chessmaster-app.pages.dev') return origin;
    return 'https://chessmaster-app.pages.dev';
  },
  allowHeaders: ['Content-Type', 'Authorization', 'X-Device-ID', 'Accept'],
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

// ════════════════════════════════════════
// WEBSOCKET ROUTING
// ════════════════════════════════════════

// LOBBY (Global Presence & Matchmaking)
app.get('/multiplayer/lobby', async (c) => {
  const upgrade = c.req.header('Upgrade')
  if (upgrade !== 'websocket') return c.text('Expect WebSocket', 426)
  
  const id = c.env.LOBBY.idFromName('global_lobby')
  const stub = c.env.LOBBY.get(id)
  return stub.fetch(c.req.raw)
})

// GAME ROOM (Individual Match)
app.get('/multiplayer/game/:gameId', async (c) => {
  const upgrade = c.req.header('Upgrade')
  if (upgrade !== 'websocket') return c.text('Expect WebSocket', 426)

  const gameId = c.req.param('gameId')
  const id = c.env.GAME_ROOM.idFromName(gameId)
  const stub = c.env.GAME_ROOM.get(id)
  return stub.fetch(c.req.raw)
})

// Health check
app.get('/health', (c) => c.json({ status: 'ok', timestamp: new Date().toISOString() }))

export default app
