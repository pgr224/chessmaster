# 🦁 AI Coach System: Interactive Chess Mentor

The AI Coach system transforms the practice and single-player modes into an interactive learning experience. It provides real-time feedback, tactical hints, and mini-lessons to help players improve.

## 🧠 Brain: Coach Controller

The [CoachController](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/domain/engine/coach_controller.dart) acts as the logic engine:
- **Move Classification:** Compares player moves against the best Engine move using Stockfish.
- **Pattern Detection:** Identifies tactical patterns like Forks, Pins, Skewers, and Back-rank mates.
- **Personality Engine:** Adapts messaging based on chosen personality (Friendly, Strict, Motivational).
- **Non-Blocking Logic:** Evaluation is asynchronous to maintain smooth gameplay.

## ⚡ Integration: GameBloc

The [GameBloc](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/presentation/blocs/game/game_bloc.dart) orchestrates the coaching lifecycle:
- **Real-Time Analysis:** Evaluation starts automatically after every player move.
- **State Management:** Tracks `accuracy`, `mistakes`, `blunders`, and `hintedMoveHistory`.
- **Hint System:** Provides rich hints (Best move + explanation) costing 10 XP.
- **Undo Strategy:** Enforces a "one undo per move" rule for hinted positions to prevent brute forcing.

## ✨ UI: Feedback & Overlays

The UI is designed to be child-friendly, engaging, and premium:
- **Coach Overlays:** [CoachOverlayWidget](file:///d:/PP942920DRIVE/PROJECTS/chess/app/lib/presentation/widgets/coach_overlay_widget.dart) shows instant feedback (Brilliant, Blunder, etc.) with animated avatars.
- **Board Highlighting:** Suggested moves are highlighted with a glowing indicator.
- **Mini-Lessons:** Major blunders trigger a fullscreen training overlay with a "Take Back" option.
- **Action Bar:** New "Coach" button to toggle feedback and personality.

## 🛠️ Usage

1. **Start a Game:** Open Practice or Single Player mode.
2. **Make a Move:** Watch for the coach's bubble at the bottom.
3. **Request Help:** Use the "Hint" button for a 10 XP penalty to see the best move.
4. **Learn from Mistakes:** If you blunder, the coach will offer an immediate "Undo" to try again.
5. **Customize:** Click the "Coach" button in the action bar to switch personalities (e.g., from Friendly to Strict).
