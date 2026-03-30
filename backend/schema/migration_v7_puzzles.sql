-- Migration v7: Add Puzzle Stats to user_stats table
ALTER TABLE user_stats ADD COLUMN puzzles_solved INTEGER NOT NULL DEFAULT 0;
ALTER TABLE user_stats ADD COLUMN puzzle_rating INTEGER NOT NULL DEFAULT 1200;
