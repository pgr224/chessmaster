# ♟️ Chess Master

> A production-ready, cross-platform Chess application with AI, online multiplayer, and tournaments.

[![Flutter](https://img.shields.io/badge/Flutter-3.22-blue?logo=flutter)](https://flutter.dev)
[![Cloudflare Workers](https://img.shields.io/badge/Cloudflare-Workers-orange?logo=cloudflare)](https://workers.cloudflare.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 🎮 Features

| Feature | Status |
|---------|--------|
| FIDE-compliant chess rules | ✅ |
| Single Player vs AI (4 levels) | ✅ |
| Two Player (local) | ✅ |
| Online multiplayer (WebSocket) | ✅ |
| Tournament bracket system | ✅ |
| Challenge system | ✅ |
| Interactive tutorial | ✅ |
| Offline-first architecture | ✅ |
| Board/piece themes | ✅ |
| Move animations | ✅ |
| Hint system | ✅ |
| Confetti win animation | ✅ |
| Leaderboard | ✅ |
| Achievement badges | ✅ |
| Share game (PGN) | ✅ |
| Chat system | ✅ |
| Anti-cheat (server validation) | ✅ |
| ELO rating system | ✅ |
| PWA support | ✅ |
| Android APK | ✅ |
| iOS IPA | ✅ |

## 🏗️ Architecture

```
chess/
├── app/           # Flutter (Android/iOS/Web/PWA)
├── backend/       # Cloudflare Workers + D1 + Durable Objects
├── docs/          # Deployment & API documentation
└── .github/       # CI/CD workflows
```

## 🚀 Quick Start

### Backend (Local Dev)
```bash
cd backend
npm install
npm run db:migrate    # Create local D1 DB
npm run dev           # Start dev server at localhost:8787
```

### Flutter App
```bash
cd app
flutter pub get
flutter run            # Run on connected device
flutter run -d chrome  # Run as web app
```

## 📦 Tech Stack

- **Frontend**: Flutter 3.22 (BLoC, GoRouter, flutter_animate)
- **Backend**: Cloudflare Workers (Hono framework)
- **Database**: Cloudflare D1 (SQLite-based)
- **Realtime**: CloudFlare Durable Objects (WebSocket)
- **Auth**: Device fingerprint + JWT
- **AI**: Minimax with α-β pruning + Stockfish WASM
- **Storage**: Hive (local offline), Cloudflare KV (server cache)
- **CI/CD**: GitHub Actions → Cloudflare Pages/Workers

## 📖 Documentation

- [Deployment Guide](docs/DEPLOYMENT.md)
- [API Reference](docs/API.md)
- [Security Guide](docs/SECURITY.md)

## 🔐 Security

- Server-side move validation (anti-cheat)
- JWT tokens bound to device fingerprint
- Rate limiting per IP/user
- All secrets via Wrangler secrets (never in code)
- CORS restricted to known origins

## 📄 License

MIT © 2024 Chess Master
