import { GameSession, type SessionSnapshot, type SessionConfig } from './game_session'
import { StatsService } from './services/stats_service'
import { PushService } from './services/push_service'
import type { Env } from './index'

type Receipt = { xpDeltas: Record<string,number>; eloDeltas: Record<string,number> }
type RematchReady = {gameId:string;whiteId:string;blackId:string;timeControl:string}
/** One authoritative, durable session per reserved game. */
export class GameRoom {
 private session: GameSession | null = null
 private receipt: Receipt | null = null
 private queue: Promise<unknown> = Promise.resolve()
 constructor(private state:DurableObjectState,private env:Env) {
  state.blockConcurrencyWhile(async()=>{
   const saved=await state.storage.get<SessionSnapshot>('session')
   if(saved)this.session=new GameSession(saved,saved)
   this.receipt=await state.storage.get<Receipt>('receipt')??null
  })
 }
 private async serial<T>(task:()=>Promise<T>):Promise<T> { const next=this.queue.then(task,task);this.queue=next.catch(()=>{});return next }
 async fetch(request:Request):Promise<Response> {
  return this.serial(async()=>{
   const url=new URL(request.url)
   if(request.method==='POST'&&url.pathname==='/initialize') {
    const config=await request.json() as SessionConfig
    if(this.session){if(this.session.data.gameId!==config.gameId||this.session.data.whiteId!==config.whiteId||this.session.data.blackId!==config.blackId)return new Response('Conflicting session', {status:409})}
    else {this.session=new GameSession(config);await this.persist()}
    return Response.json({success:true})
   }
   const userId=request.headers.get('X-Authenticated-User')
   if(!userId)return new Response('Unauthorized',{status:401})
   const gameId=decodeURIComponent(url.pathname.split('/').pop()??'')
   if(!this.session){
    const row=await this.env.DB.prepare('SELECT * FROM games WHERE id=?').bind(gameId).first<any>()
    if(!row||!row.white_user_id||!row.black_user_id)return new Response('Match not found',{status:404})
    const variant=await this.env.DB.prepare('SELECT variant_id FROM challenges WHERE game_id=? LIMIT 1').bind(gameId).first<{variant_id:string}>()
    if(variant&&variant.variant_id!=='standard')return new Response('This variant is not supported for online play',{status:422})
    const session=new GameSession({gameId,whiteId:row.white_user_id,blackId:row.black_user_id,timeControl:row.time_control??'10+0',mode:row.mode==='tournament'?'tournament':'multiplayer',tournamentId:row.tournament_id??undefined,initialFen:row.initial_fen??undefined})
    if(row.pgn){session.chess.loadPgn(row.pgn);session.data.moves=session.chess.history({verbose:true}).map(m=>({from:m.from,to:m.to,...(m.promotion?{promotion:m.promotion}:{})}))}
    if(row.white_time_left!=null)session.data.whiteTime=row.white_time_left/1000
    if(row.black_time_left!=null)session.data.blackTime=row.black_time_left/1000
    if(['completed','draw','abandoned'].includes(row.status)){session.finish(row.result??'draw',row.termination??'completed');this.receipt={xpDeltas:{},eloDeltas:{}}}
    this.session=session
   }
   try {this.session.color(userId)}catch{return new Response('Not a participant',{status:403})}
   const pair=new WebSocketPair(),client=pair[0],server=pair[1]
   for(const ws of this.state.getWebSockets(userId)){try{ws.close(1000,'Replaced by a newer connection')}catch{}}
   this.state.acceptWebSocket(server,[userId]);server.serializeAttachment({userId,name:request.headers.get('X-Authenticated-Name')??'Player'})
   this.session.connect(userId,Date.now());await this.persist()
   this.send(server,'ROOM_STATE',this.session.publicState())
   if(this.session.data.status==='active'){this.broadcast('ROOM_STATE',this.session.publicState());this.broadcast('OPPONENT_JOINED',this.session.publicState())}
   if(this.session.finished){await this.settle();this.sendResult(server,userId);await this.sendRematchState(server,userId)}
   if(this.session.data.status==='waiting')this.state.waitUntil(PushService.notifyUser(this.session.opponent(userId),{title:'♟️ Opponent is waiting',body:'Your match is ready. Join to play.',data:{type:'GAME_WAITING',gameId,category:'games'}},this.env,'games'))
   return new Response(null,{status:101,webSocket:client})
  })
 }
 async webSocketMessage(ws:WebSocket,message:string|ArrayBuffer) {
  await this.serial(async()=>{
   const userId=(ws.deserializeAttachment() as {userId?:string})?.userId
   if(!userId||!this.session)return
   try {
    const msg=JSON.parse(typeof message==='string'?message:new TextDecoder().decode(message))
    const session=this.session,now=Date.now()
    session.tick(now)
    if(session.finished&&msg.type==='REMATCH_REQUEST'){await this.requestRematch(userId);return}
    if(session.finished&&msg.type==='REMATCH_ACCEPT'){await this.rematch(userId);return}
    if(session.finished){await this.settle();this.sendResult(ws,userId);return}
    if(msg.type==='MOVE') {
     const move=session.move(userId,msg.move,now);await this.persist()
     this.broadcast('MOVE_UPDATE',{...session.publicState(),userId,move,gameOver:session.finished})
    } else if(msg.type==='UNDO') {
     session.undo(userId,now);await this.persist()
     this.broadcast('MOVE_UPDATE',{...session.publicState(),userId,undo:true,move:null})
    } else if(msg.type==='RESIGN'||msg.type==='LEAVE_GAME') {session.resign(userId,now);await this.persist()}
    else if(msg.type==='DRAW_OFFER'||msg.type==='SAVE_REQUEST') {
     const kind=msg.type==='DRAW_OFFER'?'draw':'save';session.offer(userId,kind);await this.persist();this.broadcast(msg.type,{from:userId},userId)
    } else if(['DRAW_ACCEPT','DRAW_DECLINE','SAVE_ACCEPT','SAVE_DECLINE'].includes(msg.type)) {
     const kind=msg.type.startsWith('DRAW')?'draw':'save';session.respond(userId,kind,msg.type.endsWith('ACCEPT'),now);await this.persist()
     if(session.data.status==='paused') {await this.savePaused();this.broadcast('GAME_SAVED',{reason:'manual_save'});for(const socket of this.state.getWebSockets())socket.close(1000,'Game saved')}
     else if(msg.type.endsWith('DECLINE'))this.broadcast(msg.type,{},userId)
    } else if(msg.type==='CHAT') {
     const text=typeof msg.message==='string'?msg.message.trim().slice(0,500):''
     if(text)this.broadcast('CHAT',{userId,username:requestName(ws),message:text,ts:now})
    } else if(msg.type==='SYNC')this.send(ws,'ROOM_STATE',session.publicState())
    else if(msg.type==='REMATCH_REQUEST'||msg.type==='REMATCH_ACCEPT')throw new Error('Rematches are available after the match ends')
    if(session.finished){await this.settle();this.broadcastResults()}
   } catch(error) {
    this.send(ws,'MOVE_ERROR',{...this.session.publicState(),message:error instanceof Error?error.message:'Invalid action'})
    await this.persist()
   }
  })
 }
 async webSocketClose(ws:WebSocket){await this.serial(async()=>{
  const userId=(ws.deserializeAttachment() as {userId?:string})?.userId
  if(!userId||!this.session)return
  if(this.state.getWebSockets(userId).some(other=>other!==ws&&other.readyState===1))return
  this.session.disconnect(userId,Date.now());await this.persist();this.broadcast('PLAYER_DISCONNECTED',{userId})
 })}
 async webSocketError(ws:WebSocket){await this.webSocketClose(ws)}
 async alarm(){await this.serial(async()=>{
  if(!this.session)return
  this.session.tick(Date.now())
  await this.persist()
  if(this.session.finished){await this.settle();this.broadcastResults()}
  else this.broadcast('TIMER_SYNC',this.session.publicState())
 })}
 private async persist(){if(!this.session)return;await this.state.storage.put('session',this.session.data)
  if(this.session.data.status==='active'||this.session.data.status==='waiting'||(this.session.finished&&!this.receipt))await this.state.storage.setAlarm(Date.now()+1000)
  else await this.state.storage.deleteAlarm()
 }
 private async savePaused(){const s=this.session!;await this.env.DB.prepare('UPDATE games SET pgn=?,final_fen=?,white_time_left=?,black_time_left=?,updated_at=datetime(\'now\') WHERE id=? AND status=\'active\'').bind(s.chess.pgn(),s.chess.fen(),Math.round(s.data.whiteTime*1000),Math.round(s.data.blackTime*1000),s.data.gameId).run()}
 private async settle(){
  if(!this.session||this.receipt||this.session.data.status!=='finished')return
  const s=this.session,d=s.data,cancelled=d.reason==='opponent_no_show'
  await this.env.DB.prepare(`UPDATE games SET status=?,result=?,termination=?,pgn=?,final_fen=?,move_count=?,white_time_left=?,black_time_left=?,completed_at=datetime('now'),updated_at=datetime('now') WHERE id=?`).bind(cancelled?'abandoned':'completed',cancelled?null:d.result,d.reason,s.chess.pgn(),s.chess.fen(),d.moves.length,Math.round(d.whiteTime*1000),Math.round(d.blackTime*1000),d.gameId).run()
  const receipt:Receipt={xpDeltas:{},eloDeltas:{}}
  for(const [color,userId]of [['white',d.whiteId],['black',d.blackId]]as const){
   const outcome=d.result==='draw'?'draw':d.result===color?'win':'loss'
   const before=await this.env.DB.prepare('SELECT elo_rating FROM user_stats WHERE user_id=?').bind(userId).first<{elo_rating:number}>()
   receipt.xpDeltas[userId]=cancelled?0:await StatsService.updateAll(this.env.DB,{userId,gameId:d.gameId,mode:d.mode??'multiplayer',outcome,penalty:d.penalties[userId]??0})
   const after=await this.env.DB.prepare('SELECT elo_rating FROM user_stats WHERE user_id=?').bind(userId).first<{elo_rating:number}>()
   const scoring=cancelled?null:await this.env.DB.prepare('SELECT elo_delta FROM scoring_events WHERE user_id=? AND event_id=?').bind(userId,`game:${d.gameId}:result`).first<{elo_delta:number}>()
   receipt.eloDeltas[userId]=scoring?.elo_delta??0
  }
  await this.env.DB.prepare("UPDATE challenges SET status='completed',updated_at=datetime('now') WHERE game_id=? AND status='accepted'").bind(d.gameId).run()
  if(d.tournamentId){const stub=this.env.TOURNAMENT_ROOM.get(this.env.TOURNAMENT_ROOM.idFromName(d.tournamentId));const response=await stub.fetch(new Request('https://tournament/match-result',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({gameId:d.gameId,result:d.result,reason:d.reason,whiteId:d.whiteId,blackId:d.blackId,...receipt})}));if(!response.ok)throw new Error('Tournament result delivery failed')}
  this.receipt=receipt;await this.state.storage.put('receipt',receipt);await this.persist()
 }
 private sendResult(ws:WebSocket,userId:string){const s=this.session!;this.send(ws,'GAME_OVER',{...s.publicState(),xpDelta:this.receipt?.xpDeltas[userId]??0,eloDelta:this.receipt?.eloDeltas[userId]??0,settlementPending:!this.receipt})}
 private broadcastResults(){for(const ws of this.state.getWebSockets()){const meta=ws.deserializeAttachment() as {userId:string};this.sendResult(ws,meta.userId)}}
 private send(ws:WebSocket,type:string,data:unknown){try{ws.send(JSON.stringify({type,data}))}catch{}}
 private broadcast(type:string,data:unknown,skip?:string){for(const ws of this.state.getWebSockets()){if((ws.deserializeAttachment()as{userId:string}).userId!==skip)this.send(ws,type,data)}}
 private async requestRematch(userId:string){
  const s=this.session!
  if(!s.finished||s.data.mode==='tournament')throw new Error('No rematch is available')
  await this.settle()
  const ready=await this.state.storage.get<RematchReady>('rematchReady')
  if(ready){await this.ensureRematchGame(ready);this.broadcastRematchReady(ready);return}
  await this.state.storage.put('rematch',userId)
  this.broadcast('REMATCH_REQUEST',{from:userId},userId)
 }
 private async sendRematchState(ws:WebSocket,userId:string){
  const ready=await this.state.storage.get<RematchReady>('rematchReady')
  if(ready){await this.ensureRematchGame(ready);this.sendRematchReady(ws,userId,ready);return}
  const from=await this.state.storage.get<string>('rematch')
  if(from&&from!==userId)this.send(ws,'REMATCH_REQUEST',{from})
 }
 private async ensureRematchGame(ready:RematchReady){
  await this.env.DB.prepare("INSERT OR IGNORE INTO games(id,white_user_id,black_user_id,mode,time_control) VALUES(?,?,?,'multiplayer',?)").bind(ready.gameId,ready.whiteId,ready.blackId,ready.timeControl).run()
 }
 private sendRematchReady(ws:WebSocket,userId:string,ready:RematchReady){this.send(ws,'REMATCH_READY',{gameId:ready.gameId,color:userId===ready.whiteId?'white':'black',timeControl:ready.timeControl})}
 private broadcastRematchReady(ready:RematchReady){for(const ws of this.state.getWebSockets())this.sendRematchReady(ws,(ws.deserializeAttachment()as{userId:string}).userId,ready)}
 private async rematch(userId:string){
  const s=this.session!
  if(!s.finished||s.data.mode==='tournament')throw new Error('No rematch to accept')
  await this.settle()
  let ready=await this.state.storage.get<RematchReady>('rematchReady')
  if(!ready){
   const from=await this.state.storage.get<string>('rematch')
   if(!from||from===userId)throw new Error('No rematch to accept')
   ready={gameId:crypto.randomUUID(),whiteId:s.data.blackId,blackId:s.data.whiteId,timeControl:s.data.timeControl}
   // Reserve the ID first: a D1 failure/retry must not create another game.
   await this.state.storage.put('rematchReady',ready)
  }
  await this.ensureRematchGame(ready)
  await this.state.storage.delete('rematch')
  this.broadcastRematchReady(ready)
 }

}
function requestName(ws:WebSocket){return (ws.deserializeAttachment()as{name?:string}).name??'Player'}
