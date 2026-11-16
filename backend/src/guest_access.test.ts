import test from 'node:test'
import assert from 'node:assert/strict'
import {Hono} from 'hono'
import {sign} from 'hono/jwt'
import {authMiddleware} from './middleware/auth'
import {isGuestIdentity} from './auth_utils'
import {testDB} from './test_support/sqlite'
import {readFileSync} from 'node:fs'
import {currentBounty} from './services/bounty'

test('guest identities cannot use authenticated online HTTP APIs',async()=>{
 const app=new Hono<any>();app.use('*',authMiddleware);app.get('/online',c=>c.json({ok:true}))
 const key='local-test-key-for-guest-access'
 for(const payload of [{sub:'guest_temporary'},{sub:'other',isGuest:true},{sub:'other',is_guest:true},{sub:'other',role:'guest'}]){
  const token=await sign({...payload,exp:Math.floor(Date.now()/1000)+60},key,'HS256')
  assert.equal((await app.request('/online',{headers:{Authorization:`Bearer ${token}`}},{JWT_SECRET:key})).status,403)
 }
 const token=await sign({sub:'registered',exp:Math.floor(Date.now()/1000)+60},key,'HS256')
 assert.equal((await app.request('/online',{headers:{Authorization:`Bearer ${token}`}},{JWT_SECRET:key})).status,200)
 assert.equal(isGuestIdentity('registered',{username:'Guest_ChosenName'}),false)
})

test('historical guest IDs never appear in the profile ranking view or bounty pool',async()=>{
 const db=testDB(readFileSync(new URL('../schema/d1-schema.sql',import.meta.url),'utf8'))
 for(const id of ['guest_old','registered']){
  await db.prepare('INSERT INTO users(id,username,device_id,xp) VALUES(?,?,?,1000)').bind(id,id,id).run()
  await db.prepare('INSERT INTO user_stats(user_id,games_played,elo_rating) VALUES(?,20,2000)').bind(id).run()
 }
 assert.equal(await db.prepare("SELECT id FROM unified_player_scoring WHERE id='guest_old'").first(),null)
 assert.equal((await db.prepare("SELECT rank FROM unified_player_scoring WHERE id='registered'").first<any>()).rank,1)
 assert.equal((await currentBounty(db)).target?.id,'registered')
})
