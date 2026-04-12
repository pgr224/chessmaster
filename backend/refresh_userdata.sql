PRAGMA foreign_keys = OFF;

-- 1. Ensure all users have a entry in user_stats
INSERT OR IGNORE INTO user_stats (user_id) SELECT id FROM users;

-- 2. Recalculate total games played
UPDATE user_stats
SET games_played = (
  SELECT COUNT(*)
  FROM games
  WHERE (games.white_user_id = user_stats.user_id OR games.black_user_id = user_stats.user_id)
    AND games.status = 'completed'
);

-- 3. Recalculate Wins
UPDATE user_stats
SET wins = (
  SELECT COUNT(*)
  FROM games
  WHERE (
    (games.white_user_id = user_stats.user_id AND games.result = 'white') OR
    (games.black_user_id = user_stats.user_id AND games.result = 'black')
  ) AND games.status = 'completed'
);

-- 4. Recalculate Losses
UPDATE user_stats
SET losses = (
  SELECT COUNT(*)
  FROM games
  WHERE (
    (games.white_user_id = user_stats.user_id AND games.result = 'black') OR
    (games.black_user_id = user_stats.user_id AND games.result = 'white')
  ) AND games.status = 'completed'
);

-- 5. Recalculate Draws
UPDATE user_stats
SET draws = (
  SELECT COUNT(*)
  FROM games
  WHERE (games.white_user_id = user_stats.user_id OR games.black_user_id = user_stats.user_id)
    AND games.result = 'draw'
    AND games.status = 'completed'
);

-- 6. Recalculate Multiplayer Wins (specifically for the leaderboard 'multiplayer' modes)
UPDATE user_stats
SET multiplayer_wins = (
  SELECT COUNT(*)
  FROM games
  WHERE (
    (games.white_user_id = user_stats.user_id AND games.result = 'white') OR
    (games.black_user_id = user_stats.user_id AND games.result = 'black')
  ) AND games.mode = 'multiplayer' AND games.status = 'completed'
);

-- 7. Reset current streaks and set updated timestamp
UPDATE user_stats SET updated_at = datetime('now');

PRAGMA foreign_keys = ON;
