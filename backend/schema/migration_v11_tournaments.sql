-- Migration v11: Extended tournament infrastructure
-- Run: npx wrangler d1 execute chessmaster-real4 --file=schema/migration_v11_tournaments.sql --remote

-- Add type column to tournaments table (public vs private)
ALTER TABLE tournaments ADD COLUMN type TEXT NOT NULL DEFAULT 'public'
  CHECK(type IN ('public','private'));

-- Add round tracking to tournaments
ALTER TABLE tournaments ADD COLUMN total_rounds INTEGER NOT NULL DEFAULT 3;
ALTER TABLE tournaments ADD COLUMN current_round INTEGER NOT NULL DEFAULT 0;

-- Individual match results within a tournament
CREATE TABLE IF NOT EXISTS tournament_matches (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  tournament_id TEXT NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  round_number  INTEGER NOT NULL,
  game_id       TEXT REFERENCES games(id),
  player1_id    TEXT NOT NULL REFERENCES users(id),
  player2_id    TEXT NOT NULL REFERENCES users(id),
  winner_id     TEXT REFERENCES users(id),
  result        TEXT CHECK(result IN ('player1','player2','draw')),
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK(status IN ('pending','active','completed')),
  white_id      TEXT REFERENCES users(id),
  black_id      TEXT REFERENCES users(id),
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_tournament_matches_tid
  ON tournament_matches(tournament_id, round_number);
