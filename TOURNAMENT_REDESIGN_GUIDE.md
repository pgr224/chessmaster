# 🏆 Enhanced Tournament Lobby Screen Implementation Guide

## New Components to Add

### 1. Opponent Spotlight Card
```dart
Widget _buildOpponentSpotlight(TournamentState ts, String? myId) {
  // Shows:
  // - Next opponent avatar + name + rating
  // - Head-to-head record
  // - Win probability
  // - Recent games with opponent
  // - "View Profile" button
}
```

### 2. Visual Standings Podium
```dart
Widget _buildTopThreePodium(List<TournamentPlayer> players) {
  // Shows top 3 as large cards with:
  // - Avatar
  // - Place (🥇 🥈 🥉)
  // - Player name
  // - Score/Points
  // - Rating
  // - Point lead/deficit to next position
}
```

### 3. Tournament Rewards Display
```dart
Widget _buildRewardsPreview(TournamentState ts) {
  // Shows:
  // - 1st Place: XXX XP + Badge
  // - 2nd Place: XXX XP + Badge
  // - 3rd Place: XXX XP + Badge
  // - Participation: XXX XP
  // - Bonus multipliers
}
```

### 4. Analytics Dashboard
```dart
Widget _buildAnalyticsDashboard(TournamentState ts) {
  // Shows metrics:
  // - Rating trajectory (line graph)
  // - Accuracy progression per round
  // - Time management effectiveness
  // - Pairings strength analysis
}
```

### 5. Enhanced Pairings List
```dart
Widget _buildPairingsList(List<TournamentPairing> pairings) {
  // Shows:
  // - Past rounds with results (moves, captures, eval swing)
  // - Current round with live timer
  // - Upcoming rounds (scheduled time)
  // - Expandable details for each game
}
```

### 6. Share & Social Elements
```dart
Widget _buildShareActions(TournamentState ts) {
  // Buttons:
  // - 📱 Share: "I'm in 1st place! Join tournament: [link]"
  // - 📊 View Stats
  // - 🔔 Notify Me
}
```

---

## Screen Layout (New Structure)

```
┌─────────────────────────────────────────┐
│ AppBar: 🏆 TOURNAMENT HQ                │
├─────────────────────────────────────────┤
│                                         │
│  STATUS BANNER (animated)               │
│  ┌─────────────────────────────────────┐│
│  │ 📊 Round 3/5 | Score: 2.5/3 🥇    ││
│  └─────────────────────────────────────┘│
│                                         │
│  OPPONENT SPOTLIGHT (NEW)               │
│  ┌─────────────────────────────────────┐│
│  │ ⚡ NEXT: vs "DragonKing" 1650     ││
│  │ H2H: You 1-0 | Prediction: 62%    ││
│  │ [View Profile]                     ││
│  └─────────────────────────────────────┘│
│                                         │
│  VISUAL STANDINGS (NEW)                 │
│  🥇 You (2.5p)  🥈 Alice (2.0p)       │
│  🥉 Bob (1.5p)                         │
│                                         │
│  PAIRINGS HISTORY (ENHANCED)            │
│  ✅ R1: W vs Alice (moves: 34, eval:5)│
│  ✅ R2: D vs Bob (moves: 42, eval:3)  │
│  ⏳ R3: LIVE vs DragonKing (playing...) │
│  ⏰ R4: Scheduled 14:30                 │
│  ⏰ R5: Not paired yet                  │
│                                         │
│  REWARDS PREVIEW (NEW)                  │
│  🏆 1st: 500 XP + "Tournament Victor"  │
│  🥈 2nd: 300 XP + "Runner Up"          │
│  🥉 3rd: 200 XP                         │
│                                         │
│  FULL STANDINGS TABLE                   │
│  [Rank | Player | Score | Rating]      │
│                                         │
│  SHARE ACTIONS (NEW)                    │
│  [📱 Share] [📊 Stats] [🔔 Notifications] │
│                                         │
└─────────────────────────────────────────┘
```

---

## Implementation Checklist

### Phase 1: Visual Enhancements
- [ ] Redesign status banner with round/score info
- [ ] Create opponent spotlight card component
- [ ] Build visual standings podium (top 3)
- [ ] Enhance pairings list with details

### Phase 2: Data & Logic
- [ ] Add H2H record calculation
- [ ] Implement win probability formula
- [ ] Create ratings trajectory data
- [ ] Build analytics metrics

### Phase 3: Interactive Features
- [ ] Add share button with deep linking
- [ ] Implement favorite opponent tracking
- [ ] Create stats modal/page
- [ ] Add notifications toggle

### Phase 4: Polish & Animations
- [ ] Add entrance animations to cards
- [ ] Smooth transitions between rounds
- [ ] Pulse animation for live games
- [ ] Confetti celebration for position improvements

---

## Key Enhancements Over Current Version

| Aspect | Current | Enhanced |
|--------|---------|----------|
| Opponent info | None | Full spotlight card with H2H + prediction |
| Visual standings | Table only | Podium + full table |
| Reward display | Hidden | Prominent preview with XP breakdowns |
| Analytics | None | Full dashboard with metrics |
| Social features | None | Share + favorites + stats |
| Engagement messaging | Generic | Contextual + motivational |
| Live updates | Table only | Real-time spotlight + notifications |

---

## Expected Player Impact

**Before Redesign:**
- Players view standings passively
- No engagement with upcoming opponents
- Minimal social interaction
- Low motivation between rounds

**After Redesign:**
- Players check opponent preview before games
- Share tournaments with friends (viral growth)
- Track detailed performance metrics
- Higher engagement during waiting periods
- More competitive motivation

---

## Data Requirements

### Tournament Model Extensions
```typescript
interface TournamentPlayer {
  // Existing
  userId: string
  username: string
  rating: number
  
  // Add:
  totalScore: number        // Win = 1, Draw = 0.5, Loss = 0
  accuracy: number          // Average accuracy
  averageElo: number        // Average opponent rating
  longestWinStreak: number  // Consecutive wins
  ratingChange: number      // Rating delta from start
}

interface TournamentPairing {
  // Existing
  whiteId: string
  blackId: string
  result: GameResult
  
  // Add:
  moveCount: number
  captureCount: number
  longestPiece: Piece
  evalSwing: number
  whiteAccuracy: number
  blackAccuracy: number
  timeUsed: { white: number; black: number }
}
```

