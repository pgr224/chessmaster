PRAGMA foreign_keys = OFF;

-- 1. Ensure all users have a entry in user_stats
INSERT OR IGNORE INTO user_stats (user_id) SELECT id FROM users;

-- 2. Recalculate total games played
-- 1. Mark stale active games as abandoned (older than 24h)
UPDATE games 
SET status = 'abandoned', termination = 'stale_cleanup', updated_at = datetime('now')
WHERE status = 'active' AND datetime(created_at) < datetime('now', '-1 day');

-- 2. Recalculate games_played including all terminal statuses
UPDATE user_stats
SET games_played = (
  SELECT COUNT(*)
  FROM games
  WHERE (games.white_user_id = user_stats.user_id OR games.black_user_id = user_stats.user_id)
    AND games.status IN ('completed', 'abandoned', 'draw')
);

-- 3. Recalculate wins
UPDATE user_stats
SET wins = (
  SELECT COUNT(*)
  FROM games
  WHERE (
    (games.white_user_id = user_stats.user_id AND games.result = 'white') OR
    (games.black_user_id = user_stats.user_id AND games.result = 'black')
  ) AND games.status IN ('completed', 'abandoned')
);

-- 4. Recalculate Losses
UPDATE user_stats
SET losses = (
  SELECT COUNT(*)
  FROM games
  WHERE (
    (games.white_user_id = user_stats.user_id AND games.result = 'black') OR
    (games.black_user_id = user_stats.user_id AND games.result = 'white')
  ) AND games.status IN ('completed', 'abandoned')
);

-- 5. Recalculate Draws
UPDATE user_stats
SET draws = (
  SELECT COUNT(*)
  FROM games
  WHERE (games.white_user_id = user_stats.user_id OR games.black_user_id = user_stats.user_id)
    AND games.result = 'draw'
    AND games.status IN ('completed', 'draw')
);

-- 6. Recalculate MP Wins
UPDATE user_stats
SET multiplayer_wins = (
  SELECT COUNT(*)
  FROM games
  WHERE (
    (games.white_user_id = user_stats.user_id AND games.result = 'white') OR
    (games.black_user_id = user_stats.user_id AND games.result = 'black')
  ) AND games.mode = 'multiplayer' AND games.status IN ('completed', 'abandoned')
);

-- 7. Backfill Elo Rating for users stuck at default (Baseline estimate)
-- Formula: 1200 + (wins * 20) - (losses * 15) + (draws * 5)
UPDATE user_stats
SET elo_rating = 1200 + (wins * 20) - (losses * 15) + (draws * 5)
WHERE elo_rating = 1200 AND games_played > 0;

-- 8. Reset updated timestamp
UPDATE user_stats SET updated_at = datetime('now');

PRAGMA foreign_keys = ON;
