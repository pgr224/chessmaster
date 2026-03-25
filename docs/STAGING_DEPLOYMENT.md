# 🚀 Staging Deployment Guide — Chess Master

Deploy to staging for responsive UI validation across browsers and devices.

---

## Prerequisites

- Cloudflare account with API token access
- Wrangler CLI installed globally: `npm i -g wrangler` (v3.60+)
- Latest Flutter SDK and Node.js v20+
- Git access to repository

---

## Phase 1: Backend Staging Setup

### Step 1.1 — Create Staging D1 Database

```bash
cd backend

# Create staging D1 database
npx wrangler d1 create chess-master-db-staging

# Copy the database_id from output
```

Update `backend/wrangler.toml` in the `[env.staging]` section:
```toml
[[env.staging.d1_databases]]
binding = "DB"
database_name = "chess-master-db-staging"
database_id = "PASTE_ID_HERE"  # ← Update this with output from above
```

### Step 1.2 — Create Staging KV Namespace

```bash
# Create KV namespace for staging
npx wrangler kv:namespace create CHESS_KV --preview false --env staging

# Copy the id from output
```

Update `backend/wrangler.toml` in the `[env.staging.kv_namespaces]` section:
```toml
[[env.staging.kv_namespaces]]
binding = "CHESS_KV"
id = "PASTE_ID_HERE"  # ← Update this with id from above
```

### Step 1.3 — Run Staging Database Migrations

```bash
# From backend/ directory
npm run db:migrate:staging
```

### Step 1.4 — Set Staging JWT Secret

```bash
# Generate a strong JWT secret for staging (min 32 characters)
# Example: openssl rand -hex 32 → copy output

npm run secret:jwt:staging
# When prompted: paste the generated secret
```

### Step 1.5 — Deploy Backend to Staging

```bash
# Deploy to staging environment
npm run deploy:staging

# Output will show:
# ✓ Deployed to: https://chess-master-api-staging.YOUR_SUBDOMAIN.workers.dev

# Save this URL for later use
```

---

## Phase 2: Frontend Staging Setup

### Step 2.1 — Build Flutter Web Release

```bash
cd app

# Clean previous builds
flutter clean

# Build web for production-quality staging
flutter build web --release --web-renderer canvaskit

# Output: app/build/web/ (ready to deploy)
```

### Step 2.2 — Configure Staging Environment Variables

Create or update `app/.env.staging`:
```bash
API_URL=https://chess-master-api-staging.YOUR_SUBDOMAIN.workers.dev
WS_URL=wss://chess-master-api-staging.YOUR_SUBDOMAIN.workers.dev
ENVIRONMENT=staging
```

Update `app/lib/main.dart` to read staging environment variables:
```dart
const apiUrl = String.fromEnvironment('API_URL', 
  defaultValue: 'https://chess-master-api-staging.YOUR_SUBDOMAIN.workers.dev');
const wsUrl = String.fromEnvironment('WS_URL',
  defaultValue: 'wss://chess-master-api-staging.YOUR_SUBDOMAIN.workers.dev');
```

### Step 2.3 — Deploy to Cloudflare Pages (Manual Option)

```bash
cd ..  # Back to project root

# Deploy to Cloudflare Pages
npx wrangler pages deploy app/build/web --project-name=chess-master-staging
```

**Or via GitHub** (Recommended):
1. Push code to `staging` branch
2. Cloudflare Dashboard → Pages → Create Project
3. Connect GitHub repo
4. Build settings:
   - Build command: `cd app && flutter build web --release --web-renderer canvaskit`
   - Build output: `app/build/web`
   - Environment variables:
     - `API_URL`: `https://chess-master-api-staging.YOUR_SUBDOMAIN.workers.dev`
     - `WS_URL`: `wss://chess-master-api-staging.YOUR_SUBDOMAIN.workers.dev`

**Staging URL** will be: `https://chess-master-staging.pages.dev`

---

## Phase 3: Responsive Testing Plan

### Desktop Browsers (1920px)

```
✓ Browser: Chrome/Edge
✓ URL: https://chess-master-staging.pages.dev
✓ Dev Tools: Open → F12 → Inspect responsive behavior

Testing Checklist:
□ Game screen layout: Side-by-side (board left, info panel right)
□ Board sizing: Exactly 860×860px
□ Info panel: 330px fixed width
□ Captured pieces widget: Displays all pieces, scrolls horizontally
□ Player names: Full display, no ellipsis
□ Time grid: 3 columns visible
□ Buttons: "Play" button spans full width
□ Animations: Splash animations, piece movements smooth
```

### Tablet View (768px)

```
✓ Browser: Chrome DevTools → iPad dimensions
✓ Expected layout: Transitional (compact with side panel)

Testing Checklist:
□ Board sizing: 560px (responsive sizing active)
□ Info panel: Visible but constrained
□ Time grid: 2–3 columns adapting
□ Touch interactions: Tap pieces, select time controls
□ Scroll: Captured pieces scrolls smoothly
□ No horizontal overflow
```

### Mobile View (375px)

```
✓ Browser: Chrome DevTools → iPhone SE dimensions
✓ Expected layout: Fully vertical stack

Testing Checklist:
□ Board sizing: 300×300px (minimum)
□ Vertical layout: Top nav → opponent info → board → player info → actions
□ Time grid: 2 columns
□ Captured pieces: Horizontal scroll active
□ Player name: Ellipsis at ~120px width
□ Buttons: Stack vertically or wrap
□ No horizontal crop/overflow
□ Status bar readable
```

### Cross-Browser Testing

```
✓ Firefox: https://chess-master-staging.pages.dev
  □ Board rendering (CanvasKit)
  □ WebSocket connections (multiplayer)
  □ CSS animations (flutter_animate)
  □ Touch events (mobile)

✓ Safari (iOS): https://chess-master-staging.pages.dev
  □ board rendering (check for canvas issues)
  □ WebSocket support
  □ Touch responsiveness
  □ PWA install prompt

✓ Edge: https://chess-master-staging.pages.dev
  □ General compatibility
  □ Performance metrics
```

---

## Phase 4: Responsiveness Validation Checklist

### Layout Responsiveness

```
[ ] Desktop (1920px)
    [x] Side-by-side game layout
    [x] Board: 860px max
    [x] Info panel: Fixed 330px
    [x] No horizontal scroll

[ ] Tablet (768px)
    [x] Transitional layout active
    [x] Board: ~560px responsive
    [x] Time grid: 2–3 columns
    [x] Captured pieces scrollable

[ ] Mobile (375px)
    [x] Vertical stack layout
    [x] Board: 300px minimum
    [x] Time grid: 2 columns
    [x] No horizontal crop
```

### Content Fit Validation

```
[ ] Player Info Widget
    [x] Name displays without crop (ellipsis at 150px)
    [x] Piece color indicator visible
    [x] Status (thinking/ready) shows

[ ] Captured Pieces Widget
    [x] SingleChildScrollView active
    [x] Horizontal scroll smooth
    [x] All pieces visible (no crop)
    [x] Material value displays

[ ] Time Control Grid
    [x] Buttons readable at all sizes
    [x] 3 columns on desktop
    [x] 2 columns on mobile
    [x] No text overflow

[ ] Lobby Screen
    [x] Player list preview visible (wide)
    [x] DraggableScrollableSheet opens smoothly
    [x] Challenge buttons clickable
    [x] Hero animations play on all sizes
```

### Board Sizing Validation

```
[ ] Responsive Sizing (math.min logic)
    [x] Desktop (1920): 860×860px
    [x] Tablet (768): ~560×560px  
    [x] Mobile (375): ≥300×300px
    [x] Board never larger than viewport

[ ] Piece Rendering
    [x] Pieces render at all sizes
    [x] Selection highlights visible
    [x] Animation smooth
    [x] No pixelation on scaling

[ ] Coordinate Labels
    [x] Visible at all board sizes
    [x] Readable font size (scales)
    [x] Positioned correctly
```

### WebSocket/Multiplayer Validation

```
[ ] Lobby Connection
    [x] Players list loads
    [x] Challenge buttons functional
    [x] Create challenge works
    [x] Challenge notice displays

[ ] Game Connection
    [x] Moves sync in real-time
    [x] Opponent moves appear immediately
    [x] Board updates correctly
    [x] Captured pieces update live

[ ] Error Handling
    [x] Disconnection message shows
    [x] Reconnection attempts
    [x] Graceful fallback (demo mode)
```

---

## Performance Metrics (DevTools)

Run Lighthouse audit on staging:

```
DevTools → Lighthouse → Generate report
Target metrics:
  - FCP (First Contentful Paint): < 2s
  - LCP (Largest Contentful Paint): < 3s
  - CLS (Cumulative Layout Shift): < 0.1
  - First Input Delay: < 100ms
```

---

## Rollback Procedure

If issues found, rollback staging:

```bash
# Restore previous backend deployment
npm run deploy:staging  # (reinstall previous source)

# Or rollback via Cloudflare Dashboard:
# Pages → chess-master-staging → Deployments → Select previous → Rollback
```

---

## Next Steps (Post-Validation)

After responsive testing passes:

1. **Production Deployment**: `npm run deploy` (backend) + `wrangler pages deploy` (frontend)
2. **Custom Domain**: Chess Cloudflare Dashboard → Add custom domain
3. **Analytics**: Enable Cloudflare Analytics to track staging traffic
4. **Monitoring**: Set up real user monitoring (RUM) for production

---

## Troubleshooting

### WebSocket Connection Fails in Staging

**Error**: `WebSocket connection to 'wss://...' failed`

**Fix**:
```bash
# Verify staging backend URL is correct in environment
echo $API_URL  # should show chess-master-api-staging URL

# Check backend logs
wrangler tail --env staging

# If backend not deployed, run:
npm run deploy:staging
```

### Board Not Rendering at Full Size

**Error**: Board appears small on desktop

**Fix**:
```bash
# Clear browser cache
Ctrl+Shift+Delete (Windows) or Cmd+Shift+Delete (Mac)

# Refresh staging URL hard
Ctrl+F5 (Windows) or Cmd+Shift+R (Mac)

# Check responsive breakpoint (should be >= 1080px for side-by-side)
DevTools → Resize to 1200px → verify layout change
```

### Captured Pieces Cropping on Mobile

**Error**: Captured pieces get cut off on narrow screens

**Fix**: Already implemented (`SingleChildScrollView`), but verify:
```dart
// Check captured_pieces_widget.dart has horizontal scroll
SingleChildScrollView(scrollDirection: Axis.horizontal)
```

If still cropping, rebuild:
```bash
flutter clean
flutter build web --release
```

---

## Monitoring Dashboard

Monitor staging deployment health:

```
Cloudflare Dashboard → Workers → chess-master-api-staging → Logs
Cloudflare Dashboard → Pages → chess-master-staging → Analytics
```

Real-time metrics:
- Request latency
- WebSocket connection count
- Database query performance
- Error rates

---

## Sign-Off Checklist

Once validation complete, sign off:

- [ ] Desktop (1920px) responsive ✓
- [ ] Tablet (768px) responsive ✓
- [ ] Mobile (375px) responsive ✓
- [ ] All browsers tested (Chrome, Firefox, Safari, Edge) ✓
- [ ] No horizontal scroll on any screen size ✓
- [ ] Board sizing correct (300–860px range) ✓
- [ ] Captured pieces widget scrolls without crop ✓
- [ ] Player names display correctly ✓
- [ ] WebSocket multiplayer working ✓
- [ ] Lighthouse performance acceptable ✓
- [ ] Backend API responding correctly ✓

**Ready for production deployment!** 🎉
