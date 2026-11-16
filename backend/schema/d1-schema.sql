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
  game_notifications         INTEGER NOT NULL DEFAULT 1,
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
  type            TEXT NOT NULL DEFAULT 'public' CHECK(type IN ('public','private')),
  total_rounds    INTEGER NOT NULL DEFAULT 3,
  current_round   INTEGER NOT NULL DEFAULT 0,
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

-- Round games are persisted separately from participants and old bracket rows.
CREATE TABLE IF NOT EXISTS tournament_matches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tournament_id TEXT NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  round_number INTEGER NOT NULL,
  game_id TEXT UNIQUE REFERENCES games(id),
  player1_id TEXT NOT NULL REFERENCES users(id),
  player2_id TEXT NOT NULL REFERENCES users(id),
  winner_id TEXT REFERENCES users(id),
  result TEXT CHECK(result IN ('player1','player2','draw')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','active','completed')),
  white_id TEXT NOT NULL REFERENCES users(id),
  black_id TEXT NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_tournament_matches_tid
  ON tournament_matches(tournament_id, round_number);

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
    COALESCE(s.current_streak, 0) as current_streak,
    COALESCE(s.ai_games, 0) as ai_games,
    COALESCE(s.ai_wins, 0) as ai_wins,
    COALESCE(s.multiplayer_games, 0) as multiplayer_games,
    COALESCE(s.multiplayer_wins, 0) as multiplayer_wins,
    COALESCE(s.tournament_games, 0) as tournament_games,
    COALESCE(s.tournament_wins, 0) as tournament_wins,
    COALESCE(s.two_player_games, 0) as two_player_games,
    COALESCE(s.two_player_wins, 0) as two_player_wins,
    COALESCE(s.puzzle_rating, 1200) as puzzle_rating,
    COALESCE(s.puzzles_solved, 0) as puzzles_solved,
    COALESCE(s.total_time_played, 0) as total_time_played,
    COALESCE(s.tournaments_won, 0) as tournaments_won,
    COALESCE(s.pieces_captured, 0) as pieces_captured,
    COALESCE(s.checkmates_delivered, 0) as checkmates_delivered,
    COALESCE(s.best_win_elo, 0) as best_win_elo,
    CASE WHEN COALESCE(s.games_played,0)<1 THEN 0 ELSE RANK() OVER (ORDER BY CASE WHEN COALESCE(s.games_played,0)>=1 THEN 0 ELSE 1 END, COALESCE(s.elo_rating,0) DESC,u.xp DESC) END as rank
FROM users u
LEFT JOIN user_stats s ON s.user_id = u.id
WHERE u.id NOT GLOB 'guest_*';

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

-- Idempotent scoring ledger. No historical stats or XP are reset.
CREATE TABLE IF NOT EXISTS scoring_events (
 user_id TEXT NOT NULL REFERENCES users(id), event_id TEXT NOT NULL, claim_id TEXT NOT NULL,
 xp_before INTEGER NOT NULL, xp_after INTEGER NOT NULL, xp_delta INTEGER NOT NULL, elo_before INTEGER NOT NULL DEFAULT 0, elo_after INTEGER NOT NULL DEFAULT 0, elo_delta INTEGER NOT NULL DEFAULT 0,
 created_at TEXT NOT NULL DEFAULT (datetime('now')), PRIMARY KEY(user_id,event_id)
);

CREATE TABLE IF NOT EXISTS native_push_tokens (
 token TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 platform TEXT NOT NULL CHECK(platform IN('android','ios')),device_id TEXT,
 updated_at TEXT NOT NULL DEFAULT (datetime('now')));
CREATE INDEX IF NOT EXISTS idx_native_push_user ON native_push_tokens(user_id);

CREATE TABLE IF NOT EXISTS game_scoring_context (game_id TEXT PRIMARY KEY, context TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS xp_transfer_events (
 donor_id TEXT NOT NULL, event_id TEXT NOT NULL, claim_id TEXT NOT NULL,recipient_id TEXT NOT NULL,amount INTEGER NOT NULL,
 donor_before INTEGER NOT NULL,recipient_before INTEGER NOT NULL,PRIMARY KEY(donor_id,event_id));

CREATE TABLE IF NOT EXISTS bounty_windows (window_id INTEGER PRIMARY KEY,target_id TEXT NOT NULL REFERENCES users(id));
CREATE TABLE IF NOT EXISTS bounty_awards(user_id TEXT NOT NULL,game_id TEXT NOT NULL,expires_at TEXT NOT NULL,PRIMARY KEY(user_id,game_id));

-- Align catalog IDs and points with app/lib/data/models/achievement_model.dart.
-- Disambiguate duplicate display titles for the database UNIQUE name constraint.
UPDATE achievements SET name=name||' (legacy '||id||')' WHERE id NOT IN ('first_move','first_win','first_capture','first_check','first_castle','complete_tutorial','play_5_games','play_all_modes','use_hint','first_undo','win_10','win_50','win_100','win_streak_3','win_streak_5','win_streak_10','beat_ai_basic','beat_ai_intermediate','beat_ai_advanced','beat_ai_impossible','pawn_promotion','promote_knight','en_passant','fork_master','no_pieces_lost','accuracy_90','accuracy_95','zero_blunders','checkmate_fast','scholars_mate','back_rank_mate','queen_sacrifice','comeback_win','stalemate_save','long_game','bullet_win','blitz_win','rapid_win','win_on_time','survive_low_time','mp_first_win','mp_win_10','mp_win_50','donate_xp','chat_game','elo_1200','elo_1500','elo_1800','elo_2000','elo_2200','puzzle_10','puzzle_50','puzzle_rush_survive','play_100_games','daily_player','mp_matchmaker','mp_ladder_climber','mp_unstoppable_online','mp_blitz_king','mp_rapid_master','mp_classical_scholar','mp_tournament_victor','mp_comeback_king','tc_bullet_fiend','tc_blitz_warrior','tc_rapid_aficionado','tc_rapid_specialist','tc_time_management','tc_depth_over_speed','cp_fortress_defender','cp_escape_artist','cp_finisher','cp_precision_pressure','cp_sacrifice_master','cp_promotion_victory','sd_rising_star','sd_humble_victor','sd_revenge_master','sd_tournament_dominator','sd_legendary_status','daily_warrior','gg_champion','bounty_hunter','speed_demon_mp','tournament_star') AND name IN ('Baby Steps','First Blood','Piece Collector','King Hunter','Castle Builder','Star Student','Getting Started','Explorer','Wise Owl','Time Traveler','Seasoned Fighter','Veteran Warrior','Centurion','Hot Streak','On Fire','Unstoppable','Robot Beater','Machine Breaker','Terminator','Godlike','Pawn Star','Knight Rider','Sneaky Move','Fork Master','Untouchable','Precision Player','Near Perfect','Clean Sheet','Speed Demon','Scholar''s Mate','Back Rank Assassin','Queen Sacrifice','Comeback King','Escape Artist','Marathon Runner','Bullet Proof','Lightning Bolt','Rapid Fire','Clock Master','Clutch Player','World Beater','Online Champion','Internet Legend','Generous Soul','Social Butterfly','Rising Star','Expert','Master','Grandmaster','Super GM','Puzzle Addict','Puzzle Master','Rush Survivor','Century Club','Dedicated','Matchmaker','Ladder Climber','Unstoppable Online','Blitz King','Rapid Master','Classical Scholar','Tournament Victor','Comeback King','Bullet Fiend','Blitz Warrior','Rapid Aficionado','Rapid Specialist','Time Management','Depth Over Speed','Fortress Defender','Escape Artist','Finisher','Precision Under Pressure','Sacrifice Master','Promotion Victory','Rising Star','Humble Victor','Revenge Master','Tournament Dominator','Legendary Status','Daily Warrior','GG Champion','Bounty Hunter','Speed Demon','Tournament Star');
INSERT INTO achievements (id,name,description,icon,category,points,criteria) VALUES
('first_move','Baby Steps','Make your very first move in a chess game.','👶','beginner',5,'{"requiredCount":1}'),
('first_win','First Blood','Win your first game against AI or a player.','🏆','beginner',10,'{"requiredCount":1}'),
('first_capture','Piece Collector','Capture your first enemy piece.','🥊','beginner',5,'{"requiredCount":1}'),
('first_check','King Hunter','Put the opponent king in check for the first time.','👑','beginner',10,'{"requiredCount":1}'),
('first_castle','Castle Builder','Perform your first castling move.','🏰','beginner',10,'{"requiredCount":1}'),
('complete_tutorial','Star Student','Complete any tutorial lesson.','📚','beginner',15,'{"requiredCount":1}'),
('play_5_games','Getting Started','Play 5 games in any mode.','🎮','beginner',15,'{"requiredCount":5}'),
('play_all_modes','Explorer','Play at least one game in every game mode.','🗺️','beginner',25,'{"requiredCount":1}'),
('use_hint','Wise Owl','Use a hint during a game.','🦉','beginner',5,'{"requiredCount":1}'),
('first_undo','Time Traveler','Use undo for the first time.','⏪','beginner',5,'{"requiredCount":1}'),
('win_10','Seasoned Fighter','Win 10 games total.','⚔️','combat',30,'{"requiredCount":10}'),
('win_50','Veteran Warrior','Win 50 games total.','🛡️','combat',75,'{"requiredCount":50}'),
('win_100','Centurion','Win 100 games total.','💯','combat',150,'{"requiredCount":100}'),
('win_streak_3','Hot Streak','Win 3 games in a row.','🔥','combat',25,'{"requiredCount":3}'),
('win_streak_5','On Fire','Win 5 games in a row.','🌋','combat',50,'{"requiredCount":5}'),
('win_streak_10','Unstoppable','Win 10 games in a row.','💥','combat',100,'{"requiredCount":10}'),
('beat_ai_basic','Robot Beater','Beat the Basic AI.','🤖','combat',10,'{"requiredCount":1}'),
('beat_ai_intermediate','Machine Breaker','Beat the Intermediate AI.','⚙️','combat',25,'{"requiredCount":1}'),
('beat_ai_advanced','Terminator','Beat the Advanced AI.','🦾','combat',50,'{"requiredCount":1}'),
('beat_ai_impossible','Godlike','Beat the Impossible AI.','👼','combat',200,'{"requiredCount":1}'),
('pawn_promotion','Pawn Star','Promote a pawn to a Queen.','👸','strategy',20,'{"requiredCount":1}'),
('promote_knight','Knight Rider','Underpromote a pawn to a Knight.','🐴','strategy',30,'{"requiredCount":1}'),
('en_passant','Sneaky Move','Capture a pawn using en passant.','🥷','strategy',25,'{"requiredCount":1}'),
('fork_master','Fork Master','Win a game after performing a fork.','🍴','strategy',30,'{"requiredCount":1}'),
('no_pieces_lost','Untouchable','Win without losing a single piece.','🛡️','strategy',100,'{"requiredCount":1}'),
('accuracy_90','Precision Player','Finish a game with 90%+ accuracy.','🎯','strategy',50,'{"requiredCount":1}'),
('accuracy_95','Near Perfect','Finish a game with 95%+ accuracy.','💎','strategy',100,'{"requiredCount":1}'),
('zero_blunders','Clean Sheet','Win a game with zero blunders.','✨','strategy',40,'{"requiredCount":1}'),
('checkmate_fast','Speed Demon (checkmate_fast)','Checkmate in under 20 moves.','⚡','endgame',50,'{"requiredCount":1}'),
('scholars_mate','Scholar''s Mate','Win with a checkmate in 4 moves or less.','🎓','endgame',75,'{"requiredCount":1}'),
('back_rank_mate','Back Rank Assassin','Deliver a back rank checkmate.','🗡️','endgame',30,'{"requiredCount":1}'),
('queen_sacrifice','Queen Sacrifice','Sacrifice your queen and still win.','💀','endgame',75,'{"requiredCount":1}'),
('comeback_win','Comeback King (comeback_win)','Win after being down in material by 5+ points.','🦅','endgame',60,'{"requiredCount":1}'),
('stalemate_save','Escape Artist (stalemate_save)','Force a stalemate when losing.','🏃','endgame',40,'{"requiredCount":1}'),
('long_game','Marathon Runner','Play a game lasting 100+ moves.','🏃‍♂️','endgame',25,'{"requiredCount":1}'),
('bullet_win','Bullet Proof','Win a game with 1 minute time control.','🔫','speed',40,'{"requiredCount":1}'),
('blitz_win','Lightning Bolt','Win a blitz game (3-5 min).','⚡','speed',25,'{"requiredCount":1}'),
('rapid_win','Rapid Fire','Win a rapid game (10+ min).','🏹','speed',20,'{"requiredCount":1}'),
('win_on_time','Clock Master','Win a game on time (opponent runs out).','⏱️','speed',20,'{"requiredCount":1}'),
('survive_low_time','Clutch Player','Win with less than 10 seconds remaining.','😰','speed',50,'{"requiredCount":1}'),
('mp_first_win','World Beater','Win your first online multiplayer game.','🌍','social',30,'{"requiredCount":1}'),
('mp_win_10','Online Champion','Win 10 online multiplayer games.','🏅','social',75,'{"requiredCount":10}'),
('mp_win_50','Internet Legend','Win 50 online multiplayer games.','🌟','social',200,'{"requiredCount":50}'),
('donate_xp','Generous Soul','Donate XP to another player.','🎁','social',15,'{"requiredCount":1}'),
('chat_game','Social Butterfly','Send a chat message during an online game.','💬','social',5,'{"requiredCount":1}'),
('elo_1200','Rising Star (elo_1200)','Reach an ELO rating of 1200.','⭐','mastery',50,'{"requiredCount":1}'),
('elo_1500','Expert','Reach an ELO rating of 1500.','🌟','mastery',100,'{"requiredCount":1}'),
('elo_1800','Master','Reach an ELO rating of 1800.','🏆','mastery',200,'{"requiredCount":1}'),
('elo_2000','Grandmaster','Reach an ELO rating of 2000.','🎖️','mastery',500,'{"requiredCount":1}'),
('elo_2200','Super GM','Reach an ELO rating of 2200.','👑','mastery',1000,'{"requiredCount":1}'),
('puzzle_10','Puzzle Addict','Solve 10 puzzles.','🧩','collection',25,'{"requiredCount":10}'),
('puzzle_50','Puzzle Master','Solve 50 puzzles.','🧠','collection',75,'{"requiredCount":50}'),
('puzzle_rush_survive','Rush Survivor','Survive a full Puzzle Rush session.','🏃','special',30,'{"requiredCount":1}'),
('play_100_games','Century Club','Play 100 games in any mode.','🎉','collection',100,'{"requiredCount":100}'),
('daily_player','Dedicated','Play at least one game for 7 days in a row.','📅','special',50,'{"requiredCount":7}'),
('mp_matchmaker','Matchmaker','Win 5 online multiplayer games.','🎲','social',30,'{"requiredCount":5}'),
('mp_ladder_climber','Ladder Climber','Reach 1500+ rating in multiplayer.','📈','mastery',50,'{"requiredCount":1}'),
('mp_unstoppable_online','Unstoppable Online','Win 10 games in a row in multiplayer.','🔥','combat',100,'{"requiredCount":10}'),
('mp_blitz_king','Blitz King','Reach 1600+ rating in blitz time control.','👑','speed',75,'{"requiredCount":1}'),
('mp_rapid_master','Rapid Master','Reach 1700+ rating in rapid time control.','⚜️','mastery',75,'{"requiredCount":1}'),
('mp_classical_scholar','Classical Scholar','Play and complete 5 classical games (30+ min).','📖','mastery',60,'{"requiredCount":5}'),
('mp_tournament_victor','Tournament Victor','Win any online tournament.','🏅','social',100,'{"requiredCount":1}'),
('mp_comeback_king','Comeback King (mp_comeback_king)','Win after being down 2+ points of material.','💪','combat',50,'{"requiredCount":1}'),
('tc_bullet_fiend','Bullet Fiend','Win 20 bullet games.','⚡','speed',40,'{"requiredCount":20}'),
('tc_blitz_warrior','Blitz Warrior','Win 30 blitz games.','⚔️','combat',50,'{"requiredCount":30}'),
('tc_rapid_aficionado','Rapid Aficionado','Win 20 rapid games.','🎯','mastery',50,'{"requiredCount":20}'),
('tc_rapid_specialist','Rapid Specialist','Win 50 rapid games.','🎖️','mastery',100,'{"requiredCount":50}'),
('tc_time_management','Time Management','Win without using more than 60% of your time.','⏱️','strategy',40,'{"requiredCount":1}'),
('tc_depth_over_speed','Depth Over Speed','Win a game with 50+ moves.','♖','endgame',45,'{"requiredCount":1}'),
('cp_fortress_defender','Fortress Defender','Win despite opponent having 2+ point advantage.','🛡️','strategy',60,'{"requiredCount":1}'),
('cp_escape_artist','Escape Artist (cp_escape_artist)','Force a draw when facing certain defeat.','🆘','strategy',50,'{"requiredCount":1}'),
('cp_finisher','Finisher','Win 5 games with checkmate (not on time).','🎪','combat',55,'{"requiredCount":5}'),
('cp_precision_pressure','Precision Under Pressure','Maintain 80%+ accuracy while in time trouble.','💎','strategy',70,'{"requiredCount":1}'),
('cp_sacrifice_master','Sacrifice Master','Win a game after intentional material sacrifice.','💣','combat',65,'{"requiredCount":1}'),
('cp_promotion_victory','Promotion Victory','Win by promoting a pawn in multiplayer game.','👸','strategy',55,'{"requiredCount":1}'),
('sd_rising_star','Rising Star (sd_rising_star)','Win 3 games against rated higher players.','⭐','social',50,'{"requiredCount":3}'),
('sd_humble_victor','Humble Victor','Beat 5 different opponents.','🤝','social',40,'{"requiredCount":5}'),
('sd_revenge_master','Revenge Master','Beat same opponent twice in a row.','🎯','combat',35,'{"requiredCount":1}'),
('sd_tournament_dominator','Tournament Dominator','Win tournament with 100% score (no draws).','🏆','social',150,'{"requiredCount":1}'),
('sd_legendary_status','Legendary Status','Accumulate 500+ achievement points.','🌟','special',200,'{"requiredCount":1}'),
('daily_warrior','Daily Warrior','Play 5 multiplayer games in a single day.','🗓️','social',50,'{"requiredCount":5}'),
('gg_champion','GG Champion','Send "Good Game" or a friendly chat 10 times.','🤝','social',30,'{"requiredCount":10}'),
('bounty_hunter','Bounty Hunter','Capture the opponent''s Queen in 5 different multiplayer games.','🎯','combat',60,'{"requiredCount":5}'),
('speed_demon_mp','Speed Demon (speed_demon_mp)','Win a Bullet game in under 2 minutes.','⚡','speed',45,'{"requiredCount":1}'),
('tournament_star','Tournament Star','Participate in your first online tournament.','✨','special',25,'{"requiredCount":1}')
ON CONFLICT(id) DO UPDATE SET name=excluded.name,description=excluded.description,icon=excluded.icon,category=excluded.category,points=excluded.points,criteria=excluded.criteria;
