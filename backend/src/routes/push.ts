import { Hono } from 'hono'
import { authMiddleware } from '../middleware/auth'
import type { Env } from '../index'
const keys={challenges:'challenge_notifications',games:'game_notifications',community:'community_notifications',tournaments:'tournament_notifications',system:'system_notifications'} as const
export const pushRoutes=new Hono<{Bindings:Env;Variables:{user:any}}>()
pushRoutes.get('/vapid-public-key',c=>c.env.VAPID_PUBLIC_KEY?c.json({publicKey:c.env.VAPID_PUBLIC_KEY}):c.json({error:'Web push is not configured'},503))
pushRoutes.use('*',authMiddleware)
pushRoutes.get('/status',c=>c.json({webConfigured:!!(c.env.VAPID_PRIVATE_KEY&&c.env.VAPID_PUBLIC_KEY),nativeConfigured:!!c.env.FCM_SERVICE_ACCOUNT}))
pushRoutes.post('/subscribe',async c=>{
 const userId=c.get('user').sub,body=await c.req.json(),sub=body.subscription
 if(!sub||typeof sub.endpoint!=='string'||!sub.endpoint.startsWith('https://')||typeof sub.keys?.p256dh!=='string'||typeof sub.keys?.auth!=='string')return c.json({error:'Valid HTTPS subscription and keys required'},400)
 // A browser subscription belongs to its current account, never a prior login.
 await c.env.DB.batch([
  c.env.DB.prepare('DELETE FROM user_subscriptions WHERE endpoint=? AND user_id<>?').bind(sub.endpoint,userId),
  c.env.DB.prepare('DELETE FROM user_subscriptions WHERE endpoint=? AND user_id=?').bind(sub.endpoint,userId),
  c.env.DB.prepare('INSERT INTO user_subscriptions(id,user_id,endpoint,p256dh,auth,device_id) VALUES(?,?,?,?,?,?)').bind(crypto.randomUUID(),userId,sub.endpoint,sub.keys.p256dh,sub.keys.auth,body.deviceId??null)
 ])
 return c.json({status:'subscribed'},201)
})
pushRoutes.post('/unsubscribe',async c=>{const body=await c.req.json();await c.env.DB.prepare('DELETE FROM user_subscriptions WHERE user_id=? AND endpoint=?').bind(c.get('user').sub,body.endpoint??'').run();return c.json({status:'unsubscribed'})})
pushRoutes.post('/native-token',async c=>{
 const body=await c.req.json(),userId=c.get('user').sub
 if(typeof body.token!=='string'||body.token.length<20||body.token.length>4096||!['android','ios'].includes(body.platform))return c.json({error:'Valid device token and platform required'},400)
 await c.env.DB.prepare(`INSERT INTO native_push_tokens(token,user_id,platform,device_id) VALUES(?,?,?,?) ON CONFLICT(token) DO UPDATE SET user_id=excluded.user_id,platform=excluded.platform,device_id=excluded.device_id,updated_at=datetime('now')`).bind(body.token,userId,body.platform,body.deviceId??null).run()
 return c.json({success:true,nativeConfigured:!!c.env.FCM_SERVICE_ACCOUNT})
})
pushRoutes.delete('/native-token',async c=>{const body=await c.req.json();await c.env.DB.prepare('DELETE FROM native_push_tokens WHERE token=? AND user_id=?').bind(body.token??'',c.get('user').sub).run();return c.json({success:true})})
pushRoutes.get('/settings',async c=>{
 const userId=c.get('user').sub,user=await c.env.DB.prepare('SELECT push_enabled FROM users WHERE id=?').bind(userId).first<{push_enabled:number}>()
 if(!user)return c.json({error:'User not found'},404)
 const row=await c.env.DB.prepare('SELECT * FROM user_notification_preferences WHERE user_id=?').bind(userId).first<Record<string,number>>()
 return c.json({enabled:user.push_enabled===1,categories:Object.fromEntries(Object.entries(keys).map(([key,column])=>[key,row?.[column]!==0]))})
})
pushRoutes.put('/settings',async c=>{
 const userId=c.get('user').sub,body=await c.req.json()
 if(body.enabled!==undefined&&typeof body.enabled!=='boolean')return c.json({error:'enabled must be boolean'},400)
 for(const [key,value]of Object.entries(body.categories??{}))if(!(key in keys)||typeof value!=='boolean')return c.json({error:'Invalid notification category'},400)
 const columns=Object.entries(keys),existing=await c.env.DB.prepare('SELECT * FROM user_notification_preferences WHERE user_id=?').bind(userId).first<Record<string,number>>()
 const resolved=columns.map(([key,column])=>body.categories?.[key]===undefined?existing?.[column]??1:body.categories[key]?1:0)
 const statements=[c.env.DB.prepare(`INSERT INTO user_notification_preferences(user_id,${columns.map(([,column])=>column).join(',')}) VALUES(?,?,?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET ${columns.map(([,column])=>`${column}=excluded.${column}`).join(',')},updated_at=datetime('now')`).bind(userId,...resolved)]
 if(body.enabled!==undefined)statements.push(c.env.DB.prepare('UPDATE users SET push_enabled=? WHERE id=?').bind(body.enabled?1:0,userId))
 await c.env.DB.batch(statements)
 return c.json({success:true,enabled:body.enabled,categories:Object.fromEntries(columns.map(([key],i)=>[key,resolved[i]===1]))})
})
