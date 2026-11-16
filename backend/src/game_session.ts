import { Chess } from 'chess.js'
import { parseTimeControl } from './time_control'

export type Color = 'white' | 'black'
export type MatchResult = Color | 'draw'
export interface SessionConfig {
  gameId: string; whiteId: string; blackId: string; timeControl: string
  mode?: 'multiplayer' | 'tournament'; tournamentId?: string; tournamentRound?:number;totalRounds?:number; initialFen?: string
}
export interface SessionSnapshot extends SessionConfig {
  status: 'waiting' | 'active' | 'paused' | 'finished'
  moves: { from: string; to: string; promotion?: string }[]
  whiteTime: number; blackTime: number; lastTick: number; sequence: number
  connected: string[]; disconnectedUntil: Record<string, number>; waitingUntil: number | null
  undoCounts: Record<string, number>; penalties: Record<string, number>
  lastMoveAt: number; lastMover: string | null
  drawOffer: string | null; saveOffer: string | null
  result?: MatchResult; reason?: string
}

/** Serializable, server-owned chess and clock state. No client clock/color is trusted. */
export class GameSession {
  readonly data: SessionSnapshot
  readonly chess: Chess
  constructor(config: SessionConfig, snapshot?: SessionSnapshot) {
    if (!config.whiteId || !config.blackId || config.whiteId === config.blackId) throw new Error('Two distinct reserved players are required')
    const tc = parseTimeControl(config.timeControl)
    this.data = snapshot ?? { ...config, mode: config.mode ?? 'multiplayer', status: 'waiting', moves: [],
      whiteTime: tc.baseSeconds, blackTime: tc.baseSeconds, lastTick: 0, sequence: 0,
      connected: [], disconnectedUntil: {}, waitingUntil: null, undoCounts: {}, penalties: {},
      lastMoveAt: 0, lastMover: null, drawOffer: null, saveOffer: null }
    this.chess = new Chess(this.data.initialFen)
    for (const move of this.data.moves) this.chess.move(move)
  }
  color(userId: string): Color {
    if (userId === this.data.whiteId) return 'white'
    if (userId === this.data.blackId) return 'black'
    throw new Error('Not a participant')
  }
  get finished(): boolean { return this.data.status === 'finished' }
  get turn(): Color { return this.chess.turn() === 'w' ? 'white' : 'black' }
  get otherColor(): Color { return this.turn === 'white' ? 'black' : 'white' }
  opponent(userId: string) { this.color(userId); return userId === this.data.whiteId ? this.data.blackId : this.data.whiteId }
  connect(userId: string, now: number) {
    this.color(userId)
    this.tick(now)
    if (!this.data.connected.includes(userId)) this.data.connected.push(userId)
    delete this.data.disconnectedUntil[userId]
    if (this.data.status === 'paused') this.data.status = 'waiting'
    if (this.data.status === 'waiting') {
      if (this.data.connected.length === 2) {
        this.data.status = 'active'; this.data.lastTick = now; this.data.waitingUntil = null
      } else this.data.waitingUntil ??= now + 30_000
    }
  }
  disconnect(userId: string, now: number) {
    this.color(userId); this.tick(now)
    this.data.connected = this.data.connected.filter(id => id !== userId)
    if (this.data.status === 'active') this.data.disconnectedUntil[userId] = now + 30_000
  }
  tick(now: number) {
    if (this.data.status === 'active') {
      const key = this.turn === 'white' ? 'whiteTime' : 'blackTime'
      this.data[key] = Math.max(0, this.data[key] - Math.max(0, now - this.data.lastTick) / 1000)
      this.data.lastTick = now
      if (this.data[key] <= 0) { this.finish(this.canMate(this.otherColor) ? this.otherColor : 'draw', 'timeout'); return }
      const disconnected = Object.entries(this.data.disconnectedUntil).filter(([, deadline]) => deadline <= now)
      if (disconnected.length) {
        const result = this.data.connected.length === 0 ? 'draw' : this.color(this.data.connected[0])
        this.finish(result, 'disconnect_timeout')
      }
    } else if (this.data.status === 'waiting' && this.data.waitingUntil && now >= this.data.waitingUntil) {
      this.finish('draw', 'opponent_no_show')
    }
  }
  move(userId: string, input: { from: string; to: string; promotion?: string }, now: number) {
    this.color(userId); this.tick(now)
    if (this.data.status !== 'active') throw new Error('Match is not active')
    if (this.color(userId) !== this.turn) throw new Error('It is not your turn')
    const promotion = ({ queen: 'q', rook: 'r', bishop: 'b', knight: 'n' } as Record<string,string>)[input?.promotion ?? ''] ?? input?.promotion
    const played = this.chess.move({ from: input?.from, to: input?.to, ...(promotion ? { promotion } : {}) })
    const move = { from: played.from, to: played.to, ...(played.promotion ? { promotion: played.promotion } : {}) }
    this.data.moves.push(move)
    this.data[this.color(userId) === 'white' ? 'whiteTime' : 'blackTime'] += parseTimeControl(this.data.timeControl).incrementSeconds
    this.data.lastMover = userId; this.data.lastMoveAt = now; this.data.sequence++
    this.data.drawOffer = null; this.data.saveOffer = null
    if (this.chess.isCheckmate()) this.finish(this.color(userId), 'checkmate')
    else if (this.chess.isStalemate()) this.finish('draw', 'stalemate')
    else if (this.chess.isInsufficientMaterial()) this.finish('draw', 'insufficient_material')
    else if (this.chess.isThreefoldRepetition()) this.finish('draw', 'threefold_repetition')
    else if (this.chess.isDrawByFiftyMoves()) this.finish('draw', 'fifty_move_rule')
    return move
  }
  undo(userId: string, now: number) {
    this.color(userId); this.tick(now)
    if (this.data.status !== 'active' || this.data.lastMover !== userId || now - this.data.lastMoveAt > 5000 || (this.data.undoCounts[userId] ?? 0) >= 2) throw new Error('Takeback is unavailable')
    if (!this.chess.undo()) throw new Error('No move to take back')
    this.data.moves.pop(); this.data.sequence++
    this.data.undoCounts[userId] = (this.data.undoCounts[userId] ?? 0) + 1
    this.data.penalties[userId] = (this.data.penalties[userId] ?? 0) - 25
    // Time spent is never refunded; remove the increment earned by the undone move.
    const key = this.color(userId) === 'white' ? 'whiteTime' : 'blackTime'
    this.data[key] = Math.max(0, this.data[key] - parseTimeControl(this.data.timeControl).incrementSeconds)
    this.data.lastMover = null; this.data.lastMoveAt = 0; this.data.drawOffer = null; this.data.saveOffer = null
  }
  offer(userId: string, kind: 'draw' | 'save') {
    this.color(userId)
    if (this.data.status !== 'active') throw new Error('Match is not active')
    if (kind === 'save' && this.data.mode === 'tournament') throw new Error('Tournament rounds cannot be paused')
    this.data[kind === 'draw' ? 'drawOffer' : 'saveOffer'] = userId
  }
  respond(userId: string, kind: 'draw' | 'save', accept: boolean, now: number) {
    this.color(userId); this.tick(now)
    const key = kind === 'draw' ? 'drawOffer' : 'saveOffer'
    if (this.data.status !== 'active' || this.data[key] !== this.opponent(userId)) throw new Error('No opponent offer to answer')
    this.data[key] = null
    if (accept && kind === 'draw') this.finish('draw', 'agreement')
    if (accept && kind === 'save') { this.data.status = 'paused'; this.data.connected = []; this.data.disconnectedUntil = {} }
  }
  resign(userId: string, now: number) {
    this.color(userId); this.tick(now)
    if (this.data.status === 'waiting') { this.finish('draw', 'opponent_no_show'); return }
    if (this.data.status === 'active') this.finish(this.color(this.opponent(userId)), 'resignation')
  }
  finish(result: MatchResult, reason: string) {
    if (this.data.status === 'finished') return
    this.data.status = 'finished'; this.data.result = result; this.data.reason = reason
    this.data.drawOffer = null; this.data.saveOffer = null; this.data.disconnectedUntil = {}; this.data.waitingUntil = null
  }
  /** FIDE 6.9: a flag fall is drawn if the opponent cannot possibly mate. */
  canMate(color: Color) {
    const own = this.chess.board().flat().filter(p => p && p.color === color[0] && p.type !== 'k')
    const enemy = this.chess.board().flat().filter(p => p && p.color !== color[0] && p.type !== 'k')
    if (!own.length) return false
    if (own.some(p => p && ['p','r','q'].includes(p.type))) return true
    if (own.filter(p => p?.type === 'n').length >= 2) return true
    const squareColor = (square: string) => (square.charCodeAt(0) + Number(square[1])) % 2
    const bishops = own.filter(p => p?.type === 'b')
    if (bishops.length && own.some(p => p?.type === 'n')) return true
    if (new Set(bishops.map(p => squareColor(p!.square))).size > 1) return true
    if (!enemy.length) return false
    if (bishops.length === own.length && enemy.every(p => p?.type === 'b' && squareColor(p.square) === squareColor(bishops[0]!.square))) return false
    return true
  }
  publicState() {
    return { ...this.data, fen: this.chess.fen(), pgn: this.chess.pgn(), turn: this.turn,
      opponentConnected: this.data.connected.length === 2, moves: this.data.moves, sequence: this.data.sequence }
  }
}
