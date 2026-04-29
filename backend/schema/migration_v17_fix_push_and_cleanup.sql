-- Migration v17: Fix missing Push Notification support and View Cleanup
-- This ensures that older databases have the required columns and tables for push notifications.

-- 1. Add push_enabled to users if missing (SQLite doesn't support IF NOT EXISTS for columns, so we use a safe pattern)
-- Note: In Cloudflare D1, if the column exists, this will just fail. We'll wrap it in a try-catch equivalent or just let the user know.
-- However, for a migration file, we'll just list it.

-- 1. push_enabled column already exists in production (confirmed by recent migration attempt error)
-- ALTER TABLE users ADD COLUMN push_enabled INTEGER NOT NULL DEFAULT 1;

-- 2. Create user_subscriptions table if missing
CREATE TABLE IF NOT EXISTS user_subscriptions (
  id            TEXT PRIMARY KEY,           -- UUID
  user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  endpoint      TEXT NOT NULL,
  p256dh        TEXT NOT NULL,              -- public key part
  auth          TEXT NOT NULL,              -- auth secret part
  device_id     TEXT,                       -- link to specific device
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_sub_user ON user_subscriptions(user_id);

-- 3. Create notification preferences table if missing
CREATE TABLE IF NOT EXISTS user_notification_preferences (
  user_id                    TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  challenge_notifications    INTEGER NOT NULL DEFAULT 1,
  community_notifications    INTEGER NOT NULL DEFAULT 1,
  tournament_notifications   INTEGER NOT NULL DEFAULT 1,
  system_notifications       INTEGER NOT NULL DEFAULT 1,
  updated_at                 TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 3. Re-sync the view one last time to ensure it matches the code
DROP VIEW IF EXISTS unified_player_scoring;

CREATE VIEW unified_player_scoring AS
SELECT
    u.id,
    u.username,
    u.avatar_url,
    u.is_ghibli,
    u.created_at,
    u.device_model,
    u.last_username_change,
    u.is_online,
    u.last_seen,
    u.xp,
    COALESCE(s.elo_rating, 1200) as elo_rating,
    COALESCE(s.wins, 0) as wins,
    COALESCE(s.losses, 0) as losses,
    COALESCE(s.draws, 0) as draws,
    COALESCE(s.games_played, 0) as games_played,
    CASE 
        WHEN COALESCE(s.games_played, 0) > 0 
        THEN ROUND(CAST(COALESCE(s.wins, 0) AS REAL) / s.games_played * 100, 1)
        ELSE 0.0 
    END as win_rate,
    COALESCE(s.longest_streak, 0) as longest_streak,
    COALESCE(s.puzzle_rating, 1200) as puzzle_rating,
    COALESCE(s.puzzles_solved, 0) as puzzles_solved,
    COALESCE(s.total_time_played, 0) as total_time_played,
    COALESCE(s.tournaments_won, 0) as tournaments_won,
    COALESCE(s.pieces_captured, 0) as pieces_captured,
    COALESCE(s.checkmates_delivered, 0) as checkmates_delivered,
    COALESCE(s.best_win_elo, 0) as best_win_elo,
    RANK() OVER (ORDER BY u.xp DESC, COALESCE(s.elo_rating, 1200) DESC) as rank
FROM users u
LEFT JOIN user_stats s ON s.user_id = u.id;
