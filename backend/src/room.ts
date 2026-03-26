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
      const players = Array.from(this.players.keys())
      await this.env.DB.prepare(`
        INSERT INTO games (id, white_user_id, black_user_id, mode, status, result, pgn, final_fen, completed_at)
        VALUES (?, ?, ?, 'multiplayer', 'completed', ?, ?, ?, ?)
      `).bind(this.gameId, players[0], players[1], winner, this.validator.getPgn(), this.validator.getFen(), new Date().toISOString()).run()
    } catch (e) {
      console.error('[GameRoom] DB Save Failed:', e)
    }
  }
}
