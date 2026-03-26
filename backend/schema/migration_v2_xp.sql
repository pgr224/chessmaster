-- Migration: Replace Rating with XP
-- Run with: npx wrangler d1 execute chessmaster-real4 --local --file=./schema/migration_v2_xp.sql

-- 1. Rename column in users
ALTER TABLE users RENAME COLUMN rating TO xp;

-- 2. Drop the old index and create new one
DROP INDEX IF EXISTS idx_users_rating;
CREATE INDEX idx_users_xp ON users(xp DESC);

-- 3. Recreate rating_history as xp_history
DROP TABLE IF EXISTS rating_history;
CREATE TABLE IF NOT EXISTS xp_history (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  game_id     TEXT REFERENCES games(id),
  xp_before   INTEGER NOT NULL,
  xp_after    INTEGER NOT NULL,
  change      INTEGER NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 4. Clean up dummy users (if any)
DELETE FROM users WHERE id IN ('ivy-rapid', 'max-blitz', 'luna-endgame', 'sam-kids');
DELETE FROM users WHERE username LIKE 'Dummy%';
DELETE FROM users WHERE username LIKE 'Test%';
