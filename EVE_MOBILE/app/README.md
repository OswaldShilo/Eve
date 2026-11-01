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

Local (Docker Appwrite from plans/03-tech-stack.md Task 1):

    # Android emulator reaches the host at 10.0.2.2
    flutter run --dart-define=APPWRITE_ENDPOINT=http://10.0.2.2/v1 --dart-define=APPWRITE_PROJECT_ID=eve-local

Production (Appwrite Cloud):

    flutter run --release --dart-define=APPWRITE_ENDPOINT=https://<REGION>.cloud.appwrite.io/v1 --dart-define=APPWRITE_PROJECT_ID=eve-prod

Backend:

    cd functions && npm test                        # all function unit tests (no Appwrite needed)
    cd .. && appwrite push functions --all --force  # deploy to the logged-in project

Notes from the local setup (2026-11-01):

- Deploy one function per command (`--function-id <id>`); passing several `--function-id` flags deploys only the last.
- The local project needs the global variable `EVE_API_ENDPOINT=http://host.docker.internal/v1` so functions can reach the API (see `.appwrite-local/README.md`). Do not set it on Cloud.
- "Continue as Guest" works locally with no extra setup. "Sign in with Google" (and the partner join screen, which uses Google) needs a Google OAuth client ID/secret entered under Auth → OAuth2 Providers → Google (plans/03-tech-stack.md Task 3).
- The AI assistant and doctor summary need `GEMINI_API_KEY` and/or `OPENROUTER_API_KEY` (plus model IDs) set as `aiProxy` function variables (plans/03-tech-stack.md Task 7 Step 7). Without them `aiProxy` returns a friendly 503.
