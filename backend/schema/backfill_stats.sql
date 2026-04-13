-- ================================================================
-- ADVANCED RECALCULATION OF ALL USER STATISTICS
-- ================================================================

-- This script performs a deep analysis of the games table to 
-- reconstruct win rates, ratios, and the actual best winning streaks.

-- 1. Create a temporary mapping of all game outcomes per user
WITH user_game_outcomes AS (
    SELECT 
        u.id as user_id,
        g.id as game_id,
        g.created_at,
        CASE 
            WHEN (g.white_user_id = u.id AND g.result = 'white') OR (g.black_user_id = u.id AND g.result = 'black') THEN 1 -- Win
            ELSE 0 -- Not a win (Loss or Draw)
        END as is_win
    FROM users u
    JOIN games g ON (u.id = g.white_user_id OR u.id = g.black_user_id)
    WHERE g.status IN ('completed', 'abandoned')
),
-- 2. Identify "islands" of consecutive wins (Gaps and Islands)
streaks_pre AS (
    SELECT 
        user_id,
        is_win,
        row_number() OVER (PARTITION BY user_id ORDER BY created_at) - 
        row_number() OVER (PARTITION BY user_id, is_win ORDER BY created_at) as grp
    FROM user_game_outcomes
),
-- 3. Calculate max streak per user
best_streaks AS (
    SELECT 
        user_id,
        MAX(streak_len) as longest_streak
    FROM (
        SELECT user_id, COUNT(*) as streak_len
        FROM streaks_pre
        WHERE is_win = 1
        GROUP BY user_id, grp
    )
    GROUP BY user_id
),
-- 4. Gather all other aggregate stats
aggregate_stats AS (
    SELECT 
        u.id as user_id,
        COUNT(g.id) as games_played,
        SUM(CASE WHEN (g.white_user_id = u.id AND g.result = 'white') OR (g.black_user_id = u.id AND g.result = 'black') THEN 1 ELSE 0 END) as wins,
        SUM(CASE WHEN (g.white_user_id = u.id AND g.result = 'black') OR (g.black_user_id = u.id AND g.result = 'white') THEN 1 ELSE 0 END) as losses,
        SUM(CASE WHEN g.result = 'draw' THEN 1 ELSE 0 END) as draws,
        -- Multiplayer
        SUM(CASE WHEN g.mode = 'multiplayer' THEN 1 ELSE 0 END) as m_games,
        SUM(CASE WHEN g.mode = 'multiplayer' AND ((g.white_user_id = u.id AND g.result = 'white') OR (g.black_user_id = u.id AND g.result = 'black')) THEN 1 ELSE 0 END) as m_wins,
        -- Tournament
        SUM(CASE WHEN g.mode = 'tournament' THEN 1 ELSE 0 END) as t_games,
        SUM(CASE WHEN g.mode = 'tournament' AND ((g.white_user_id = u.id AND g.result = 'white') OR (g.black_user_id = u.id AND g.result = 'black')) THEN 1 ELSE 0 END) as t_wins
    FROM users u
    JOIN games g ON (u.id = g.white_user_id OR u.id = g.black_user_id)
    WHERE g.status IN ('completed', 'abandoned')
    GROUP BY u.id
)
-- 5. UPSERT everything into user_stats
INSERT INTO user_stats (
    user_id, games_played, wins, losses, draws, 
    multiplayer_games, multiplayer_wins,
    tournament_games, tournament_wins,
    longest_streak, updated_at
)
SELECT 
    a.user_id, a.games_played, a.wins, a.losses, a.draws,
    a.m_games, a.m_wins,
    a.t_games, a.t_wins,
    COALESCE(b.longest_streak, 0),
    datetime('now')
FROM aggregate_stats a
LEFT JOIN best_streaks b ON a.user_id = b.user_id
ON CONFLICT(user_id) DO UPDATE SET
    games_played = EXCLUDED.games_played,
    wins = EXCLUDED.wins,
    losses = EXCLUDED.losses,
    draws = EXCLUDED.draws,
    multiplayer_games = EXCLUDED.multiplayer_games,
    multiplayer_wins = EXCLUDED.multiplayer_wins,
    tournament_games = EXCLUDED.tournament_games,
    tournament_wins = EXCLUDED.tournament_wins,
    longest_streak = EXCLUDED.longest_streak,
    updated_at = EXCLUDED.updated_at;
