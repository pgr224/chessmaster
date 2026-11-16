import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { testDB } from '../test_support/sqlite'
import { StatsService,resultXP } from './stats_service'
function db(){const db=testDB(readFileSync(new URL('../../schema/d1-schema.sql',import.meta.url),'utf8'));return db}
async function user(db:D1Database,id:string,xp:number){await db.prepare('INSERT INTO users(id,username,device_id,xp) VALUES(?,?,?,?)').bind(id,id,id,xp).run()}
test('result settlement is idempotent for each participant, including zero XP',async()=>{const d=db();await user(d,'a',0);await user(d,'b',10);await d.prepare("INSERT INTO games(id,mode) VALUES('g','multiplayer')").run();assert.equal(await StatsService.updateAll(d,{userId:'a',gameId:'g',mode:'multiplayer',outcome:'win'}),100);assert.equal(await StatsService.updateAll(d,{userId:'b',gameId:'g',mode:'multiplayer',outcome:'loss'}),-10);await StatsService.updateAll(d,{userId:'a',gameId:'g',mode:'multiplayer',outcome:'win'});const a=await d.prepare('SELECT xp FROM users WHERE id=\'a\'').first<{xp:number}>();assert.equal(a?.xp,100);assert.equal((await d.prepare('SELECT games_played FROM user_stats WHERE user_id=\'a\'').first<any>()).games_played,1);assert.equal((await d.prepare('SELECT xp FROM users WHERE id=\'b\'').first<any>()).xp,0)})
test('progress retries do not reapply penalties or add absolute puzzle ratings',async()=>{const d=db();await user(d,'a',5);assert.equal(await StatsService.applyProgress(d,{userId:'a',eventId:'hint:one',xpDelta:-10,stats:{puzzle_rating:1250}}),-5);assert.equal(await StatsService.applyProgress(d,{userId:'a',eventId:'hint:one',xpDelta:-10}),-5);const stats=await d.prepare('SELECT * FROM user_stats WHERE user_id=\'a\'').first<any>();assert.equal(stats.puzzle_rating,1250);assert.equal((await d.prepare('SELECT xp FROM users WHERE id=\'a\'').first<any>()).xp,0)})
test('tournament bonus is paid once with no second Elo award',async()=>{const d=db();await user(d,'a',100);assert.equal(await StatsService.awardTournamentBonus(d,'a',200,0,'t'),200);await StatsService.awardTournamentBonus(d,'a',200,0,'t');assert.equal((await d.prepare('SELECT xp FROM users WHERE id=\'a\'').first<any>()).xp,300);assert.equal((await d.prepare('SELECT tournaments_won FROM user_stats WHERE user_id=\'a\'').first<any>()).tournaments_won,1)})
test('XP aliases, tournament streaks and no-XP practice/local modes match rules',()=>{assert.equal(resultXP({userId:'u',mode:'singlePlayer',outcome:'win',aiDifficulty:'basic'}),100);assert.equal(resultXP({userId:'u',mode:'singlePlayer',outcome:'win',aiDifficulty:'advanced'}),400);assert.equal(resultXP({userId:'u',mode:'tournament',outcome:'draw'},2),42);assert.equal(resultXP({userId:'u',mode:'tournament',outcome:'loss',penalty:-25},10),-45);assert.equal(resultXP({userId:'u',mode:'practice',outcome:'win'}),0);assert.equal(resultXP({userId:'u',mode:'twoPlayer',outcome:'draw'}),0)})

test('multiplayer Elo uses pre-game expected scores and K factors',async()=>{
 const {multiplayerElo}=await import('./stats_service')
 assert.equal(multiplayerElo(1200,1200,0,'win'),20)
 assert.equal(multiplayerElo(1200,1200,30,'win'),10)
 assert.equal(multiplayerElo(2400,2400,30,'win'),5)
 assert.equal(multiplayerElo(1200,1200,0,'draw'),0)
 assert.equal(multiplayerElo(0,0,0,'loss'),0)
 assert.equal(multiplayerElo(1200,1600,30,'win'),18)
 const d=db();await user(d,'a',0);await user(d,'b',100)
 for(const id of ['a','b'])await d.prepare('INSERT INTO user_stats(user_id,elo_rating,multiplayer_games) VALUES(?,1200,30)').bind(id).run()
 await d.prepare("INSERT INTO games(id,white_user_id,black_user_id,mode) VALUES('rating-game','a','b','multiplayer')").run()
 await StatsService.updateAll(d,{userId:'a',gameId:'rating-game',mode:'multiplayer',outcome:'win'})
 await StatsService.updateAll(d,{userId:'b',gameId:'rating-game',mode:'multiplayer',outcome:'loss'})
 assert.equal((await d.prepare("SELECT elo_rating FROM user_stats WHERE user_id='a'").first<any>()).elo_rating,1210)
 assert.equal((await d.prepare("SELECT elo_rating FROM user_stats WHERE user_id='b'").first<any>()).elo_rating,1190)
})

test('underdog bonus tiers, zero floor and stored game receipts survive retry',async()=>{
 for(const [diff,bonus] of [[199,0],[200,200],[499,200],[500,500],[1000,500],[1001,1000]]){
  const d=db();await user(d,'a',0);await user(d,'b',100)
  await d.prepare("INSERT INTO user_stats(user_id,elo_rating) VALUES('a',1200),('b',?)").bind(1200+diff).run()
  await d.prepare("INSERT INTO games(id,white_user_id,black_user_id,mode) VALUES('tiers','a','b','multiplayer')").run()
  assert.equal(await StatsService.updateAll(d,{userId:'a',gameId:'tiers',mode:'multiplayer',outcome:'win'}),100+bonus)
  await d.prepare("UPDATE user_stats SET elo_rating=3500 WHERE user_id='a'").run()
  assert.equal(await StatsService.updateAll(d,{userId:'a',gameId:'tiers',mode:'multiplayer',outcome:'win'}),100+bonus)
 }
})

test('profile view exposes streak and all mode counters without changing XP',async()=>{
 const d=db();await user(d,'a',10000)
 await d.prepare("INSERT INTO user_stats(user_id,current_streak,ai_games,ai_wins,multiplayer_games,multiplayer_wins,tournament_games,tournament_wins,two_player_games,two_player_wins) VALUES('a',3,7,6,4,2,3,1,2,1)").run()
 const row=await d.prepare("SELECT * FROM unified_player_scoring WHERE id='a'").first<any>()
 assert.equal(row.xp,10000);assert.equal(row.current_streak,3)
 assert.equal(row.ai_games,7);assert.equal(row.ai_wins,6);assert.equal(row.multiplayer_games,4);assert.equal(row.tournament_games,3);assert.equal(row.two_player_games,2)
})

test('achievement IDs and point values match every displayed client badge',async()=>{
 const d=db(),source=readFileSync(new URL('../../../app/lib/data/models/achievement_model.dart',import.meta.url),'utf8')
 const matches=[...source.matchAll(/const Achievement\(\s*id: '([^']+)'[\s\S]*?points: (\d+)/g)]
 assert.ok(matches.length>=55)
 for(const [,id,points] of matches)assert.equal((await d.prepare('SELECT points FROM achievements WHERE id=?').bind(id).first<any>())?.points,Number(points),id)
})

test('bounty stays fixed for four hours and bonus does not multiply takeback penalties',async()=>{
 const {currentBounty}=await import('./bounty')
 const d=db();await user(d,'a',0);await user(d,'b',100)
 await d.prepare("INSERT INTO user_stats(user_id,games_played,elo_rating) VALUES('a',1,1200),('b',1,1200)").run()
 const first=await currentBounty(d)
 const winner=first.target!.id==='a'?'b':'a',target=first.target!.id
 await d.prepare('UPDATE user_stats SET elo_rating=3000 WHERE user_id=?').bind(winner).run()
 assert.equal((await currentBounty(d)).target!.id,target)
 await d.prepare("INSERT INTO games(id,white_user_id,black_user_id,mode) VALUES('bounty',?,?,'multiplayer')").bind(winner,target).run()
 assert.equal(await StatsService.updateAll(d,{userId:winner,gameId:'bounty',mode:'multiplayer',outcome:'win',penalty:-25}),125)
 assert.equal((await d.prepare('SELECT COUNT(*) AS n FROM bounty_awards WHERE user_id=?').bind(winner).first<any>()).n,1)
})
