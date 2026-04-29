import { ChessValidator, Move } from './validation'
import { parseTimeControl, DEFAULT_TIME_CONTROL } from './time_control'
import { getPlayerUsername } from './player_name_sync'
import { calculateMultiplayerXP } from './xp_rules'
import { PushService } from './services/push_service'
import { StatsService } from './services/stats_service'
import type { Env } from './index'

function normalizePromotionCode(code?: string): string | undefined {
  if (!code) return undefined
  const value = code.toLowerCase()
  if (value === 'q' || value === 'queen') return 'q'
  if (value === 'r' || value === 'rook') return 'r'
  if (value === 'b' || value === 'bishop') return 'b'
  if (value === 'n' || value === 'knight') return 'n'
  return undefined
}

export class GameRoom {
  private state: DurableObjectState
  private players: Map<string, { socket: WebSocket; name: string; color: 'white' | 'black'; disconnected: boolean; disconnectTimer?: any }> = new Map()
  private validator: ChessValidator = new ChessValidator()
  private gameId: string | null = null
  private status: 'active' | 'finished' = 'active'
  private env: Env

  // Timer fields
  private whiteTime: number = 1800
  private blackTime: number = 1800
  private baseTime: number = 1800
  private increment: number = 0
  private lastMoveTimestamp: number = 0
  private timerInterval: any = null
  private nameSyncInterval: any = null
  private lastNameSync: number = 0
  private NAME_SYNC_INTERVAL_MS: number = 10000 // Sync player names every 10 seconds
  private waitingTimer: any = null
  private opponentUserId: string | null = null

  constructor(state: DurableObjectState, env: Env) {
    this.state = state
    this.env = env
  }

  async fetch(request: Request): Promise<Response> {
    const { 0: client, 1: server } = new WebSocketPair()
    server.accept()

    const url = new URL(request.url)
    const userId = url.searchParams.get('userId') ?? 'anon'
    const name = url.searchParams.get('username') ?? 'Player'
    const color = url.searchParams.get('color') as 'white' | 'black' ?? 'white'
    this.gameId = url.searchParams.get('gameId')

    // If game is already finished, reject connection
    if (this.status === 'finished') {
      server.close(1000, 'Game has ended')
      return new Response(null, { status: 101, webSocket: client })
    }

    // Parse time control: e.g. "blitz_3_2" or "3+2" or "30+0"
    const tcStr = url.searchParams.get('timeControl') ?? DEFAULT_TIME_CONTROL
    const parsed = parseTimeControl(tcStr)
    this.baseTime = parsed.baseSeconds
    this.whiteTime = parsed.baseSeconds
    this.blackTime = parsed.baseSeconds
    this.increment = parsed.incrementSeconds

    const player = { socket: server, name, color, disconnected: false }
    this.players.set(userId, player)

    server.addEventListener('message', async (event) => {
      try {
        const msg = JSON.parse(event.data as string)
        await this.handleMessage(userId, msg)
      } catch (_) {}
    })

    server.addEventListener('close', () => {
      this.handleDisconnect(userId)
    })

    // Initial game state
    server.send(JSON.stringify({
      type: 'ROOM_STATE',
      data: {
        fen: this.validator.getFen(),
        turn: this.validator.getFen().split(' ')[1] === 'w' ? 'white' : 'black',
        status: this.status,
        whiteTime: this.whiteTime,
        blackTime: this.blackTime,
        increment: this.increment
      }
    }))

    // Notify all players if opponent has joined
    if (this.players.size === 2) {
      if (this.waitingTimer) {
        clearTimeout(this.waitingTimer)
        this.waitingTimer = null
      }
      this.broadcast({
        type: 'OPPONENT_JOINED',
        data: {}
      })
    }

    // If only one player, start waiting timer and notify opponent
    if (this.players.size === 1) {
      this.startWaitingTimer(userId)
    }

    // Start game if 2 players are present
    if (this.players.size === 2 && !this.timerInterval) {
      this.lastMoveTimestamp = Date.now()
      this.startSyncTimer()
    }

    return new Response(null, {
      status: 101,
      webSocket: client,
    })
  }

  private startSyncTimer() {
    this.timerInterval = setInterval(() => {
      if (this.status === 'finished') {
        clearInterval(this.timerInterval)
        return
      }

      this.updateClocks()
      
      // Periodically sync player names from database
      const now = Date.now()
      if (now - this.lastNameSync > this.NAME_SYNC_INTERVAL_MS) {
        this.syncPlayerNames()
        this.lastNameSync = now
      }

      this.broadcast({
        type: 'TIMER_SYNC',
        data: {
          whiteTime: Math.max(0, this.whiteTime),
          blackTime: Math.max(0, this.blackTime),
          turn: this.validator.getFen().split(' ')[1] === 'w' ? 'white' : 'black'
        }
      })

      // Check for timeout
      if (this.whiteTime <= 0 || this.blackTime <= 0) {
        this.handleTimeout()
      }
    }, 1000)
  }

  /**
   * Sync player names from database to ensure current names are displayed
   * Called periodically during game to handle mid-game username changes
   */
  private async syncPlayerNames() {
    try {
      const userIds = Array.from(this.players.keys())
      for (const userId of userIds) {
        const player = this.players.get(userId)
        if (!player) continue

        const dbUsername = await getPlayerUsername(this.env, userId)
        if (dbUsername && dbUsername !== player.name) {
          const oldName = player.name
          player.name = dbUsername
          
          // Notify all players of the name change
          this.broadcast({
            type: 'PLAYER_NAME_UPDATED',
            data: {
              userId,
              oldName,
              newName: dbUsername,
              color: player.color
            }
          })
        }
      }
    } catch (err) {
      console.error('[GameRoom] Name sync error:', err)
    }
  }

  private updateClocks() {
    if (this.status !== 'active' || this.players.size < 2) return
    const now = Date.now()
    const elapsed = (now - this.lastMoveTimestamp) / 1000
    const turn = this.validator.getFen().split(' ')[1] === 'w' ? 'white' : 'black'

    if (turn === 'white') {
      this.whiteTime -= elapsed
    } else {
      this.blackTime -= elapsed
    }
    this.lastMoveTimestamp = now
  }

  private async startWaitingTimer(waitingUserId: string) {
    try {
      // Query challenge to find opponent
      const challenge = await this.env.DB.prepare(
        `SELECT challenger_id, challenged_id FROM challenges WHERE game_id = ?`
      ).bind(this.gameId).first<{ challenger_id: string; challenged_id: string }>()

      if (!challenge) return

      const opponentId = challenge.challenger_id === waitingUserId ? challenge.challenged_id : challenge.challenger_id
      this.opponentUserId = opponentId

      // Send push notification
      const waitingPlayer = this.players.get(waitingUserId)
      if (waitingPlayer) {
        await this.sendOpponentWaitingNotification(opponentId, waitingPlayer.name)
      }

      // Start 10-second timer
      this.waitingTimer = setTimeout(async () => {
        await this.handleOpponentNoShow()
      }, 10000)
    } catch (err) {
      console.error('[GameRoom] Error starting waiting timer:', err)
    }
  }

  private async sendOpponentWaitingNotification(opponentId: string, waitingPlayerName: string) {
    await PushService.notifyUser(opponentId, {
      title: '♟️ Game Started!',
      body: `${waitingPlayerName} has joined the game and is waiting for you. Join now!`,
      icon: '/icons/Icon-192.png',
      data: {
        type: 'GAME_WAITING',
        gameId: this.gameId,
        category: 'games',
      },
    }, this.env, 'games')
  }

  private async handleOpponentNoShow() {
    this.status = 'finished'
    this.broadcast({
      type: 'GAME_OVER',
      data: {
        result: 'opponent_no_show',
        reason: 'opponent_no_show',
        message: 'Your opponent did not join the game in time.',
      }
    })

    // Clear the challenge
    if (this.gameId) {
      await this.env.DB.prepare(
        `DELETE FROM challenges WHERE game_id = ?`
      ).bind(this.gameId).run()
    }

    // Disconnect players after a short delay
    setTimeout(() => {
      for (const [userId, player] of this.players) {
        try {
          player.socket.close(1000, 'Opponent did not join')
        } catch (_) {}
      }
    }, 2000)
  }

  private async handleTimeout() {
    if (this.status !== 'active') return
    this.status = 'finished'
    clearInterval(this.timerInterval)
    if (this.nameSyncInterval) clearInterval(this.nameSyncInterval)

    const turn = this.validator.getFen().split(' ')[1] === 'w' ? 'white' : 'black'
    const timedOutColor = turn === 'white' ? 'white' : 'black'
    const opponentColor = turn === 'white' ? 'black' : 'white'

    // Insufficient material check
    let result: string
    if (this.validator.isInsufficientMaterial()) {
      result = 'draw'
    } else {
      result = opponentColor
    }

    this.broadcast({
      type: 'GAME_OVER',
      data: {
        result,
        reason: 'timeout',
        winner: result === 'draw' ? null : result
      }
    })

    await this.saveGameToDB(result)
  }

  private async handleMessage(userId: string, msg: any) {
    if (this.status === 'finished') return

    switch (msg.type) {
      case 'MOVE':
        if (msg.move?.promotion) {
          msg.move.promotion = normalizePromotionCode(msg.move.promotion)
        }
        const moveRes = this.validator.validateMove(msg.move as Move)
        if (moveRes.valid) {
          // Final clock update for this turn
          this.updateClocks()
          
          // Apply increment (Fischer)
          const turnBeforeMove = moveRes.fen.split(' ')[1] === 'b' ? 'white' : 'black'
          if (turnBeforeMove === 'white') {
            this.whiteTime += this.increment
          } else {
            this.blackTime += this.increment
          }

          this.broadcast({
            type: 'MOVE_UPDATE',
            data: {
              userId,
              move: msg.move,
              fen: moveRes.fen,
              turn: moveRes.fen.split(' ')[1] === 'w' ? 'white' : 'black',
              gameOver: moveRes.gameOver,
              result: moveRes.result,
              whiteTime: Math.max(0, this.whiteTime),
              blackTime: Math.max(0, this.blackTime)
            }
          })

          if (moveRes.gameOver) {
            this.status = 'finished'
            clearInterval(this.timerInterval)
            await this.saveGameToDB(moveRes.result)
          }
        } else {
          this.players.get(userId)?.socket.send(JSON.stringify({ type: 'MOVE_ERROR', data: { fen: this.validator.getFen() } }))
        }
        break

      case 'CHAT':
        this.broadcast({
          type: 'CHAT',
          data: {
            userId,
            username: this.players.get(userId)?.name ?? 'Player',
            message: msg.message,
            emoji: msg.emoji,
            ts: Date.now()
          }
        })
        break

      case 'RESIGN':
        this.status = 'finished'
        const winner = this.players.get(userId)?.color === 'white' ? 'black' : 'white'
        this.broadcast({ type: 'GAME_OVER', data: { result: winner, reason: 'resignation' } })
        await this.saveGameToDB(winner)
        break

      case 'DRAW_OFFER':
        // Forward draw offer to the opponent only
        this.broadcast({ type: 'DRAW_OFFER', data: { from: userId } }, userId)
        break

      case 'DRAW_ACCEPT':
        this.status = 'finished'
        this.broadcast({ type: 'DRAW_ACCEPT', data: {} })
        this.broadcast({ type: 'GAME_OVER', data: { result: 'draw', reason: 'agreement' } })
        await this.saveGameToDB('draw')
        break

      case 'DRAW_DECLINE':
        this.broadcast({ type: 'DRAW_DECLINE', data: {} }, userId)
        break

      case 'UNDO':
        // Perform undo on internal state to keep sync
        const newFen = this.validator.undo()
        this.broadcast({ 
          type: 'MOVE_UPDATE', 
          data: { 
            fen: newFen, 
            turn: newFen.split(' ')[1] === 'w' ? 'white' : 'black',
            undo: true,
            userId,
            move: null 
          }
        })
        break

      case 'SAVE_REQUEST':
        // Forward save request to opponent
        this.broadcast({ type: 'SAVE_REQUEST', data: { from: userId } }, userId)
        break

      case 'SAVE_ACCEPT':
        // Both agreed, save state as 'active' (paused) and finish session
        this.status = 'finished'
        await this.syncPausedGame()
        this.broadcast({ type: 'GAME_SAVED', data: { reason: 'manual_save' } })
        break

      case 'SAVE_DECLINE':
        this.broadcast({ type: 'SAVE_DECLINE', data: {} }, userId)
        break
    }
  }

  private handleDisconnect(userId: string) {
    const player = this.players.get(userId)
    if (!player) return

    player.disconnected = true
    this.broadcast({ type: 'PLAYER_DISCONNECTED', data: { userId } })

    // Start 30s timer
    player.disconnectTimer = setTimeout(async () => {
      if (player.disconnected && this.status === 'active') {
        this.status = 'finished'
        clearInterval(this.timerInterval)
        
        // Find the remaining player
        let winnerColor: 'white' | 'black' | 'draw' = 'draw'
        for (const [id, p] of this.players.entries()) {
          if (id !== userId) {
            winnerColor = p.color
            break
          }
        }

        this.broadcast({ 
          type: 'GAME_OVER', 
          data: { 
            result: winnerColor, 
            reason: 'disconnect_timeout',
            message: 'Opponent disconnected and timed out.'
          } 
        })
        
        await this.saveGameToDB(winnerColor)
      }
    }, 30000)
  }

  private broadcast(data: any, skipUserId?: string) {
    const payload = JSON.stringify(data)
    for (const [id, p] of this.players.entries()) {
      if (id === skipUserId || p.disconnected) continue
      try {
        p.socket.send(payload)
      } catch (_) {
        p.disconnected = true
      }
    }
  }

  private async saveGameToDB(winner?: string) {
    if (!this.env.DB) return
    try {
      // Correctly map users to white/black based on their assigned color
      let whiteUserId: string | null = null
      let blackUserId: string | null = null
      for (const [id, p] of this.players.entries()) {
        if (p.color === 'white') whiteUserId = id
        if (p.color === 'black') blackUserId = id
      }

      const moveCount = this.validator.getMoveCount()

      await this.env.DB.prepare(`
        INSERT INTO games (id, white_user_id, black_user_id, mode, status, result, pgn, final_fen, move_count, completed_at, created_at, updated_at)
        VALUES (?, ?, ?, 'multiplayer', 'completed', ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET 
          status = 'completed', result = excluded.result, pgn = excluded.pgn, 
          final_fen = excluded.final_fen, move_count = excluded.move_count,
          completed_at = excluded.completed_at, updated_at = excluded.updated_at
      `).bind(
        this.gameId, whiteUserId, blackUserId, winner,
        this.validator.getPgn(), this.validator.getFen(), moveCount,
        new Date().toISOString(), new Date().toISOString(), new Date().toISOString()
      ).run()

      // Update user stats and XP
      if (whiteUserId) {
        const outcome = winner === 'white' ? 'win' : winner === 'black' ? 'loss' : 'draw'
        await this.updateUserStatsAndXP(whiteUserId, outcome)
      }
      if (blackUserId) {
        const outcome = winner === 'black' ? 'win' : winner === 'white' ? 'loss' : 'draw'
        await this.updateUserStatsAndXP(blackUserId, outcome)
      }
    } catch (e) {
      console.error('[GameRoom] DB Save Failed:', e)
    }
  }

  private async updateUserStatsAndXP(userId: string, outcome: 'win' | 'loss' | 'draw') {
    if (!this.env.DB) return
    try {
      await StatsService.updateAll(this.env.DB, {
        userId,
        gameId: this.gameId,
        outcome,
        mode: 'multiplayer'
      })
    } catch (e) {
      console.error('[GameRoom] Stats/XP update failed:', e)
    }
  }
  private async syncPausedGame() {
    if (!this.env.DB) return
    try {
      let whiteUserId: string | null = null
      let blackUserId: string | null = null
      for (const [id, p] of this.players.entries()) {
        if (p.color === 'white') whiteUserId = id
        if (p.color === 'black') blackUserId = id
      }

      await this.env.DB.prepare(`
        INSERT INTO games (id, white_user_id, black_user_id, mode, status, result, pgn, final_fen, move_count, created_at, updated_at)
        VALUES (?, ?, ?, 'multiplayer', 'active', NULL, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET 
          status = 'active', result = NULL, pgn = excluded.pgn, 
          final_fen = excluded.final_fen, move_count = excluded.move_count,
          updated_at = excluded.updated_at
      `).bind(
        this.gameId, whiteUserId, blackUserId,
        this.validator.getPgn(), this.validator.getFen(), this.validator.getMoveCount(),
        new Date().toISOString(), new Date().toISOString()
      ).run()
    } catch (e) {
      console.error('[GameRoom] syncPausedGame failed:', e)
    }
  }
}
