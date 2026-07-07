import { Matchmaker, QueuedPlayer } from './matchmaking'
import type { Env } from './index'
import { normalizeTimeControl, DEFAULT_TIME_CONTROL } from './time_control'
import { PushService } from './services/push_service'

export interface LobbyPlayer {
  id: string
  name: string
  rating: number
  status: 'idle' | 'searching' | 'in_game' | 'tournament' | 'offline_game'
}

type ChallengeMode = 'duel' | 'tournament'
type ChallengeDelivery = 'live' | 'queued'

interface StoredChallengeRow {
  id: string
  challenger_id: string
  challenged_id: string
  time_control: string
  mode: ChallengeMode
  variant_id: string
  delivery_status: ChallengeDelivery
  challenger_name?: string
  challenged_name?: string
  created_at?: string
}

interface XpTransferNotification {
  donorId: string
  donorName: string
  donorXp: number
  recipientId: string
  recipientName: string
  recipientXp: number
  amount: number
  ts?: number
}

export class Lobby implements DurableObject {
  private state: DurableObjectState
  private env: Env
  private matchmaker: Matchmaker = new Matchmaker()

  constructor(state: DurableObjectState, env: Env) {
    this.state = state
    this.env = env
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url)
    const upgrade = request.headers.get('Upgrade')

    if (upgrade !== 'websocket') {
      if (request.method === 'POST' && url.pathname.endsWith('/internal/xp-update')) {
        try {
          const payload = await request.json() as Partial<XpTransferNotification>
          if (!payload.donorId || !payload.recipientId || !payload.amount) {
            return new Response(JSON.stringify({ error: 'Invalid payload' }), {
              status: 400,
              headers: { 'content-type': 'application/json' },
            })
          }

          this.broadcastXpTransfer({
            donorId: payload.donorId,
            donorName: payload.donorName ?? 'Player',
            donorXp: Number(payload.donorXp ?? 0),
            recipientId: payload.recipientId,
            recipientName: payload.recipientName ?? 'Player',
            recipientXp: Number(payload.recipientXp ?? 0),
            amount: Number(payload.amount),
            ts: payload.ts ?? Date.now(),
          })

          return new Response(JSON.stringify({ success: true }), {
            status: 200,
            headers: { 'content-type': 'application/json' },
          })
        } catch (err) {
          console.error('Failed to broadcast XP update:', err)
          return new Response(JSON.stringify({ error: 'Bad request' }), {
            status: 400,
            headers: { 'content-type': 'application/json' },
          })
        }
      }

      return new Response('Expected websocket upgrade', { status: 426 })
    }

    const { 0: client, 1: server } = new WebSocketPair()

    const userId = url.searchParams.get('userId') ?? 'anon'
    const queryUsername = url.searchParams.get('username') ?? 'Player'
    const rating = parseInt(url.searchParams.get('rating') ?? '0')

    const dbUser = await this.env.DB.prepare('SELECT username FROM users WHERE id = ?')
      .bind(userId)
      .first<{ username: string }>()
    const canonicalUsername = dbUser?.username ?? queryUsername

    const playerMeta: LobbyPlayer = {
      id: userId,
      name: canonicalUsername,
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
    await this.sendPendingChallenges(server, userId)

    return new Response(null, {
      status: 101,
      webSocket: client,
    })
  }

  private broadcastXpTransfer(payload: XpTransferNotification) {
    const sockets = this.state.getWebSockets()
    const message = JSON.stringify({
      type: 'XP_TRANSFERRED',
      data: payload,
    })

    for (const ws of sockets) {
      try {
        ws.send(message)
      } catch (_) {
        ws.close()
      }
    }
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer) {
    const meta = ws.deserializeAttachment() as LobbyPlayer
    if (!meta) return

    try {
      const msg = JSON.parse(message as string)
      
      switch (msg.type) {
        case 'PRESENCE_UPDATE': {
          meta.status = this.normalizePresence(msg.status)
          ws.serializeAttachment(meta)
          if (meta.status !== 'searching') {
            this.matchmaker.remove(meta.id)
          }
          this.broadcastUpdate()
          break
        }

        case 'FIND_MATCH':
          const requestedTimeControl =
            typeof msg.timeControl === 'string' && msg.timeControl.length > 0
              ? normalizeTimeControl(msg.timeControl)
              : DEFAULT_TIME_CONTROL
          meta.status = 'searching'
          ws.serializeAttachment(meta)
          
          this.matchmaker.add({
            id: meta.id,
            username: meta.name,
            rating: meta.rating,
            timeControl: requestedTimeControl,
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
          const opponentId = typeof msg.opponentId === 'string' ? msg.opponentId : ''
          const requestId =
            typeof msg.requestId === 'string' && msg.requestId.length > 0
              ? msg.requestId
              : crypto.randomUUID()
          const mode = this.normalizeChallengeMode(msg.mode)
          const timeControl = normalizeTimeControl(msg.timeControl ?? DEFAULT_TIME_CONTROL)
          const variantId =
            typeof msg.variantId === 'string' && msg.variantId.length > 0
              ? msg.variantId
              : 'standard'
          const allowOffline = msg.allowOffline === true
          const sockets = this.state.getWebSockets()
          const opponent = sockets.find(s => (s.deserializeAttachment() as LobbyPlayer)?.id === opponentId)
          const opponentMeta = opponent?.deserializeAttachment() as LobbyPlayer | undefined
          const opponentStatus = opponentMeta?.status ?? 'offline'
          const isOpponentReady = opponentMeta?.status === 'idle'

          if (!opponentId) {
            ws.send(JSON.stringify({
              type: 'CHALLENGE_CANCELLED',
              data: {
                requestId,
                message: 'Opponent not specified.',
              },
            }))
            break
          }

          if (!opponent && !allowOffline) {
            ws.send(JSON.stringify({
              type: 'CHALLENGE_BUSY',
              data: {
                requestId,
                opponentId,
                recipientStatus: opponentStatus,
                message: 'That player is offline right now. Send as offline request to queue it.',
              },
            }))
            break
          }

          if (opponent && !isOpponentReady && !allowOffline) {
            ws.send(JSON.stringify({
              type: 'CHALLENGE_BUSY',
              data: {
                requestId,
                opponentId,
                recipientStatus: opponentStatus,
                message: `${opponentMeta?.name ?? 'That player'} is currently busy. Send it as an offline request to queue it.`,
              },
            }))
            break
          }

          // Cancel any existing challenge from this challenger to this opponent
          await this.env.DB.prepare(
            `DELETE FROM challenges WHERE challenger_id = ? AND challenged_id = ? AND status = 'pending'`
          ).bind(meta.id, opponentId).run()

          const deliveryStatus: ChallengeDelivery = (opponent && isOpponentReady) ? 'live' : 'queued'

          await this.upsertChallenge({
            id: requestId,
            challengerId: meta.id,
            challengedId: opponentId,
            timeControl,
            mode,
            variantId,
            deliveryStatus,
          })

          if (opponent && isOpponentReady) {
            opponent.send(JSON.stringify({
              type: 'CHALLENGE_RECEIVED',
              data: {
                requestId,
                challengerId: meta.id,
                challengerName: meta.name,
                mode,
                timeControl,
                variantId,
                queued: false,
                ts: Date.now(),
              }
            }))

            ws.send(JSON.stringify({
              type: 'CHALLENGE_SENT',
              data: {
                requestId,
                opponentId,
                recipientStatus: opponentStatus,
                deliveryStatus,
              },
            }))
          } else {
            await PushService.notifyUser(opponentId, {
              title: '♟️ New Battle Request',
              body: `${meta.name} sent you a ${mode} request. Open Chess Master to respond.`,
              icon: '/icons/Icon-192.png',
              data: {
                type: 'CHALLENGE_RECEIVED',
                requestId,
                challengerId: meta.id,
                challengerName: meta.name,
                category: mode === 'tournament' ? 'tournaments' : 'challenges',
                mode,
                timeControl,
                variantId,
                queued: true,
              },
            }, this.env, mode === 'tournament' ? 'tournaments' : 'challenges')

            ws.send(JSON.stringify({
              type: 'CHALLENGE_QUEUED',
              data: {
                requestId,
                opponentId,
                recipientStatus: opponentStatus,
                message: `${opponentMeta?.name ?? 'That player'} is busy. Your request is queued and will appear in their inbox.`,
              },
            }))
          }
          break
        }

        case 'CHALLENGE_ACCEPTED': {
          const challengerId = typeof msg.challengerId === 'string' ? msg.challengerId : ''
          const requestId = typeof msg.requestId === 'string' ? msg.requestId : ''
          const sockets = this.state.getWebSockets()
          const challenger = sockets.find(s => (s.deserializeAttachment() as LobbyPlayer)?.id === challengerId)
          if (!requestId) {
            ws.send(JSON.stringify({
              type: 'CHALLENGE_CANCELLED',
              data: {
                message: 'Missing request ID for challenge acceptance.',
              },
            }))
            break
          }

          const challenge = await this.getPendingChallenge(requestId, meta.id)
          if (!challenge) {
            ws.send(JSON.stringify({
              type: 'CHALLENGE_EXPIRED',
              data: {
                requestId,
                message: 'This request is no longer available.',
              },
            }))
            break
          }

          const gameId = crypto.randomUUID()
          await this.acceptChallengeRecord(challenge, gameId)

          const challengerName =
            (challenger?.deserializeAttachment() as LobbyPlayer | undefined)?.name ??
            challenge.challenger_name ??
            'Opponent'
          const acceptorName = meta.name
          const payload = (
            color: string,
            oppName: string,
            oppId: string,
          ) => JSON.stringify({
            type: 'MATCH_FOUND',
            data: {
              gameId,
              color,
              opponentId: oppId,
              opponentName: oppName,
              mode: challenge.mode,
              timeControl: challenge.time_control,
              variantId: challenge.variant_id,
              requestId,
              queued: challenge.delivery_status === 'queued',
            }
          })

          ws.send(payload('black', challengerName, challenge.challenger_id))
          if (challenger) {
            challenger.send(payload('white', acceptorName, challenge.challenged_id))
          } else {
            await PushService.notifyUser(challenge.challenger_id, {
              title: '♟️ Battle Request Accepted',
              body: `${acceptorName} accepted your request. Re-open the app to join the game.`,
              icon: '/icons/Icon-192.png',
              data: {
                type: 'CHALLENGE_ACCEPTED',
                requestId,
                gameId,
                category: challenge.mode === 'tournament' ? 'tournaments' : 'challenges',
              },
            }, this.env, challenge.mode === 'tournament' ? 'tournaments' : 'challenges')
          }

          meta.status = 'in_game'
          ws.serializeAttachment(meta)
          if (challenger) {
            const challengerMeta = challenger.deserializeAttachment() as LobbyPlayer | undefined
            if (challengerMeta) {
              challengerMeta.status = 'in_game'
              challenger.serializeAttachment(challengerMeta)
            }
          }
          this.broadcastUpdate()
          break
        }

        case 'CHALLENGE_DECLINED': {
          const challengerId = typeof msg.challengerId === 'string' ? msg.challengerId : ''
          const requestId = typeof msg.requestId === 'string' ? msg.requestId : ''
          if (!requestId) {
            break
          }
          const didDecline = await this.declineChallengeRecord(requestId, meta.id)
          if (!didDecline) {
            ws.send(JSON.stringify({
              type: 'CHALLENGE_EXPIRED',
              data: {
                requestId,
                message: 'This request has already been processed.',
              },
            }))
            break
          }

          const sockets = this.state.getWebSockets()
          const challenger = sockets.find(s => (s.deserializeAttachment() as LobbyPlayer)?.id === challengerId)
          const declinePayload = JSON.stringify({
            type: 'CHALLENGE_DECLINED',
            data: {
              requestId,
              challengerId,
              message: `${meta.name} declined your request.`,
            },
          })
          if (challenger) {
            challenger.send(declinePayload)
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
          opponentRating: opponent.rating,
          timeControl: p1.timeControl
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

    for (const ws of sockets) {
      try {
        const self = ws.deserializeAttachment() as LobbyPlayer | undefined
        const visiblePlayers = self
          ? allPlayers.filter((p) => p.id !== self.id)
          : allPlayers
        const data = JSON.stringify({
          type: 'LOBBY_UPDATE',
          data: {
            onlinePlayers: visiblePlayers.length,
            searchingPlayers: this.matchmaker.getQueueCount(),
            players: visiblePlayers.map((player) => ({
              ...player,
              presence: this.mapPresence(player.status),
              flair: this.buildFlair(player.status),
            }))
          }
        })
        ws.send(data)
      } catch (_) {
        ws.close()
      }
    }
  }

  private normalizePresence(value: unknown): LobbyPlayer['status'] {
    switch (value) {
      case 'searching':
        return 'searching'
      case 'playing':
      case 'in_game':
        return 'in_game'
      case 'tournament':
        return 'tournament'
      case 'offline_game':
        return 'offline_game'
      default:
        return 'idle'
    }
  }

  private mapPresence(status: LobbyPlayer['status']): string {
    switch (status) {
      case 'in_game':
        return 'playing'
      case 'offline_game':
        return 'offline_game'
      default:
        return status
    }
  }

  private buildFlair(status: LobbyPlayer['status']): string {
    switch (status) {
      case 'searching':
        return 'Searching for a match'
      case 'in_game':
        return 'In a live game'
      case 'tournament':
        return 'In a tournament'
      case 'offline_game':
        return 'Playing offline'
      default:
        return 'Ready for a challenge'
    }
  }

  private normalizeChallengeMode(value: unknown): ChallengeMode {
    return value === 'tournament' ? 'tournament' : 'duel'
  }

  private async upsertChallenge(input: {
    id: string
    challengerId: string
    challengedId: string
    timeControl: string
    mode: ChallengeMode
    variantId: string
    deliveryStatus: ChallengeDelivery
  }) {
    await this.env.DB.prepare(
      `INSERT OR REPLACE INTO challenges (
        id,
        challenger_id,
        challenged_id,
        time_control,
        mode,
        variant_id,
        delivery_status,
        status,
        created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', datetime('now'))`
    )
      .bind(
        input.id,
        input.challengerId,
        input.challengedId,
        input.timeControl,
        input.mode,
        input.variantId,
        input.deliveryStatus,
      )
      .run()
  }

  private async sendPendingChallenges(ws: WebSocket, userId: string) {
    // Clean up challenges older than 1 hour (autoclear)
    await this.env.DB.prepare(
      `DELETE FROM challenges WHERE status = 'pending' AND created_at < datetime('now', '-1 hour')`
    ).run()

    // Fetch both incoming and outgoing challenges to sync full state
    const { results } = await this.env.DB.prepare(
      `SELECT c.id, c.challenger_id, c.challenged_id, c.time_control, c.mode, c.variant_id,
              c.delivery_status, c.created_at, c.status,
              cu.username as challenger_name,
              tu.username as challenged_name
       FROM challenges c
       JOIN users cu ON cu.id = c.challenger_id
       JOIN users tu ON tu.id = c.challenged_id
       WHERE (c.challenged_id = ? OR c.challenger_id = ?) AND c.status = 'pending'
       ORDER BY c.created_at DESC
       LIMIT 40`
    )
      .bind(userId, userId)
      .all<StoredChallengeRow & { challenger_name: string, challenged_name: string, status: string }>()

    if (!results.length) {
      return
    }

    ws.send(JSON.stringify({
      type: 'PENDING_CHALLENGES_SYNC',
      data: {
        requests: results.map((challenge) => {
          const isIncoming = challenge.challenged_id === userId
          return {
            requestId: challenge.id,
            playerId: isIncoming ? challenge.challenger_id : challenge.challenged_id,
            playerName: isIncoming ? (challenge.challenger_name ?? 'Opponent') : (challenge.challenged_name ?? 'Opponent'),
            mode: challenge.mode,
            timeControl: challenge.time_control,
            variantId: challenge.variant_id,
            isIncoming,
            queued: challenge.delivery_status === 'queued',
            status: challenge.status,
            ts: challenge.created_at ? Date.parse(challenge.created_at) : Date.now(),
          }
        }),
      },
    }))
  }

  private async getPendingChallenge(requestId: string, challengedUserId: string) {
    return this.env.DB.prepare(
      `SELECT c.id, c.challenger_id, c.challenged_id, c.time_control, c.mode, c.variant_id,
              c.delivery_status, c.created_at,
              cu.username as challenger_name,
              tu.username as challenged_name
       FROM challenges c
       JOIN users cu ON cu.id = c.challenger_id
       JOIN users tu ON tu.id = c.challenged_id
       WHERE c.id = ? AND c.challenged_id = ? AND c.status = 'pending'`
    )
      .bind(requestId, challengedUserId)
      .first<StoredChallengeRow>()
  }

  private async acceptChallengeRecord(challenge: StoredChallengeRow, gameId: string) {
    let whiteId = challenge.challenger_id
    let blackId = challenge.challenged_id
    if (challenge.mode === 'tournament') {
      whiteId = challenge.challenger_id
      blackId = challenge.challenged_id
    }

    await this.env.DB.batch([
      this.env.DB.prepare(
        `INSERT INTO games (id, white_user_id, black_user_id, mode, time_control)
         VALUES (?, ?, ?, 'multiplayer', ?)`
      ).bind(gameId, whiteId, blackId, challenge.time_control),
      this.env.DB.prepare(
        `UPDATE challenges
         SET status = 'accepted', game_id = ?, updated_at = datetime('now')
         WHERE id = ?`
      ).bind(gameId, challenge.id),
    ])
  }

  private async declineChallengeRecord(requestId: string, challengedUserId: string) {
    const result = await this.env.DB.prepare(
      `UPDATE challenges
       SET status = 'declined', updated_at = datetime('now')
       WHERE id = ? AND challenged_id = ? AND status = 'pending'`
    )
      .bind(requestId, challengedUserId)
      .run()

    return (result.meta?.changes ?? 0) > 0
  }
}
