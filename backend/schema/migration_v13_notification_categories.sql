CREATE TABLE IF NOT EXISTS user_notification_preferences (
  user_id                    TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  challenge_notifications    INTEGER NOT NULL DEFAULT 1,
  community_notifications    INTEGER NOT NULL DEFAULT 1,
  tournament_notifications   INTEGER NOT NULL DEFAULT 1,
  system_notifications       INTEGER NOT NULL DEFAULT 1,
  updated_at                 TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO user_notification_preferences (
  user_id,
  challenge_notifications,
  community_notifications,
  tournament_notifications,
  system_notifications,
  updated_at
)
SELECT id, 1, 1, 1, 1, datetime('now')
FROM users;
