import { Matchmaker, QueuedPlayer } from './matchmaking'

export interface LobbyPlayer {
  id: string
  name: string
  rating: number
  status: 'idle' | 'searching' | 'in_game'
}

export class Lobby implements DurableObject {
  private state: DurableObjectState
  private matchmaker: Matchmaker = new Matchmaker()

  constructor(state: DurableObjectState) {
    this.state = state
  }

  async fetch(request: Request): Promise<Response> {
    const { 0: client, 1: server } = new WebSocketPair()
    
    const url = new URL(request.url)
    const userId = url.searchParams.get('userId') ?? 'anon'
    const username = url.searchParams.get('username') ?? 'Player'
    const rating = parseInt(url.searchParams.get('rating') ?? '1200')

    const playerMeta: LobbyPlayer = {
      id: userId,
      name: username,
      rating,
      status: 'idle'
    }

    // Close any existing sessions for this user to prevent duplicates
    const existingSockets = this.state.getWebSockets()
    for (const ws of existingSockets) {
      if ((ws.deserializeAttachment() as LobbyPlayer)?.id === userId) {
        ws.close(1001, 'Newer session started')
      }
    }

    // Accept and tag with metadata
    this.state.acceptWebSocket(server, [userId])
    
    // Store metadata in the socket itself
    server.serializeAttachment({ ...playerMeta })

    // Broadcast update to everyone
    this.broadcastUpdate()

    return new Response(null, {
      status: 101,
      webSocket: client,
    })
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer) {
    const meta = ws.deserializeAttachment() as LobbyPlayer
    if (!meta) return

    try {
      const msg = JSON.parse(message as string)
      
      switch (msg.type) {
        case 'FIND_MATCH':
          meta.status = 'searching'
          ws.serializeAttachment(meta)
          
          this.matchmaker.add({
            id: meta.id,
            username: meta.name,
            rating: meta.rating,
            joinedAt: Date.now(),
            socket: ws
          })
          this.checkMatches()
          break

        case 'CANCEL_FIND_MATCH':
          meta.status = 'idle'
          ws.serializeAttachment(meta)
          this.matchmaker.remove(meta.id)
          this.broadcastUpdate()
          break

        case 'CHALLENGE': {
          const { opponentId, mode, timeControl } = msg
          const sockets = this.state.getWebSockets()
          const opponent = sockets.find(s => (s.deserializeAttachment() as LobbyPlayer)?.id === opponentId)
          if (opponent) {
            opponent.send(JSON.stringify({
              type: 'CHALLENGE_RECEIVED',
              data: {
                challengerId: meta.id,
                challengerName: meta.name,
                mode,
                timeControl
              }
            }))
          }
          break
        }

        case 'CHALLENGE_ACCEPTED': {
          const { challengerId, mode, timeControl } = msg
          const sockets = this.state.getWebSockets()
          const challenger = sockets.find(s => (s.deserializeAttachment() as LobbyPlayer)?.id === challengerId)
          
          if (challenger) {
            const gameId = crypto.randomUUID()
            const payload = (color: string, oppName: string) => JSON.stringify({
              type: 'MATCH_FOUND',
              data: { gameId, color, opponentName: oppName, mode, timeControl }
            })

            ws.send(payload('black', (challenger.deserializeAttachment() as LobbyPlayer).name))
            challenger.send(payload('white', meta.name))
          }
          break
        }

        case 'TOURNAMENT_CHALLENGE': {
          // Challenger sends: { opponentId, tournamentId, totalRounds, timeControl }
          const { opponentId, tournamentId, totalRounds, timeControl: tc } = msg
          const sockets = this.state.getWebSockets()
          const opponent = sockets.find(s => (s.deserializeAttachment() as LobbyPlayer)?.id === opponentId)
          if (opponent) {
            opponent.send(JSON.stringify({
              type: 'TOURNAMENT_CHALLENGE_RECEIVED',
              data: {
                challengerId: meta.id,
                challengerName: meta.name,
                tournamentId,
                totalRounds,
                timeControl: tc,
              }
            }))
          }
          break
        }

        case 'TOURNAMENT_CHALLENGE_ACCEPTED': {
          // Acceptor sends: { challengerId, tournamentId }
          const { challengerId: cId, tournamentId: tId } = msg
          const sockets = this.state.getWebSockets()
          const challenger2 = sockets.find(s => (s.deserializeAttachment() as LobbyPlayer)?.id === cId)
          if (challenger2) {
            challenger2.send(JSON.stringify({
              type: 'TOURNAMENT_ACCEPTED',
              data: { tournamentId: tId, acceptorId: meta.id, acceptorName: meta.name }
            }))
          }
          // Also notify the acceptor (self) with confirmation
          ws.send(JSON.stringify({
            type: 'TOURNAMENT_ACCEPTED',
            data: { tournamentId: tId, acceptorId: meta.id, acceptorName: meta.name }
          }))
          break
        }
      }
    } catch (e) {
      console.error('Lobby DO error:', e)
    }
  }

  async webSocketClose(ws: WebSocket) {
    const meta = ws.deserializeAttachment() as LobbyPlayer
    if (meta) {
      this.matchmaker.remove(meta.id)
    }
    this.broadcastUpdate()
  }

  async webSocketError(ws: WebSocket) {
    await this.webSocketClose(ws)
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

      // Update metadata to in_game
      const meta1 = p1.socket.deserializeAttachment() as LobbyPlayer
      if (meta1) {
        meta1.status = 'in_game'
        p1.socket.serializeAttachment(meta1)
      }
      const meta2 = p2.socket.deserializeAttachment() as LobbyPlayer
      if (meta2) {
        meta2.status = 'in_game'
        p2.socket.serializeAttachment(meta2)
      }
    }
    this.broadcastUpdate()
  }

  private broadcastUpdate() {
    const sockets = this.state.getWebSockets()
    const allPlayers: LobbyPlayer[] = []
    
    const seen = new Set<string>()
    for (const ws of sockets) {
      const meta = ws.deserializeAttachment() as LobbyPlayer
      if (meta && !seen.has(meta.id)) {
        seen.add(meta.id)
        allPlayers.push(meta)
      }
    }

    const data = JSON.stringify({
      type: 'LOBBY_UPDATE',
      data: {
        onlinePlayers: allPlayers.length,
        searchingPlayers: this.matchmaker.getQueueCount(),
        players: allPlayers
      }
    })

    for (const ws of sockets) {
      try {
        ws.send(data)
      } catch (_) {
        ws.close()
      }
    }
  }
}
