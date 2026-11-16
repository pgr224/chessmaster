/** Claim a pending challenge and reserve exactly one game in the same transaction. */
export async function acceptChallenge(db:D1Database, challengeId:string, acceptorId:string, gameId:string, whiteId:string, blackId:string) {
 const result=await db.batch([
  db.prepare(`INSERT INTO games(id,white_user_id,black_user_id,mode,time_control)
   SELECT ?,?,?,'multiplayer',time_control FROM challenges WHERE id=? AND challenged_id=? AND status='pending'
   AND variant_id='standard' AND (expires_at IS NULL OR datetime(expires_at)>datetime('now'))`)
   .bind(gameId,whiteId,blackId,challengeId,acceptorId),
  db.prepare(`UPDATE challenges SET status='accepted',game_id=?,updated_at=datetime('now')
   WHERE id=? AND challenged_id=? AND status='pending' AND EXISTS(SELECT 1 FROM games WHERE id=?)`).bind(gameId,challengeId,acceptorId,gameId),
 ])
 return (result[1].meta.changes??0)>0
}
