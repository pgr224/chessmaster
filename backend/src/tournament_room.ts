import type { Env } from './index'
import { StatsService } from './services/stats_service'
interface Player { id:string;username:string;rating:number;score:number;wins:number;losses:number;draws:number;colorHistory:('white'|'black')[];opponentIds:string[];byes:number }
interface Pair {player1Id:string;player2Id:string;gameId:string;whiteId:string;blackId:string;result?:string;winnerId?:string;initialized?:boolean}
interface Tournament {id:string;status:'waiting'|'active'|'finished';players:Player[];currentRound:number;totalRounds:number;timeControl:string;type:'private'|'public';currentPairings:Pair[];readyIds:string[];xpDeltas:Record<string,number>;eloDeltas:Record<string,number>;nextRoundAt?:number;bonusesSettled?:boolean}
export class TournamentRoom {
 private tournament:Tournament|null=null
 private queue:Promise<unknown>=Promise.resolve()
 constructor(private state:DurableObjectState,private env:Env){state.blockConcurrencyWhile(async()=>{this.tournament=await state.storage.get<Tournament>('tournament')??null})}
 private async serial<T>(action:()=>Promise<T>){const next=this.queue.then(action,action);this.queue=next.catch(()=>{});return next}
 async fetch(request:Request):Promise<Response>{return this.serial(async()=>{
  const url=new URL(request.url)
  if(request.method==='POST'&&url.pathname==='/match-result'){if(!this.tournament)return new Response('Tournament missing',{status:404});await this.result(await request.json());return Response.json({success:true})}
  const id=url.searchParams.get('tournamentId')??decodeURIComponent(url.pathname.split('/').pop()??'')
  const actor=request.headers.get('X-Authenticated-User')
  if(!actor)return new Response('Unauthorized',{status:401})
  const row=await this.env.DB.prepare('SELECT * FROM tournaments WHERE id=?').bind(id).first<any>()
  if(!row)return new Response('Tournament missing',{status:404})
  const enrolled=await this.env.DB.prepare('SELECT user_id FROM tournament_participants WHERE tournament_id=? AND user_id=?').bind(id,actor).first()
  if(!enrolled)return new Response('Join or accept your invitation first',{status:403})
  if(!this.tournament){this.tournament={id,status:row.status==='completed'?'finished':'waiting',players:[],currentRound:row.current_round??0,totalRounds:row.total_rounds??3,timeControl:row.time_control??'10+0',type:row.type??'public',currentPairings:[],readyIds:[],xpDeltas:{},eloDeltas:{}}}
  if(this.tournament.id!==id)return new Response('Wrong tournament',{status:409})
  if(this.tournament.status==='waiting')await this.loadPlayers()
  if(request.method==='POST'&&url.pathname.endsWith('/start')){if(row.created_by!==actor)return new Response('Creator only',{status:403});await this.start();return Response.json({success:true})}
  const pair=new WebSocketPair(),client=pair[0],server=pair[1]
  for(const ws of this.state.getWebSockets(actor))ws.close(1000,'New session')
  this.state.acceptWebSocket(server,[actor]);server.serializeAttachment({id:actor})
  this.send(server,'tournament_state',this.publicState());this.broadcast('players_update',{players:this.standings()});await this.persist()
  return new Response(null,{status:101,webSocket:client})
 })}
 async webSocketMessage(ws:WebSocket,message:string|ArrayBuffer){await this.serial(async()=>{
  if(!this.tournament)return
  const id=(ws.deserializeAttachment()as{id:string}).id
  try{const msg=JSON.parse(typeof message==='string'?message:new TextDecoder().decode(message))
   if(msg.type==='READY'&&this.tournament.status==='waiting'){
    if(!this.tournament.readyIds.includes(id))this.tournament.readyIds.push(id)
    await this.loadPlayers();await this.persist()
    if(this.tournament.players.length>=2&&this.tournament.players.every(p=>this.tournament!.readyIds.includes(p.id)))await this.start()
    else this.broadcast('waiting',{message:'Waiting for all participants to be ready.'})
   } else if(msg.type==='MATCH_RESULT'||msg.type==='NEXT_ROUND')this.send(ws,'error',{message:'Only verified game results can advance a tournament.'})
  }catch(error){this.send(ws,'error',{message:error instanceof Error?error.message:'Invalid tournament action'})}
 })}
 async webSocketClose(ws:WebSocket){this.broadcast('player_disconnected',{userId:(ws.deserializeAttachment()as{id:string})?.id})}
 async webSocketError(ws:WebSocket){await this.webSocketClose(ws)}
 async alarm(){await this.serial(async()=>{
  const t=this.tournament;if(!t)return
  if(t.status==='finished'){await this.end();return}
  if(t.nextRoundAt&&Date.now()>=t.nextRoundAt){delete t.nextRoundAt;t.currentRound++;await this.round()}
  else if(t.status==='active')await this.initializeGames()
 })}
 private async loadPlayers(){
  const t=this.tournament!;const rows=await this.env.DB.prepare(`SELECT u.id,u.username,COALESCE(s.elo_rating,0) AS rating FROM tournament_participants tp JOIN users u ON u.id=tp.user_id LEFT JOIN user_stats s ON s.user_id=u.id WHERE tp.tournament_id=? ORDER BY tp.joined_at,u.id`).bind(t.id).all<{id:string;username:string;rating:number}>()
  t.players=rows.results.map(row=>t.players.find(p=>p.id===row.id)??{...row,score:0,wins:0,losses:0,draws:0,colorHistory:[],opponentIds:[],byes:0})
 }
 private async start(){const t=this.tournament!;if(t.status!=='waiting')return;if(t.players.length<2)throw new Error('At least two players are required');if(t.type==='private'&&t.players.length!==2)throw new Error('A private series has two players');t.status='active';t.currentRound=1;await this.persist();await this.env.DB.prepare("UPDATE tournaments SET status='active',current_round=1 WHERE id=?").bind(t.id).run();this.broadcast('tournament_start',{totalRounds:t.totalRounds});await this.round()}
 private async round(){
  const t=this.tournament!,players=[...this.standings()]
  if(players.length%2){const bye=[...players].sort((a,b)=>a.byes-b.byes||a.score-b.score||a.id.localeCompare(b.id))[0];bye.score++;bye.byes++;players.splice(players.findIndex(p=>p.id===bye.id),1);this.broadcast('engagement_notice',{message:`${bye.username} receives a bye this round.`})}
  const pairs=pairPlayers(players)
  t.currentPairings=pairs.map(([a,b])=>{
   const white=a.colorHistory.at(-1)==='white'?b:a,black=white===a?b:a
   white.colorHistory.push('white');black.colorHistory.push('black');a.opponentIds.push(b.id);b.opponentIds.push(a.id)
   return {player1Id:a.id,player2Id:b.id,whiteId:white.id,blackId:black.id,gameId:crypto.randomUUID()}
  })
  await this.persist();await this.env.DB.prepare('UPDATE tournaments SET current_round=? WHERE id=?').bind(t.currentRound,t.id).run();await this.initializeGames()
 }
 private async initializeGames(){
  const t=this.tournament!;let needsRetry=false
  for(const p of t.currentPairings){if(p.initialized)continue
   try{
    await this.env.DB.batch([
     this.env.DB.prepare("INSERT OR IGNORE INTO games(id,white_user_id,black_user_id,mode,time_control,tournament_id) VALUES(?,?,?,'tournament',?,?)").bind(p.gameId,p.whiteId,p.blackId,t.timeControl,t.id),
     this.env.DB.prepare("INSERT INTO tournament_matches(tournament_id,round_number,game_id,player1_id,player2_id,white_id,black_id,status) SELECT ?,?,?,?,?,?,?,'active' WHERE NOT EXISTS(SELECT 1 FROM tournament_matches WHERE game_id=?)").bind(t.id,t.currentRound,p.gameId,p.player1Id,p.player2Id,p.whiteId,p.blackId,p.gameId),
    ])
    const stub=this.env.GAME_ROOM.get(this.env.GAME_ROOM.idFromName(p.gameId));const response=await stub.fetch(new Request('https://game/initialize',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({gameId:p.gameId,whiteId:p.whiteId,blackId:p.blackId,timeControl:t.timeControl,mode:'tournament',tournamentId:t.id,tournamentRound:t.currentRound,totalRounds:t.totalRounds})}));if(!response.ok)throw new Error('Round setup failed');p.initialized=true
   }catch{needsRetry=true}
  }
  await this.persist()
  if(needsRetry){await this.state.storage.setAlarm(Date.now()+2000);return}
  this.broadcast('round_start',{round:t.currentRound,totalRounds:t.totalRounds,pairings:this.publicPairings()})
 }
 private async result(msg:any){
  const t=this.tournament!,pair=t.currentPairings.find(p=>p.gameId===msg.gameId)
  if(!pair){const old=await this.env.DB.prepare("SELECT id FROM games WHERE id=? AND tournament_id=? AND status IN('completed','abandoned')").bind(msg.gameId,t.id).first();if(old)return;throw new Error('Unknown round game')}
  const alreadyApplied=!!pair.result
  const game=await this.env.DB.prepare('SELECT status,result,white_user_id,black_user_id FROM games WHERE id=? AND tournament_id=?').bind(pair.gameId,t.id).first<any>()
  if(!game||game.status!=='completed'&&game.status!=='abandoned'||game.white_user_id!==pair.whiteId||game.black_user_id!==pair.blackId)throw new Error('Unverified result')
  const winnerId=game.result==='white'?pair.whiteId:game.result==='black'?pair.blackId:undefined
  if(!alreadyApplied){
  pair.result=winnerId===pair.player1Id?'player1':winnerId===pair.player2Id?'player2':'draw';pair.winnerId=winnerId
  const a=t.players.find(p=>p.id===pair.player1Id)!,b=t.players.find(p=>p.id===pair.player2Id)!
  if(winnerId===a.id){a.score++;a.wins++;b.losses++}else if(winnerId===b.id){b.score++;b.wins++;a.losses++}else{a.score+=0.5;b.score+=0.5;a.draws++;b.draws++}
  for(const id of [a.id,b.id]){t.xpDeltas[id]=(t.xpDeltas[id]??0)+Number(msg.xpDeltas?.[id]??0);t.eloDeltas[id]=(t.eloDeltas[id]??0)+Number(msg.eloDeltas?.[id]??0)}
  await this.persist()
  }
  await this.env.DB.prepare("UPDATE tournament_matches SET result=?,winner_id=?,status='completed' WHERE game_id=?").bind(pair.result,winnerId??null,pair.gameId).run()
  for(const p of t.players)await this.env.DB.prepare('UPDATE tournament_participants SET points=?,wins=?,losses=?,draws=? WHERE tournament_id=? AND user_id=?').bind(p.score,p.wins,p.losses,p.draws,t.id,p.id).run()
  this.broadcast('match_result',{gameId:pair.gameId,result:pair.result,standings:this.standings(),xpDeltas:t.xpDeltas,eloDeltas:t.eloDeltas})
  if(t.currentPairings.every(p=>p.result)){
   const remaining=t.totalRounds-t.currentRound,early=t.type==='private'&&Math.abs(t.players[0].score-t.players[1].score)>remaining
   if(early||remaining<=0)await this.end()
   else{t.nextRoundAt??=Date.now()+5000;await this.persist();await this.state.storage.setAlarm(t.nextRoundAt)}
  }
 }
 private async end(){
  const t=this.tournament!;t.status='finished';await this.persist()
  const standings=this.standings(),first=standings[0],tied=standings[1]?.score===first?.score
  const winner=first&&!tied?first:null
  if(!t.bonusesSettled){
   if(winner){const bonus=await StatsService.awardTournamentBonus(this.env.DB,winner.id,200,0,t.id);t.xpDeltas[winner.id]=(t.xpDeltas[winner.id]??0)+bonus}
   t.bonusesSettled=true;await this.persist()
  }
  await this.env.DB.prepare("UPDATE tournaments SET status='completed',current_round=? WHERE id=?").bind(t.currentRound,t.id).run()
  this.broadcast('tournament_end',{standings,winner:winner?{id:winner.id,username:winner.username}:null,xpDeltas:t.xpDeltas,eloDeltas:t.eloDeltas})
 }
 private standings(){return [...this.tournament!.players].sort((a,b)=>b.score-a.score||b.wins-a.wins||a.id.localeCompare(b.id))}
 private publicPairings(){const t=this.tournament!;return t.currentPairings.map(p=>({...p,player1:{id:p.player1Id,username:t.players.find(x=>x.id===p.player1Id)?.username,color:p.whiteId===p.player1Id?'white':'black'},player2:{id:p.player2Id,username:t.players.find(x=>x.id===p.player2Id)?.username,color:p.whiteId===p.player2Id?'white':'black'}}))}
 private publicState(){const t=this.tournament!;return {...t,players:this.standings(),pairings:this.publicPairings()}}
 private async persist(){await this.state.storage.put('tournament',this.tournament)}
 private send(ws:WebSocket,type:string,data:unknown){try{ws.send(JSON.stringify({type,data}))}catch{}}
 private broadcast(type:string,data:unknown){for(const ws of this.state.getWebSockets())this.send(ws,type,data)}
}
/** Backtrack for an opponent-complete round; use repeats only when unavoidable. */
export function pairPlayers(players:Player[]):[Player,Player][] {
 const search=(remaining:Player[],avoid:boolean):[Player,Player][]|null=>{
  if(!remaining.length)return []
  const [a,...rest]=remaining
  for(let i=0;i<rest.length;i++){
   const b=rest[i];if(avoid&&a.opponentIds.includes(b.id))continue
   const tail=search(rest.filter((_,j)=>j!==i),avoid)
   if(tail)return [[a,b],...tail]
  }
  return null
 }
 return search(players,true)??search(players,false)??[]
}
