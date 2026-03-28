-- XP Transfers and Requests Migration
CREATE TABLE IF NOT EXISTS xp_transfers (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  donor_id    TEXT NOT NULL REFERENCES users(id),
  recipient_id TEXT NOT NULL REFERENCES users(id),
  amount      INTEGER NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS xp_requests (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  requester_id TEXT NOT NULL REFERENCES users(id),
  amount      INTEGER NOT NULL,
  status      TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open', 'fulfilled', 'cancelled')),
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Register "Generosity" badge
INSERT OR IGNORE INTO achievements (id, name, description, icon, category, points, criteria) VALUES
  ('generous_donor', 'Kind Soul', 'Donate 500 XP to others in need', '🎁', 'social', 50, '{"type":"donation","amount":500}');
