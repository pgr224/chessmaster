-- Migration v9: Username Change Limit
-- Add username_changes column to track how many times a user has updated their name.
-- Max limit is 2.
-- Run with: npx wrangler d1 execute chessmaster-real4 --remote --file=./schema/migration_v9_username_limit.sql

ALTER TABLE users ADD COLUMN username_changes INTEGER NOT NULL DEFAULT 0;
