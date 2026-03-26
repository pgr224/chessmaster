-- Migration: Add Ghibli filter and Local Avatar persistence
-- Run with: npx wrangler d1 execute chessmaster-real4 --remote --file=./schema/migration_v3_profile.sql

ALTER TABLE users ADD COLUMN is_ghibli INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN local_avatar TEXT;
