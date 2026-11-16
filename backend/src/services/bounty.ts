export async function currentBounty(db:D1Database,now=Date.now()) {
 await db.prepare(`CREATE TABLE IF NOT EXISTS bounty_windows (window_id INTEGER PRIMARY KEY,target_id TEXT NOT NULL REFERENCES users(id))`).run()
 const window=Math.floor(now/14_400_000)
 const saved=await db.prepare(`SELECT u.id,u.username FROM bounty_windows b JOIN users u ON u.id=b.target_id WHERE u.id NOT GLOB 'guest_*' AND window_id=?`).bind(window).first<{id:string;username:string}>()
 if(saved)return {target:saved,expiresAt:new Date((window+1)*14_400_000).toISOString()}
 const {results}=await db.prepare(`SELECT u.id,u.username FROM users u JOIN user_stats s ON s.user_id=u.id WHERE u.id NOT GLOB 'guest_*' AND s.games_played>0 ORDER BY s.elo_rating DESC,u.id LIMIT 20`).all<{id:string;username:string}>()
 if(results.length)await db.prepare(`INSERT INTO bounty_windows(window_id,target_id) VALUES(?,?) ON CONFLICT(window_id) DO UPDATE SET target_id=excluded.target_id WHERE target_id GLOB 'guest_*'`).bind(window,results[window%results.length].id).run()
 const target=results.length?await db.prepare(`SELECT u.id,u.username FROM bounty_windows b JOIN users u ON u.id=b.target_id WHERE u.id NOT GLOB 'guest_*' AND window_id=?`).bind(window).first<{id:string;username:string}>():null
 return {target,expiresAt:new Date((window+1)*14_400_000).toISOString()}
}
