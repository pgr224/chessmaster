import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { logger } from 'hono/logger'
import { prettyJSON } from 'hono/pretty-json'
import { rateLimiter } from './middleware/rate-limiter'
import { authMiddleware } from './middleware/auth'
import { authRoutes } from './routes/auth'
import { profileRoutes } from './routes/profile'
import { gameRoutes } from './routes/game'
import { tournamentRoutes } from './routes/tournament'
import { leaderboardRoutes } from './routes/leaderboard'
import { contentRoutes } from './routes/content'
import { challengeRoutes } from './routes/challenge'

export interface Env {
  DB: D1Database
  CHESS_KV: KVNamespace
  GAME_ROOM: DurableObjectNamespace
  JWT_SECRET: string
  ENVIRONMENT: string
}

const app = new Hono<{ Bindings: Env }>()

// ════════════════════════════════════════
// MIDDLEWARE
// ════════════════════════════════════════
app.use('*', logger())
app.use('*', prettyJSON())
app.use('*', cors({
  origin: (origin) => {
    if (!origin) return null;
    if (origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:')) return origin;
    return 'https://chess.yourdomain.com';
  },
  allowHeaders: ['Content-Type', 'Authorization', 'X-Device-ID', 'Accept'],
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  credentials: true,
}))
app.use('/api/*', rateLimiter())

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

// WebSocket upgrade — proxied to Durable Object
app.get('/multiplayer', async (c) => {
  const upgrade = c.req.header('Upgrade')
  if (upgrade !== 'websocket') {
    return c.text('Expected WebSocket upgrade', 426)
  }
  const gameId = c.req.query('gameId') ?? 'lobby'
  const id = c.env.GAME_ROOM.idFromName(gameId)
  const stub = c.env.GAME_ROOM.get(id)
  return stub.fetch(c.req.raw)
})

// Health check
app.get('/health', (c) => c.json({ status: 'ok', timestamp: new Date().toISOString() }))

// 404
app.notFound((c) => c.json({ error: 'Not found' }, 404))

// Error handler
app.onError((err, c) => {
  console.error(err)
  return c.json({ error: 'Internal server error' }, 500)
})

// ════════════════════════════════════════
// DURABLE OBJECT — Game Room
// ════════════════════════════════════════
export class GameRoom {
  private state: DurableObjectState
  private sessions: Map<string, WebSocket> = new Map()
  private gameState: Record<string, unknown> = {}
  private players: string[] = []
  private spectators: string[] = []
  private chatLog: Array<{ userId: string; message: string; ts: number }> = []
  private moveLog: Array<{ from: string; to: string; promotion?: string; color: string; ts: number }> = []

  constructor(state: DurableObjectState) {
    this.state = state
  }

  async fetch(request: Request): Promise<Response> {
    const { 0: client, 1: server } = new WebSocketPair()
    server.accept()

    const url = new URL(request.url)
    const userId = url.searchParams.get('userId') ?? 'anon'

    this.sessions.set(userId, server)

    server.addEventListener('message', async (event) => {
      try {
        const msg = JSON.parse(event.data as string)
        await this.handleMessage(userId, msg, server)
      } catch (e) {
        server.send(JSON.stringify({ type: 'error', data: { message: 'Invalid message' } }))
      }
    })

    server.addEventListener('close', () => {
      this.sessions.delete(userId)
      this.broadcast({
        type: 'playerLeft',
        data: { userId, timestamp: Date.now() },
      }, userId)
    })

    // Send current game state to new connection
    server.send(JSON.stringify({
      type: 'gameState',
      data: {
        gameState: this.gameState,
        players: this.players,
        chatLog: this.chatLog.slice(-50),
        moveLog: this.moveLog,
      },
    }))

    return new Response(null, {
      status: 101,
      webSocket: client,
    })
  }

  private async handleMessage(userId: string, msg: Record<string, unknown>, socket: WebSocket) {
    const { type, data } = msg as { type: string; data: Record<string, unknown> }

    switch (type) {
      case 'join': {
        if (!this.players.includes(userId)) {
          if (this.players.length < 2) {
            this.players.push(userId)
          } else {
            this.spectators.push(userId)
          }
        }
        this.broadcast({ type: 'playerJoined', data: { userId, playerCount: this.players.length } })
        break
      }

      case 'move': {
        const move = data as { from: string; to: string; promotion?: string }
        if (!this.isValidPlayer(userId)) break

        // Server-side move validation would happen here
        // with a chess engine implementation
        const moveEntry = {
          userId,
          from: move.from,
          to: move.to,
          promotion: move.promotion,
          color: this.players.indexOf(userId) === 0 ? 'white' : 'black',
          ts: Date.now(),
        }
        this.moveLog.push(moveEntry)
        this.gameState.lastMove = moveEntry

        this.broadcast({
          type: 'move',
          data: moveEntry,
        }, userId) // Broadcast to all except sender
        break
      }

      case 'chat': {
        const chatEntry = {
          userId,
          message: (data.message as string)?.slice(0, 200) ?? '', // Sanitize
          ts: Date.now(),
        }
        this.chatLog.push(chatEntry)
        if (this.chatLog.length > 100) this.chatLog.shift()

        this.broadcast({ type: 'chat', data: { ...chatEntry, username: data.username } })
        break
      }

      case 'resign': {
        this.gameState.result = this.players.indexOf(userId) === 0 ? 'black' : 'white'
        this.gameState.termination = 'resignation'
        this.broadcast({ type: 'gameOver', data: { result: this.gameState.result, reason: 'resign' } })
        break
      }

      case 'drawOffer': {
        this.broadcast({ type: 'drawOffer', data: { from: userId } }, userId)
        break
      }

      case 'drawAccept': {
        this.gameState.result = 'draw'
        this.gameState.termination = 'agreement'
        this.broadcast({ type: 'gameOver', data: { result: 'draw', reason: 'agreement' } })
        break
      }

      case 'ping': {
        socket.send(JSON.stringify({ type: 'pong', data: { ts: Date.now() } }))
        break
      }
    }
  }

  private broadcast(msg: Record<string, unknown>, excludeUser?: string) {
    const payload = JSON.stringify(msg)
    this.sessions.forEach((ws, userId) => {
      if (userId !== excludeUser) {
        try { ws.send(payload) } catch (_) {}
      }
    })
  }

  private isValidPlayer(userId: string): boolean {
    return this.players.includes(userId)
  }
}

export default app
