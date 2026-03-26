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
    if (origin.startsWith('https://chessmaster-app.pages.dev') || origin === 'https://chessmaster-app.pages.dev') return origin;
    return 'https://chessmaster-app.pages.dev';
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
  private env: Env
  private sessions: Map<string, WebSocket> = new Map()
  private gameState: Record<string, unknown> = {}
  private players: string[] = []
  private spectators: string[] = []
  private chatLog: Array<{ userId: string; message: string; ts: number }> = []
  private moveLog: Array<{ from: string; to: string; promotion?: string; color: string; ts: number }> = []
  private roomGameId: string | null = null
  private finished = false

  constructor(state: DurableObjectState, env: Env) {
    this.state = state
    this.env = env
  }

  async fetch(request: Request): Promise<Response> {
    const { 0: client, 1: server } = new WebSocketPair()
    server.accept()

    const url = new URL(request.url)
    const userId = url.searchParams.get('userId') ?? 'anon'
    this.roomGameId = url.searchParams.get('gameId')

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
      void this.handlePeerDisconnect(userId)
    })

    // Send current game state to new connection
    const playersInfo = await this.getPlayersInfo()
    server.send(JSON.stringify({
      type: 'gameState',
      data: {
        gameState: this.gameState,
        players: this.players,
        chatLog: this.chatLog.slice(-50),
        moveLog: this.moveLog,
        onlinePlayers: playersInfo,
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
        const playersInfo = await this.getPlayersInfo()
        this.broadcast({ type: 'playerJoined', data: { userId, playerCount: this.players.length, players: playersInfo } })
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
        const user = await this.env.DB.prepare('SELECT username FROM users WHERE id = ?').bind(userId).first<{ username: string }>()
        const chatEntry = {
          userId,
          username: user?.username ?? data.username ?? 'Opponent',
          message: (data.message as string)?.slice(0, 200) ?? '', // Sanitize
          ts: Date.now(),
        }
        this.chatLog.push(chatEntry)
        if (this.chatLog.length > 100) this.chatLog.shift()

        this.broadcast({ type: 'chat', data: chatEntry })
        break
      }

      case 'challenge': {
        const { opponentId, mode, timeControl } = data as { opponentId: string; mode: string; timeControl: string }
        const challenger = await this.env.DB.prepare('SELECT username, xp FROM users WHERE id = ?').bind(userId).first<{ username: string; xp: number }>()
        
        // Notify the specific opponent if they are online in the SAME room (lobby)
        const opponentSession = this.sessions.get(opponentId)
        if (opponentSession) {
          opponentSession.send(JSON.stringify({
            type: 'challenge',
            data: {
              challengerId: userId,
              username: challenger?.username ?? 'Challenger',
              xp: challenger?.xp ?? 0,
              mode,
              timeControl
            }
          }))
        }
        break
      }

      case 'resign': {
        const result = await this.resolveWinnerByResignation(userId)
        this.gameState.result = result
        this.gameState.termination = 'resignation_user_quit'
        await this.completeGameInDb(result, 'resignation_user_quit')
        this.finished = true
        this.broadcast({
          type: 'gameOver',
          data: { result, reason: 'resignation_user_quit', loserUserId: userId },
        })
        break
      }

      case 'drawOffer': {
        this.broadcast({ type: 'drawOffer', data: { from: userId } }, userId)
        break
      }

      case 'drawAccept': {
        this.gameState.result = 'draw'
        this.gameState.termination = 'agreement'
        await this.completeGameInDb('draw', 'agreement')
        this.finished = true
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

  private async handlePeerDisconnect(userId: string) {
    if (this.finished) return

    // Update is_online in DB
    try {
      await this.env.DB.prepare('UPDATE users SET is_online = 0, last_seen = ? WHERE id = ?')
        .bind(new Date().toISOString(), userId)
        .run()
    } catch (_) {}

    if (this.roomGameId && this.roomGameId !== 'lobby') {
      // Graceful closure: the player who leaves counts as the loser,
      // the remaining player wins. Stats ARE updated for both.
      const game = await this.getGameRow()
      if (game && game.status === 'active') {
        const result: 'white' | 'black' = game.white_user_id === userId ? 'black' : 'white'
        this.gameState.result = result
        this.gameState.termination = 'player_disconnected'
        await this.completeGameInDb(result, 'player_disconnected')
        this.finished = true

        this.broadcast({
          type: 'gameOver',
          data: {
            result,
            reason: 'player_disconnected',
            loserUserId: userId,
            message: 'Your opponent left the game. You win!',
          },
        }, userId)
      } else {
        // Game not active (already finished or doesn't exist) — just notify
        this.broadcast({
          type: 'playerLeft',
          data: { userId, reason: 'network_disconnect_or_app_crash', timestamp: Date.now() },
        }, userId)
      }
    } else {
      // Lobby disconnect
      this.broadcast({
        type: 'playerLeft',
        data: { userId, reason: 'leave', players: await this.getPlayersInfo() },
      })
    }
  }

  private async resolveWinnerByResignation(resigningUserId: string): Promise<'white' | 'black'> {
    const game = await this.getGameRow()
    if (!game) return this.players.indexOf(resigningUserId) === 0 ? 'black' : 'white'
    return game.white_user_id === resigningUserId ? 'black' : 'white'
  }

  private async completeGameInDb(result: 'white' | 'black' | 'draw', termination: string) {
    const gameId = this.roomGameId
    if (!gameId || gameId === 'lobby') return

    const game = await this.getGameRow()
    if (!game || game.status !== 'active') return

    const now = new Date().toISOString()
    await this.env.DB.prepare(`
      UPDATE games
      SET status = 'completed', result = ?, termination = ?, completed_at = ?, updated_at = ?
      WHERE id = ?
    `).bind(result, termination, now, now, gameId).run()

    if (game.white_user_id) {
      await this.updateStats(
        game.white_user_id,
        result === 'white' ? 'win' : result === 'black' ? 'loss' : 'draw',
        game.mode,
      )
    }
    if (game.black_user_id) {
      await this.updateStats(
        game.black_user_id,
        result === 'black' ? 'win' : result === 'white' ? 'loss' : 'draw',
        game.mode,
      )
    }
  }

  private async abandonGameInDb(cause: string) {
    const gameId = this.roomGameId
    if (!gameId || gameId === 'lobby') return

    const game = await this.getGameRow()
    if (!game || game.status !== 'active') return

    const now = new Date().toISOString()
    await this.env.DB.prepare(`
      UPDATE games
      SET status = 'abandoned', termination = ?, completed_at = ?, updated_at = ?
      WHERE id = ?
    `).bind(cause, now, now, gameId).run()
  }

  private async getGameRow(): Promise<any | null> {
    const gameId = this.roomGameId
    if (!gameId || gameId === 'lobby') return null
    return await this.env.DB.prepare('SELECT * FROM games WHERE id = ?').bind(gameId).first()
  }

  private async updateStats(
    userId: string,
    outcome: 'win' | 'loss' | 'draw',
    mode: string,
  ) {
    const field = outcome === 'win' ? 'wins' : outcome === 'loss' ? 'losses' : 'draws'
    const modeField = mode === 'multiplayer' ? 'multiplayer_games' : mode === 'tournament' ? 'tournament_games' : 'ai_games'
    const modeWinField = mode === 'multiplayer' ? 'multiplayer_wins' : mode === 'tournament' ? 'tournament_wins' : 'ai_wins'

    await this.env.DB.prepare(`
      UPDATE user_stats SET
        games_played = games_played + 1,
        ${field} = ${field} + 1,
        ${modeField} = ${modeField} + 1,
        ${outcome === 'win' ? `${modeWinField} = ${modeWinField} + 1,` : ''}
        current_streak = CASE WHEN ? = 'win' THEN current_streak + 1 ELSE 0 END,
        longest_streak = CASE WHEN current_streak + 1 > longest_streak AND ? = 'win' THEN current_streak + 1 ELSE longest_streak END,
        updated_at = ?
      WHERE user_id = ?
    `).bind(outcome, outcome, new Date().toISOString(), userId).run()
  }

  private async getPlayersInfo(): Promise<any[]> {
    const userIds = Array.from(this.sessions.keys())
    if (userIds.length === 0) return []
    
    const placeholders = userIds.map(() => '?').join(',')
    const { results } = await this.env.DB.prepare(
      `SELECT id, username as name, xp, 1 as available, 'Online' as flair FROM users WHERE id IN (${placeholders})`
    ).bind(...userIds).all()
    
    return results
  }
}

export default app
