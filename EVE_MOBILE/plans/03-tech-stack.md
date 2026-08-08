# EVE Tech Stack — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the concrete environment, dependency, and infrastructure layer — Firebase project, Flutter package set, Cloud Functions scaffold, Gemini secret handling, Cloud Scheduler notification dispatch, and local emulator dev loop — that every other EVE plan assumes already exists.

**Architecture:** Two independently-buildable halves that talk over Firebase: the Flutter client (`EVE_MOBILE/app/`) and the Cloud Functions backend (`EVE_MOBILE/functions/`), both pointed at one Firebase project. The client never calls Gemini directly — every AI call, and the nine-type notification dispatch, is server-side. Emulator vs. production is a single `--dart-define` flag threaded through one init function.

**Tech Stack:** Flutter (Dart) + Riverpod, Firebase (Auth, Firestore, Cloud Functions, Cloud Messaging, Cloud Scheduler), Firebase Cloud Functions on Node.js 20 / TypeScript, Gemini via Secret Manager, Jest for Cloud Functions unit tests.

## Global Constraints

- Frontend is Flutter (Dart), single codebase for Android + iOS — EVE2_PRD §10.1, design-spec §2.
- State management is Riverpod — design-spec §2 (locked; PRD left this open, Riverpod was the session decision).
- Backend is Firebase: Auth, Firestore, Cloud Functions, `firebase_messaging`, Cloud Scheduler — design-spec §2. Firebase Hosting and Storage are **not** part of this build; do not `firebase init` them.
- Cloud Functions runtime is Node.js/TypeScript — design-spec §2.
- AI provider is Google Gemini, called only from a Cloud Function proxy — **never** from the Flutter client, because that would expose the API key in the client bundle — EVE2_PRD §10.1, §10.3.
- PDF export uses the `pdf` + `printing` Flutter packages, rendered client-side from AI-generated text — design-spec §2. This plan only wires the packages; PDF layout logic is out of scope here.
- Every file this plan creates must land at the exact path given in design-spec §9's canonical folder structure. Do not invent new top-level directories.
- Firestore paths are fixed by design-spec §10 and must not be altered. One exception is called out explicitly in Task 9 below (FCM device-token storage), where design-spec §10 has no path defined — flagged there as a gap, not silently invented.
- The nine notification types are exactly: `morning`, `medicine`, `workout`, `water`, `sleep`, `cycle`, `appointment`, `mood`, `daily_tip` — EVE2_PRD §4 (Common Survey). This plan does not invent a tenth type or rename these.
- Copy voice is formal and warm, no emojis anywhere in-product — design-spec §2. Applies to the notification body strings drafted in Task 9.
- Out of scope for this plan (owned elsewhere): Firestore security rules content (Plan 5, `05-data-model-firestore.md`), the `partnerView` recompute Cloud Function (Plan 7, `07-partner-mode-consent.md`), the mascot rig (Plan 6, `06-mascot-rig-plan.md`), onboarding screens (Plan 1, `01-core-workflow.md`). This plan only creates the scaffolding those plans build inside of.
- This plan assumes a git repository already exists at `D:\Projects\favourites\eve\EVE_MOBILE`. If it does not yet exist when a task's steps are executed, run `git init` in `EVE_MOBILE/` before the first commit step below.

---

## Task 1: Firebase project init (`firebase.json`, `.firebaserc`, Firestore placeholders)

**Files:**
- Create: `EVE_MOBILE/firebase.json`
- Create: `EVE_MOBILE/.firebaserc`
- Create: `EVE_MOBILE/firestore.rules`
- Create: `EVE_MOBILE/firestore.indexes.json`
- Create: `EVE_MOBILE/.gitignore`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: a Firebase project (`eve-hack26`) and the `firebase.json` emulator port map (Auth `9099`, Firestore `8080`, Functions `5001`, Emulator UI `4000`) that Tasks 6–12 all read.

- [ ] **Step 1: Verify the Firebase CLI is installed**

Run:
```bash
npm install -g firebase-tools
firebase --version
```
Expected: a version string `>= 13.0.0` printed, e.g. `13.29.1`. If the command is not found after install, close and reopen the shell so the global npm bin directory is on `PATH`.

- [ ] **Step 2: Log in and create the Firebase project**

Run:
```bash
firebase login
firebase projects:create eve-hack26 --display-name "EVE Hack26"
```
Expected: a browser OAuth flow completes for `firebase login`, then `firebase projects:create` prints:
```
✔ Created Google Cloud project eve-hack26
✔ Created Firebase project eve-hack26
```
If `eve-hack26` is already taken globally (Firebase project IDs are global), append a suffix, e.g. `eve-hack26-<initials>`, and use that ID consistently in every command below and in `.firebaserc`.

- [ ] **Step 3: Run `firebase init` from the `EVE_MOBILE/` directory**

Run `firebase init` and answer the interactive prompts exactly as follows:
- "Which Firebase features do you want to set up?" → select only **Firestore** and **Functions** (space to select, enter to confirm). Do **not** select Hosting, Storage, or Emulators here — emulator config is written directly in Step 5 below.
- "Please select an option" (project setup) → **Use an existing project** → `eve-hack26`.
- "What file should be used for Firestore Rules?" → `firestore.rules` (default).
- "What file should be used for Firestore indexes?" → `firestore.indexes.json` (default).
- "What language would you like to use to write Cloud Functions?" → **TypeScript**.
- "Do you want to use ESLint to catch probable bugs?" → **No** (keep hackathon iteration fast; can be added later without affecting this plan).
- "Do you want to install dependencies with npm now?" → **No** (Task 6 controls `functions/package.json` exactly; installing now would generate a version set this plan then has to override).

Expected: the CLI reports `✔ Firebase initialization complete!` and creates `functions/` (a default scaffold Task 6 will overwrite), `firestore.rules`, `firestore.indexes.json`, and `firebase.json`.

- [ ] **Step 4: Confirm `.firebaserc` matches the expected project mapping**

Read `EVE_MOBILE/.firebaserc` and confirm it reads exactly:
```json
{
  "projects": {
    "default": "eve-hack26"
  }
}
```
If the project ID differs (Step 2's fallback), substitute it here and everywhere else in this plan.

- [ ] **Step 5: Replace `firebase.json` with the exact structure this project needs**

Overwrite `EVE_MOBILE/firebase.json`:
```json
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "functions": [
    {
      "source": "functions",
      "codebase": "default",
      "ignore": [
        "node_modules",
        ".git",
        "firebase-debug.log",
        "firebase-debug.*.log",
        "*.local"
      ],
      "predeploy": [
        "npm --prefix \"$RESOURCE_DIR\" run build"
      ]
    }
  ],
  "emulators": {
    "auth": { "port": 9099 },
    "functions": { "port": 5001 },
    "firestore": { "port": 8080 },
    "ui": { "enabled": true, "port": 4000 },
    "singleProjectMode": true
  }
}
```
No Hosting, Storage, or Messaging block — Cloud Messaging has no emulator and does not appear in `firebase.json`; Hosting/Storage are out of scope per Global Constraints.

- [ ] **Step 6: Write a placeholder-deny `firestore.rules`**

Overwrite `EVE_MOBILE/firestore.rules`:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Placeholder — Plan 5 (05-data-model-firestore.md) owns the real
    // security rules for every path in design-spec §10. This file denies
    // all access so the project is never accidentally left open while
    // Plan 5 is still in progress.
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

- [ ] **Step 7: Confirm `firestore.indexes.json` is an empty valid index file**

Confirm `EVE_MOBILE/firestore.indexes.json` reads:
```json
{
  "indexes": [],
  "fieldOverrides": []
}
```
Plan 5 adds composite indexes here if the security-rules/query design needs them; this plan leaves it empty.

- [ ] **Step 8: Add a root `.gitignore` covering Firebase and Flutter build artifacts**

Create `EVE_MOBILE/.gitignore`:
```
# Firebase
.firebase/
firebase-debug.log
firebase-debug.*.log
ui-debug.log
functions/lib/
functions/node_modules/
functions/.secret.local

# Flutter
app/build/
app/.dart_tool/
app/.flutter-plugins
app/.flutter-plugins-dependencies
app/ios/Pods/
app/ios/Flutter/Flutter.framework
app/ios/Flutter/Flutter.podspec
app/android/.gradle/
app/android/local.properties
```

- [ ] **Step 9: Commit**

```bash
git add firebase.json .firebaserc firestore.rules firestore.indexes.json .gitignore
git commit -m "chore: initialize Firebase project config for eve-hack26"
```

---

## Task 2: Enable Auth providers and generate `firebase_options.dart`

**Files:**
- Create: `EVE_MOBILE/app/lib/firebase_options.dart` (generated by `flutterfire configure`)
- Modify: `EVE_MOBILE/app/lib/main.dart` (created fresh here if Plan 4's base shell hasn't landed yet; otherwise Task 11 below finishes wiring it)

**Interfaces:**
- Consumes: the `eve-hack26` project from Task 1.
- Produces: `DefaultFirebaseOptions.currentPlatform`, the exact symbol every Firebase-touching service (`core/services/firebase_service.dart`, Plan 2's architecture) initializes against.

- [ ] **Step 1: Enable Google as a sign-in provider in the Firebase console**

In the Firebase console for `eve-hack26`: **Build → Authentication → Get started → Sign-in method → Google → Enable**, set a project support email, **Save**.

Verify: `firebase auth:export /tmp/auth-check.json --project eve-hack26` (or PowerShell equivalent path) runs without an "Authentication not enabled" error — an empty `{"kind":"identitytoolkit#DownloadAccountResponse","users":[]}` is expected output on a fresh project.

- [ ] **Step 2: Install the FlutterFire CLI**

Run:
```bash
dart pub global activate flutterfire_cli
flutterfire --version
```
Expected: a version string is printed, e.g. `1.1.1`. If `flutterfire` is not found, ensure `<pub-cache>/bin` is on `PATH` (`dart pub global activate` prints the exact path to add if missing).

- [ ] **Step 3: Run `flutterfire configure` from `EVE_MOBILE/app/`**

Run:
```bash
flutterfire configure --project=eve-hack26 --out=lib/firebase_options.dart --platforms=android,ios
```
When prompted "Which platforms should your configuration support?" confirm `android` and `ios` only (no web/macOS/Windows for this build). When prompted for Android package name, use `in.thinkroot.eve` (or the org's real reverse-domain bundle ID if different — keep it consistent across this step, Task 3, and Task 4). When prompted for iOS bundle ID, use the same reverse-domain value, e.g. `in.thinkroot.eve`.

Expected: the command ends with `Firebase configuration file lib/firebase_options.dart generated successfully with the following Firebase apps:` followed by an Android and an iOS app entry, and it also drops `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` into the project automatically.

- [ ] **Step 4: Confirm the generated file's shape**

Read `EVE_MOBILE/app/lib/firebase_options.dart` and confirm it defines a `DefaultFirebaseOptions` class with a static `currentPlatform` getter that switches on `defaultTargetPlatform` and returns platform-specific `FirebaseOptions(apiKey: ..., appId: ..., messagingSenderId: ..., projectId: 'eve-hack26', ...)` values for `android` and `ios`. Do not hand-edit this file — regenerate via Step 3 if the project config ever changes.

- [ ] **Step 5: Commit**

```bash
git add app/lib/firebase_options.dart app/android/app/google-services.json app/ios/Runner/GoogleService-Info.plist
git commit -m "chore: generate Firebase client config via flutterfire configure"
```

---

## Task 3: Google Sign-In — Android SHA-1 wiring

**Files:**
- Modify: `EVE_MOBILE/app/android/build.gradle`
- Modify: `EVE_MOBILE/app/android/app/build.gradle`

**Interfaces:**
- Consumes: `android/app/google-services.json` from Task 2.
- Produces: a working Google Sign-In on Android for whichever plan builds the auth screen (Plan 1's `screen-auth`); this task only wires the native prerequisites, not the Dart sign-in call.

- [ ] **Step 1: Get the debug keystore's SHA-1 fingerprint**

Run (adjust the keystore path on Windows if it differs — default is under the user profile):
```bash
keytool -list -v -keystore "$HOME/.android/debug.keystore" -alias androiddebugkey -storepass android -keypass android
```
Expected output includes a line:
```
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```
Copy this value.

- [ ] **Step 2: Add the fingerprint to the Firebase console**

In the Firebase console: **Project settings → Your apps → (the Android app) → Add fingerprint**, paste the SHA-1 from Step 1, **Save**. Re-download `google-services.json` (**Project settings → Your apps → Android app → google-services.json**) and overwrite `EVE_MOBILE/app/android/app/google-services.json` — the fingerprint must be present in this file for Google Sign-In to succeed, not just registered in the console.

Verify: open the re-downloaded `google-services.json` and confirm the SHA-1 (with colons stripped, lowercase) from Step 1 appears under `client[].oauth_client[].android_info.certificate_hash`.

- [ ] **Step 3: Apply the Google Services Gradle plugin**

In `EVE_MOBILE/app/android/build.gradle`, confirm/add to the top-level `dependencies` block inside `buildscript`:
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.2'
    }
}
```

In `EVE_MOBILE/app/android/app/build.gradle`, add as the last line of the file:
```gradle
apply plugin: 'com.google.gms.google-services'
```

- [ ] **Step 4: Verify Gradle sync picks up the plugin**

Run from `EVE_MOBILE/app/`:
```bash
flutter build apk --debug --target-platform android-arm64
```
Expected: the build succeeds and the log contains no `google-services.json is missing` or `File google-services.json is missing from module root folder` error. A full successful build ending in `Built build/app/outputs/flutter-apk/app-debug.apk` confirms the plugin found and parsed the config file.

- [ ] **Step 5: Commit**

```bash
git add app/android/build.gradle app/android/app/build.gradle app/android/app/google-services.json
git commit -m "chore: wire Google Services Gradle plugin and debug SHA-1 for Google Sign-In"
```

---

## Task 4: Google Sign-In — iOS URL scheme wiring

**Files:**
- Modify: `EVE_MOBILE/app/ios/Runner/Info.plist`

**Interfaces:**
- Consumes: `ios/Runner/GoogleService-Info.plist` from Task 2.
- Produces: a working Google Sign-In redirect on iOS for the same auth screen Task 3 unblocks on Android.

- [ ] **Step 1: Read the reversed client ID out of `GoogleService-Info.plist`**

Open `EVE_MOBILE/app/ios/Runner/GoogleService-Info.plist` and find the `REVERSED_CLIENT_ID` key, e.g.:
```xml
<key>REVERSED_CLIENT_ID</key>
<string>com.googleusercontent.apps.123456789012-abc123def456</string>
```
Copy the full string value.

- [ ] **Step 2: Register it as a URL scheme in `Info.plist`**

In `EVE_MOBILE/app/ios/Runner/Info.plist`, add (or extend, if `CFBundleURLTypes` already exists from Flutter's default scaffold) inside the root `<dict>`:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.123456789012-abc123def456</string>
    </array>
  </dict>
</array>
```
Replace the scheme string with the exact `REVERSED_CLIENT_ID` value copied in Step 1 — this must match character-for-character or the OAuth redirect back into the app silently fails.

- [ ] **Step 3: Verify the plist is well-formed**

Run:
```bash
plutil -lint "EVE_MOBILE/app/ios/Runner/Info.plist"
```
Expected: `EVE_MOBILE/app/ios/Runner/Info.plist: OK`. (On Windows without `plutil` available, open the file and confirm it is valid XML with matching tags as a substitute check — actual `plutil` validation should be re-run on a macOS build machine before the first iOS build.)

- [ ] **Step 4: Commit**

```bash
git add app/ios/Runner/Info.plist
git commit -m "chore: register Google Sign-In reversed-client-id URL scheme on iOS"
```

---

## Task 5: Flutter `pubspec.yaml` dependency set

**Files:**
- Create: `EVE_MOBILE/app/pubspec.yaml`

**Interfaces:**
- Consumes: nothing new.
- Produces: every package name/import path that Plans 1, 2, 5, 6, 7 assume is available (`flutter_riverpod`, `go_router`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `firebase_messaging`, `google_sign_in`, `pdf`, `printing`, `intl`, `flutter_local_notifications`, `google_fonts`).

- [ ] **Step 1: Write `pubspec.yaml`**

Create `EVE_MOBILE/app/pubspec.yaml`:
```yaml
name: eve
description: EVE — AI-powered adaptive health companion (Hack26 build).
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: '^3.9.0'
  flutter: '>=3.35.0'

dependencies:
  flutter:
    sdk: flutter

  # State management (design-spec §2, locked decision)
  flutter_riverpod: ^3.0.0

  # Routing (design-spec §9 core/router/app_router.dart)
  go_router: ^15.1.2

  # UI / typography
  google_fonts: ^6.2.1

  # Firebase core + services (design-spec §2)
  firebase_core: ^4.6.0
  firebase_auth: ^6.3.0
  cloud_firestore: ^6.2.0
  firebase_messaging: ^16.4.3
  # Required to call the Cloud Functions AI proxy (core/services/ai_proxy_service.dart,
  # design-spec §9) and the notification-eligibility path from the client if ever
  # needed for debugging. Not in the task's literal package list but required by
  # the "AI proxy, never called directly from the client" requirement in
  # EVE2_PRD §10.1 — the client needs *a* way to invoke an https.onCall function.
  cloud_functions: ^6.0.0

  # Auth — Google Sign-In (v7 API: GoogleSignIn.instance, initialize(), authenticate())
  google_sign_in: ^7.1.0

  # Local display of scheduled/foreground notifications delivered via FCM
  # (firebase_messaging delivers the message; flutter_local_notifications
  # renders it as a local notification when the app is foregrounded, since FCM
  # does not auto-display notifications while the app is in the foreground).
  flutter_local_notifications: ^19.1.0

  # Doctor-ready summary PDF export (design-spec §2)
  pdf: ^3.11.3
  printing: ^5.14.2

  # Date formatting across cycle/pregnancy-week calculations and Log calendar
  intl: ^0.20.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  mocktail: ^1.0.4

flutter:
  uses-material-design: true
```

- [ ] **Step 2: Resolve dependencies**

Run from `EVE_MOBILE/app/`:
```bash
flutter pub get
```
Expected: output ends with `Got dependencies!` and no version-solving conflict errors. If `flutter_riverpod: ^3.0.0` conflicts with a Flutter SDK constraint on the machine running this step (Riverpod 3.0 requires a recent Dart SDK), fall back to `flutter_riverpod: ^2.6.1` and re-run — the API surface Plans 1/2 depend on (`StateNotifierProvider`, `ProviderScope`) is present in both major versions.

- [ ] **Step 3: Verify the SDK constraint is satisfiable**

Run:
```bash
flutter --version
```
Expected: the reported Flutter version is `>= 3.35.0` with a bundled Dart SDK `>= 3.9.0`, matching the `environment:` block in Step 1. If the installed Flutter is older, either upgrade (`flutter upgrade`) or lower the `environment:` floor to match the installed SDK — do not leave a constraint the installed toolchain can't satisfy.

- [ ] **Step 4: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock
git commit -m "chore: add Flutter dependency set (Riverpod, go_router, Firebase, PDF export)"
```

---

## Task 6: Cloud Functions TypeScript scaffold

**Files:**
- Create: `EVE_MOBILE/functions/package.json`
- Create: `EVE_MOBILE/functions/tsconfig.json`
- Create: `EVE_MOBILE/functions/src/index.ts`
- Create: `EVE_MOBILE/functions/jest.config.js`

**Interfaces:**
- Consumes: the `functions/` directory scaffolded by `firebase init` in Task 1 (this task overwrites its default contents with the exact versions below).
- Produces: `npm run build` (compiles `src/**/*.ts` → `lib/`), `npm test` (Jest), and the `admin.initializeApp()` call every subsequent Cloud Function in this plan and in Plan 7 relies on having already run once per process.

- [ ] **Step 1: Write `functions/package.json`**

Create `EVE_MOBILE/functions/package.json`:
```json
{
  "name": "functions",
  "private": true,
  "engines": {
    "node": "20"
  },
  "main": "lib/index.js",
  "scripts": {
    "build": "tsc",
    "build:watch": "tsc --watch",
    "serve": "npm run build && firebase emulators:start --only functions,firestore,auth",
    "test": "jest",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "dependencies": {
    "firebase-admin": "^13.0.0",
    "firebase-functions": "^6.1.0"
  },
  "devDependencies": {
    "@types/jest": "^29.5.13",
    "@types/node": "^20.14.10",
    "firebase-functions-test": "^3.3.0",
    "jest": "^29.7.0",
    "ts-jest": "^29.2.5",
    "typescript": "^5.6.3"
  }
}
```

- [ ] **Step 2: Write `functions/tsconfig.json`**

Create `EVE_MOBILE/functions/tsconfig.json`:
```json
{
  "compilerOptions": {
    "module": "commonjs",
    "target": "ES2021",
    "lib": ["ES2021"],
    "outDir": "lib",
    "rootDir": ".",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "sourceMap": true
  },
  "include": ["src/**/*.ts", "test/**/*.ts"]
}
```

- [ ] **Step 3: Write `functions/jest.config.js`**

Create `EVE_MOBILE/functions/jest.config.js`:
```js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/test'],
};
```

- [ ] **Step 4: Write the `functions/src/index.ts` entry point**

Create `EVE_MOBILE/functions/src/index.ts`:
```ts
import * as admin from 'firebase-admin';

admin.initializeApp();

// Each export below is added by the task/plan that implements it:
// - aiProxy: Task 8 of this plan.
// - dispatchScheduledNotifications: Task 9 of this plan.
// - onUserCreate: implemented in Plan 2 (02-system-architecture.md).
// - partnerView: implemented in Plan 7 (07-partner-mode-consent.md).
// - chatSystemMessages: implemented in Plan 7 (07-partner-mode-consent.md).
export { aiProxy } from './aiProxy';
export { dispatchScheduledNotifications } from './notifications/scheduler';
```

- [ ] **Step 5: Install dependencies and verify the build**

Run from `EVE_MOBILE/functions/`:
```bash
npm install
```
Expected: `added N packages` with no `npm ERR!` lines.

This will fail at Step 6 below until Tasks 8 and 9 create `src/aiProxy.ts` and `src/notifications/scheduler.ts` — that is expected at this point in the plan; re-run the build verification after those tasks land. To confirm the scaffold itself is sound right now, temporarily comment out both `export` lines in `index.ts`, run:
```bash
npm run build
```
Expected: `lib/index.js` is created with no TypeScript errors, then restore the two `export` lines before moving to Task 7.

- [ ] **Step 6: Commit**

```bash
git add functions/package.json functions/tsconfig.json functions/jest.config.js functions/src/index.ts functions/package-lock.json
git commit -m "chore: scaffold Cloud Functions TypeScript project"
```

---

## Task 7: Gemini API key via Secret Manager + `aiProxy` callable shell

**Files:**
- Create: `EVE_MOBILE/functions/src/aiProxy.ts`
- Create: `EVE_MOBILE/functions/.secret.local` (local-only, gitignored — created but never committed)

**Interfaces:**
- Consumes: `admin.initializeApp()` from Task 6's `index.ts`.
- Produces: the `aiProxy` callable Cloud Function (`onCall`, name `aiProxy`) that `core/services/ai_proxy_service.dart` (Plan 2) invokes via `FirebaseFunctions.instance.httpsCallable('aiProxy')`. This task wires the secret and the callable shell only — prompt construction, Gemini SDK calls, and response parsing for doctor summaries/chat check-ins are implemented by whichever plan builds that feature, not here.

- [ ] **Step 1: Store the Gemini API key in Secret Manager**

Run from `EVE_MOBILE/`:
```bash
firebase functions:secrets:set GEMINI_API_KEY --project eve-hack26
```
When prompted `Enter a value for GEMINI_API_KEY:`, paste the real Gemini API key (from Google AI Studio / Vertex AI credentials). Expected output:
```
Created a new secret version projects/eve-hack26/secrets/GEMINI_API_KEY/versions/1
```
followed by a note that a deploy is needed for the change to take effect — that's expected; the emulator path (Step 3) doesn't need a deploy.

- [ ] **Step 2: Write `functions/src/aiProxy.ts`**

Create `EVE_MOBILE/functions/src/aiProxy.ts`:
```ts
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';

export const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');

/**
 * Callable AI proxy. This is the only place in the entire codebase that may
 * read GEMINI_API_KEY — the Flutter client never sees it, per EVE2_PRD
 * §10.1/§10.3 ("never called directly from the client").
 *
 * Request/response shaping for specific AI features (doctor summary export,
 * chat check-ins, phase-aware insights) is out of scope for this tech-stack
 * plan; this shell only proves the secret loads and the callable is
 * reachable from an authenticated client.
 */
export const aiProxy = onCall({ secrets: [GEMINI_API_KEY] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required to use the AI assistant.');
  }

  const apiKey = GEMINI_API_KEY.value();
  if (!apiKey) {
    throw new HttpsError('failed-precondition', 'GEMINI_API_KEY secret is not configured.');
  }

  return { ok: true, keyLoaded: apiKey.length > 0 };
});
```

- [ ] **Step 3: Create a local-only secret file for emulator testing**

The Functions emulator cannot reach Secret Manager directly; it reads secret values from a `.secret.local` file instead. Create `EVE_MOBILE/functions/.secret.local` (already covered by the root `.gitignore` from Task 1 Step 8 — confirm it is, since this file must never be committed):
```
GEMINI_API_KEY=paste-your-real-or-a-dummy-test-key-here
```

- [ ] **Step 4: Build and verify against the emulator**

Run from `EVE_MOBILE/functions/`:
```bash
npm run build
firebase emulators:start --only functions,firestore,auth --project eve-hack26
```
Expected: the emulator log shows `✔ functions[us-central1-aiProxy]: http function initialized` (region defaults to `us-central1` unless a region is set) and no `Failed to load secret` error.

In a second terminal, call it with the Firebase emulator's callable-function HTTP shape (requires an emulator Auth ID token in practice; for a first structural check, an unauthenticated call is enough to prove the function is reachable and returns the expected `unauthenticated` error rather than a 404):
```bash
curl -X POST http://localhost:5001/eve-hack26/us-central1/aiProxy \
  -H "Content-Type: application/json" \
  -d '{"data":{}}'
```
Expected: an HTTP error body containing `"status":"UNAUTHENTICATED"` — proof the function deployed to the emulator and the auth check runs before any Gemini call is attempted.

- [ ] **Step 5: Commit**

```bash
git add functions/src/aiProxy.ts
git commit -m "feat: add Gemini API key secret and aiProxy callable shell"
```

---

## Task 8: Notification-eligibility pure function (TDD)

**Files:**
- Create: `EVE_MOBILE/functions/src/notifications/eligibility.ts`
- Test: `EVE_MOBILE/functions/test/eligibility.test.ts`

**Interfaces:**
- Consumes: nothing (pure function, no Firestore/Firebase dependency).
- Produces: `NOTIFICATION_TYPES`, `NotificationType`, `UserNotificationPrefs`, and `dueNotificationTypes(prefs: UserNotificationPrefs, now: Date): NotificationType[]` — the exact names Task 9's `scheduler.ts` imports.

This is the one part of this plan with real business logic, so it gets real TDD: write the failing tests first, watch them fail, then implement.

- [ ] **Step 1: Write the failing test file**

Create `EVE_MOBILE/functions/test/eligibility.test.ts`:
```ts
import { dueNotificationTypes, UserNotificationPrefs } from '../src/notifications/eligibility';

describe('dueNotificationTypes', () => {
  it('returns an empty array when no reminders are enabled', () => {
    const prefs: UserNotificationPrefs = { enabledReminders: [] };
    const now = new Date(Date.UTC(2026, 7, 8, 7, 0));
    expect(dueNotificationTypes(prefs, now)).toEqual([]);
  });

  it('returns morning when enabled and now is 07:00 UTC', () => {
    const prefs: UserNotificationPrefs = { enabledReminders: ['morning'] };
    const now = new Date(Date.UTC(2026, 7, 8, 7, 0));
    expect(dueNotificationTypes(prefs, now)).toEqual(['morning']);
  });

  it('does not return morning when enabled but now is outside its slot', () => {
    const prefs: UserNotificationPrefs = { enabledReminders: ['morning'] };
    const now = new Date(Date.UTC(2026, 7, 8, 9, 0));
    expect(dueNotificationTypes(prefs, now)).toEqual([]);
  });

  it('matches anywhere within a slot\'s 30-minute window, not just on the exact minute', () => {
    const prefs: UserNotificationPrefs = { enabledReminders: ['morning'] };
    const now = new Date(Date.UTC(2026, 7, 8, 7, 22));
    expect(dueNotificationTypes(prefs, now)).toEqual(['morning']);
  });

  it('returns multiple types when several are due in the same slot', () => {
    const prefs: UserNotificationPrefs = { enabledReminders: ['appointment', 'cycle'] };
    const now = new Date(Date.UTC(2026, 7, 8, 8, 10));
    expect(dueNotificationTypes(prefs, now)).toEqual(['appointment', 'cycle']);
  });

  it('handles a reminder type with multiple daily slots (medicine: morning + evening dose)', () => {
    const prefs: UserNotificationPrefs = { enabledReminders: ['medicine'] };
    const morningDose = new Date(Date.UTC(2026, 7, 8, 9, 5));
    const eveningDose = new Date(Date.UTC(2026, 7, 8, 21, 5));
    const midday = new Date(Date.UTC(2026, 7, 8, 14, 0));
    expect(dueNotificationTypes(prefs, morningDose)).toEqual(['medicine']);
    expect(dueNotificationTypes(prefs, eveningDose)).toEqual(['medicine']);
    expect(dueNotificationTypes(prefs, midday)).toEqual([]);
  });

  it('ignores values in enabledReminders that are not recognized notification types', () => {
    const prefs = {
      enabledReminders: ['morning', 'not_a_real_type'],
    } as unknown as UserNotificationPrefs;
    const now = new Date(Date.UTC(2026, 7, 8, 7, 0));
    expect(dueNotificationTypes(prefs, now)).toEqual(['morning']);
  });

  it('covers all nine notification types across their configured slots', () => {
    const allEnabled: UserNotificationPrefs = {
      enabledReminders: [
        'morning', 'medicine', 'workout', 'water', 'sleep',
        'cycle', 'appointment', 'mood', 'daily_tip',
      ],
    };
    expect(dueNotificationTypes(allEnabled, new Date(Date.UTC(2026, 7, 8, 7, 0)))).toEqual(['morning']);
    expect(dueNotificationTypes(allEnabled, new Date(Date.UTC(2026, 7, 8, 8, 0)))).toEqual(['appointment', 'cycle']);
    expect(dueNotificationTypes(allEnabled, new Date(Date.UTC(2026, 7, 8, 8, 30)))).toEqual(['daily_tip']);
    expect(dueNotificationTypes(allEnabled, new Date(Date.UTC(2026, 7, 8, 17, 30)))).toEqual(['workout']);
    expect(dueNotificationTypes(allEnabled, new Date(Date.UTC(2026, 7, 8, 21, 30)))).toEqual(['sleep']);
  });
});
```

- [ ] **Step 2: Run the test suite and verify it fails**

Run from `EVE_MOBILE/functions/`:
```bash
npx jest test/eligibility.test.ts
```
Expected: FAIL — `Cannot find module '../src/notifications/eligibility'` (the file doesn't exist yet).

- [ ] **Step 3: Implement `functions/src/notifications/eligibility.ts`**

Create `EVE_MOBILE/functions/src/notifications/eligibility.ts`:
```ts
export const NOTIFICATION_TYPES = [
  'morning',
  'medicine',
  'workout',
  'water',
  'sleep',
  'cycle',
  'appointment',
  'mood',
  'daily_tip',
] as const;

export type NotificationType = (typeof NOTIFICATION_TYPES)[number];

export interface UserNotificationPrefs {
  // Matches users/{uid}/preferences/notifications.enabledReminders (design-spec §10).
  enabledReminders: NotificationType[];
}

interface ScheduleSlot {
  /** 0-23, UTC. See Task 9's note on timezone handling being a known V0 gap. */
  hour: number;
  /** Must be 0 or 30 — the scheduler in Task 9 runs on a 30-minute cadence. */
  minute: number;
}

/**
 * One or more fixed daily fire times per notification type. This is
 * eligibility only — whether the type is enabled and whether "now" falls in
 * one of its configured windows. It intentionally does NOT decide whether
 * there is actually an appointment today, what cycle phase she's in, etc.;
 * that content-level filtering belongs to whichever feature owns the data
 * (e.g. Plan 7 for partner-relevant content), not to this scheduling gate.
 */
export const NOTIFICATION_SCHEDULE: Record<NotificationType, ScheduleSlot[]> = {
  morning: [{ hour: 7, minute: 0 }],
  daily_tip: [{ hour: 8, minute: 30 }],
  appointment: [{ hour: 8, minute: 0 }],
  cycle: [{ hour: 8, minute: 0 }],
  medicine: [
    { hour: 9, minute: 0 },
    { hour: 21, minute: 0 },
  ],
  water: [
    { hour: 10, minute: 0 },
    { hour: 13, minute: 0 },
    { hour: 16, minute: 0 },
    { hour: 19, minute: 0 },
  ],
  mood: [
    { hour: 12, minute: 0 },
    { hour: 20, minute: 0 },
  ],
  workout: [{ hour: 17, minute: 30 }],
  sleep: [{ hour: 21, minute: 30 }],
};

function halfHourSlotIndex(hour: number, minute: number): number {
  return hour * 2 + (minute >= 30 ? 1 : 0);
}

/**
 * Pure function: given a user's enabled reminder types and the current time,
 * return the subset of the nine notification types that should fire right
 * now. No Firestore/Firebase dependency — Task 9's scheduler.ts is the only
 * caller that wires this to real data and real dispatch.
 */
export function dueNotificationTypes(
  prefs: UserNotificationPrefs,
  now: Date,
): NotificationType[] {
  const nowSlot = halfHourSlotIndex(now.getUTCHours(), now.getUTCMinutes());
  return NOTIFICATION_TYPES.filter((type) => {
    if (!prefs.enabledReminders.includes(type)) return false;
    return NOTIFICATION_SCHEDULE[type].some(
      (slot) => halfHourSlotIndex(slot.hour, slot.minute) === nowSlot,
    );
  });
}
```

- [ ] **Step 4: Run the test suite and verify it passes**

Run:
```bash
npx jest test/eligibility.test.ts
```
Expected: `Tests: 8 passed, 8 total`.

- [ ] **Step 5: Commit**

```bash
git add functions/src/notifications/eligibility.ts functions/test/eligibility.test.ts
git commit -m "feat: add dueNotificationTypes eligibility filter with unit tests"
```

---

## Task 9: Cloud Scheduler wiring — `dispatchScheduledNotifications`

**Files:**
- Create: `EVE_MOBILE/functions/src/notifications/scheduler.ts`
- Modify: `EVE_MOBILE/functions/src/index.ts`

**Interfaces:**
- Consumes: `dueNotificationTypes`, `UserNotificationPrefs`, `NotificationType` from Task 8.
- Produces: the deployed scheduled function `dispatchScheduledNotifications`, which Cloud Scheduler invokes every 30 minutes.

**Spec gap flagged here, not silently resolved:** design-spec §10's Firestore path list has no path for FCM device tokens. Push dispatch cannot work without storing them somewhere. This task adds `users/{uid}/fcmTokens/{token}` (token string as document ID, doc body `{ createdAt: Timestamp }`) as the minimal addition needed. **Plan 5 should ratify or relocate this path** when it formalizes the schema — this plan does not have the authority to make that permanent, only to note the dependency and pick something that unblocks this task.

- [ ] **Step 1: Write `functions/src/notifications/scheduler.ts`**

Create `EVE_MOBILE/functions/src/notifications/scheduler.ts`:
```ts
import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { dueNotificationTypes, NotificationType, UserNotificationPrefs } from './eligibility';

const NOTIFICATION_COPY: Record<NotificationType, string> = {
  morning: 'Good morning. Eve has a moment for you whenever you are ready.',
  medicine: 'A reminder for your medication.',
  workout: 'Today\'s workout is on your calendar whenever you are ready for it.',
  water: 'A short reminder to drink some water.',
  sleep: 'Consider logging tonight\'s sleep before you wind down.',
  cycle: 'Your cycle tracker has an update worth a look.',
  appointment: 'You have an appointment reminder from Eve.',
  mood: 'How are you feeling right now? Eve would like to know.',
  daily_tip: 'Eve has a new tip for you today.',
};

/**
 * Runs every 30 minutes. For each user, loads her notification preferences,
 * asks the pure dueNotificationTypes() filter (Task 8) which of the nine
 * types should fire in this window, and sends one FCM message per due type
 * to every device token she has registered.
 *
 * Cron syntax: 'every 30 minutes' is Cloud Scheduler's App-Engine-style
 * shorthand, equivalent to the standard cron expression '*\/30 * * * *'.
 * Either form is accepted by onSchedule's `schedule` option.
 */
export const dispatchScheduledNotifications = onSchedule(
  { schedule: 'every 30 minutes', timeZone: 'Etc/UTC' },
  async () => {
    const now = new Date();
    const db = admin.firestore();
    const usersSnapshot = await db.collection('users').get();

    const sends: Promise<unknown>[] = [];

    for (const userDoc of usersSnapshot.docs) {
      const uid = userDoc.id;

      const notifPrefsSnap = await db.doc(`users/${uid}/preferences/notifications`).get();
      if (!notifPrefsSnap.exists) continue;

      const prefs = notifPrefsSnap.data() as UserNotificationPrefs;
      const dueTypes = dueNotificationTypes(prefs, now);
      if (dueTypes.length === 0) continue;

      // See the spec-gap note above this task: fcmTokens is not yet in
      // design-spec §10 and should be ratified/relocated by Plan 5.
      const tokensSnap = await db.collection(`users/${uid}/fcmTokens`).get();
      const tokens = tokensSnap.docs.map((doc) => doc.id);
      if (tokens.length === 0) continue;

      for (const type of dueTypes) {
        sends.push(
          admin.messaging().sendEachForMulticast({
            tokens,
            notification: {
              title: 'Eve',
              body: NOTIFICATION_COPY[type],
            },
            data: { notificationType: type },
          }),
        );
      }
    }

    await Promise.all(sends);
  },
);
```

- [ ] **Step 2: Export it from `index.ts`**

`EVE_MOBILE/functions/src/index.ts` already contains `export { dispatchScheduledNotifications } from './notifications/scheduler';` from Task 6 Step 4 — confirm that line is uncommented.

- [ ] **Step 3: Build and verify the scheduled function registers**

Run from `EVE_MOBILE/functions/`:
```bash
npm run build
firebase emulators:start --only functions,firestore,auth --project eve-hack26
```
Expected: the emulator log includes:
```
✔ functions[us-central1-dispatchScheduledNotifications]: scheduler function initialized.
```
The Functions emulator does not auto-fire schedules; trigger it manually to verify the handler runs end-to-end:
```bash
curl -X POST http://localhost:5001/eve-hack26/us-central1/dispatchScheduledNotifications
```
Expected: HTTP 200 (or 204) with no thrown error in the emulator log, even with zero users in the emulator's Firestore (the `usersSnapshot.docs` loop simply does nothing).

- [ ] **Step 4: Commit**

```bash
git add functions/src/notifications/scheduler.ts functions/src/index.ts
git commit -m "feat: wire Cloud Scheduler dispatch for the nine notification types"
```

---

## Task 10: Local emulator suite — full run verification

**Files:**
- None created — this task verifies the composition of Tasks 1, 6, 7, 9.

**Interfaces:**
- Consumes: `firebase.json`'s `emulators` block (Task 1), the built `functions/lib/` output (Tasks 6/7/9).
- Produces: a confirmed-working `firebase emulators:start` baseline that Task 12 points the Flutter client at.

- [ ] **Step 1: Build functions and start the full emulator suite**

Run from `EVE_MOBILE/`:
```bash
npm --prefix functions run build
firebase emulators:start --project eve-hack26
```
Expected console output includes a table like:
```
┌────────────────────────────────────────────────────────────────┐
│ ✔  All emulators ready! It is now safe to connect your app.     │
│ i  View Emulator UI at http://127.0.0.1:4000/                   │
└────────────────────────────────────────────────────────────────┘

┌───────────┬────────────────┬─────────────────────────────────┐
│ Emulator  │ Host:Port      │ View in Emulator UI              │
├───────────┼────────────────┼─────────────────────────────────┤
│ Authentication │ 127.0.0.1:9099 │ http://127.0.0.1:4000/auth   │
│ Functions      │ 127.0.0.1:5001 │ http://127.0.0.1:4000/functions │
│ Firestore      │ 127.0.0.1:8080 │ http://127.0.0.1:4000/firestore │
└───────────┴────────────────┴─────────────────────────────────┘
```
and lists `aiProxy` and `dispatchScheduledNotifications` under the Functions section with no load errors.

- [ ] **Step 2: Verify Firestore emulator accepts a write with rules-off semantics irrelevant to this check**

In a second terminal, seed a test user doc directly against the emulator (bypasses rules, which is expected/fine for a local Firestore emulator smoke test):
```bash
curl -X PATCH \
  "http://localhost:8080/v1/projects/eve-hack26/databases/(default)/documents/users/test-uid" \
  -H "Content-Type: application/json" \
  -d '{"fields":{"name":{"stringValue":"Test User"}}}'
```
Expected: HTTP 200 with a JSON body echoing back the written document, confirming the Firestore emulator is live and reachable on port 8080.

- [ ] **Step 3: Stop the emulator suite cleanly**

Press `Ctrl+C` in the terminal running `firebase emulators:start`. Expected: `i  Stopping emulators` followed by a clean exit (no hung processes on ports 4000/5001/8080/9099 — re-run `firebase emulators:start` to confirm the ports are free again if unsure).

No commit for this task — it is a verification-only checkpoint confirming Tasks 1–9 compose correctly before the client is wired up in Tasks 11–12.

---

## Task 11: Flutter client — Firebase init + emulator wiring

**Files:**
- Create: `EVE_MOBILE/app/lib/core/config/app_env.dart`
- Create: `EVE_MOBILE/app/lib/core/services/firebase_service.dart`
- Modify: `EVE_MOBILE/app/lib/main.dart`

**Interfaces:**
- Consumes: `DefaultFirebaseOptions.currentPlatform` (Task 2), the emulator ports `9099`/`8080`/`5001` (Task 1).
- Produces: `initializeFirebase()` — the exact function `main.dart` and, per design-spec §9, any other bootstrap code calls before touching `FirebaseAuth.instance` / `FirebaseFirestore.instance` / `FirebaseFunctions.instance`.

- [ ] **Step 1: Write `core/config/app_env.dart`**

Create `EVE_MOBILE/app/lib/core/config/app_env.dart`:
```dart
/// Compile-time environment flags, set via `--dart-define` at `flutter run`/
/// `flutter build` time. See EVE_MOBILE/plans/03-tech-stack.md Task 12 for
/// the exact commands that set these for emulator vs. production runs.
class AppEnv {
  const AppEnv._();

  /// When true, Auth/Firestore/Functions point at the local emulator suite
  /// (EVE_MOBILE/plans/03-tech-stack.md Task 1/Task 10) instead of the real
  /// eve-hack26 project.
  static const bool useEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  /// Host the emulator suite is reachable at from the running app. Use
  /// 10.0.2.2 for the Android emulator (its alias for the host machine's
  /// localhost), localhost for iOS simulator/desktop, or a LAN IP for a
  /// physical device on the same network as the emulator host.
  static const String emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: 'localhost',
  );
}
```

- [ ] **Step 2: Write `core/services/firebase_service.dart`**

Create `EVE_MOBILE/app/lib/core/services/firebase_service.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import '../config/app_env.dart';

/// Initializes Firebase and, when [AppEnv.useEmulator] is true, redirects
/// Auth/Firestore/Functions to the local emulator suite. Must be awaited
/// before any other code touches FirebaseAuth.instance,
/// FirebaseFirestore.instance, or FirebaseFunctions.instance — including
/// core/services/ai_proxy_service.dart, which calls
/// FirebaseFunctions.instance.httpsCallable('aiProxy') and is otherwise
/// unaffected by which environment is active.
Future<void> initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (AppEnv.useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(AppEnv.emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(AppEnv.emulatorHost, 8080);
    FirebaseFunctions.instance.useFunctionsEmulator(AppEnv.emulatorHost, 5001);
  }
}
```

- [ ] **Step 3: Wire `main.dart`**

Create or modify `EVE_MOBILE/app/lib/main.dart` so it reads:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  runApp(const ProviderScope(child: EveApp()));
}
```
If `EVE_MOBILE/app/lib/app.dart` does not exist yet (owned by whichever plan builds the base app shell — Plan 4's build order), create a minimal placeholder so this task's verification step can run in isolation:
```dart
import 'package:flutter/material.dart';

class EveApp extends StatelessWidget {
  const EveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('EVE'))),
    );
  }
}
```
Leave a comment at the top of this placeholder noting it is superseded by Plan 2's router-based `app.dart` once that plan's tasks run.

- [ ] **Step 4: Verify static analysis passes**

Run from `EVE_MOBILE/app/`:
```bash
flutter analyze
```
Expected: `No issues found!` (or only issues unrelated to the files touched in this task, if other plans' placeholder code already exists and has separate lint warnings).

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/config/app_env.dart app/lib/core/services/firebase_service.dart app/lib/main.dart
git commit -m "feat: wire Firebase init with emulator-vs-production dart-define switch"
```

---

## Task 12: Emulator vs. production run commands

**Files:**
- None created — this task documents and verifies the two run configurations Task 11's `AppEnv` supports.

**Interfaces:**
- Consumes: `AppEnv.useEmulator` / `AppEnv.emulatorHost` (Task 11).
- Produces: the two canonical commands every other plan's "run the app" instructions should reference.

- [ ] **Step 1: Verify the production-mode default**

Run from `EVE_MOBILE/app/`:
```bash
flutter run
```
Expected: the app builds and launches against the real `eve-hack26` project (no `--dart-define` flags passed means `AppEnv.useEmulator` defaults to `false`). Confirm by checking the Firebase console's Authentication/Firestore usage panels show activity if a sign-in is attempted, rather than the emulator UI at `localhost:4000`.

- [ ] **Step 2: Verify emulator mode on an Android emulator**

With `firebase emulators:start --project eve-hack26` running (Task 10) in a separate terminal, run:
```bash
flutter run --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```
Expected: the app launches and any Firestore/Auth/Functions call it makes shows up in the Emulator UI at `http://127.0.0.1:4000` within a few seconds, not in the real `eve-hack26` project's console. `10.0.2.2` is the Android emulator's fixed alias for the host machine's `localhost` — a physical Android device would instead need the host machine's real LAN IP.

- [ ] **Step 3: Verify emulator mode on an iOS simulator or desktop run**

```bash
flutter run --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=localhost
```
Expected: same as Step 2 — activity appears in the Emulator UI. The iOS simulator shares the host's network namespace, so `localhost` (unlike Android) resolves correctly without a special alias.

- [ ] **Step 4: Record the two canonical commands for other plans to reference**

No new file — this step is a checkpoint confirming the two commands below are the ones Plan 4 (`04-build-roadmap.md`) and any other plan's "how to run this locally" instructions should copy verbatim:

- Local/emulator development: `flutter run --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=<10.0.2.2|localhost>`
- Production/demo build: `flutter run` (or `flutter build apk` / `flutter build ios` with no `USE_FIREBASE_EMULATOR` define)

No commit — this task verifies behavior already implemented in Task 11 and produces no new files.

---

## Self-Review

**1. Spec coverage.**
- Firebase project setup (`firebase init`, `firebase.json`, `flutterfire configure`, Android SHA-1, iOS URL scheme) → Tasks 1–4.
- Full `pubspec.yaml` with the exact package list from the task brief plus the justified `cloud_functions` addition → Task 5.
- Cloud Functions setup (`package.json`, `tsconfig.json`, Node runtime, `firebase-admin`/`firebase-functions`, emulator suite, Gemini key via `functions:secrets:set` + `defineSecret`) → Tasks 6, 7, 10.
- Cloud Scheduler covering all nine notification types with a real TDD'd eligibility filter and `onSchedule` cron wiring → Tasks 8, 9.
- Local dev against the emulator suite plus `--dart-define` prod/emulator switch → Tasks 10–12.
- All boundaries respected: no Firestore security-rules content beyond a deny-all placeholder (Task 1 Step 6, explicitly deferred to Plan 5), no `partnerView` recompute logic, no mascot code, no onboarding screens.

**2. Placeholder scan.** No "TBD"/"fill in details"/"add error handling" left unresolved. The one intentionally-incomplete piece — `aiProxy`'s actual Gemini request/response handling — is explicitly named as out of scope with a reason (owned by whichever plan builds the feature that calls it), not left as a vague placeholder. `app.dart` in Task 11 gets a real minimal implementation, not a TODO.

**3. Type/name consistency.** `dueNotificationTypes(prefs: UserNotificationPrefs, now: Date): NotificationType[]` (Task 8) is imported with that exact signature in Task 9's `scheduler.ts`. `initializeFirebase()` (Task 11) is the exact name called from `main.dart`. `AppEnv.useEmulator` / `AppEnv.emulatorHost` (Task 11) are the exact names read in `firebase_service.dart` and referenced in Task 12's run commands. The `aiProxy` callable name (Task 7) matches what Task 5's `cloud_functions` dependency comment says the client will invoke.

**Known gaps flagged inline, not silently resolved:**
- `users/{uid}/fcmTokens/{token}` (Task 9) is not in design-spec §10's canonical path list — flagged for Plan 5 to ratify or relocate.
- Notification-eligibility fire times (Task 8's `NOTIFICATION_SCHEDULE`) and the "every 30 minutes" cron cadence are this plan's invented defaults — neither PRD specifies exact times, so these are reasonable placeholders a product owner can retune without changing the function's shape.
- Timezone handling: `dueNotificationTypes` operates on UTC wall-clock time; no per-user timezone field exists in design-spec §10's User Profile schema, so all users are treated as UTC for V0. This is a known simplification, not an oversight.
