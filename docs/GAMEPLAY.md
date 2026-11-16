# Gameplay verification

Run the backend checks with Node 26 (the version used for these checks):

```sh
cd backend
npm ci
npm run type-check
npm run test:unit
npm run test:integration
```

The integration suite bundles the actual Worker entry point and runs Miniflare
with ephemeral D1, Durable Objects, authenticated HTTP requests, and WebSockets.
It requires permission to open local loopback sockets. It does not connect to
production D1, send real push notifications, or retain its test database.

The three integration scenarios passed locally:

- A private best-of-three series creates reserved tournament games, rejects
  nonparticipants and client-reported results, alternates colors, advances to
  round two, and finishes early after two wins. The winner receives 100 + 120 XP
  from the rounds and one 200 XP championship bonus; Elo increases by 40.
  Replayed results and reconnects preserve those totals.
- A public three-player round gives exactly one bye. Equal final scores produce
  a tie and no championship bonus.
- An ordinary multiplayer game enforces the takeback penalty, settles each
  participant once, and preserves rematch requests across reconnects. Duplicate
  acceptances and reconnects return the same rematch game with swapped colors.

The suite runs in about ten seconds, including the real five-second delay
between tournament rounds. Its source is
`backend/test/integration/rooms.test.ts`.

## Tournament storage

The fresh `backend/schema/d1-schema.sql` includes tournament type/round columns
and the `tournament_matches` table. Existing databases that already have the
columns from migration v11 can use
`backend/schema/migration_v20_tournament_matches.sql` to create missing match
storage. This migration creates the missing table/index without resetting
players, scores, or game history. No remote migration was run during verification.

## Scoring and release configuration

For existing databases already migrated through v17, inspect the schema and apply the new migrations in order: v18 native push (ADD COLUMN only once), v19 scoring/transfer/bounty ledgers, v20 missing tournament match storage, v21 complete profile scoring view, v22 achievement catalog. The v11 tournament type/round columns must already exist. Do not apply historical reset/clear scripts. Fresh databases use d1-schema.sql instead of replaying these ALTER migrations. No remote schema or production changes were performed.

Multiplayer uses expected-score Elo with K factors 40 (first 30 online games), 20, and 10 (2400+ established rating). Tournament round Elo retains the plan's +20/+5/-15; the champion bonus has no extra Elo. Both XP and Elo floor at zero, and game receipts preserve the actual applied delta including zero. Practice and local two-player games earn zero XP. Level 10 starts at 10,000 XP everywhere.

Tournament win/draw base XP gets +20% per prior win streak point; losses reset the streak, draws preserve it. The AI win multiplier grows 10% per prior streak point to a maximum of 2x. Underdog thresholds are 200–499 / 500–1000 / >1000. Perfect game is +1000 XP. The four-hour bounty is fixed across users for the whole window; its +50% bonus applies before penalties, and the temporary hunter badge lasts until that window ends. Donation caps are 2000/day and 10000 lifetime.

The server owns online moves, clocks, results and scoring. Offline AI/puzzle progress is queued locally and synchronized with stable event IDs; it still trusts the client to report offline play. These are application chess rules: threefold repetition and the 50-move rule end the game automatically, rather than requiring formal over-the-board claims. Online variants are restricted to standard chess until other rule engines exist.

Latest checks: 51 Flutter tests, 36 backend unit tests, 3 local integration tests, and 25 JavaScript checks passed. Flutter analysis has no errors; existing warnings and deprecation notices remain. Native Android/iOS compilation and physical-device notification delivery require platform toolchains/provisioning and have not been verified here.

## Hint and thinking behavior

Post-move coach feedback appears after human moves only in computer games (including practice), and after either side's move in multiplayer, tournaments and local two-player games. Human-game coaching is enabled by default and still observes the real-time coaching setting. Server move snapshots use the same coaching path as local moves; reconnects do not replay analysis. A message is discarded if its position changed while analysis was running. Computer replies clear previous hints/feedback.

Thinking animation requires a computer opponent, the computer's turn, and an active move search. Manual hint analysis does not set that flag or cancel computer searches. Unknown multiplayer opponent names no longer cause a fallback to a computer avatar. Post-move search uses one 350 ms analysis budget instead of a separate long timeout for every candidate. Search budget limits depth, so coaching is approximate rather than full engine analysis.

Verification after this change: 54 Flutter tests pass, including both-color visibility, human-only modes without thinking animation, both server-delivered multiplayer move colors, and reconnect de-duplication. Dart analysis reports no errors; existing warnings remain.

## Guest sessions

Guest play is offline-only: computer/practice, local two-player, bundled lessons and puzzles. Online route taps and deep links (multiplayer, rooms, tournaments, rankings, profile and XP sharing) lead to an account prompt with Create account, Log in and Keep playing offline choices. Game-end screens include the same gentle account invitation; leaving a guest game clearly explains that temporary XP and the game are discarded.

Guest XP, result receipts, stats and game records are memory-only. Leaving/restarting a game or reopening the app resets guest XP to zero. Guest actions never enter the account XP queue, update server achievements, or write game history to D1. Registering or logging in discards guest earnings rather than merging them into the account. Old guest event IDs cannot credit a newer guest session. Stale account login responses cannot replace a later guest choice.

Guest entry removes active bearer credentials and blocks authenticated network requests and socket connections. The previous registered profile cache is kept separate and never used as guest progression. Device ID generation and backend device binding remain unchanged; explicit login sends the same device ID and loads that account's existing progress.

The updated backend rejects guest JWT identities and filters historical guest IDs out of rankings and bounty selection. Existing installations should apply migration_v23_exclude_guest_ranking.sql after the earlier scoring migrations to update the profile view. The migration changes a view only; it does not delete users or reset registered XP. No remote database operation or deployment was performed.

Guest-specific regression checks cover cached-account/token isolation, zero-XP session restart, no game/XP sync, unchanged device-bound account login, stale login cancellation, online-route policy, mobile account-prompt navigation and keeping the registration form open during a guest reset. Full verification after these changes: 65 Flutter tests, 38 backend unit tests and 3 local multiplayer/tournament integration scenarios pass.
