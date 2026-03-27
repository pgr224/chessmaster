-- Migration v4: Add two-player mode stats
ALTER TABLE user_stats ADD COLUMN two_player_games INTEGER NOT NULL DEFAULT 0;
ALTER TABLE user_stats ADD COLUMN two_player_wins INTEGER NOT NULL DEFAULT 0;
