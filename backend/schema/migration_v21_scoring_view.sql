-- Preserve XP and all mode counters; expose complete stats to profile/gameboard.
DROP VIEW IF EXISTS unified_player_scoring;
CREATE VIEW IF NOT EXISTS unified_player_scoring AS
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
    COALESCE(s.elo_rating, 0) as elo_rating,
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
    COALESCE(s.current_streak, 0) as current_streak,
    COALESCE(s.ai_games, 0) as ai_games,
    COALESCE(s.ai_wins, 0) as ai_wins,
    COALESCE(s.multiplayer_games, 0) as multiplayer_games,
    COALESCE(s.multiplayer_wins, 0) as multiplayer_wins,
    COALESCE(s.tournament_games, 0) as tournament_games,
    COALESCE(s.tournament_wins, 0) as tournament_wins,
    COALESCE(s.two_player_games, 0) as two_player_games,
    COALESCE(s.two_player_wins, 0) as two_player_wins,
    COALESCE(s.puzzle_rating, 1200) as puzzle_rating,
    COALESCE(s.puzzles_solved, 0) as puzzles_solved,
    COALESCE(s.total_time_played, 0) as total_time_played,
    COALESCE(s.tournaments_won, 0) as tournaments_won,
    COALESCE(s.pieces_captured, 0) as pieces_captured,
    COALESCE(s.checkmates_delivered, 0) as checkmates_delivered,
    COALESCE(s.best_win_elo, 0) as best_win_elo,
    CASE WHEN COALESCE(s.games_played,0)<1 THEN 0 ELSE RANK() OVER (ORDER BY CASE WHEN COALESCE(s.games_played,0)>=1 THEN 0 ELSE 1 END, COALESCE(s.elo_rating,0) DESC,u.xp DESC) END as rank
FROM users u
LEFT JOIN user_stats s ON s.user_id = u.id;

