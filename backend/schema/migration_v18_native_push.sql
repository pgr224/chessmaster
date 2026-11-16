-- Apply once on existing installations; do not reset user data.
ALTER TABLE user_notification_preferences ADD COLUMN game_notifications INTEGER NOT NULL DEFAULT 1;
CREATE TABLE IF NOT EXISTS native_push_tokens (
 token TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 platform TEXT NOT NULL CHECK(platform IN('android','ios')), device_id TEXT,
 updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_native_push_user ON native_push_tokens(user_id);
