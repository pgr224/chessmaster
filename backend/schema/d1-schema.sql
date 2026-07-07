-- ================================================================
-- Chess Master — Cloudflare D1 (SQLite) Schema
-- ================================================================

-- ────────────────────────────────────────
-- USERS
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id            TEXT PRIMARY KEY,           -- UUID
  username      TEXT NOT NULL UNIQUE,
  device_id     TEXT NOT NULL UNIQUE,       -- device fingerprint (offline auth)
  device_model  TEXT,
  avatar_url    TEXT,
  is_ghibli     INTEGER NOT NULL DEFAULT 0, -- Toggles Ghibli filter
  local_avatar      TEXT,                       -- Path to local asset avatar
  username_changes  INTEGER NOT NULL DEFAULT 0, -- Track rename count (limit 2)
  xp                INTEGER NOT NULL DEFAULT 0,
  push_enabled      INTEGER NOT NULL DEFAULT 1, -- 0=disabled, 1=enabled
  is_online     INTEGER NOT NULL DEFAULT 0, -- 0=offline, 1=online
  last_seen     TEXT,                       -- ISO8601
  last_username_change TEXT,                -- ISO8601
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ────────────────────────────────────────
-- PUSH SUBSCRIPTIONS (W3C Web Push / VAPID)
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_subscriptions (
  id            TEXT PRIMARY KEY,           -- UUID
  user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  endpoint      TEXT NOT NULL,
  p256dh        TEXT NOT NULL,              -- public key part
  auth          TEXT NOT NULL,              -- auth secret part
  device_id     TEXT,                       -- link to specific device
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_sub_user ON user_subscriptions(user_id);

-- ────────────────────────────────────────
-- USER NOTIFICATION PREFERENCES
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_notification_preferences (
  user_id                    TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  challenge_notifications    INTEGER NOT NULL DEFAULT 1,
  community_notifications    INTEGER NOT NULL DEFAULT 1,
  tournament_notifications   INTEGER NOT NULL DEFAULT 1,
  system_notifications       INTEGER NOT NULL DEFAULT 1,
  updated_at                 TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_users_device ON users(device_id);
CREATE INDEX idx_users_xp     ON users(xp DESC);

-- ────────────────────────────────────────
-- USER STATS
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_stats (
  user_id           TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  games_played      INTEGER NOT NULL DEFAULT 0,
  wins              INTEGER NOT NULL DEFAULT 0,
  losses            INTEGER NOT NULL DEFAULT 0,
  draws             INTEGER NOT NULL DEFAULT 0,
  ai_games          INTEGER NOT NULL DEFAULT 0,
  ai_wins           INTEGER NOT NULL DEFAULT 0,
  multiplayer_games INTEGER NOT NULL DEFAULT 0,
  multiplayer_wins  INTEGER NOT NULL DEFAULT 0,
  tournament_games  INTEGER NOT NULL DEFAULT 0,
  tournament_wins   INTEGER NOT NULL DEFAULT 0,
  longest_streak    INTEGER NOT NULL DEFAULT 0,
  current_streak    INTEGER NOT NULL DEFAULT 0,
  hints_used        INTEGER NOT NULL DEFAULT 0,
  total_moves       INTEGER NOT NULL DEFAULT 0,
  puzzles_solved    INTEGER NOT NULL DEFAULT 0,
  puzzle_rating     INTEGER NOT NULL DEFAULT 1200,
  elo_rating        INTEGER NOT NULL DEFAULT 0,
  two_player_games  INTEGER NOT NULL DEFAULT 0,
  two_player_wins   INTEGER NOT NULL DEFAULT 0,
  total_time_played INTEGER NOT NULL DEFAULT 0,
  tournaments_won   INTEGER NOT NULL DEFAULT 0,
  pieces_captured   INTEGER NOT NULL DEFAULT 0,
  checkmates_delivered INTEGER NOT NULL DEFAULT 0,
  best_win_elo      INTEGER NOT NULL DEFAULT 0,
  updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ────────────────────────────────────────
-- GAMES
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS games (
  id              TEXT PRIMARY KEY,
  white_user_id   TEXT REFERENCES users(id),
  black_user_id   TEXT REFERENCES users(id),
  mode            TEXT NOT NULL CHECK(mode IN ('singlePlayer','twoPlayer','multiplayer','tournament','tutorial','puzzle','practice')),
  status          TEXT NOT NULL DEFAULT 'active'
                    CHECK(status IN ('active','completed','abandoned','draw')),
  result          TEXT CHECK(result IN ('white','black','draw')),
  termination     TEXT,     -- checkmate, resignation, timeout, draw agreement, etc.
  pgn             TEXT,     -- full PGN string
  initial_fen     TEXT,     -- starting FEN (standard or custom)
  final_fen       TEXT,
  time_control    TEXT,     -- e.g. "10+0", "5+3"
  move_count      INTEGER NOT NULL DEFAULT 0,
  white_time_left INTEGER,  -- milliseconds
  black_time_left INTEGER,
  tournament_id   TEXT REFERENCES tournaments(id),
  ai_difficulty   TEXT,
  rated           INTEGER NOT NULL DEFAULT 1,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
  completed_at    TEXT
);

CREATE INDEX idx_games_white    ON games(white_user_id, created_at DESC);
CREATE INDEX idx_games_black    ON games(black_user_id, created_at DESC);
CREATE INDEX idx_games_status   ON games(status);
CREATE INDEX idx_games_tournament ON games(tournament_id);

-- ────────────────────────────────────────
-- MOVES
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS moves (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  game_id     TEXT NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  move_number INTEGER NOT NULL,
  color       TEXT NOT NULL CHECK(color IN ('white','black')),
  from_sq     TEXT NOT NULL,  -- e.g. "e2"
  to_sq       TEXT NOT NULL,  -- e.g. "e4"
  promotion   TEXT,           -- q, r, b, n
  algebraic   TEXT NOT NULL,  -- e.g. "e4", "Nf3", "O-O"
  fen_after   TEXT NOT NULL,
  time_spent  INTEGER,        -- ms
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_moves_game ON moves(game_id, move_number);

-- ────────────────────────────────────────
-- TOURNAMENTS
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tournaments (
  id              TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  description     TEXT,
  format          TEXT NOT NULL DEFAULT 'single_elimination'
                    CHECK(format IN ('single_elimination','double_elimination','round_robin','swiss')),
  status          TEXT NOT NULL DEFAULT 'upcoming'
                    CHECK(status IN ('upcoming','registration','active','completed','cancelled')),
  max_players     INTEGER NOT NULL DEFAULT 16,
  current_players INTEGER NOT NULL DEFAULT 0,
  time_control    TEXT NOT NULL DEFAULT '10+0',
  prize_info      TEXT,
  registration_fee INTEGER NOT NULL DEFAULT 0,
  start_time      TEXT NOT NULL,
  end_time        TEXT,
  created_by      TEXT REFERENCES users(id),
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ────────────────────────────────────────
-- TOURNAMENT PARTICIPANTS
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tournament_participants (
  tournament_id TEXT NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  user_id       TEXT NOT NULL REFERENCES users(id),
  seed          INTEGER,
  status        TEXT NOT NULL DEFAULT 'active'
                  CHECK(status IN ('active','eliminated','winner')),
  points        REAL NOT NULL DEFAULT 0,
  wins          INTEGER NOT NULL DEFAULT 0,
  losses        INTEGER NOT NULL DEFAULT 0,
  draws         INTEGER NOT NULL DEFAULT 0,
  joined_at     TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (tournament_id, user_id)
);

-- ────────────────────────────────────────
-- TOURNAMENT BRACKETS
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tournament_rounds (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  tournament_id TEXT NOT NULL REFERENCES tournaments(id),
  round_number  INTEGER NOT NULL,
  game_id       TEXT REFERENCES games(id),
  player1_id    TEXT REFERENCES users(id),
  player2_id    TEXT REFERENCES users(id),
  winner_id     TEXT REFERENCES users(id),
  status        TEXT NOT NULL DEFAULT 'pending'
                  CHECK(status IN ('pending','active','completed','bye')),
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ────────────────────────────────────────
-- CHALLENGES
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS challenges (
  id              TEXT PRIMARY KEY,
  challenger_id   TEXT NOT NULL REFERENCES users(id),
  challenged_id   TEXT NOT NULL REFERENCES users(id),
  mode            TEXT NOT NULL DEFAULT 'duel'
                    CHECK(mode IN ('duel','tournament')),
  variant_id      TEXT NOT NULL DEFAULT 'standard',
  time_control    TEXT NOT NULL DEFAULT '10+0',
  delivery_status TEXT NOT NULL DEFAULT 'live'
                    CHECK(delivery_status IN ('live','queued')),
  color_preference TEXT DEFAULT 'random',
  status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK(status IN ('pending','accepted','declined','expired','completed','cancelled')),
  game_id         TEXT REFERENCES games(id),
  message         TEXT,
  expires_at      TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_challenges_status ON challenges(status);

-- ────────────────────────────────────────
-- CHAT MESSAGES
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS chat_messages (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  game_id     TEXT NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  user_id     TEXT NOT NULL REFERENCES users(id),
  message     TEXT NOT NULL,
  message_type TEXT NOT NULL DEFAULT 'text' CHECK(message_type IN ('text','emoji','system')),
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_chat_game ON chat_messages(game_id, created_at);

-- ────────────────────────────────────────
-- ACHIEVEMENTS
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS achievements (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL,
  icon        TEXT NOT NULL,
  category    TEXT NOT NULL,
  points      INTEGER NOT NULL DEFAULT 10,
  criteria    TEXT NOT NULL  -- JSON criteria
);

CREATE TABLE IF NOT EXISTS user_achievements (
  user_id        TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  achievement_id TEXT NOT NULL REFERENCES achievements(id),
  earned_at      TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, achievement_id)
);

-- ────────────────────────────────────────
-- DAILY CONTENT
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS daily_content (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  category    TEXT NOT NULL CHECK(category IN (
    'history','champion','famous_game','opening','tactic','endgame',
    'tournament','career_guide','puzzle'
  )),
  title       TEXT NOT NULL,
  content     TEXT NOT NULL,  -- Markdown
  author      TEXT,
  image_url   TEXT,
  difficulty  INTEGER DEFAULT 0,
  publish_date TEXT NOT NULL DEFAULT (date('now')),
  is_premium  INTEGER NOT NULL DEFAULT 0,
  tags        TEXT,           -- JSON array
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_content_date     ON daily_content(publish_date DESC);
CREATE INDEX idx_content_category ON daily_content(category);

-- ────────────────────────────────────────
-- SAVED GAMES (local resume)
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS saved_games (
  id          TEXT PRIMARY KEY,
  user_id     TEXT REFERENCES users(id),
  game_id     TEXT REFERENCES games(id),
  fen         TEXT NOT NULL,
  pgn         TEXT,
  mode        TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ────────────────────────────────────────
-- XP TRANSFERS AND REQUESTS
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS xp_transfers (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  donor_id     TEXT NOT NULL REFERENCES users(id),
  recipient_id TEXT NOT NULL REFERENCES users(id),
  amount       INTEGER NOT NULL,
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS xp_requests (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  requester_id TEXT NOT NULL REFERENCES users(id),
  amount       INTEGER NOT NULL,
  status       TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open', 'fulfilled', 'cancelled')),
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

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

-- ────────────────────────────────────────
-- PLAYER XP HISTORY
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS xp_history (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  game_id     TEXT REFERENCES games(id),
  xp_before   INTEGER NOT NULL,
  xp_after    INTEGER NOT NULL,
  change      INTEGER NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ────────────────────────────────────────
-- UNIFIED PLAYER SCORING VIEW
-- ────────────────────────────────────────
-- Single source of truth for profile + stats, queried by buildProfileData()
CREATE VIEW IF NOT EXISTS unified_player_scoring AS
SELECT
    u.id,
    u.username,
    u.avatar_url,
    u.is_ghibli,
    u.created_at,
    u.device_model,
    u.last_username_change,
    u.is_online,
    u.last_seen,
    u.xp, -- Master XP from users table
    COALESCE(s.elo_rating, 0) as elo_rating,
    COALESCE(s.wins, 0) as wins,
    COALESCE(s.losses, 0) as losses,
    COALESCE(s.draws, 0) as draws,
    COALESCE(s.games_played, 0) as games_played,
    CASE 
        WHEN COALESCE(s.games_played, 0) > 0 
        THEN ROUND(CAST(COALESCE(s.wins, 0) AS REAL) / s.games_played * 100, 1)
        ELSE 0.0 
    END as win_rate,
    COALESCE(s.longest_streak, 0) as longest_streak,
    COALESCE(s.puzzle_rating, 1200) as puzzle_rating,
    COALESCE(s.puzzles_solved, 0) as puzzles_solved,
    COALESCE(s.total_time_played, 0) as total_time_played,
    COALESCE(s.tournaments_won, 0) as tournaments_won,
    COALESCE(s.pieces_captured, 0) as pieces_captured,
    COALESCE(s.checkmates_delivered, 0) as checkmates_delivered,
    COALESCE(s.best_win_elo, 0) as best_win_elo,
    RANK() OVER (ORDER BY u.xp DESC, COALESCE(s.elo_rating, 0) DESC) as rank
FROM users u
LEFT JOIN user_stats s ON s.user_id = u.id;

-- ────────────────────────────────────────
-- SEED ACHIEVEMENTS
-- ────────────────────────────────────────
INSERT OR IGNORE INTO achievements (id, name, description, icon, category, points, criteria) VALUES
  ('first_win', 'First Victory', 'Win your first game', '🏆', 'milestone', 10, '{"wins":1}'),
  ('ten_wins', 'Getting Started', 'Win 10 games', '⭐', 'milestone', 25, '{"wins":10}'),
  ('hundred_wins', 'Chess Warrior', 'Win 100 games', '🗡️', 'milestone', 100, '{"wins":100}'),
  ('perfect_game', 'Flawless', 'Win without losing a major piece', '💎', 'skill', 50, '{"type":"flawless"}'),
  ('speedster', 'Speed Demon', 'Win in under 20 moves', '⚡', 'skill', 30, '{"maxMoves":20,"result":"win"}'),
  ('scholar', 'Scholar''s Mate', 'Win with Scholar''s Mate', '📚', 'opening', 20, '{"type":"scholars_mate"}'),
  ('comeback', 'The Comeback', 'Win after being down material', '🔄', 'dramatic', 40, '{"type":"comeback"}'),
  ('streak5', 'On Fire', '5 game winning streak', '🔥', 'streak', 50, '{"streak":5}'),
  ('streak10', 'Unstoppable', '10 game winning streak', '💥', 'streak', 100, '{"streak":10}'),
  ('tournament_win', 'Champion', 'Win a tournament', '👑', 'tournament', 200, '{"type":"tournament_win"}'),
  ('generous_donor', 'Kind Soul', 'Donate 500 XP to others in need', '🎁', 'social', 50, '{"type":"donation","amount":500}');
