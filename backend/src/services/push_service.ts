import type { Env } from '../index'
import { SignJWT, importPKCS8 } from 'jose'
import { encryptWebPush,createVapidJwt } from './web_push_crypto'
export type NotificationCategory='challenges'|'games'|'community'|'tournaments'|'system'
export interface NotificationPayload {title:string;body:string;icon?:string;badge?:string;data?:Record<string,unknown>}
export function notificationAllowed(enabled:unknown,preferences:Record<string,unknown>|null,category:NotificationCategory){
 if(enabled!==1&&enabled!==true)return false
 const column={challenges:'challenge_notifications',games:'game_notifications',community:'community_notifications',tournaments:'tournament_notifications',system:'system_notifications'}[category]
 return preferences?.[column]!==0&&preferences?.[column]!==false
}
export class PushService {
 static async notifyUser(userId:string,payload:NotificationPayload,env:Env,explicitCategory?:NotificationCategory){
  const category=explicitCategory??((payload.data?.category as NotificationCategory)||'system')
  const user=await env.DB.prepare('SELECT push_enabled FROM users WHERE id=?').bind(userId).first<{push_enabled:number}>()
  const prefs=await env.DB.prepare('SELECT * FROM user_notification_preferences WHERE user_id=?').bind(userId).first<Record<string,unknown>>()
  if(!user||!notificationAllowed(user.push_enabled,prefs,category))return {sent:0,disabled:true}
  let sent=0
  const data={...payload.data,category},message={...payload,data}
  if(env.VAPID_PUBLIC_KEY&&env.VAPID_PRIVATE_KEY){
   const {results}=await env.DB.prepare('SELECT endpoint,p256dh,auth FROM user_subscriptions WHERE user_id=?').bind(userId).all<{endpoint:string;p256dh:string;auth:string}>()
   for(const sub of results){try{
    const body=await encryptWebPush(JSON.stringify(message),sub.p256dh,sub.auth)
    const token=await createVapidJwt(sub.endpoint,env.VAPID_PUBLIC_KEY,env.VAPID_PRIVATE_KEY,env.VAPID_SUBJECT??'https://chessmaster-app.pages.dev')
    const response=await fetch(sub.endpoint,{method:'POST',headers:{Authorization:`vapid t=${token}, k=${env.VAPID_PUBLIC_KEY}`,'Content-Encoding':'aes128gcm','Content-Type':'application/octet-stream',TTL:'86400',Urgency:'high'},body:body as unknown as BodyInit})
    if(response.ok)sent++;else if([404,410].includes(response.status))await env.DB.prepare('DELETE FROM user_subscriptions WHERE user_id=? AND endpoint=?').bind(userId,sub.endpoint).run()
   }catch(error){console.error('Web push failed',{userId,category,message:error instanceof Error?error.message:'delivery error'})}}
  }
  if(env.FCM_SERVICE_ACCOUNT){
   const {results}=await env.DB.prepare('SELECT token,platform FROM native_push_tokens WHERE user_id=?').bind(userId).all<{token:string;platform:string}>()
   if(results.length){try{
    const account=JSON.parse(env.FCM_SERVICE_ACCOUNT) as {project_id:string;client_email:string;private_key:string}
    const assertion=await new SignJWT({scope:'https://www.googleapis.com/auth/firebase.messaging'}).setProtectedHeader({alg:'RS256'}).setIssuer(account.client_email).setSubject(account.client_email).setAudience('https://oauth2.googleapis.com/token').setIssuedAt().setExpirationTime('1h').sign(await importPKCS8(account.private_key,'RS256'))
    const auth=await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'content-type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion})})
    if(!auth.ok)throw new Error('FCM authentication failed')
    const {access_token}=await auth.json() as {access_token:string}
    const stringData=Object.fromEntries(Object.entries(data).filter(([,v])=>v!=null).map(([k,v])=>[k,String(v)]))
    for(const device of results){
     const response=await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`,{method:'POST',headers:{Authorization:`Bearer ${access_token}`,'Content-Type':'application/json'},body:JSON.stringify({message:{token:device.token,notification:{title:payload.title,body:payload.body},data:stringData,android:{priority:'HIGH',notification:{channel_id:`chess_${category}`,sound:'default'}},apns:{headers:{'apns-priority':'10'},payload:{aps:{sound:'default'}}}}})})
     if(response.ok)sent++;else{const error=await response.json() as any;if(error?.error?.details?.some((x:any)=>x.errorCode==='UNREGISTERED'))await env.DB.prepare('DELETE FROM native_push_tokens WHERE token=?').bind(device.token).run()}
    }
   }catch(error){console.error('Native push failed',{userId,category,message:error instanceof Error?error.message:'delivery error'})}}
  }
  return {sent,disabled:false}
 }
}
