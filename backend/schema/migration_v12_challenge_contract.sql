ALTER TABLE challenges ADD COLUMN mode TEXT NOT NULL DEFAULT 'duel';
ALTER TABLE challenges ADD COLUMN variant_id TEXT NOT NULL DEFAULT 'standard';
ALTER TABLE challenges ADD COLUMN delivery_status TEXT NOT NULL DEFAULT 'live';
ALTER TABLE challenges ADD COLUMN updated_at TEXT NOT NULL DEFAULT (datetime('now'));

UPDATE challenges
SET mode = COALESCE(mode, 'duel'),
    variant_id = COALESCE(variant_id, 'standard'),
    delivery_status = COALESCE(delivery_status, 'live'),
    updated_at = COALESCE(updated_at, created_at, datetime('now'));
