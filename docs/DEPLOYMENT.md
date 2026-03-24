# 🚀 Chess Master — Deployment Guide

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter | ≥ 3.22 | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Node.js | ≥ 20 | [nodejs.org](https://nodejs.org) |
| Wrangler CLI | ≥ 3.60 | `npm i -g wrangler` |
| Git | Latest | [git-scm.com](https://git-scm.com) |

---

## Step 1 — Cloudflare Account Setup

```bash
# Login to Cloudflare
npx wrangler login

# Verify account
npx wrangler whoami
```

---

## Step 2 — Create D1 Database

```bash
cd backend

# Create production DB
npx wrangler d1 create chess-master-db

# Copy the database_id from output → paste into wrangler.toml

# Create dev DB
npx wrangler d1 create chess-master-db-dev
```

Update `wrangler.toml`:
```toml
[[d1_databases]]
database_id = "YOUR_ACTUAL_ID_HERE"  # ← replace this
```

---

## Step 3 — Create KV Namespace

```bash
npx wrangler kv:namespace create CHESS_KV
# Copy the id → paste into wrangler.toml [kv_namespaces]
```

---

## Step 4 — Run Database Migrations

```bash
# Local development DB
npm run db:migrate

# Production (remote)
npm run db:migrate:remote
```

---

## Step 5 — Set Secrets

```bash
# Generate and set JWT secret
npm run secret:jwt
# When prompted, enter a strong random string (min 32 chars)
# E.g.: openssl rand -hex 32
```

---

## Step 6 — Deploy Backend (Workers)

```bash
# Deploy to production
npm run deploy

# Or deploy dev environment
npm run deploy:dev

# Your Workers URL will be: https://chess-master-api.YOUR_SUBDOMAIN.workers.dev
```

---

## Step 7 — Deploy Flutter Web (Cloudflare Pages)

### Option A: GitHub Auto-Deploy (Recommended)

1. Push code to GitHub
2. Go to Cloudflare Dashboard → Pages → Create Project
3. Connect GitHub repo
4. Build settings:
   - **Build command**: `cd app && flutter build web --release --web-renderer canvaskit`
   - **Build output**: `app/build/web`
   - **Root directory**: `/`
5. Set environment variables:
   - `API_URL` = `https://chess-master-api.YOUR_SUBDOMAIN.workers.dev`
   - `WS_URL` = `wss://chess-master-api.YOUR_SUBDOMAIN.workers.dev`

### Option B: Manual Deploy

```bash
cd app
flutter build web --release --web-renderer canvaskit

cd ..
npx wrangler pages deploy app/build/web --project-name=chess-master
```

---

## Step 8 — Custom Domain

1. Cloudflare Dashboard → Pages → chess-master → Custom Domains
2. Add `chess.yourdomain.com`
3. Cloudflare auto-provisions SSL

For Workers API:
1. Dashboard → Workers → chess-master-api → Triggers → Custom Domains
2. Add `api.chess.yourdomain.com`

---

## Step 9 — GitHub Actions (CI/CD)

Add these secrets to your GitHub repo (`Settings → Secrets`):

```
CLOUDFLARE_API_TOKEN   ← Cloudflare API token with Pages & Workers permissions
CLOUDFLARE_ACCOUNT_ID  ← Your Cloudflare Account ID
KEYSTORE_PASSWORD       ← Android signing keystore password (for APK builds)
```

Generate Cloudflare API token:
1. `dash.cloudflare.com` → Profile → API Tokens
2. Create Token → Custom → Permissions:
   - Workers Scripts: Edit
   - D1: Edit
   - Pages: Edit

---

## Step 10 — Build Mobile Apps

### Android APK

```bash
cd app

# Create keystore (first time only)
keytool -genkey -v -keystore android/app/release-key.jks \
  -alias chess-master -keyalg RSA -keysize 2048 -validity 10000

# Build release APK
flutter build apk --release

# Output: app/build/app/outputs/flutter-apk/app-release.apk

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

### iOS IPA

```bash
cd app
flutter build ios --release

# Open Xcode → Product → Archive → Distribute
open ios/Runner.xcworkspace
```

---

## Step 11 — PWA Configuration

`app/web/manifest.json` is auto-generated. For production, update:
- `name`: "Chess Master"
- `short_name`: "Chess"
- `theme_color`: "#0A0E27"
- `background_color`: "#0A0E27"
- Add high-res icons (192×192, 512×512)

---

## Environment Configuration

| Variable | Development | Production |
|----------|-------------|-----------|
| `API_URL` | `http://localhost:8787` | `https://api.chess.yourdomain.com` |
| `WS_URL` | `ws://localhost:8787` | `wss://api.chess.yourdomain.com` |

---

## Performance Checklist

- [ ] Enable Cloudflare Caching for static assets
- [ ] Set Cache-Control headers on Workers responses
- [ ] Enable Brotli compression on Pages
- [ ] Use `--web-renderer canvaskit` for consistent Flutter rendering
- [ ] Enable Flutter web service worker for PWA caching
- [ ] Set up Cloudflare R2 for avatar/asset storage

---

## Security Checklist

- [ ] JWT_SECRET is 32+ chars and stored as Wrangler secret
- [ ] CORS restricted to your domains only
- [ ] Rate limiting configured (100 req/min default)
- [ ] D1 database not publicly accessible
- [ ] All API routes use auth middleware except `/auth/*`
- [ ] WebSocket connections validated server-side
- [ ] Move validation happens server-side (anti-cheat)

---

## Monitoring

```bash
# Live tail Workers logs
npx wrangler tail

# D1 query analytics
npx wrangler d1 info chess-master-db
```
