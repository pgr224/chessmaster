export const TRANSFER_SCHEMA=`CREATE TABLE IF NOT EXISTS xp_transfer_events (
 donor_id TEXT NOT NULL, event_id TEXT NOT NULL, claim_id TEXT NOT NULL,recipient_id TEXT NOT NULL,amount INTEGER NOT NULL,
 donor_before INTEGER NOT NULL,recipient_before INTEGER NOT NULL,PRIMARY KEY(donor_id,event_id))`
/** All-or-nothing debit/credit with limits evaluated inside the same D1 batch. */
export async function transferXP(db:D1Database,donorId:string,recipientId:string,amount:number,eventId:string,requestId:number|null=null){
 if(donorId===recipientId||!Number.isSafeInteger(amount)||amount<=0||amount>2000||!eventId||eventId.length>200)throw new Error('Invalid transfer')
 await db.prepare(TRANSFER_SCHEMA).run();const claim=crypto.randomUUID()
 const exists='EXISTS(SELECT 1 FROM xp_transfer_events WHERE donor_id=? AND event_id=? AND claim_id=?)'
 const statements=[
  db.prepare(`INSERT OR IGNORE INTO xp_transfer_events(donor_id,event_id,claim_id,recipient_id,amount,donor_before,recipient_before)
   SELECT d.id,?,?,r.id,?,d.xp,r.xp FROM users d JOIN users r ON r.id=? WHERE d.id=? AND d.xp>=?
   AND COALESCE((SELECT SUM(amount) FROM xp_transfers WHERE donor_id=d.id),0)+?<=10000
   AND COALESCE((SELECT SUM(amount) FROM xp_transfers WHERE donor_id=d.id AND date(created_at)=date('now')),0)+?<=2000
   AND (? IS NULL OR EXISTS(SELECT 1 FROM xp_requests_v2 WHERE id=? AND requester_id=r.id AND status='open' AND datetime(expires_at)>datetime('now')))`)
    .bind(eventId,claim,amount,recipientId,donorId,amount,amount,amount,requestId,requestId),
  db.prepare(`UPDATE users SET xp=xp-? WHERE id=? AND ${exists}`).bind(amount,donorId,donorId,eventId,claim),
  db.prepare(`UPDATE users SET xp=xp+? WHERE id=? AND ${exists}`).bind(amount,recipientId,donorId,eventId,claim),
  db.prepare(`INSERT INTO xp_transfers(donor_id,recipient_id,amount) SELECT donor_id,recipient_id,amount FROM xp_transfer_events WHERE donor_id=? AND event_id=? AND claim_id=?`).bind(donorId,eventId,claim),
  db.prepare(`INSERT INTO xp_history(user_id,xp_before,xp_after,change) SELECT donor_id,donor_before,donor_before-amount,-amount FROM xp_transfer_events WHERE donor_id=? AND event_id=? AND claim_id=?`).bind(donorId,eventId,claim),
  db.prepare(`INSERT INTO xp_history(user_id,xp_before,xp_after,change) SELECT recipient_id,recipient_before,recipient_before+amount,amount FROM xp_transfer_events WHERE donor_id=? AND event_id=? AND claim_id=?`).bind(donorId,eventId,claim),
 ]
 if(requestId!==null)statements.push(db.prepare(`UPDATE xp_requests_v2 SET status='fulfilled',fulfilled_by=?,fulfilled_at=datetime('now'),updated_at=datetime('now') WHERE id=? AND ${exists}`).bind(donorId,requestId,donorId,eventId,claim))
 const hasXP=(await db.prepare('PRAGMA table_info(user_stats)').all<{name:string}>()).results.some(x=>x.name==='xp')
 if(hasXP)statements.push(db.prepare(`UPDATE user_stats SET xp=(SELECT xp FROM users WHERE id=user_id) WHERE user_id IN(?,?) AND ${exists}`).bind(donorId,recipientId,donorId,eventId,claim))
 await db.batch(statements)
 const receipt=await db.prepare('SELECT amount,recipient_id FROM xp_transfer_events WHERE donor_id=? AND event_id=?').bind(donorId,eventId).first<{amount:number;recipient_id:string}>()
 if(!receipt)throw new Error('Insufficient XP, transfer limit exceeded, or request unavailable')
 if(receipt.amount!==amount||receipt.recipient_id!==recipientId)throw new Error('Transfer ID already used')
 return receipt
}
