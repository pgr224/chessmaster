import type { Env } from './index'

interface TournamentPlayer {
  id: string
  username: string
  rating: number
  score: number      // points: 1=win, 0.5=draw, 0=loss
  wins: number
  losses: number
  draws: number
  colorHistory: ('white' | 'black')[]   // alternation tracking
  // opponents faced (to avoid repeat in Swiss)
  opponentIds: string[]
}

type TournamentStatus = 'waiting' | 'active' | 'finished'

interface TournamentState {
  status: TournamentStatus
  players: TournamentPlayer[]
  currentRound: number
  totalRounds: number
  timeControl: string
  type: 'public' | 'private'
  // current round pairings: [player1Id, player2Id, gameId]
  currentPairings: { player1Id: string; player2Id: string; gameId: string; winnerId?: string; result?: string }[]
}

export class TournamentRoom implements DurableObject {
  private state: DurableObjectState
  private env: Env
  private tournament: TournamentState = {
    status: 'waiting',
    players: [],
    currentRound: 0,
    totalRounds: 3,
    timeControl: '10+0',
    type: 'private',
    currentPairings: [],
  }

  constructor(state: DurableObjectState, env: Env) {
    this.state = state
    this.env = env
  }

  async fetch(request: Request): Promise<Response> {
    const upgrade = request.headers.get('Upgrade')
    if (upgrade !== 'websocket') return new Response('Expect WebSocket', { status: 426 })

    const { 0: client, 1: server } = new WebSocketPair()
    const url = new URL(request.url)
    const userId = url.searchParams.get('userId') ?? 'anon'
    const username = url.searchParams.get('username') ?? 'Player'
    const rating = parseInt(url.searchParams.get('rating') ?? '1200')
    const totalRounds = parseInt(url.searchParams.get('totalRounds') ?? '3')
    const timeControl = url.searchParams.get('timeControl') ?? '10+0'
    const type = (url.searchParams.get('type') ?? 'private') as 'public' | 'private'

    // Restore persisted state
    const saved = await this.state.storage.get<TournamentState>('tournament')
    if (saved) {
      this.tournament = saved
    } else {
      this.tournament.totalRounds = totalRounds
      this.tournament.timeControl = timeControl
      this.tournament.type = type
    }

    // Accept WebSocket
    this.state.acceptWebSocket(server, [userId])
    server.serializeAttachment({ id: userId, username, rating })

    // Add player if not already present
    const existing = this.tournament.players.find(p => p.id === userId)
    if (!existing) {
      this.tournament.players.push({
        id: userId,
        username,
        rating,
        score: 0,
        wins: 0,
        losses: 0,
        draws: 0,
        colorHistory: [],
        opponentIds: [],
      })
      await this._persist()
    }

    // Send current state to the connected player
    this._send(server, { type: 'tournament_state', data: this._publicState() })

    // If enough players ready, broadcast lobby update
    this._broadcastAll({ type: 'players_update', data: { players: this._publicPlayers() } })

    return new Response(null, { status: 101, webSocket: client })
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer) {
    const meta = ws.deserializeAttachment() as { id: string; username: string; rating: number }
    if (!meta) return

    try {
      const msg = JSON.parse(message as string)
      switch (msg.type) {
        case 'READY':
          await this._handleReady(ws, meta)
          break
        case 'MATCH_RESULT':
          await this._handleMatchResult(msg, meta)
          break
        case 'NEXT_ROUND':
          await this._handleNextRound()
          break
      }
    } catch (e) {
      console.error('[TournamentRoom] message error:', e)
    }
  }

  async webSocketClose(ws: WebSocket) {
    // Player disconnected — leave them in, they'll reconnect or forfeit
    this._broadcastAll({ type: 'player_disconnected', data: { userId: (ws.deserializeAttachment() as any)?.id } })
  }

  async webSocketError(ws: WebSocket) {
    await this.webSocketClose(ws)
  }

  // ─── Private Helpers ─────────────────────────────────────────────

  private async _handleReady(ws: WebSocket, meta: { id: string }) {
    // For private best-of: start when 2 players are ready
    // For public Swiss: start is triggered by the creator via REST
    const sockets = this.state.getWebSockets()
    if (this.tournament.type === 'private' && sockets.length >= 2 && this.tournament.status === 'waiting') {
      await this._startTournament()
    } else {
      this._send(ws, { type: 'waiting', data: { message: 'Waiting for opponent…' } })
    }
  }

  private async _startTournament() {
    this.tournament.status = 'active'
    this.tournament.currentRound = 1
    await this._persist()
    this._broadcastAll({ type: 'tournament_start', data: { totalRounds: this.tournament.totalRounds } })
    await this._kickOffRound()
  }

  private async _kickOffRound() {
    const pairings = this._computePairings()
    this.tournament.currentPairings = pairings.map(([p1, p2]) => {
      const gameId = crypto.randomUUID()
      // Determine colors: alternate from previous round
      const p1Color = this._nextColor(p1)
      const p2Color = p1Color === 'white' ? 'black' : 'white'
      p1.colorHistory.push(p1Color)
      p2.colorHistory.push(p2Color)
      p1.opponentIds.push(p2.id)
      p2.opponentIds.push(p1.id)
      return { player1Id: p1.id, player2Id: p2.id, gameId }
    })
    await this._persist()

    this._broadcastAll({
      type: 'round_start',
      data: {
        round: this.tournament.currentRound,
        totalRounds: this.tournament.totalRounds,
        pairings: this.tournament.currentPairings.map(pair => {
          const p1 = this.tournament.players.find(p => p.id === pair.player1Id)!
          const p2 = this.tournament.players.find(p => p.id === pair.player2Id)!
          const p1Color = p1.colorHistory[p1.colorHistory.length - 1]
          const p2Color = p2.colorHistory[p2.colorHistory.length - 1]
          return {
            gameId: pair.gameId,
            player1: { id: p1.id, username: p1.username, color: p1Color },
            player2: { id: p2.id, username: p2.username, color: p2Color },
          }
        }),
      },
    })
  }

  private async _handleMatchResult(msg: any, meta: { id: string }) {
    const { gameId, result } = msg  // result: 'player1' | 'player2' | 'draw'
    const pairing = this.tournament.currentPairings.find(p => p.gameId === gameId)
    if (!pairing || pairing.result) return  // already processed

    pairing.result = result
    pairing.winnerId = result === 'player1' ? pairing.player1Id
      : result === 'player2' ? pairing.player2Id
      : undefined

    // Update scores
    const p1 = this.tournament.players.find(p => p.id === pairing.player1Id)!
    const p2 = this.tournament.players.find(p => p.id === pairing.player2Id)!
    if (result === 'player1') { p1.score += 1; p1.wins++; p2.losses++ }
    else if (result === 'player2') { p2.score += 1; p2.wins++; p1.losses++ }
    else { p1.score += 0.5; p2.score += 0.5; p1.draws++; p2.draws++ }

    await this._persist()

    const standings = this._standings()
    this._broadcastAll({
      type: 'match_result',
      data: { gameId, result, standings },
    })

    // Check for engagement notices
    this._sendEngagementNotices()

    // Check if private best-of is already decided
    if (this.tournament.type === 'private' && this.tournament.players.length === 2) {
      const [pa, pb] = this.tournament.players
      const majority = Math.floor(this.tournament.totalRounds / 2) + 1
      if (pa.wins >= majority || pb.wins >= majority) {
        await this._endTournament()
        return
      }
    }

    // Check if all pairings in this round are done
    const allDone = this.tournament.currentPairings.every(p => !!p.result)
    if (allDone) {
      if (this.tournament.currentRound >= this.tournament.totalRounds) {
        await this._endTournament()
      } else {
        // Auto-advance after a brief pause
        this.tournament.currentRound++
        await this._persist()
        await this._kickOffRound()
      }
    }
  }

  private async _handleNextRound() {
    if (this.tournament.currentRound < this.tournament.totalRounds) {
      this.tournament.currentRound++
      await this._persist()
      await this._kickOffRound()
    }
  }

  private async _endTournament() {
    this.tournament.status = 'finished'
    await this._persist()

    const standings = this._standings()
    const winner = standings[0]

    // XP / ELO deltas per plan: Win=+100, Draw=+30, Loss=-20, bonus +200 for overall winner
    const xpDeltas: Record<string, number> = {}
    const eloDeltas: Record<string, number> = {}
    for (const p of this.tournament.players) {
      const xpBase = (p.wins * 100) + (p.draws * 30) + (p.losses * -20)
      const streakMultiplier = 1 + Math.min(p.wins, 5) * 0.2
      xpDeltas[p.id] = Math.round(xpBase * streakMultiplier) + (p.id === winner?.id ? 200 : 0)
      eloDeltas[p.id] = (p.wins * 20) + (p.draws * 5) + (p.losses * -15)
    }

    this._broadcastAll({
      type: 'tournament_end',
      data: {
        standings,
        winner: winner ? { id: winner.id, username: winner.username } : null,
        xpDeltas,
        eloDeltas,
      },
    })
  }

  private _sendEngagementNotices() {
    if (this.tournament.players.length !== 2) return
    const [pa, pb] = this.tournament.players
    const majority = Math.floor(this.tournament.totalRounds / 2) + 1
    const isLastRound = this.tournament.currentRound === this.tournament.totalRounds

    for (const [me, opp] of [[pa, pb], [pb, pa]] as [TournamentPlayer, TournamentPlayer][]) {
      let notice: string | null = null
      if (me.wins === majority - 1 && opp.wins < majority - 1) notice = '🎯 Match point! One more win!'
      else if (opp.wins === majority - 1 && me.wins < majority - 1) notice = '💪 Opponent at match point — fight back!'
      else if (isLastRound) notice = '🏁 Final round!'
      else if (me.score > opp.score) notice = `🔥 You lead ${me.score}–${opp.score}`

      if (notice) {
        const sockets = this.state.getWebSockets()
        const playerSocket = sockets.find(s => (s.deserializeAttachment() as any)?.id === me.id)
        if (playerSocket) this._send(playerSocket, { type: 'engagement_notice', data: { message: notice } })
      }
    }
  }

  private _computePairings(): [TournamentPlayer, TournamentPlayer][] {
    const players = [...this.tournament.players]
    if (this.tournament.type === 'private' || players.length === 2) {
      return [[players[0], players[1]]]
    }
    // Swiss pairing: sort by score DESC, pair adjacent, avoid rematches
    players.sort((a, b) => b.score - a.score || b.rating - a.rating)
    const used = new Set<string>()
    const pairs: [TournamentPlayer, TournamentPlayer][] = []
    for (let i = 0; i < players.length; i++) {
      if (used.has(players[i].id)) continue
      for (let j = i + 1; j < players.length; j++) {
        if (used.has(players[j].id)) continue
        if (!players[i].opponentIds.includes(players[j].id)) {
          pairs.push([players[i], players[j]])
          used.add(players[i].id)
          used.add(players[j].id)
          break
        }
      }
    }
    return pairs
  }

  private _nextColor(p: TournamentPlayer): 'white' | 'black' {
    if (p.colorHistory.length === 0) return Math.random() < 0.5 ? 'white' : 'black'
    const last = p.colorHistory[p.colorHistory.length - 1]
    return last === 'white' ? 'black' : 'white'
  }

  private _standings(): TournamentPlayer[] {
    return [...this.tournament.players].sort(
      (a, b) => b.score - a.score || b.wins - a.wins || b.rating - a.rating,
    )
  }

  private _publicPlayers(): object[] {
    return this._standings().map(p => ({
      id: p.id,
      username: p.username,
      rating: p.rating,
      score: p.score,
      wins: p.wins,
      losses: p.losses,
      draws: p.draws,
    }))
  }

  private _publicState(): object {
    return {
      status: this.tournament.status,
      currentRound: this.tournament.currentRound,
      totalRounds: this.tournament.totalRounds,
      timeControl: this.tournament.timeControl,
      type: this.tournament.type,
      players: this._publicPlayers(),
      pairings: this.tournament.currentPairings,
    }
  }

  private _broadcastAll(payload: object) {
    const msg = JSON.stringify(payload)
    for (const ws of this.state.getWebSockets()) {
      try { ws.send(msg) } catch (_) {}
    }
  }

  private _send(ws: WebSocket, payload: object) {
    try { ws.send(JSON.stringify(payload)) } catch (_) {}
  }

  private async _persist() {
    await this.state.storage.put('tournament', this.tournament)
  }
}
