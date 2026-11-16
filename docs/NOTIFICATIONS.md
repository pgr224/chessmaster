# Notification setup and verification

## Firebase-free option with Cloudflare D1

The installed web app uses standards-based Web Push. The existing Cloudflare Worker sends encrypted messages with VAPID, and D1 stores subscriptions and player preferences. This path needs no Firebase project, Firebase database, FCM service account, or native Apple provisioning. Generate VAPID credentials and configure the Worker secrets described below; notification delivery is not enabled merely by having D1.

On iOS/iPadOS 16.4 or later, install the web app using Add to Home Screen, open it there, and enable notifications using the device button. Apple documents these requirements at https://developer.apple.com/documentation/usernotifications/sending-web-push-notifications-in-web-apps-and-browsers . Android requires a supported browser and notification permission. OS settings control final presentation and sound.

Cloudflare hosts the sender and storage; its platform Alerts/Notifications product is not an app-device push delivery replacement. Workers/D1 free allowances can cover small usage; usage beyond plan allowances may require a paid plan. No unlimited-free claim is made.

Native Flutter push remains an optional integration. The implemented native adapter requires FCM and, for iOS delivery, APNs configuration. FCM is a no-cost Firebase product and can be used solely for messaging while all game data remains in D1: https://firebase.google.com/products/cloud-messaging/ . A direct APNs native adapter would be a separate implementation; it is not part of the current integration. With Firebase unconfigured, native push stays disabled and the game remains usable.


The code supports native Android/iOS notifications through Firebase Cloud Messaging (FCM), plus installed-web/PWA notifications through standard Web Push and VAPID. Web delivery does not use Firebase. Both paths share the authenticated account's master switch and five category preferences.

**Current verification:** provider credentials and platform configuration are not supplied in this checkout. Automated tests verify encryption, authenticated preference/token ownership, permission and unsubscribe behavior, and notification tap routes with mocks. Actual Android, iPhone, APNs, FCM, and installed-PWA delivery has not been verified. The `/api/push/status` response checks whether configuration values exist; it does not validate credentials or prove delivery.

## How this implementation works

| Category | Stored preference | Existing producers |
| --- | --- | --- |
| `challenges` | `challenge_notifications` | Match invitations and challenge responses |
| `games` | `game_notifications` | Opponent waiting for a match |
| `community` | `community_notifications` | Direct XP requests and request responses |
| `tournaments` | `tournament_notifications` | Tournament invitations |
| `system` | `system_notifications` | Available to system events; no recurring broadcast is configured |

The master switch is `users.push_enabled`. `PushService` checks it and the selected category before contacting either provider. Turning a category off does not revoke the entire device subscription. Turning the master switch off revokes this browser subscription/native FCM token and saves the account setting. Signing out also revokes the local subscription/token. Expired web endpoints (HTTP 404/410) and FCM `UNREGISTERED` tokens are removed when a delivery attempt encounters them.

`SettingsBloc` saves explicit changes locally, keeps a dirty marker when offline, and retries them on authenticated load. Successful writes clear the marker. Clean loads accept server preferences so another device's opt-out remains effective. Token refresh registers a device without replacing account preferences with local defaults. OS notification settings remain a separate permission layer.

Tap handling supports `gameId`, `tournamentId`, challenge `requestId`, and direct-XP `requestId`. Native cold-start taps wait for sign-in. Web taps use the app's deployment base and Flutter hash routes; a notification action opens the app, where normal authenticated checks still apply.

## Backend and database

Use `backend/` as the working directory for Wrangler commands. The configured API is selected independently in the Flutter build with `--dart-define=API_URL=https://your-api.example`.

New databases use `schema/d1-schema.sql`, which includes notification preferences and native tokens. For an existing database that already has the v17 push tables, inspect its schema before applying the additive v18 migration:

```sh
npx wrangler d1 execute YOUR_DATABASE --remote --command 'PRAGMA table_info(user_notification_preferences)'
npx wrangler d1 execute YOUR_DATABASE --remote --command 'PRAGMA table_info(native_push_tokens)'
```

If `game_notifications` is missing, apply `schema/migration_v18_native_push.sql` once. Its `ALTER TABLE ... ADD COLUMN` is not repeatable. If the column already exists but `native_push_tokens` is absent, execute only that migration's `CREATE TABLE IF NOT EXISTS` and `CREATE INDEX IF NOT EXISTS` statements. Do not reset the database or rerun the full schema against an existing installation. Select the matching Wrangler environment/database explicitly.

Authenticated endpoints are:

| Endpoint | Purpose |
| --- | --- |
| `GET /api/push/status` | Report presence of web/native configuration |
| `GET` / `PUT /api/push/settings` | Read or partially update master/category preferences |
| `POST /api/push/subscribe` | Bind a browser subscription to the JWT account |
| `POST /api/push/unsubscribe` | Remove that account's browser endpoint |
| `POST` / `DELETE /api/push/native-token` | Register or remove an Android/iOS FCM token |

`GET /api/push/vapid-public-key` is public and returns 503 when Web Push is unconfigured. Client-supplied `userId` values cannot select another account for registration or preference updates. A browser endpoint or native token moves to its current authenticated account when registered again.

## Installed web / PWA

1. Generate one P-256 VAPID key pair for the deployment. The implementation accepts a base64url-encoded 65-byte uncompressed public key and either a base64url 32-byte private scalar or PKCS#8 private PEM. Keep the same pair across deployments; changing it requires resubscribing existing browsers. Encryption and authentication follow [RFC 8291](https://www.rfc-editor.org/rfc/rfc8291.html) and [RFC 8292](https://www.rfc-editor.org/rfc/rfc8292.html).
2. Set `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, and `VAPID_SUBJECT` as Worker secrets. The subject is the owner's real `mailto:` contact or HTTPS contact URL. For each name, run `npx wrangler secret put NAME` in the intended environment. Keep private keys in backend secrets, never Flutter defines or web assets.
3. Serve the built app over HTTPS with its manifest, icons, `push_bootstrap.js`, and `sw.js`. If deployed below `/`, use the matching Flutter `--base-href=/your/path/`; worker registration and notification links derive their scope from this base.
4. Sign in to the installed app, open **Settings → Notifications**, and use the explicit enable action. Merely loading the app does not request permission. If permission was denied, change it in browser/OS settings before trying again.
5. On iPhone/iPad, add the app to the Home Screen and launch that installed app before enabling notifications. Home Screen Web Push is supported from iOS/iPadOS 16.4, and the permission request must follow user interaction. See [WebKit's platform guidance](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/).

For a new deployment, this Node command creates compatible VAPID key files in the owner's terminal. It refuses to overwrite existing files:

```sh
node --input-type=module <<'JS'
import { generateKeyPairSync } from 'node:crypto';
import { writeFileSync } from 'node:fs';
const { publicKey, privateKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const pub = publicKey.export({ format: 'jwk' });
const uncompressed = Buffer.concat([Buffer.from([4]), Buffer.from(pub.x, 'base64url'), Buffer.from(pub.y, 'base64url')]);
writeFileSync('vapid-public.key', uncompressed.toString('base64url'), { mode: 0o600, flag: 'wx' });
writeFileSync('vapid-private.key', privateKey.export({ format: 'jwk' }).d, { mode: 0o600, flag: 'wx' });
JS
npx wrangler secret put VAPID_PUBLIC_KEY < vapid-public.key
npx wrangler secret put VAPID_PRIVATE_KEY < vapid-private.key
npx wrangler secret put VAPID_SUBJECT
```

Use the existing pair for an established deployment; do not rotate it as a routine setup step. Store the private file in the owner's secret storage after uploading it.

The web worker handles notifications; it does not preload the whole game for offline use. Background delivery is subject to browser, OS, and network availability. There is no periodic polling fallback.

## Firebase project and native apps

Create or select an owner-controlled Firebase project and register both native applications with their final identifiers. This checkout still uses Android `com.example.chess_master` and iOS `com.example.chessMaster`; any identifier change must also be reflected in Firebase and signing/provisioning. [Firebase's Flutter setup](https://firebase.google.com/docs/flutter/setup) describes the owner login and `flutterfire configure` workflow.

Choose one configuration method supported by `web_push_config_native.dart`:

- **Platform configuration files:** place the matching `google-services.json` in `app/android/app/` and add `GoogleService-Info.plist` to the iOS Runner target. Build with `--dart-define=FIREBASE_NOTIFICATIONS_ENABLED=true`. Android applies the Google Services Gradle plugin only when its JSON file exists. The generated `firebase_options.dart` is not imported by this adapter; adding that file alone does not activate this path.
- **Explicit Firebase options:** provide `FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`, `FIREBASE_MESSAGING_SENDER_ID`, and the applicable `FIREBASE_ANDROID_APP_ID` or `FIREBASE_IOS_APP_ID` through Dart defines. iOS also accepts `FIREBASE_IOS_BUNDLE_ID`. Leave `FIREBASE_NOTIFICATIONS_ENABLED` false for this method so the explicit options are used. These client identifiers are distinct from the server service-account private key.

Without either complete method, the native adapter stays inactive and chess still launches.

### Android owner setup

Use an FCM-capable device or emulator with Google Play services. The manifest includes Internet and Android notification permissions, the default notification channel, and a monochrome `ic_stat_chess` drawable. The app creates `chess_challenges`, `chess_games`, `chess_community`, `chess_tournaments`, and `chess_system` channels. Their importance/sound can also be changed by the user in Android settings. The explicit enable action requests the OS permission when applicable.

The Gradle setup includes Java 17 and core-library desugaring for local notifications. Build with the owner's Android SDK and normal release signing; for the platform-file method:

```sh
flutter build appbundle --release \
  --dart-define=FIREBASE_NOTIFICATIONS_ENABLED=true \
  --dart-define=API_URL=https://your-api.example
```

### iOS / APNs owner setup

On macOS, open `app/ios/Runner.xcworkspace`, select the owner's Apple team and correct bundle ID, and ensure the signing profile includes **Push Notifications**. Enable the appropriate background notification capability; `Info.plist` already includes `remote-notification`. Runner's entitlements use `APS_ENVIRONMENT`, with development and production settings in the Xcode project.

Upload the owner's APNs `.p8` authentication key, key ID, and team ID in the Firebase project's Apple Cloud Messaging configuration. Leave Firebase method swizzling enabled. The adapter waits for an APNs token before requesting an FCM token; missing APNs registration prevents native delivery. See [Firebase's Apple/Flutter FCM prerequisites](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).

Build/archive with that owner's provisioning and Firebase configuration, then test on a physical iPhone. No APNs key, provisioning profile, or signed device test was supplied for this implementation.

### Worker credentials for native delivery

Enable the Firebase Cloud Messaging HTTP v1 API and grant the server service account permission to send messages for the app's Firebase project. Store that account's JSON as `FCM_SERVICE_ACCOUNT` in the selected Worker environment; the implementation reads `project_id`, `client_email`, and `private_key`. For example, the owner can supply a protected JSON file via stdin:

```sh
npx wrangler secret put FCM_SERVICE_ACCOUNT < /secure/path/service-account.json
```

The Worker obtains an OAuth access token and calls FCM's HTTP v1 endpoint. FCM delivers Apple notifications through the configured APNs connection. This is a server credential, not an Android/iOS config file. See [FCM HTTP v1 server authorization](https://firebase.google.com/docs/cloud-messaging/send/v1-api).

## Verification before calling delivery complete

Run the mocked checks from their respective directories:

```sh
# backend/
node --import tsx --test --test-isolation=none src/services/web_push_crypto.test.ts src/routes/push.test.ts
npm run type-check

# app/
flutter test test/notification_preferences_test.dart test/notification_routes_test.dart
node --test test/web/push_bootstrap.test.cjs test/web/service_worker.test.cjs
```

Then use two authorized test accounts and the actual configured deployment. Send a match invitation, a waiting-game alert, a tournament invitation, and a direct XP request through their normal app flows. On Android, iPhone, and an installed PWA, verify foreground, background, and cold-start delivery; notification taps; permission refusal; every category toggle; master opt-out; sign-out; and token/account switching. In foreground, native notifications are displayed once by the local-notification adapter; background notification payloads are displayed by the OS.

Confirm that opt-out prevents new provider sends and that a signed-out device stops receiving the previous account's alerts. Provider acceptance (`sent`) is not proof that a device displayed a notification. Record the tested OS/app versions and delivery results separately; until those physical-device checks pass, delivery remains unverified.
