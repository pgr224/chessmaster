-- Migration v15: Fix Username Cooldown Column
-- Adds the missing last_username_change column to the users table
-- which is required by buildProfileData and profile update logic.

ALTER TABLE users ADD COLUMN last_username_change TEXT;
