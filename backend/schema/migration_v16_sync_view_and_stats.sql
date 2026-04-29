-- Synchronize user_stats table and unified_player_scoring view with the application requirements

-- 1. Add missing columns to user_stats if they don't exist
-- SQLite doesn't support IF NOT EXISTS for ADD COLUMN, so we'll do it safely
-- but since D1 execute stops on error, we should be careful.
-- Actually, I already checked PRAGMA table_info, so I know which ones are missing.

-- Missing in user_stats (remote):
-- total_time_played, tournaments_won, pieces_captured, checkmates_delivered, best_win_elo

ALTER TABLE user_stats ADD COLUMN total_time_played INTEGER DEFAULT 0;
ALTER TABLE user_stats ADD COLUMN tournaments_won INTEGER DEFAULT 0;
ALTER TABLE user_stats ADD COLUMN pieces_captured INTEGER DEFAULT 0;
ALTER TABLE user_stats ADD COLUMN checkmates_delivered INTEGER DEFAULT 0;
ALTER TABLE user_stats ADD COLUMN best_win_elo INTEGER DEFAULT 0;

-- 2. Drop and recreate the view to include all required columns
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
    u.xp, -- Master XP from users table
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

