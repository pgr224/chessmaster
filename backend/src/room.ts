import { ChessValidator, Move } from './validation'

export class GameRoom {
  private state: DurableObjectState
  private players: Map<string, { socket: WebSocket; name: string; color: 'white' | 'black'; disconnected: boolean; disconnectTimer?: any }> = new Map()
  private validator: ChessValidator = new ChessValidator()
  private gameId: string | null = null
  private status: 'active' | 'finished' = 'active'
  private env: any

  constructor(state: DurableObjectState, env: any) {
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
        status: this.status
      }
    }))

    return new Response(null, {
      status: 101,
      webSocket: client,
    })
  }

  private async handleMessage(userId: string, msg: any) {
    if (this.status === 'finished') return

    switch (msg.type) {
      case 'MOVE':
        const moveRes = this.validator.validateMove(msg.move as Move)
        if (moveRes.valid) {
          this.broadcast({
            type: 'MOVE_UPDATE',
            data: {
              move: msg.move,
              fen: moveRes.fen,
              turn: moveRes.fen.split(' ')[1] === 'w' ? 'white' : 'black',
              gameOver: moveRes.gameOver,
              result: moveRes.result
            }
          })

          if (moveRes.gameOver) {
            this.status = 'finished'
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
        this.broadcast({ type: 'GAME_OVER', data: { result: 'abandoned', reason: 'disconnect_timeout' } })
        // Abandoned games don't affect stats as per requirement, but we might want to log it
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

      // Update user stats
      if (whiteUserId) {
        const whiteOutcome = winner === 'white' ? 'win' : winner === 'black' ? 'loss' : 'draw'
        await this.updateUserStats(whiteUserId, whiteOutcome)
      }
      if (blackUserId) {
        const blackOutcome = winner === 'black' ? 'win' : winner === 'white' ? 'loss' : 'draw'
        await this.updateUserStats(blackUserId, blackOutcome)
      }
    } catch (e) {
      console.error('[GameRoom] DB Save Failed:', e)
    }
  }

  private async updateUserStats(userId: string, outcome: 'win' | 'loss' | 'draw') {
    if (!this.env.DB) return
    try {
      const field = outcome === 'win' ? 'wins' : outcome === 'loss' ? 'losses' : 'draws'
      await this.env.DB.prepare(`
        UPDATE user_stats SET 
          games_played = games_played + 1,
          ${field} = ${field} + 1,
          multiplayer_games = multiplayer_games + 1,
          ${outcome === 'win' ? 'multiplayer_wins = multiplayer_wins + 1,' : ''}
          current_streak = CASE WHEN ? = 'win' THEN current_streak + 1 ELSE 0 END,
          longest_streak = CASE WHEN current_streak + 1 > longest_streak AND ? = 'win' THEN current_streak + 1 ELSE longest_streak END,
          updated_at = ?
        WHERE user_id = ?
      `).bind(outcome, outcome, new Date().toISOString(), userId).run()
    } catch (e) {
      console.error('[GameRoom] Stats update failed:', e)
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
        VALUES (?, ?, ?, 'multiplayer', 'active', 'ongoing', ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET 
          status = 'active', result = 'ongoing', pgn = excluded.pgn, 
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
