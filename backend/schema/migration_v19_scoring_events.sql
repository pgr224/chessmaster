-- Idempotent scoring ledger. No historical stats or XP are reset.
CREATE TABLE IF NOT EXISTS scoring_events (
 user_id TEXT NOT NULL REFERENCES users(id), event_id TEXT NOT NULL, claim_id TEXT NOT NULL,
 xp_before INTEGER NOT NULL, xp_after INTEGER NOT NULL, xp_delta INTEGER NOT NULL, elo_before INTEGER NOT NULL DEFAULT 0, elo_after INTEGER NOT NULL DEFAULT 0, elo_delta INTEGER NOT NULL DEFAULT 0,
 created_at TEXT NOT NULL DEFAULT (datetime('now')), PRIMARY KEY(user_id,event_id)
);
CREATE TABLE IF NOT EXISTS game_scoring_context (game_id TEXT PRIMARY KEY, context TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS xp_transfer_events (
 donor_id TEXT NOT NULL, event_id TEXT NOT NULL, claim_id TEXT NOT NULL,recipient_id TEXT NOT NULL,amount INTEGER NOT NULL,
 donor_before INTEGER NOT NULL,recipient_before INTEGER NOT NULL,PRIMARY KEY(donor_id,event_id));
CREATE TABLE IF NOT EXISTS bounty_windows (window_id INTEGER PRIMARY KEY,target_id TEXT NOT NULL REFERENCES users(id));
CREATE TABLE IF NOT EXISTS bounty_awards(user_id TEXT NOT NULL,game_id TEXT NOT NULL,expires_at TEXT NOT NULL,PRIMARY KEY(user_id,game_id));
