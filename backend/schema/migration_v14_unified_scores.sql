-- Migration v14: Unified User Scoring
-- This script unifies XP and performance stats into a single scoring table
-- and creates a unified view for perfect consistency across the app.

-- 1. Create the new Unified Scoring table (renamed from user_stats for clarity)
-- We will first add XP to the existing user_stats table to simplify the transition.
ALTER TABLE user_stats ADD COLUMN xp INTEGER NOT NULL DEFAULT 0;
ALTER TABLE user_stats ADD COLUMN elo_rating INTEGER NOT NULL DEFAULT 1200;

-- 2. Migrate XP data from users to user_stats
UPDATE user_stats 
SET xp = (SELECT xp FROM users WHERE users.id = user_stats.user_id);

-- 3. Standardize Naming (Rename elo_rating to elo for consistency, 
-- though we'll keep the column name for now but alias it in the view to avoid breaking existing code)

-- 4. Create the Unified Scoring View
-- This "stitches" the user and their stats together one time only.
-- This ensures profile and leaderboard always use the EXACT same logic.
DROP VIEW IF EXISTS unified_player_scoring;
CREATE VIEW unified_player_scoring AS
SELECT 
    u.id,
    u.username,
    u.avatar_url,
    u.is_online,
    u.last_seen,
    -- Use the master XP from users table, not the potentially stale stats table
    u.xp,
    s.elo_rating,
    s.games_played,
    s.wins,
    s.losses,
    s.draws,
    s.multiplayer_wins,
    s.tournament_wins,
    s.ai_wins,
    s.two_player_wins,
    s.longest_streak,
    s.current_streak,
    s.puzzles_solved,
    s.puzzle_rating,
    CASE 
        WHEN s.games_played > 0 
        THEN ROUND(CAST(s.wins AS REAL) / s.games_played * 100, 1)
        ELSE 0 
    END as win_rate
FROM users u
LEFT JOIN user_stats s ON u.id = s.user_id;

-- 5. Fix Inconsistencies: Recalculate total wins/losses/draws from games history
-- (Similar to backfill_stats.sql but specifically for the unified view context)
-- We'll perform an update to ensure games_played is correct.
UPDATE user_stats
SET games_played = wins + losses + draws
WHERE games_played != (wins + losses + draws);

-- 6. Optional: Remove xp from users (We'll keep it for now as a fallback until all code is updated)
-- ALTER TABLE users DROP COLUMN xp; -- Cloudflare D1 doesn't support DROP COLUMN yet easily.
