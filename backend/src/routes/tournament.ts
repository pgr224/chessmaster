import { Hono } from 'hono'
import { authMiddleware } from '../middleware/auth'
import { normalizeTimeControl, isValidTimeControl } from '../time_control'
import { PushService } from '../services/push_service'
import type { Env } from '../index'
const tournamentRoutes=new Hono<{Bindings:Env;Variables:{user:any}}>()
tournamentRoutes.use('*',authMiddleware)
async function visible(db:D1Database,id:string,userId:string){return db.prepare(`SELECT t.* FROM tournaments t WHERE t.id=? AND (t.type='public' OR EXISTS(SELECT 1 FROM tournament_participants p WHERE p.tournament_id=t.id AND p.user_id=?))`).bind(id,userId).first<any>()}
tournamentRoutes.get('/',async c=>{const {results}=await c.env.DB.prepare(`SELECT t.* FROM tournaments t WHERE (t.type='public' OR EXISTS(SELECT 1 FROM tournament_participants p WHERE p.tournament_id=t.id AND p.user_id=?)) AND t.status IN('upcoming','registration','active') ORDER BY t.start_time LIMIT 50`).bind(c.get('user').sub).all();return c.json({tournaments:results})})
tournamentRoutes.get('/:id',async c=>{
 const t=await visible(c.env.DB,c.req.param('id'),c.get('user').sub);if(!t)return c.json({error:'Tournament not found'},404)
 const {results}=await c.env.DB.prepare(`SELECT u.id,u.username,COALESCE(s.elo_rating,0) AS rating,p.* FROM tournament_participants p JOIN users u ON u.id=p.user_id LEFT JOIN user_stats s ON s.user_id=u.id WHERE p.tournament_id=? ORDER BY p.points DESC,u.id`).bind(t.id).all()
 return c.json({tournament:t,participants:results})
})
tournamentRoutes.post('/',async c=>{
 const userId=c.get('user').sub,body=await c.req.json(),type=body.type==='private'?'private':'public',rounds=Number(body.total_rounds??body.totalRounds??3),tc=body.time_control??body.timeControl??'10+0'
 if(!Number.isInteger(rounds)||(type==='private'?![3,5,7].includes(rounds):rounds<1||rounds>15)||!isValidTimeControl(tc))return c.json({error:'Invalid rounds or time control'},400)
 const invited=Array.from(new Set<string>((Array.isArray(body.invited_players)?body.invited_players:[]).filter((x:unknown)=>typeof x==='string'&&x!==userId)))
 if(type==='private'&&invited.length>1)return c.json({error:'A private series has two players'},400)
 const id=crypto.randomUUID(),ids=[userId,...invited]
 for(const player of ids)if(!await c.env.DB.prepare('SELECT id FROM users WHERE id=?').bind(player).first())return c.json({error:'Invited player not found'},400)
 await c.env.DB.batch([
  c.env.DB.prepare(`INSERT INTO tournaments(id,name,description,format,start_time,time_control,created_by,type,total_rounds,max_players,current_players) VALUES(?,?,?,?,?,?,?,?,?,?,?)`).bind(id,String(body.name??'New Tournament').slice(0,80),String(body.description??'').slice(0,500),type==='private'?'round_robin':'swiss',new Date().toISOString(),normalizeTimeControl(tc),userId,type,rounds,type==='private'?2:16,ids.length),
  ...ids.map(player=>c.env.DB.prepare('INSERT INTO tournament_participants(tournament_id,user_id) VALUES(?,?)').bind(id,player))
 ])
 for(const player of invited)c.executionCtx.waitUntil(PushService.notifyUser(player,{title:'🏆 Tournament invitation',body:'You have been invited to a chess series.',data:{type:'TOURNAMENT_INVITE',tournamentId:id,category:'tournaments'}},c.env,'tournaments'))
 return c.json({success:true,id},201)
})
async function join(c:any){
 const id=c.req.param('id'),userId=c.get('user').sub,t=await visible(c.env.DB,id,userId)
 if(!t)return c.json({error:'Tournament not found or invitation required'},404)
 const existing=await c.env.DB.prepare('SELECT user_id FROM tournament_participants WHERE tournament_id=? AND user_id=?').bind(id,userId).first()
 if(existing)return c.json({success:true})
 if(t.type==='private')return c.json({error:'Invitation required'},403)
 if(!['upcoming','registration'].includes(t.status))return c.json({error:'Registration is closed'},409)
 await c.env.DB.batch([
  c.env.DB.prepare(`INSERT OR IGNORE INTO tournament_participants(tournament_id,user_id) SELECT ?,? WHERE (SELECT COUNT(*) FROM tournament_participants WHERE tournament_id=?) < (SELECT max_players FROM tournaments WHERE id=?)`).bind(id,userId,id,id),
  c.env.DB.prepare('UPDATE tournaments SET current_players=(SELECT COUNT(*) FROM tournament_participants WHERE tournament_id=?) WHERE id=?').bind(id,id)
 ])
 if(!await c.env.DB.prepare('SELECT user_id FROM tournament_participants WHERE tournament_id=? AND user_id=?').bind(id,userId).first())return c.json({error:'Tournament is full'},409)
 return c.json({success:true})
}
tournamentRoutes.post('/:id/join',join)
tournamentRoutes.post('/:id/accept-invite',join)
tournamentRoutes.post('/:id/start',async c=>{
 const id=c.req.param('id'),userId=c.get('user').sub,t=await visible(c.env.DB,id,userId)
 if(!t||t.created_by!==userId)return c.json({error:'Creator only'},403)
 const headers=new Headers({'X-Authenticated-User':userId})
 const stub=c.env.TOURNAMENT_ROOM.get(c.env.TOURNAMENT_ROOM.idFromName(id))
 return stub.fetch(new Request(`https://tournament/start?tournamentId=${encodeURIComponent(id)}`,{method:'POST',headers}))
})
tournamentRoutes.post('/:id/result',c=>c.json({error:'Results are submitted only by the authoritative game room'},403))
tournamentRoutes.get('/:id/standings',async c=>{
 const t=await visible(c.env.DB,c.req.param('id'),c.get('user').sub);if(!t)return c.json({error:'Tournament not found'},404)
 const {results}=await c.env.DB.prepare(`SELECT u.id,u.username,COALESCE(s.elo_rating,0) AS rating,p.points,p.wins,p.losses,p.draws,p.status FROM tournament_participants p JOIN users u ON u.id=p.user_id LEFT JOIN user_stats s ON s.user_id=u.id WHERE p.tournament_id=? ORDER BY p.points DESC,p.wins DESC,u.id`).bind(t.id).all();return c.json({standings:results})
})
tournamentRoutes.post('/:id/invite',async c=>{
 const id=c.req.param('id'),userId=c.get('user').sub,t=await visible(c.env.DB,id,userId),body=await c.req.json(),invited=body.invited_user_id
 if(!t||t.created_by!==userId)return c.json({error:'Creator only'},403)
 if(!['upcoming','registration'].includes(t.status))return c.json({error:'Registration closed'},409)
 if(typeof invited!=='string'||invited===userId||!await c.env.DB.prepare('SELECT id FROM users WHERE id=?').bind(invited).first())return c.json({error:'Invalid invited player'},400)
 await c.env.DB.batch([
  c.env.DB.prepare(`INSERT OR IGNORE INTO tournament_participants(tournament_id,user_id) SELECT ?,? WHERE (SELECT COUNT(*) FROM tournament_participants WHERE tournament_id=?) < ?`).bind(id,invited,id,t.type==='private'?2:16),
  c.env.DB.prepare('UPDATE tournaments SET current_players=(SELECT COUNT(*) FROM tournament_participants WHERE tournament_id=?) WHERE id=?').bind(id,id)
 ])
 if(!await c.env.DB.prepare('SELECT user_id FROM tournament_participants WHERE tournament_id=? AND user_id=?').bind(id,invited).first())return c.json({error:'Tournament full'},409)
 c.executionCtx.waitUntil(PushService.notifyUser(invited,{title:'🏆 Tournament invitation',body:'You have been invited to a chess series.',data:{type:'TOURNAMENT_INVITE',tournamentId:id,category:'tournaments'}},c.env,'tournaments'))
 return c.json({success:true})
})
export { tournamentRoutes }
