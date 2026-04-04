-- XP Social Requests and Friendships
CREATE TABLE IF NOT EXISTS xp_requests_v2 (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  requester_id TEXT NOT NULL REFERENCES users(id),
  target_user_id TEXT REFERENCES users(id),
  amount INTEGER NOT NULL,
  request_type TEXT NOT NULL CHECK(request_type IN ('broadcast','direct')),
  status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','fulfilled','rejected','expired','cancelled')),
  expires_at TEXT NOT NULL,
  fulfilled_by TEXT REFERENCES users(id),
  fulfilled_at TEXT,
  responded_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_xp_requests_v2_open
ON xp_requests_v2(status, request_type, expires_at);

CREATE UNIQUE INDEX IF NOT EXISTS idx_xp_requests_v2_one_open_per_user
ON xp_requests_v2(requester_id)
WHERE status = 'open';

CREATE TABLE IF NOT EXISTS xp_friendships (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_a TEXT NOT NULL REFERENCES users(id),
  user_b TEXT NOT NULL REFERENCES users(id),
  requested_by TEXT NOT NULL REFERENCES users(id),
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','accepted','rejected','blocked')),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  responded_at TEXT,
  UNIQUE(user_a, user_b)
);

CREATE INDEX IF NOT EXISTS idx_xp_friendships_status
ON xp_friendships(status, updated_at);
