# eve_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Running against Appwrite

Default (Appwrite Cloud project `eve-dev`, `https://sgp.cloud.appwrite.io/v1`,
project ID `6ae966a5002293c1e5c3` — set as defaults in `lib/core/config/app_env.dart`):

    flutter run

In debug builds the Welcome screen shows a **Ping Appwrite** chip (top right)
that calls `client.ping()` and reports success or the error. The Cloud
project needs an Android platform with package `com.shilo.eve.eve_app`
(Console → Overview → Add platform → Flutter → Android).

Local (Docker Appwrite from plans/03-tech-stack.md Task 1):

    # Android emulator reaches the host at 10.0.2.2; a physical phone uses the PC's LAN IP
    flutter run --dart-define=APPWRITE_ENDPOINT=http://10.0.2.2/v1 --dart-define=APPWRITE_PROJECT_ID=eve-local

Another Cloud project:

    flutter run --release --dart-define=APPWRITE_ENDPOINT=https://<REGION>.cloud.appwrite.io/v1 --dart-define=APPWRITE_PROJECT_ID=<PROJECT_ID>

Backend:

    cd functions && npm test                        # all function unit tests (no Appwrite needed)
    cd .. && appwrite push table --all --force       # database, tables, permissions
    appwrite push function --function-id eveEvents --force
    appwrite push function --function-id eveApi --force

Only two functions are deployed, because the free Cloud plan allows two: `eveEvents` runs
onUserCreate, partnerView, chatSystemMessages (table/user events) and notifications (every 30 min);
`eveApi` runs partnerInvites, sendChatMessage and aiProxy, chosen by the `route` field the app sends.
Each original function folder keeps its handler and tests. Delete `functions/node_modules` before
pushing so it is not uploaded.

`appwrite.config.json` targets Cloud eve-dev. To push to local Docker instead, temporarily set its
`projectId` to `eve-local` and `endpoint` to `http://localhost/v1` (do not commit that).
Google sign-in returns to the app via the `appwrite-callback-<projectId>` scheme registered in
`android/app/src/main/AndroidManifest.xml`; add one there for any new project.

Notes from the local setup (2026-11-01):

- Deploy one function per command (`--function-id <id>`); passing several `--function-id` flags deploys only the last.
- The local project needs the global variable `EVE_API_ENDPOINT=http://host.docker.internal/v1` so functions can reach the API (see `.appwrite-local/README.md`). Do not set it on Cloud.
- "Continue as Guest" works locally with no extra setup. "Sign in with Google" (and the partner join screen, which uses Google) needs a Google OAuth client ID/secret entered under Auth → OAuth2 Providers → Google (plans/03-tech-stack.md Task 3).
- The AI assistant and doctor summary need `GEMINI_API_KEY` and/or `OPENROUTER_API_KEY` (plus model IDs) set as `eveApi` function variables (plans/03-tech-stack.md Task 7 Step 7). Without them the aiProxy route returns a friendly 503.
