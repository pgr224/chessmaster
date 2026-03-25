# Chess App — UI Overhaul & Dependency Updates

Transform the Chess Master app from a dark, adult-oriented design into a vibrant, child-friendly, artistic experience while keeping all existing functionality intact.

---

## Proposed Changes

### 1. Dependency Updates

#### [MODIFY] [pubspec.yaml](file:///d:/PP942920DRIVE/PROJECTS/chess/app/pubspec.yaml)

Run `flutter pub upgrade --dry-run` to identify safe bumps. The key constraints:
- Keep `flutter_bloc ^8.x`, `go_router ^14.x`, `equatable ^2.x` — these are tightly coupled
- Upgrade `flutter_animate`, `google_fonts`, `lottie`, `shimmer`, UI-only packages freely
- Keep `chess ^0.8.1` and `stockfish ^1.1.0` pinned (engine packages, no newer versions exist)
- After upgrading, run `flutter build web --release` to verify no breakage

---

### 2. Onboarding Animations (Generated Illustrations)

Generate 4 large, vibrant, semi-transparent illustrations using `generate_image`. Each image is a playful, cartoon-style artwork that matches the onboarding section:

| Page | Title | Image Description |
|------|-------|-------------------|
| 1 | Welcome | Colorful chess pieces (king, queen, pawn) bouncing happily on a rainbow board |
| 2 | AI Opponent | A friendly robot holding a chess piece, smiling, with sparkles |
| 3 | Multiplayer | Two kids on opposite sides of a globe, playing chess with joy |
| 4 | Learn & Improve | An open magic book with chess pieces flying out like stars |

Files placed in `assets/images/onboarding_1.png` through `onboarding_4.png`.

#### [MODIFY] [onboarding_screen.dart](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/presentation/screens/onboarding/onboarding_screen.dart)

- Replace emoji placeholders with the generated `Image.asset()` illustrations
- Add `flutter_animate` effects: `.fadeIn()`, `.scale()`, `.shimmer()` on the images
- Use large, rounded text with `Fredoka` font from `google_fonts`
- Add a soft gradient background per page using warm, vibrant colors

---

### 3. UI Rewrite — Child-Friendly Artistic Style

> [!IMPORTANT]
> **Design Principles:** Large text (18px+), rounded corners (20px+), warm vibrant colors (candy pink, sky blue, sunshine yellow, mint green), playful fonts (`Fredoka` for headings, `Baloo 2` for body), bouncy animations, no small/muted text. A 3-year-old should be able to tap the right button.

#### [MODIFY] [app_theme.dart](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/core/theme/app_theme.dart)

Replace the dark midnight palette with a warm, vibrant, child-friendly palette:

| Old Color | New Color | Purpose |
|-----------|-----------|---------|
| `midnight #0A0E27` | `#1A1A2E` (soft dark navy) | Still dark but warmer |
| `goldPrimary #D4AF37` | `#FFD93D` (bright sunshine yellow) | Primary accent |
| `accentCyan #00D4FF` | `#6BCB77` (fresh mint green) | Secondary |
| `accentPurple #7B61FF` | `#FF6B9D` (candy pink) | Tertiary |
| `accentRed #FF3D71` | `#FF8A5C` (warm coral) | Alerts |

- Replace `GoogleFonts.outfit` → `GoogleFonts.fredoka` for headings
- Replace `GoogleFonts.inter` → `GoogleFonts.baloo2` for body text
- Increase default font sizes by ~2px across the board
- Increase default border radius from 16px → 24px

#### [MODIFY] [splash_screen.dart](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/presentation/screens/splash/splash_screen.dart)

- Use the new warm gradient background
- Make the chess piece icon larger (120px → 160px) and add a bounce animation
- Use `Fredoka` for "CHESS MASTER" title with rainbow gradient text
- Add sparkling particle-like shimmer effects

#### [MODIFY] [home_screen.dart](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/presentation/screens/home/home_screen.dart)

- Replace small mode cards with **large, colorful, rounded pills** (each 80px+ tall)
- Each game mode card gets a unique bright gradient (pink, blue, green, yellow, purple)
- Enlarge all text to 18px+ for readability
- Replace emoji icons with larger, more prominent emoji (64px font size)
- Make the daily puzzle card more colorful with a rainbow border

#### [MODIFY] [game_setup_screen.dart](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/presentation/screens/game/game_setup_screen.dart)

- Use large, chunky selector buttons instead of compact rows
- Add colorful emoji backgrounds to difficulty options
- Make the "Start Game" button extra large (64px height) with a bouncy press animation

#### Remaining Screens (lighter touch)

- [profile_screen.dart](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/presentation/screens/profile/profile_screen.dart): Update colors and fonts to match new theme
- [learn_screen.dart](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/presentation/screens/learn/learn_screen.dart): Same treatment
- [tournament_screen.dart](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/presentation/screens/tournament/tournament_screen.dart): Same treatment
- [lobby_screen.dart](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/presentation/screens/multiplayer/lobby_screen.dart): Same treatment

### 4. Replace Tournament Mode with "Chess World" (News & Events)

> [!IMPORTANT]
> The user requested to completely remove the old "Tournament" mode (which simulated brackets/multiplayer tournaments) and replace it with a new informative section acting as a news feed for global tournaments, contact info for participation, and resources for building a chess career.
> **Proposed Title:** "Chess World" or "News & Events"

#### [MODIFY] [app_router.dart](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/core/router/app_router.dart)
- Remove [TournamentScreen](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/presentation/screens/tournament/tournament_screen.dart#25-195) and [BracketScreen](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/presentation/screens/tournament/bracket_screen.dart#22-142) routes (`/tournaments`, `/tournament/:id/bracket`).
- Add a new route `/chess_world` pointing to `ChessWorldScreen`.

#### [MODIFY] [home_screen.dart](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/presentation/screens/home/home_screen.dart)
- Replace the "Tournament" card on the home screen with "Chess World" (or "News & Events").
- Use an appropriate icon (e.g., globe or newspaper) and wire the `onTap` to `/chess_world`.

#### [DELETE] [tournament_screen.dart](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/presentation/screens/tournament/tournament_screen.dart)
#### [DELETE] [bracket_screen.dart](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/presentation/screens/tournament/bracket_screen.dart)
- Delete the old tournament UI files.

#### [NEW] [chess_world_screen.dart](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/presentation/screens/news/chess_world_screen.dart)
Create a new screen that follows the vibrant, child-friendly theme. It will contain three main scrollable sections/cards:
1. **Global Tournament News:** A feed of recent and trending global chess tournaments (e.g., FIDE World Championship, Candidates Tournament) formatted playfully.
2. **Upcoming & Participation:** Information on how to register for ongoing/upcoming kids and amateur tournaments, including placeholder contact emails (e.g., "contact@chesskids.org").
3. **Career in Chess:** Useful reference links/tips (books, grandmaster paths, rating systems) to inspire a career in chess.
- Use `ListView` with colorful `Container` cards, `google_fonts`, and `flutter_animate` for a polished look.

#### [MODIFY] [game_config.dart](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/data/models/game_config.dart)
- Remove `tournament` from the `GameMode` enum as it's no longer a playable mode.

---

## Verification Plan

### Automated Tests
1. Run `flutter build web --release --no-tree-shake-icons` from `d:\PP942920DRIVE\PROJECTS\chess\app` — must succeed with exit code 0.
2. Run `flutter analyze` from `d:\PP942920DRIVE\PROJECTS\chess\app` — errors count must be 0 (warnings/infos acceptable).

### Manual Verification
1. **Open the live site** at `https://chessmaster-app.pages.dev` after final deployment.
2. **Home screen**: Confirm the "Tournament" card is replaced by "Chess World".
3. **Chess World Area**: Tap the card and verify it navigates to the new informational screen. Ensure the three sections (News, Participation, Career) are visible, colorful, and well-formatted.
4. Verify there are no dead links or remaining "Tournament logic" errors in the console.
