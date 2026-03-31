-- Migration v8: Final synchronization with Flutter models
-- Add ELO rating, Ghibli mode, and other missing stats to ensure data persistence.
-- Run with: npx wrangler d1 execute chessmaster-real4 --remote --file=./schema/migration_v8_elo_and_sync.sql

-- 1. Users Table enhancements
-- Note: SQLite allows adding multiple columns in separate ALTER TABLE statements
ALTER TABLE users ADD COLUMN is_ghibli INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN local_avatar TEXT;

-- 2. User Stats Table enhancements
ALTER TABLE user_stats ADD COLUMN elo_rating INTEGER NOT NULL DEFAULT 1200;
ALTER TABLE user_stats ADD COLUMN puzzles_solved INTEGER NOT NULL DEFAULT 0;
ALTER TABLE user_stats ADD COLUMN puzzle_rating INTEGER NOT NULL DEFAULT 1200;
ALTER TABLE user_stats ADD COLUMN two_player_games INTEGER NOT NULL DEFAULT 0;
ALTER TABLE user_stats ADD COLUMN two_player_wins INTEGER NOT NULL DEFAULT 0;

-- 3. Game Table enhancement (already in v6, but ensuring consistency for main schema later)
-- Note: CHECK constraints cannot be updated easily, but v6 already handled this.

-- 4. Create xp_transfers and xp_requests if they didn't exist
CREATE TABLE IF NOT EXISTS xp_transfers (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  donor_id    TEXT NOT NULL REFERENCES users(id),
  recipient_id TEXT NOT NULL REFERENCES users(id),
  amount      INTEGER NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS xp_requests (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  requester_id TEXT NOT NULL REFERENCES users(id),
  amount      INTEGER NOT NULL,
  status      TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open', 'fulfilled', 'cancelled')),
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 5. Finalize XP-related achievements if missing
INSERT OR IGNORE INTO achievements (id, name, description, icon, category, points, criteria) VALUES
  ('generous_donor', 'Kind Soul', 'Donate 500 XP to others in need', '🎁', 'social', 50, '{"type":"donation","amount":500}');
