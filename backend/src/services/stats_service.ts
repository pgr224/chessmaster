import { Chess } from 'chess.js'
import { currentBounty } from './bounty'
import { XP_RULES, calculateAIGameXP } from '../xp_rules'
export const GAME_SCORING_SCHEMA = `CREATE TABLE IF NOT EXISTS game_scoring_context (game_id TEXT PRIMARY KEY, context TEXT NOT NULL)`
export function multiplayerElo(rating:number, opponent:number, games:number, outcome:GameOutcome) {
 const k=games<30?40:rating>=2400?10:20
 const expected=1/(1+10**(Math.max(-400,Math.min(400,opponent-rating))/400))
 const score=outcome==='win'?1:outcome==='draw'?0.5:0
 return Math.max(0,Math.min(3500,Math.round(rating+k*(score-expected))))-rating
}
export type GameOutcome = 'win' | 'loss' | 'draw'
export type GameMode = 'multiplayer' | 'tournament' | 'singlePlayer' | 'twoPlayer' | 'tutorial' | 'puzzle' | 'practice'
export interface UpdateStatsOptions { userId: string; gameId?: string | null; outcome: GameOutcome; mode: GameMode; aiDifficulty?: string; eloChange?: number; penalty?: number; bonusXP?: number; rated?: boolean }
export const SCORING_SCHEMA = `CREATE TABLE IF NOT EXISTS scoring_events (
 user_id TEXT NOT NULL REFERENCES users(id), event_id TEXT NOT NULL, claim_id TEXT NOT NULL,
 xp_before INTEGER NOT NULL, xp_after INTEGER NOT NULL, xp_delta INTEGER NOT NULL, elo_before INTEGER NOT NULL DEFAULT 0, elo_after INTEGER NOT NULL DEFAULT 0, elo_delta INTEGER NOT NULL DEFAULT 0,
 created_at TEXT NOT NULL DEFAULT (datetime('now')), PRIMARY KEY(user_id,event_id))`
const counterKeys = new Set(['wins','losses','draws','ai_games','ai_wins','two_player_games','two_player_wins','multiplayer_games','multiplayer_wins','tournament_games','tournament_wins','puzzles_solved','hints_used','pieces_captured','checkmates_delivered','total_moves','total_time_played','tournaments_won'])
const absoluteKeys = new Set(['puzzle_rating','current_streak','longest_streak','best_win_elo'])

export function resultXP(options: UpdateStatsOptions, streak = 0): number {
 const {mode,outcome}=options
 if (options.rated === false) return 0
 let base=0
 if(mode==='multiplayer'||mode==='tournament') base=XP_RULES.multiplayer[outcome]
 else if(mode==='singlePlayer') base=outcome==='win'?calculateAIGameXP(options.aiDifficulty??'intermediate'):outcome==='loss'?-20:10
 if(outcome!=='loss' && mode==='tournament') base=Math.round(base*(1+Math.max(0,streak)*0.2))
 else if(outcome==='win' && mode==='singlePlayer') base=Math.round((base+(options.bonusXP??0))*Math.min(2,1+Math.max(0,streak)*0.1))
 else base+=options.bonusXP??0
 return base+(options.penalty??0)
}

/** D1 batch + per-user event claim: a retry cannot award twice, even after partial delivery. */
export class StatsService {
 static async applyProgress(db:D1Database, options:{userId:string;eventId:string;xpDelta:number;stats?:Record<string,number>;gameId?:string|null;eloChange?:number;online?:boolean}):Promise<number> {
  if(!options.eventId || options.eventId.length>200 || !Number.isSafeInteger(options.xpDelta)) throw new Error('Invalid scoring event')
  await db.prepare(SCORING_SCHEMA).run()
  const claim=crypto.randomUUID(), {userId,eventId,xpDelta}=options
  const updates:string[]=[], values:unknown[]=[]
  for(const [key,value] of Object.entries(options.stats??{})) {
   if(!counterKeys.has(key)&&!absoluteKeys.has(key)) continue
   if(!Number.isSafeInteger(value)) throw new Error('Invalid stat value')
   if(counterKeys.has(key)){updates.push(`${key} = MAX(0, ${key} + ?)`);values.push(value)}
   else {updates.push(`${key} = MAX(0, ?)`);values.push(value)}
  }
  updates.push('elo_rating=(SELECT elo_after FROM scoring_events WHERE user_id=user_stats.user_id AND event_id=?)');values.push(eventId)
  const condition='EXISTS (SELECT 1 FROM scoring_events WHERE user_id = ? AND event_id = ? AND claim_id = ?)'
  const hasXp=!!(await db.prepare('PRAGMA table_info(user_stats)').all<{name:string}>()).results.find(x=>x.name==='xp')
  const statements=[
   db.prepare(`INSERT OR IGNORE INTO scoring_events(user_id,event_id,claim_id,xp_before,xp_after,xp_delta,elo_before,elo_after,elo_delta)
    SELECT id, ?, ?, MAX(0,xp), MAX(0,MAX(0,xp)+?), MAX(0,MAX(0,xp)+?)-MAX(0,xp),COALESCE((SELECT elo_rating FROM user_stats WHERE user_id=users.id),0),MAX(0,COALESCE((SELECT elo_rating FROM user_stats WHERE user_id=users.id),0)+?),MAX(0,COALESCE((SELECT elo_rating FROM user_stats WHERE user_id=users.id),0)+?)-COALESCE((SELECT elo_rating FROM user_stats WHERE user_id=users.id),0) FROM users WHERE id=?`).bind(eventId,claim,xpDelta,xpDelta,options.eloChange??0,options.eloChange??0,userId),
   db.prepare('INSERT OR IGNORE INTO user_stats(user_id) VALUES (?)').bind(userId),
   db.prepare(`UPDATE users SET xp=(SELECT xp_after FROM scoring_events WHERE user_id=? AND event_id=?), updated_at=datetime('now') WHERE id=? AND ${condition}`).bind(userId,eventId,userId,userId,eventId,claim),
   db.prepare(`UPDATE user_stats SET ${[...updates,...(hasXp?['xp=(SELECT xp FROM users WHERE id=user_id)']:[]),"updated_at=datetime('now')"].join(', ')} WHERE user_id=? AND ${condition}`).bind(...values,userId,userId,eventId,claim),
   db.prepare(`INSERT INTO xp_history(user_id,game_id,xp_before,xp_after,change) SELECT user_id,?,xp_before,xp_after,xp_delta FROM scoring_events WHERE user_id=? AND event_id=? AND claim_id=?`).bind(options.gameId??null,userId,eventId,claim),
  ]
  await db.batch(statements)
  const result=await db.prepare('SELECT xp_delta FROM scoring_events WHERE user_id=? AND event_id=?').bind(userId,eventId).first<{xp_delta:number}>()
  if(!result) throw new Error('Scoring user not found')
  return result.xp_delta
 }
 static async updateAll(db:D1Database,options:UpdateStatsOptions):Promise<number> {
  if(!options.gameId) throw new Error('A game ID is required for result settlement')
  // Freeze both participants' pre-settlement ratings/streaks once. Delivery order
  // and retries must not change expected scores, underdog bonuses or the bounty.
  await db.prepare(GAME_SCORING_SCHEMA).run()
  const game=await db.prepare('SELECT * FROM games WHERE id=?').bind(options.gameId).first<any>()
  const participants=[...new Set([game?.white_user_id,game?.black_user_id,options.userId].filter(Boolean))] as string[]
  const fresh:Record<string,Record<string,number>>={}
  for(const id of participants)fresh[id]=await db.prepare('SELECT * FROM user_stats WHERE user_id=?').bind(id).first<Record<string,number>>()??{}
  const bountyTarget=game?.white_user_id&&game?.black_user_id?(await currentBounty(db)).target?.id:null
  await db.prepare('INSERT OR IGNORE INTO game_scoring_context(game_id,context) VALUES(?,?)').bind(options.gameId,JSON.stringify({players:fresh,bountyTarget,bountyExpiresAt:new Date((Math.floor(Date.now()/14_400_000)+1)*14_400_000).toISOString()})).run()
  const saved=await db.prepare('SELECT context FROM game_scoring_context WHERE game_id=?').bind(options.gameId).first<{context:string}>()
  const context=JSON.parse(saved!.context),stats=context.players[options.userId]??{}
  const opponentId=game?.white_user_id===options.userId?game?.black_user_id:game?.white_user_id
  const opponent=context.players[opponentId]??{}

  const outcomeKey=options.outcome==='win'?'wins':options.outcome==='loss'?'losses':'draws'
  const prefix=options.mode==='multiplayer'?'multiplayer':options.mode==='tournament'?'tournament':options.mode==='twoPlayer'?'two_player':'ai'
  const streak=options.outcome==='win'?(stats.current_streak??0)+1:options.outcome==='loss'?0:(stats.current_streak??0)
  const changes:Record<string,number>={ [outcomeKey]:1,[`${prefix}_games`]:1,current_streak:streak,longest_streak:Math.max(streak,stats.longest_streak??0) }
  if(options.outcome==='win')changes[`${prefix}_wins`]=1
  // games_played is derived from the outcome counters, avoiding legacy drift.
  const elo=options.rated===false?0:options.eloChange??(options.mode==='multiplayer'?multiplayerElo(stats.elo_rating??0,opponent.elo_rating??0,stats.multiplayer_games??0,options.outcome):options.mode==='tournament'?(options.outcome==='win'?20:options.outcome==='draw'?5:-15):0)
  let bonus=0,bounty=false
  if(options.mode==='multiplayer'&&options.outcome==='win'){
   if(game){
    const diff=(opponent.elo_rating??0)-(stats.elo_rating??0)
    bonus+=diff>1000?1000:diff>=500?500:diff>=200?200:0
    if(game.termination==='checkmate'&&game.move_count<=10)bonus+=XP_RULES.milestones.mateIn5
    if(game.move_count>10&&game.pgn){try{const chess=new Chess();chess.loadPgn(game.pgn);const color=game.white_user_id===options.userId?'w':'b';if(!chess.history({verbose:true}).some(m=>m.color!==color&&m.captured))bonus+=XP_RULES.milestones.perfectGame}catch{}}
    if(((stats.wins??0)+1)%100===0)bonus+=XP_RULES.milestones.every100thWin
    bounty=!!context.bountyTarget&&!!opponentId&&context.bountyTarget===opponentId
   }
  }
  let requestedXP=resultXP({...options,bonusXP:bonus+(options.bonusXP??0),penalty:0},stats.current_streak??0)
  if(bounty&&requestedXP>0)requestedXP=Math.round(requestedXP*1.5)
  requestedXP+=options.penalty??0
  const xp=await this.applyProgress(db,{userId:options.userId,eventId:`game:${options.gameId}:result`,gameId:options.gameId,xpDelta:requestedXP,stats:changes,eloChange:elo,online:true})
  await db.prepare('UPDATE user_stats SET games_played=wins+losses+draws WHERE user_id=?').bind(options.userId).run()
  if(bounty){
   await db.prepare('CREATE TABLE IF NOT EXISTS bounty_awards(user_id TEXT NOT NULL,game_id TEXT NOT NULL,expires_at TEXT NOT NULL,PRIMARY KEY(user_id,game_id))').run()
   await db.prepare('INSERT OR IGNORE INTO bounty_awards(user_id,game_id,expires_at) VALUES(?,?,?)').bind(options.userId,options.gameId,context.bountyExpiresAt).run()
  }
  return xp
 }
 static async awardTournamentBonus(db:D1Database,userId:string,bonusAmount:number,eloDelta=0,tournamentId?:string) {
  if(!tournamentId)throw new Error('Tournament ID required for champion bonus')
  return this.applyProgress(db,{userId,eventId:`tournament:${tournamentId}:champion`,xpDelta:bonusAmount,eloChange:eloDelta,stats:{tournaments_won:1},online:true})
 }
}
