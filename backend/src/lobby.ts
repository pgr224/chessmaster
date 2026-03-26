import { Matchmaker, QueuedPlayer } from './matchmaking'

export interface LobbyPlayer {
  id: string
  name: string
  rating: number
  status: 'idle' | 'searching' | 'in_game'
  socket: WebSocket
}

export class Lobby {
  private state: DurableObjectState
  private players: Map<string, LobbyPlayer> = new Map()
  private matchmaker: Matchmaker = new Matchmaker()

  constructor(state: DurableObjectState) {
    this.state = state
  }

  async fetch(request: Request): Promise<Response> {
    const { 0: client, 1: server } = new WebSocketPair()
    server.accept()

    const url = new URL(request.url)
    const userId = url.searchParams.get('userId') ?? 'anon'
    const username = url.searchParams.get('username') ?? 'Player'
    const rating = parseInt(url.searchParams.get('rating') ?? '1200')

    const player: LobbyPlayer = {
      id: userId,
      name: username,
      rating,
      status: 'idle',
      socket: server
    }

    this.players.set(userId, player)

    server.addEventListener('message', async (event) => {
      try {
        const msg = JSON.parse(event.data as string)
        await this.handleMessage(userId, msg)
      } catch (_) {}
    })

    server.addEventListener('close', () => {
      this.players.delete(userId)
      this.matchmaker.remove(userId)
      this.broadcastUpdate()
    })

    this.broadcastUpdate()

    return new Response(null, {
      status: 101,
      webSocket: client,
    })
  }

  private async handleMessage(userId: string, msg: any) {
    const player = this.players.get(userId)
    if (!player) return

    switch (msg.type) {
      case 'FIND_MATCH':
        player.status = 'searching'
        this.matchmaker.add({
          id: player.id,
          username: player.name,
          rating: player.rating,
          joinedAt: Date.now(),
          socket: player.socket
        })
        this.checkMatches()
        break

      case 'CANCEL_FIND_MATCH':
        player.status = 'idle'
        this.matchmaker.remove(userId)
        this.broadcastUpdate()
        break
    }
  }

  private checkMatches() {
    const matches = this.matchmaker.findMatches()
    for (const [p1, p2] of matches) {
      const gameId = crypto.randomUUID()
      
      const payload = (color: 'white' | 'black', opponent: QueuedPlayer) => JSON.stringify({
        type: 'MATCH_FOUND',
        data: {
          gameId,
          color,
          opponentName: opponent.username,
          opponentRating: opponent.rating
        }
      })

      p1.socket.send(payload('white', p2))
      p2.socket.send(payload('black', p1))

      // Update status in lobby
      if (this.players.has(p1.id)) this.players.get(p1.id)!.status = 'in_game'
      if (this.players.has(p2.id)) this.players.get(p2.id)!.status = 'in_game'
    }
    this.broadcastUpdate()
  }

  private broadcastUpdate() {
    const data = JSON.stringify({
      type: 'LOBBY_UPDATE',
      data: {
        onlinePlayers: this.players.size,
        searchingPlayers: this.matchmaker.getQueueCount()
      }
    })

    for (const p of this.players.values()) {
      try {
        p.socket.send(data)
      } catch (_) {
        this.players.delete(p.id)
      }
    }
  }
}
