import assert from 'node:assert/strict'
import { after, before, test } from 'node:test'
import { readFile, mkdtemp, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { build } from 'esbuild'
import { Miniflare, type WebSocket as LocalWebSocket } from 'miniflare'
import { sign } from 'hono/jwt'

const secret='local-integration-secret-at-least-32-characters'
let mf:Miniflare,db:D1Database,output:string
const tokens=new Map<string,string>()
type Message={type:string;data:any}
class Socket {
  readonly messages:Message[]=[]
  constructor(readonly ws:LocalWebSocket){
    ws.addEventListener('message',event=>this.messages.push(JSON.parse(String(event.data))))
    ws.accept()
  }
  send(type:string,body:Record<string,unknown>={}){this.ws.send(JSON.stringify({type,...body}))}
  async wait(type:string,after=0,predicate:(data:any)=>boolean=()=>true,timeout=10000):Promise<any>{
    const deadline=Date.now()+timeout
    while(Date.now()<deadline){
      const found=this.messages.slice(after).find(message=>message.type===type&&predicate(message.data))
      if(found)return found.data
      await new Promise(resolve=>setTimeout(resolve,20))
    }
    throw new Error(`Missing ${type}; received ${JSON.stringify(this.messages.slice(after))}`)
  }
}
async function request(path:string,userId:string,body?:unknown){
  return mf.dispatchFetch(`http://chess.local${path}`,{method:body===undefined?'GET':'POST',headers:{Authorization:`Bearer ${tokens.get(userId)}`,'Content-Type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)})})
}
async function socket(path:string,userId:string){
  const response=await mf.dispatchFetch(`http://chess.local${path}?token=${tokens.get(userId)}`,{headers:{Upgrade:'websocket'}})
  assert.equal(response.status,101,await response.text())
  assert.ok(response.webSocket)
  return new Socket(response.webSocket)
}
async function tournament(type:'public'|'private',creator:string,invited:string[]=[],rounds=3){
  const response=await request('/api/tournament',creator,{name:'Integration tournament',type,total_rounds:rounds,time_control:'3+2',invited_players:invited})
  assert.equal(response.status,201,await response.clone().text())
  return (await response.json() as {id:string}).id
}
async function finishByResignation(gameId:string,whiteId:string,blackId:string,loserId:string){
  const white=await socket(`/multiplayer/game/${gameId}`,whiteId)
  const black=await socket(`/multiplayer/game/${gameId}`,blackId)
  await white.wait('ROOM_STATE',0,state=>state.status==='active')
  const losing=loserId===whiteId?white:black
  losing.send('RESIGN')
  const result=await white.wait('GAME_OVER')
  await black.wait('GAME_OVER')
  return {white,black,result}
}

before(async()=>{
  output=await mkdtemp(join(tmpdir(),'chess-room-integration-'))
  await build({entryPoints:[resolve('src/index.ts')],bundle:true,format:'esm',platform:'browser',target:'es2022',outfile:join(output,'worker.mjs')})
  mf=new Miniflare({rootPath:output,modulesRoot:output,modules:[{type:'ESModule',path:join(output,'worker.mjs')}],compatibilityDate:'2025-07-18',d1Databases:['DB'],kvNamespaces:['CHESS_KV'],durableObjects:{GAME_ROOM:'GameRoom',TOURNAMENT_ROOM:'TournamentRoom',LOBBY:'Lobby'},bindings:{JWT_SECRET:secret,ENVIRONMENT:'test'},log:undefined})
  db=await mf.getD1Database('DB') as unknown as D1Database
  const schema=(await readFile(resolve('schema/d1-schema.sql'),'utf8')).replace(/--[^\n]*/g,'')
  for(const statement of schema.split(';').map(s=>s.trim()).filter(Boolean))await db.prepare(statement).run()
  for(const id of ['alice','bob','carol','dave','erin','outsider']){
    await db.prepare('INSERT INTO users(id,username,device_id,xp,push_enabled) VALUES(?,?,?,?,0)').bind(id,id,`device-${id}`,1000).run()
    await db.prepare('INSERT INTO user_stats(user_id,elo_rating) VALUES(?,1200)').bind(id).run()
    tokens.set(id,await sign({sub:id,username:id,exp:Math.floor(Date.now()/1000)+3600},secret,'HS256'))
  }
}, {timeout:30000})
after(async()=>{try{await mf?.dispose()}finally{if(output)await rm(output,{recursive:true,force:true})}})

test('private series initializes reserved games, alternates colors, settles each round and champion once',{timeout:20000},async()=>{
  const id=await tournament('private','alice',['bob'])
  const outsider=await mf.dispatchFetch(`http://chess.local/multiplayer/tournament/${id}?token=${tokens.get('outsider')}`,{headers:{Upgrade:'websocket'}})
  assert.equal(outsider.status,403)
  const alice=await socket(`/multiplayer/tournament/${id}`,'alice'),bob=await socket(`/multiplayer/tournament/${id}`,'bob')
  const initial=await alice.wait('tournament_state')
  assert.equal(initial.players.length,2)
  alice.send('READY');bob.send('READY')
  const first=await alice.wait('round_start')
  assert.equal(first.round,1);assert.equal(first.pairings.length,1)
  const pair1=first.pairings[0]
  assert.equal((await db.prepare('SELECT mode FROM games WHERE id=?').bind(pair1.gameId).first<any>())?.mode,'tournament')
  const forbidden=await mf.dispatchFetch(`http://chess.local/multiplayer/game/${pair1.gameId}?token=${tokens.get('outsider')}`,{headers:{Upgrade:'websocket'}})
  assert.equal(forbidden.status,403)
  alice.send('MATCH_RESULT',{gameId:pair1.gameId,result:'player1'})
  assert.match((await alice.wait('error')).message,/verified/)
  const firstGame=await finishByResignation(pair1.gameId,pair1.whiteId,pair1.blackId,'bob')
  assert.equal(firstGame.result.mode,'tournament')
  assert.equal(firstGame.result.xpDelta,100)
  const firstResult=await alice.wait('match_result')
  assert.equal(firstResult.standings.find((p:any)=>p.id==='alice').score,1)
  const second=await alice.wait('round_start',0,data=>data.round===2)
  const pair2=second.pairings[0]
  assert.notEqual(pair1.whiteId,pair2.whiteId)
  await finishByResignation(pair2.gameId,pair2.whiteId,pair2.blackId,'bob')
  const ended=await alice.wait('tournament_end')
  assert.equal(ended.winner.id,'alice')
  assert.equal(ended.xpDeltas.alice,420)
  assert.equal(ended.eloDeltas.alice,40)
  assert.equal(ended.xpDeltas.bob,-40)
  assert.equal((await db.prepare('SELECT xp FROM users WHERE id=?').bind('alice').first<any>())?.xp,1420)
  assert.equal((await db.prepare('SELECT tournaments_won FROM user_stats WHERE user_id=?').bind('alice').first<any>())?.tournaments_won,1)
  assert.equal((await db.prepare('SELECT COUNT(*) n FROM tournament_matches WHERE tournament_id=?').bind(id).first<any>())?.n,2)
  const rooms=await mf.getDurableObjectNamespace('TOURNAMENT_ROOM'),stub=rooms.get(rooms.idFromName(id))
  await stub.fetch('https://tournament/match-result',{method:'POST',body:JSON.stringify({gameId:pair2.gameId,xpDeltas:{alice:99999}})})
  const replay=await socket(`/multiplayer/tournament/${id}`,'alice')
  const replayState=await replay.wait('tournament_state')
  assert.equal(replayState.xpDeltas.alice,420)
  assert.equal((await db.prepare('SELECT xp FROM users WHERE id=?').bind('alice').first<any>())?.xp,1420)
})

test('public odd-player round gives a single bye and never fabricates a champion on a tie',{timeout:10000},async()=>{
  const id=await tournament('public','carol',[],1)
  for(const user of ['dave','erin'])assert.equal((await request(`/api/tournament/${id}/join`,user,{})).status,200)
  const sockets=await Promise.all(['carol','dave','erin'].map(user=>socket(`/multiplayer/tournament/${id}`,user)))
  for(const entry of sockets)entry.send('READY')
  const round=await sockets[0].wait('round_start')
  assert.equal(round.pairings.length,1)
  const pair=round.pairings[0]
  const bye=['carol','dave','erin'].find(id=>id!==pair.whiteId&&id!==pair.blackId)!
  const winner=pair.whiteId,loser=pair.blackId
  await finishByResignation(pair.gameId,pair.whiteId,pair.blackId,loser)
  const ended=await sockets[0].wait('tournament_end')
  assert.equal(ended.standings.find((p:any)=>p.id===bye).score,1)
  assert.equal(ended.standings.find((p:any)=>p.id===winner).score,1)
  assert.equal(ended.winner,null)
  assert.equal((await db.prepare("SELECT COUNT(*) n FROM scoring_events WHERE event_id=?").bind(`tournament:${id}:champion`).first<any>())?.n,0)
})

test('multiplayer takeback settles once and rematch requests/results survive reconnects',{timeout:10000},async()=>{
  const id=crypto.randomUUID(),whiteId='outsider',blackId='dave'
  await db.prepare("INSERT INTO games(id,white_user_id,black_user_id,mode,time_control) VALUES(?,?,?,'multiplayer','3+2')").bind(id,whiteId,blackId).run()
  const white=await socket(`/multiplayer/game/${id}`,whiteId)
  const black=await socket(`/multiplayer/game/${id}`,blackId)
  await white.wait('ROOM_STATE',0,state=>state.status==='active')
  white.send('REMATCH_REQUEST')
  assert.match((await white.wait('MOVE_ERROR')).message,/after the match ends/)
  white.send('MOVE',{move:{from:'e2',to:'e4'}})
  await black.wait('MOVE_UPDATE',0,state=>state.moves.length===1)
  white.send('UNDO')
  const undo=await black.wait('MOVE_UPDATE',0,state=>state.undo===true)
  assert.equal(undo.moves.length,0)
  assert.equal(undo.penalties[whiteId],-25)
  const before=await db.prepare('SELECT xp FROM users WHERE id=?').bind(whiteId).first<any>()
  white.send('RESIGN')
  const over=await white.wait('GAME_OVER')
  await black.wait('GAME_OVER')
  assert.equal(over.xpDelta,-45)
  assert.equal((await db.prepare('SELECT xp FROM users WHERE id=?').bind(whiteId).first<any>())?.xp,before.xp-45)
  white.send('REMATCH_REQUEST')
  assert.equal((await black.wait('REMATCH_REQUEST')).from,whiteId)
  const reconnectedBlack=await socket(`/multiplayer/game/${id}`,blackId)
  assert.equal((await reconnectedBlack.wait('REMATCH_REQUEST')).from,whiteId)
  reconnectedBlack.send('REMATCH_ACCEPT')
  const ready=await reconnectedBlack.wait('REMATCH_READY')
  assert.equal(ready.color,'white')
  assert.equal((await white.wait('REMATCH_READY')).color,'black')
  const start=reconnectedBlack.messages.length
  reconnectedBlack.send('REMATCH_ACCEPT')
  assert.equal((await reconnectedBlack.wait('REMATCH_READY',start)).gameId,ready.gameId)
  const reconnectedWhite=await socket(`/multiplayer/game/${id}`,whiteId)
  assert.equal((await reconnectedWhite.wait('REMATCH_READY')).gameId,ready.gameId)
  const rematch=await db.prepare('SELECT white_user_id,black_user_id FROM games WHERE id=?').bind(ready.gameId).first<any>()
  assert.equal(rematch.white_user_id,blackId)
  assert.equal(rematch.black_user_id,whiteId)
  assert.equal((await db.prepare('SELECT COUNT(*) n FROM scoring_events WHERE event_id=?').bind(`game:${id}:result`).first<any>())?.n,2)
  assert.equal((await db.prepare('SELECT COUNT(*) n FROM xp_history WHERE game_id=?').bind(id).first<any>())?.n,2)
})
