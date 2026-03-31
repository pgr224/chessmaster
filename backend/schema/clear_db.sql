-- ================================================================
-- Reset Chess Master D1 Database
-- Clears all user data, progress, and history
-- ================================================================

PRAGMA foreign_keys = OFF;

-- 1. Clear History and Logs
DELETE FROM moves;
DELETE FROM chat_messages;
DELETE FROM xp_history;
DELETE FROM saved_games;

-- 2. Clear Social and Interaction Data
DELETE FROM challenges;
DELETE FROM user_achievements;

-- 3. Clear Tournament Data
DELETE FROM tournament_rounds;
DELETE FROM tournament_participants;
DELETE FROM tournaments;

-- 4. Clear Core Game and User Data
DELETE FROM games;
DELETE FROM user_stats;
DELETE FROM users;

-- 5. Reset Sequences
DELETE FROM sqlite_sequence WHERE name IN (
  'moves', 'chat_messages', 'xp_history', 'tournament_rounds', 'daily_content'
);

PRAGMA foreign_keys = ON;

-- Re-insert Achievement Master Data if it was deleted (schema uses INSERT OR IGNORE, but good to be sure)
-- Note: 'achievements' table was NOT deleted above to keep the 55-badge definition. 
-- If you want to delete and re-insert, uncomment the next line:
-- DELETE FROM achievements;

VACUUM;
