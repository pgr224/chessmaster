# Implementation Plan: Unified User Scoring System

This plan outlines the steps to consolidate user statistics and scoring data into a single, consistent source of truth, resolving discrepancies between the profile and leaderboard views.

## 1. Analysis of Current State

### Data Fragmentation
- **`users` Table**: Stores `xp`.
- **`user_stats` Table**: Stores `wins`, `losses`, `draws`, `elo_rating`, `games_played`, and mode-specific wins.
- **Inconsistency**: `POST /:id/xp` in `profile.ts` updates `wins` and `losses` but **fails to update `games_played`**, causing win rates to be calculated incorrectly.
- **Similar Columns**: `wins` (total) vs `multiplayer_wins`, `tournament_wins`, etc.

## 2. Proposed Changes

### Database Schema (Migration)
1.  **Move `xp`**: Transfer the `xp` column from `users` to `user_stats`.
2.  **Rename `user_stats`**: Rename the table to `user_scores` to reflect its role as the primary scoring entity.
3.  **Fix Inconsistencies**: Ensure `games_played` always equals `wins + losses + draws`.
4.  **Add Naming Consistency**: Ensure "Elo" is consistently used (resolving "ilo" typos).

### Data Integrity (Recalculation)
- Run a one-time script (based on `backfill_stats.sql`) to ensure all `wins`, `losses`, `draws`, and `games_played` columns are perfectly synced with the actual `games` history.

### Unified View
Create a SQL VIEW `unified_player_scores` that:
- Performs a `JOIN` between `users` and `user_scores`.
- Provides a "One Stop Shop" for all profile and leaderboard data.
- Ensures identical logic for ranking and stat display.

## 3. Implementation Steps

### Step 1: Migration Script
Create `migration_v14_unified_scores.sql`:
- Add `xp` to `user_stats`.
- Copy data: `UPDATE user_stats SET xp = (SELECT xp FROM users WHERE id = user_stats.user_id)`.
- Create the `unified_player_scores` view.

### Step 2: Update Backend Code
- **`StatsService.ts`**: Update to write `xp` and stats to the new unified location.
- **`profile.ts`**: Update the `POST /xp` route and `buildProfileData` to use the unified view/table.
- **`leaderboard.ts`**: Simplify the query by using the unified view.

### Step 3: Verify and Test
- Verify that `profile` and `leaderboard` return identical numbers for the same user.
- Ensure `games_played` correctly increments on new game completions.

## 4. Expected Outcome
- **Zero Drift**: Profile and Leaderboard statistics will be identical across the app.
- **Simplified Queries**: No more complex joins needed in every route.
- **Clean Schema**: Competitive data is separated from basic user account data.
