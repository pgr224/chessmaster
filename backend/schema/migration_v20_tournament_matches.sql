-- Safe repair for installations missing round-game storage.
-- Tournament type/round columns are supplied by migration_v11_tournaments.sql.
-- Round games are persisted separately from participants and old bracket rows.
CREATE TABLE IF NOT EXISTS tournament_matches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tournament_id TEXT NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  round_number INTEGER NOT NULL,
  game_id TEXT UNIQUE REFERENCES games(id),
  player1_id TEXT NOT NULL REFERENCES users(id),
  player2_id TEXT NOT NULL REFERENCES users(id),
  winner_id TEXT REFERENCES users(id),
  result TEXT CHECK(result IN ('player1','player2','draw')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','active','completed')),
  white_id TEXT NOT NULL REFERENCES users(id),
  black_id TEXT NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_tournament_matches_tid
  ON tournament_matches(tournament_id, round_number);

