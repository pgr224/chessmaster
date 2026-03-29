-- Migration v6: Fix games table to support all game modes
-- SQLite doesn't support modifying CHECK constraints, so we need to recreate the table

-- Create new games table with all modes
CREATE TABLE IF NOT EXISTS games_new (
  id              TEXT PRIMARY KEY,
  white_user_id   TEXT REFERENCES users(id),
  black_user_id   TEXT REFERENCES users(id),
  mode            TEXT NOT NULL CHECK(mode IN ('singlePlayer','twoPlayer','multiplayer','tournament','tutorial','puzzle','practice')),
  status          TEXT NOT NULL DEFAULT 'active'
                    CHECK(status IN ('active','completed','abandoned','draw')),
  result          TEXT CHECK(result IN ('white','black','draw')),
  termination     TEXT,
  pgn             TEXT,
  initial_fen     TEXT,
  final_fen       TEXT,
  time_control    TEXT,
  move_count      INTEGER NOT NULL DEFAULT 0,
  white_time_left INTEGER,
  black_time_left INTEGER,
  tournament_id   TEXT REFERENCES tournaments(id),
  ai_difficulty   TEXT,
  rated           INTEGER NOT NULL DEFAULT 1,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
  completed_at    TEXT
);

-- Copy existing data
INSERT INTO games_new SELECT * FROM games;

-- Drop old table and indexes
DROP TABLE games;
DROP INDEX IF EXISTS idx_games_white;
DROP INDEX IF EXISTS idx_games_black;
DROP INDEX IF EXISTS idx_games_status;
DROP INDEX IF EXISTS idx_games_tournament;

-- Rename new table
ALTER TABLE games_new RENAME TO games;

-- Recreate indexes
CREATE INDEX idx_games_white    ON games(white_user_id, created_at DESC);
CREATE INDEX idx_games_black    ON games(black_user_id, created_at DESC);
CREATE INDEX idx_games_status   ON games(status);
CREATE INDEX idx_games_tournament ON games(tournament_id);