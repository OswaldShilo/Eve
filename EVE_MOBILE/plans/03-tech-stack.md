# EVE Tech Stack — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the concrete environment, dependency, and infrastructure layer — Appwrite project (local Docker + Cloud), Google OAuth2, Flutter package set, the `functions/` TypeScript package, the `aiProxy` Gemini→OpenRouter provider chain, cron-scheduled notification dispatch over Appwrite native push, and the local/prod run loop — that every other EVE plan assumes already exists.

**Architecture:** Two independently-buildable halves that talk over Appwrite: the Flutter client (`EVE_MOBILE/app/`) and one TypeScript package (`EVE_MOBILE/functions/`) that is deployed as several Appwrite Functions, all declared in `EVE_MOBILE/appwrite.config.json`. The client never calls an AI provider directly — every AI call and the nine-type reminder dispatch run server-side. Local vs. Cloud is a pair of `--dart-define`s (`APPWRITE_ENDPOINT`, `APPWRITE_PROJECT_ID`) read by `AppEnv` (Plan 2 Task 8).

**Tech Stack:** Flutter (Dart ≥ 3.10, Flutter ≥ 3.38.1) + Riverpod + `appwrite` 28.x; Appwrite 2.6.x (Cloud, and `appwrite/appwrite:2.6.2` self-hosted via Docker); `appwrite-cli` 28.x; Node.js 22 + TypeScript 5.9 (ESM) + `node-appwrite` 31.x + Vitest 5; Gemini REST API (AI Studio key) with OpenRouter (`/api/v1/chat/completions`, free models) as fallback.

## Global Constraints

- Frontend is Flutter (Dart), single codebase for Android + iOS — EVE2_PRD §10.1, design-spec §2.
- State management is Riverpod — design-spec §2.
- Backend is Appwrite: Auth, TablesDB, Functions, Realtime, Messaging. **No Firebase/GCP SDK, config file (`google-services.json`, `GoogleService-Info.plist`, `firebase.json`) or service may be added** — design-spec §2.
- Functions runtime is Node.js 22 / TypeScript, one package at `EVE_MOBILE/functions/`, ESM (`"type": "module"`), relative imports end in `.js` — design-spec §9.
- AI keys (`GEMINI_API_KEY`, `OPENROUTER_API_KEY`) live only in the `aiProxy` function's environment variables. They are never committed, never sent to the client, never logged — EVE2_PRD §10.1, §10.3.
- PDF export uses `pdf` + `printing`, client-side — design-spec §2. This plan only adds the packages.
- Every file lands at the path given in design-spec §9.
- Table/function IDs and stored vocabularies are fixed by design-spec §10. The nine notification types are exactly `morning`, `medicine`, `workout`, `water`, `sleep`, `cycle`, `appointment`, `mood`, `daily_tip` (exported as `NOTIFICATION_TYPES` by Plan 5 Task 1).
- Copy voice is formal and warm, no emojis — applies to notification bodies (Task 9) and the AI system prompt (Task 7).
- Out of scope (owned elsewhere): table schema and permissions (Plan 5), `partnerView`/chat functions (Plan 7), `AppEnv`/`AppwriteService` client wrapper (Plan 2 Task 8), mascot (Plan 6), screens (Plan 1).
- Package versions below were checked on 2026-11-01 (pub.dev / npm). Riverpod, go_router and google_fonts stay on the majors the already-scaffolded app uses (`02-system-architecture.md` Task 1) — upgrading them is a separate decision, not part of the backend swap.

---

## Task 1: Local Appwrite (Docker) + project + CLI

**Files:**
- Create: `EVE_MOBILE/.appwrite-local/README.md`
- Modify: `EVE_MOBILE/.gitignore` (create if missing)

**Interfaces:**
- Produces: a running Appwrite 2.6.2 at `http://localhost` with a project whose ID is `eve-local`, a server API key for the CLI, and `appwrite` CLI logged in. Every later "verify against local Appwrite" step assumes this.

- [ ] **Step 1: Verify prerequisites**

```bash
docker --version
node --version
```

Expected: Docker 24+ (Docker Desktop on Windows, WSL2 backend), Node `v22.x` or newer. Install Node 22 LTS if older.

- [ ] **Step 2: Install self-hosted Appwrite**

From `EVE_MOBILE/.appwrite-local/` in PowerShell:

```powershell
docker run -it --rm `
    --publish 20080:20080 `
    --volume /var/run/docker.sock:/var/run/docker.sock `
    --volume ${pwd}/appwrite:/usr/src/code/appwrite:rw `
    --entrypoint="install" `
    appwrite/appwrite:2.6.2
```

Open `http://localhost:20080` and complete the wizard: HTTP port `80`, HTTPS port `443`, hostname `localhost`. Expected: `docker ps` lists the `appwrite` stack (appwrite, mariadb, redis, executor, realtime, …) and `http://localhost/console` loads.

> **Verified on Windows 11 / Docker Desktop 29.9 (2026-11-01).** The web wizard can be skipped: run the same command without `-it`/`--publish` and with `--interactive=N --http-port=80 --https-port=443` appended. Two Windows-specific fixes were needed:
> 1. Port **8883** (Traefik's MQTT entrypoint) is inside a Windows excluded port range (`netsh interface ipv4 show excludedportrange protocol=tcp`), so `docker compose up` fails with `bind: An attempt was made to access a socket in a way forbidden`. Append `_APP_MQTT_PORT=18883` to `appwrite/.env` and run `docker compose -f appwrite/docker-compose.yml up -d`. EVE does not use MQTT.
> 2. Function runtimes receive `APPWRITE_FUNCTION_API_ENDPOINT=http://localhost/v1`, which a runtime container cannot reach (`TypeError: fetch failed`), and a function variable of the same name does **not** override it. `serverClient` therefore honours `EVE_API_ENDPOINT` first (Task 5); set it once as a **project** variable on the local project: Console → Settings → Global variables → `EVE_API_ENDPOINT` = `http://host.docker.internal/v1`. Do not set it on Cloud.
>
> The API key needs these scopes beyond the obvious ones for `appwrite push`: `collections.write`/`attributes.write`/`indexes.write` (legacy names the CLI still checks), `rules.read` (function push), and `project.write` (to create the global variable via API).

- [ ] **Step 3: Create the project**

In the console: sign up (local admin account), **Create project** → name `EVE (local)`, **Project ID `eve-local`**. Then **Overview → Integrations → API keys → Create API key** named `cli-local` with all scopes. Copy the secret.

- [ ] **Step 4: Install and log in the CLI**

```bash
npm install -g appwrite-cli@28
appwrite --version
appwrite login --endpoint http://localhost/v1
```

Expected: version `28.x`; login succeeds with the console account.

- [ ] **Step 5: Ignore local state**

Append to `EVE_MOBILE/.gitignore`:

```
# Appwrite self-hosted data and CLI session
.appwrite-local/appwrite/
.appwrite/
functions/node_modules/
functions/dist/
```

Create `EVE_MOBILE/.appwrite-local/README.md`:

```markdown
# Local Appwrite

Self-hosted Appwrite 2.6.2 for development. Install with the `docker run ... --entrypoint="install" appwrite/appwrite:2.6.2`
command in `plans/03-tech-stack.md` Task 1, from this directory. Stop with `docker compose -f appwrite/docker-compose.yml down`,
start again with `docker compose -f appwrite/docker-compose.yml up -d`.

Project ID: `eve-local`. Console: http://localhost/console. API endpoint: http://localhost/v1
(Android emulator: http://10.0.2.2/v1, physical device: http://<your LAN IP>/v1).
```

- [ ] **Step 6: Commit**

```bash
git add EVE_MOBILE/.gitignore EVE_MOBILE/.appwrite-local/README.md
git commit -m "chore: document local Appwrite setup"
```

---

## Task 2: `appwrite.config.json` skeleton

**Files:**
- Create: `EVE_MOBILE/appwrite.config.json`

**Interfaces:**
- Produces: the single declarative config every plan appends to — Plan 5 Task 3 fills `tables`, Plan 5/7 and Tasks 7/9 below append to `functions`. Nothing else in the repo describes Appwrite resources.

- [ ] **Step 1: Create the file**

```json
{
  "projectId": "eve-local",
  "projectName": "EVE (local)",
  "endpoint": "http://localhost/v1",
  "tablesDB": [
    {
      "$id": "eve",
      "name": "eve",
      "enabled": true
    }
  ],
  "tables": [],
  "functions": []
}
```

- [ ] **Step 2: Push the database and verify**

Run (from `EVE_MOBILE/`):

```bash
appwrite push tables --all --force
```

Expected: the CLI reports database `eve` created (no tables yet). Console → Databases shows `eve`.

- [ ] **Step 3: Commit**

```bash
git add EVE_MOBILE/appwrite.config.json
git commit -m "chore: add appwrite.config.json skeleton with eve database"
```

---

## Task 3: Google OAuth2 provider + Android/iOS callback wiring

**Files:**
- Modify: `EVE_MOBILE/app/android/app/src/main/AndroidManifest.xml`
- Modify: `EVE_MOBILE/app/ios/Podfile` (deployment target)

**Interfaces:**
- Produces: `Account.createOAuth2Session(provider: OAuthProvider.google)` works on Android and iOS against both local and Cloud projects. Plan 1's Auth screen calls it through `AppwriteService` (Plan 2 Task 8).

**Note on "no GCP":** a Google OAuth client ID/secret is created in the Google Auth Platform console (`console.cloud.google.com/auth/clients`). That creates OAuth credentials only — no billing account, no enabled services, nothing hosted. It is the unavoidable cost of "Sign in with Google" for any backend. If the team wants zero Google console use, swap the provider for Appwrite email OTP (`account.createEmailToken`) — Plan 1's Auth screen only needs the button label changed.

- [ ] **Step 1: Create the Google OAuth client**

In the Google Auth Platform console: create an OAuth client of type **Web application** named `EVE Appwrite`. Authorized redirect URI: the URI Appwrite shows in the next step (format `<endpoint>/account/sessions/oauth2/callback/google/<projectId>`). Copy the client ID and secret.

- [ ] **Step 2: Enable Google in Appwrite**

Console → Auth → Settings → OAuth2 Providers → **Google** → paste client ID (as App ID) and secret → Enable. Repeat for the Cloud project in Task 10. Note: Google rejects `http://localhost` redirects only for non-Web client types; a Web client with `http://localhost/v1/...` works for local testing on desktop browsers, but a phone cannot reach `localhost` — for device testing use an `ngrok http 80` tunnel and set the tunnel URL as the Appwrite endpoint (`_APP_DOMAIN`) and redirect URI.

- [ ] **Step 3: Register the Android callback activity**

Add inside `<application>` in `EVE_MOBILE/app/android/app/src/main/AndroidManifest.xml` (one activity per project ID you build against — local and Cloud):

```xml
        <activity
            android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
            android:exported="true"
            android:taskAffinity="">
            <intent-filter android:label="flutter_web_auth_2">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="appwrite-callback-eve-local" />
                <data android:scheme="appwrite-callback-eve-prod" />
            </intent-filter>
        </activity>
```

- [ ] **Step 4: iOS deployment target**

iOS uses `ASWebAuthenticationSession` and needs no URL scheme. Set the minimum to 13.0: in `EVE_MOBILE/app/ios/Podfile` ensure the first line is `platform :ios, '13.0'` (uncomment/replace the generated line), and in Xcode set Runner → General → Minimum Deployments to 13.0.

- [ ] **Step 5: Register the app platforms in Appwrite**

Console → Overview → Platforms → Add platform → **Flutter**: Android with package `com.thinkroot.eve.eve_app`, iOS with bundle ID from `ios/Runner.xcodeproj` (`com.thinkroot.eve.eveApp`). Without a registered platform Appwrite rejects client requests with `general_unknown_origin`.

- [ ] **Step 6: Commit**

```bash
git add EVE_MOBILE/app/android/app/src/main/AndroidManifest.xml EVE_MOBILE/app/ios/Podfile
git commit -m "feat(app): wire Appwrite Google OAuth2 callback for Android and iOS"
```

Verification of the actual sign-in happens in Plan 2 Task 8 Step 8 once `AppwriteService` exists.

---

## Task 4: Flutter `pubspec.yaml` dependency set

**Files:**
- Modify: `EVE_MOBILE/app/pubspec.yaml`

**Interfaces:**
- Produces: the canonical dependency set (roadmap CN-1). Removes every Firebase package.

- [ ] **Step 1: Replace `EVE_MOBILE/app/pubspec.yaml`**

```yaml
name: eve_app
description: EVE — an AI-powered adaptive health companion for women.
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: '>=3.10.0 <4.0.0'
  flutter: '>=3.38.1'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.0
  go_router: ^14.0.0
  google_fonts: ^6.2.0
  appwrite: ^28.2.0
  pdf: ^3.13.1
  printing: ^5.15.1
  intl: ^0.20.2
  cupertino_icons: ^1.0.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  mocktail: ^1.0.5

flutter:
  uses-material-design: true
```

Why the SDK floor moved: `appwrite` 28.x requires Dart ≥ 3.10 / Flutter ≥ 3.38.1.

- [ ] **Step 2: Resolve**

```bash
cd EVE_MOBILE/app
flutter --version
flutter pub get
```

Expected: Flutter ≥ 3.38.1; `pub get` succeeds. **This step intentionally breaks compilation of `lib/core/services/firebase_service.dart`** until Plan 2 Task 8 replaces it — run them back to back (roadmap M2).

- [ ] **Step 3: Commit (together with Plan 2 Task 8, see roadmap M2)**

---

## Task 5: Functions package scaffold + shared execution helpers

**Files:**
- Create: `EVE_MOBILE/functions/package.json`
- Create: `EVE_MOBILE/functions/tsconfig.json`
- Create: `EVE_MOBILE/functions/tsconfig.build.json`
- Create: `EVE_MOBILE/functions/vitest.config.ts`
- Create: `EVE_MOBILE/functions/shared/src/appwrite.ts`
- Test: `EVE_MOBILE/functions/shared/test/appwrite.test.ts`

**Interfaces:**
- Produces: `FunctionContext`, `serverClient(context)`, `serverMessaging(context)`, `callerId(context)`, `readJsonBody(context)`, `eventName(context)` — every function entrypoint in Plans 3/5/7 uses these. `npm test` / `npm run build` / `npm run typecheck` scripts.

- [ ] **Step 1: Create `EVE_MOBILE/functions/package.json`**

```json
{
  "name": "eve-functions",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "engines": {
    "node": ">=22"
  },
  "scripts": {
    "build": "tsc -p tsconfig.build.json",
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  },
  "dependencies": {
    "node-appwrite": "^31.1.0"
  },
  "devDependencies": {
    "@types/node": "^22.20.5",
    "typescript": "^5.9.0",
    "vitest": "^5.0.5"
  }
}
```

- [ ] **Step 2: Create `EVE_MOBILE/functions/tsconfig.json` and `tsconfig.build.json`**

`tsconfig.json` (type-checks sources and tests):

```json
{
  "compilerOptions": {
    "target": "es2023",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "strict": true,
    "noImplicitReturns": true,
    "noUnusedLocals": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "outDir": "dist",
    "rootDir": "."
  },
  "include": ["*/src/**/*.ts", "*/test/**/*.ts", "vitest.config.ts"]
}
```

`tsconfig.build.json` (emits only function sources — `dist/<name>/src/main.js` is each function's entrypoint):

```json
{
  "extends": "./tsconfig.json",
  "include": ["*/src/**/*.ts"]
}
```

- [ ] **Step 3: Create `EVE_MOBILE/functions/vitest.config.ts`**

```ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['*/test/**/*.test.ts'],
    environment: 'node',
  },
});
```

- [ ] **Step 4: Install**

```bash
cd EVE_MOBILE/functions
npm install
```

Expected: exits 0, creates `package-lock.json`.

- [ ] **Step 5: Write the failing helper tests**

Create `EVE_MOBILE/functions/shared/test/appwrite.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { callerId, eventName, readJsonBody, type FunctionContext } from '../src/appwrite.js';

function context(headers: Record<string, string>, body: { bodyJson?: unknown; bodyText?: string } = {}): FunctionContext {
  return {
    req: { headers, method: 'POST', ...body },
    res: { json: (b: unknown, status = 200) => ({ b, status }) },
    log: () => undefined,
    error: () => undefined,
  };
}

describe('execution helpers', () => {
  it('reads the caller from x-appwrite-user-id and treats empty as anonymous', () => {
    expect(callerId(context({ 'x-appwrite-user-id': 'u1' }))).toBe('u1');
    expect(callerId(context({ 'x-appwrite-user-id': '' }))).toBeNull();
    expect(callerId(context({}))).toBeNull();
  });

  it('parses the JSON body from bodyJson or bodyText, null when invalid', () => {
    expect(readJsonBody(context({}, { bodyJson: { feature: 'ping' } }))).toEqual({ feature: 'ping' });
    expect(readJsonBody(context({}, { bodyText: '{"feature":"ping"}' }))).toEqual({ feature: 'ping' });
    expect(readJsonBody(context({}, { bodyText: 'not json' }))).toBeNull();
  });

  it('exposes the triggering event name', () => {
    expect(eventName(context({ 'x-appwrite-event': 'users.u1.create' }))).toBe('users.u1.create');
    expect(eventName(context({}))).toBeNull();
  });
});
```

- [ ] **Step 6: Run to verify it fails**

Run: `npx vitest run shared/test/appwrite.test.ts`
Expected: FAIL — `Failed to resolve import "../src/appwrite.js"`.

- [ ] **Step 7: Implement `EVE_MOBILE/functions/shared/src/appwrite.ts`**

```ts
import { Client, Messaging } from 'node-appwrite';

/** The subset of the Appwrite Functions runtime context EVE's functions use. */
export interface FunctionContext {
  req: {
    headers: Record<string, string | undefined>;
    method?: string;
    bodyJson?: unknown;
    bodyText?: string;
  };
  res: {
    json(body: unknown, statusCode?: number): unknown;
  };
  log(message: unknown): void;
  error(message: unknown): void;
}

/**
 * Server client authenticated with the execution's dynamic API key
 * (`x-appwrite-key`), scoped to the function's configured `scopes`.
 * APPWRITE_FUNCTION_API_ENDPOINT / _PROJECT_ID are injected by the runtime.
 */
export function serverClient(context: FunctionContext): Client {
  return new Client()
    .setEndpoint(process.env.APPWRITE_FUNCTION_API_ENDPOINT ?? '')
    .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID ?? '')
    .setKey(context.req.headers['x-appwrite-key'] ?? '');
}

export function serverMessaging(context: FunctionContext): Messaging {
  return new Messaging(serverClient(context));
}

/** The signed-in user who created this execution, or null (events, schedule, anonymous). */
export function callerId(context: FunctionContext): string | null {
  const id = context.req.headers['x-appwrite-user-id'];
  return id ? id : null;
}

export function readJsonBody<T = Record<string, unknown>>(context: FunctionContext): T | null {
  if (context.req.bodyJson !== undefined && context.req.bodyJson !== null && typeof context.req.bodyJson === 'object') {
    return context.req.bodyJson as T;
  }
  if (!context.req.bodyText) return null;
  try {
    return JSON.parse(context.req.bodyText) as T;
  } catch {
    return null;
  }
}

export function eventName(context: FunctionContext): string | null {
  return context.req.headers['x-appwrite-event'] ?? null;
}
```

- [ ] **Step 8: Run to verify it passes**

Run: `npx vitest run shared/test/appwrite.test.ts && npm run typecheck`
Expected: `3 passed`; typecheck exits 0.

- [ ] **Step 9: Commit**

```bash
git add EVE_MOBILE/functions/package.json EVE_MOBILE/functions/package-lock.json EVE_MOBILE/functions/tsconfig.json EVE_MOBILE/functions/tsconfig.build.json EVE_MOBILE/functions/vitest.config.ts EVE_MOBILE/functions/shared/src/appwrite.ts EVE_MOBILE/functions/shared/test/appwrite.test.ts
git commit -m "feat(functions): scaffold TypeScript functions package with execution helpers"
```

---

## Task 6: AI provider chain — Gemini primary, OpenRouter free models fallback

**Files:**
- Create: `EVE_MOBILE/functions/aiProxy/src/providers.ts`
- Test: `EVE_MOBILE/functions/aiProxy/test/providers.test.ts`

**Interfaces:**
- Produces: `AiPrompt`, `AiResult`, `AiProvider`, `ProviderError`, `AllProvidersFailedError`, `geminiProvider(opts)`, `openRouterProvider(opts)`, `generateWithFallback(providers, prompt, log?)`, `providersFromEnv(env, fetchFn?)`. Task 7 and roadmap M19 call only `generateWithFallback`/`providersFromEnv`.

**Fallback rule:** the next provider is tried when the current one times out, returns HTTP 429 or any other non-2xx, throws a network error, or returns empty text. Gemini gets 12 s, OpenRouter 15 s — together under Appwrite's 30 s synchronous-execution limit. (Verified on local Appwrite 2.6.2: a synchronous execution is cut off at 30 s with `408 Synchronous function execution timed out`, regardless of the function's own `timeout`; the 25 s probe completed, the 45 s one returned 408 at 30.1 s.)

- [ ] **Step 1: Write the failing tests**

Create `EVE_MOBILE/functions/aiProxy/test/providers.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import {
  AllProvidersFailedError,
  generateWithFallback,
  geminiProvider,
  openRouterProvider,
  providersFromEnv,
  type AiPrompt,
} from '../src/providers.js';

const prompt: AiPrompt = { system: 'Be warm.', user: 'Hello', maxOutputTokens: 200 };

type FetchArgs = [string, RequestInit];
function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
}
function recordingFetch(responses: Response[]) {
  const calls: FetchArgs[] = [];
  const fn = async (url: string | URL | Request, init?: RequestInit) => {
    calls.push([String(url), init ?? {}]);
    const next = responses.shift();
    if (!next) throw new Error('no more responses');
    return next;
  };
  return { fn: fn as typeof fetch, calls };
}
const hangingFetch = ((_: unknown, init?: RequestInit) =>
  new Promise<Response>((_resolve, reject) => {
    init?.signal?.addEventListener('abort', () => reject(init.signal?.reason));
  })) as typeof fetch;

const geminiOk = { candidates: [{ content: { parts: [{ text: 'Hi from ' }, { text: 'Gemini' }] } }] };
const openRouterOk = { model: 'meta-llama/x:free', choices: [{ message: { role: 'assistant', content: 'Hi from OpenRouter' } }] };

describe('geminiProvider', () => {
  it('posts generateContent with the key header, system instruction and token limit', async () => {
    const { fn, calls } = recordingFetch([jsonResponse(200, geminiOk)]);
    const result = await geminiProvider({ apiKey: 'g-key', model: 'gemini-test', fetchFn: fn }).generate(
      prompt,
      AbortSignal.timeout(1000),
    );

    expect(result).toEqual({ text: 'Hi from Gemini', provider: 'gemini', model: 'gemini-test' });
    const [url, init] = calls[0];
    expect(url).toBe('https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent');
    expect((init.headers as Record<string, string>)['x-goog-api-key']).toBe('g-key');
    const body = JSON.parse(String(init.body));
    expect(body.systemInstruction.parts[0].text).toBe('Be warm.');
    expect(body.contents[0].parts[0].text).toBe('Hello');
    expect(body.generationConfig.maxOutputTokens).toBe(200);
  });
});

describe('openRouterProvider', () => {
  it('posts chat completions with bearer auth and the models fallback list', async () => {
    const { fn, calls } = recordingFetch([jsonResponse(200, openRouterOk)]);
    const result = await openRouterProvider({
      apiKey: 'or-key',
      models: ['a/b:free', 'c/d:free'],
      fetchFn: fn,
    }).generate(prompt, AbortSignal.timeout(1000));

    expect(result).toEqual({ text: 'Hi from OpenRouter', provider: 'openrouter', model: 'meta-llama/x:free' });
    const [url, init] = calls[0];
    expect(url).toBe('https://openrouter.ai/api/v1/chat/completions');
    expect((init.headers as Record<string, string>).Authorization).toBe('Bearer or-key');
    const body = JSON.parse(String(init.body));
    expect(body.models).toEqual(['a/b:free', 'c/d:free']);
    expect(body.messages).toEqual([
      { role: 'system', content: 'Be warm.' },
      { role: 'user', content: 'Hello' },
    ]);
    expect(body.max_tokens).toBe(200);
  });
});

describe('generateWithFallback', () => {
  it('uses Gemini when it succeeds and never calls OpenRouter', async () => {
    const gemini = recordingFetch([jsonResponse(200, geminiOk)]);
    const openRouter = recordingFetch([]);
    const result = await generateWithFallback(
      [
        geminiProvider({ apiKey: 'g', model: 'm', fetchFn: gemini.fn }),
        openRouterProvider({ apiKey: 'o', models: ['x:free'], fetchFn: openRouter.fn }),
      ],
      prompt,
    );
    expect(result.provider).toBe('gemini');
    expect(openRouter.calls).toHaveLength(0);
  });

  it.each([
    ['429 rate limit', () => jsonResponse(429, { error: { message: 'quota' } })],
    ['500 server error', () => jsonResponse(500, { error: { message: 'boom' } })],
    ['empty candidates', () => jsonResponse(200, { candidates: [] })],
  ])('falls back to OpenRouter on Gemini %s', async (_label, failure) => {
    const gemini = recordingFetch([failure()]);
    const openRouter = recordingFetch([jsonResponse(200, openRouterOk)]);
    const result = await generateWithFallback(
      [
        geminiProvider({ apiKey: 'g', model: 'm', fetchFn: gemini.fn }),
        openRouterProvider({ apiKey: 'o', models: ['x:free'], fetchFn: openRouter.fn }),
      ],
      prompt,
    );
    expect(result.provider).toBe('openrouter');
  });

  it('falls back when Gemini exceeds its timeout', async () => {
    const openRouter = recordingFetch([jsonResponse(200, openRouterOk)]);
    const result = await generateWithFallback(
      [
        geminiProvider({ apiKey: 'g', model: 'm', fetchFn: hangingFetch, timeoutMs: 20 }),
        openRouterProvider({ apiKey: 'o', models: ['x:free'], fetchFn: openRouter.fn }),
      ],
      prompt,
    );
    expect(result.provider).toBe('openrouter');
  });

  it('throws AllProvidersFailedError listing each failure, without leaking keys', async () => {
    const gemini = recordingFetch([jsonResponse(429, {})]);
    const openRouter = recordingFetch([jsonResponse(503, {})]);
    const error = await generateWithFallback(
      [
        geminiProvider({ apiKey: 'secret-g', model: 'm', fetchFn: gemini.fn }),
        openRouterProvider({ apiKey: 'secret-o', models: ['x:free'], fetchFn: openRouter.fn }),
      ],
      prompt,
    ).catch((e) => e);
    expect(error).toBeInstanceOf(AllProvidersFailedError);
    expect(error.message).toContain('gemini: HTTP 429');
    expect(error.message).toContain('openrouter: HTTP 503');
    expect(error.message).not.toContain('secret');
  });
});

describe('providersFromEnv', () => {
  it('orders Gemini first and skips providers without keys', () => {
    expect(
      providersFromEnv({ GEMINI_API_KEY: 'g', GEMINI_MODEL: 'gm', OPENROUTER_API_KEY: 'o', OPENROUTER_MODELS: 'a:free, b:free' }).map(
        (p) => p.name,
      ),
    ).toEqual(['gemini', 'openrouter']);
    expect(providersFromEnv({ OPENROUTER_API_KEY: 'o', OPENROUTER_MODELS: 'a:free' }).map((p) => p.name)).toEqual([
      'openrouter',
    ]);
    expect(providersFromEnv({ OPENROUTER_API_KEY: 'o' }).map((p) => p.name)).toEqual([]);
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run aiProxy/test/providers.test.ts`
Expected: FAIL — `Failed to resolve import "../src/providers.js"`.

- [ ] **Step 3: Implement `EVE_MOBILE/functions/aiProxy/src/providers.ts`**

```ts
export interface AiPrompt {
  system: string;
  user: string;
  maxOutputTokens: number;
}

export interface AiResult {
  text: string;
  provider: 'gemini' | 'openrouter';
  model: string;
}

export interface AiProvider {
  readonly name: AiResult['provider'];
  readonly timeoutMs: number;
  generate(prompt: AiPrompt, signal: AbortSignal): Promise<AiResult>;
}

export class ProviderError extends Error {
  constructor(message: string, readonly status?: number) {
    super(message);
  }
}

export class AllProvidersFailedError extends Error {}

type FetchFn = typeof fetch;

async function postJson(fetchFn: FetchFn, url: string, headers: Record<string, string>, body: unknown, signal: AbortSignal) {
  const response = await fetchFn(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: JSON.stringify(body),
    signal,
  });
  if (!response.ok) throw new ProviderError(`HTTP ${response.status}`, response.status);
  return (await response.json()) as unknown;
}

export function geminiProvider(opts: { apiKey: string; model: string; fetchFn?: FetchFn; timeoutMs?: number }): AiProvider {
  const fetchFn = opts.fetchFn ?? fetch;
  return {
    name: 'gemini',
    timeoutMs: opts.timeoutMs ?? 12_000,
    async generate(prompt, signal) {
      const json = (await postJson(
        fetchFn,
        `https://generativelanguage.googleapis.com/v1beta/models/${opts.model}:generateContent`,
        { 'x-goog-api-key': opts.apiKey },
        {
          systemInstruction: { parts: [{ text: prompt.system }] },
          contents: [{ role: 'user', parts: [{ text: prompt.user }] }],
          generationConfig: { maxOutputTokens: prompt.maxOutputTokens },
        },
        signal,
      )) as { candidates?: { content?: { parts?: { text?: string }[] } }[] };
      const text = (json.candidates?.[0]?.content?.parts ?? []).map((part) => part.text ?? '').join('').trim();
      if (!text) throw new ProviderError('empty response');
      return { text, provider: 'gemini', model: opts.model };
    },
  };
}

export function openRouterProvider(opts: {
  apiKey: string;
  models: string[];
  fetchFn?: FetchFn;
  timeoutMs?: number;
}): AiProvider {
  const fetchFn = opts.fetchFn ?? fetch;
  return {
    name: 'openrouter',
    timeoutMs: opts.timeoutMs ?? 15_000,
    async generate(prompt, signal) {
      const json = (await postJson(
        fetchFn,
        'https://openrouter.ai/api/v1/chat/completions',
        { Authorization: `Bearer ${opts.apiKey}`, 'X-Title': 'EVE' },
        {
          models: opts.models,
          messages: [
            { role: 'system', content: prompt.system },
            { role: 'user', content: prompt.user },
          ],
          max_tokens: prompt.maxOutputTokens,
        },
        signal,
      )) as { model?: string; choices?: { message?: { content?: string } }[] };
      const text = (json.choices?.[0]?.message?.content ?? '').trim();
      if (!text) throw new ProviderError('empty response');
      return { text, provider: 'openrouter', model: json.model ?? opts.models[0] };
    },
  };
}

/** Tries each provider in order with its own timeout; first non-empty answer wins. */
export async function generateWithFallback(
  providers: AiProvider[],
  prompt: AiPrompt,
  log: (message: string) => void = () => undefined,
): Promise<AiResult> {
  const failures: string[] = [];
  for (const provider of providers) {
    try {
      return await provider.generate(prompt, AbortSignal.timeout(provider.timeoutMs));
    } catch (e) {
      const reason =
        e instanceof ProviderError
          ? e.message
          : e instanceof Error && (e.name === 'TimeoutError' || e.name === 'AbortError')
            ? `timeout after ${provider.timeoutMs}ms`
            : 'network error';
      failures.push(`${provider.name}: ${reason}`);
      log(`aiProxy: ${provider.name} failed (${reason}), trying next provider`);
    }
  }
  throw new AllProvidersFailedError(`All AI providers failed — ${failures.join('; ') || 'none configured'}`);
}

/** Gemini first (when keyed), then OpenRouter (when keyed and models are listed). */
export function providersFromEnv(env: Record<string, string | undefined>, fetchFn?: FetchFn): AiProvider[] {
  const providers: AiProvider[] = [];
  if (env.GEMINI_API_KEY) {
    providers.push(geminiProvider({ apiKey: env.GEMINI_API_KEY, model: env.GEMINI_MODEL || 'gemini-3.8-flash', fetchFn }));
  }
  const models = (env.OPENROUTER_MODELS ?? '')
    .split(',')
    .map((m) => m.trim())
    .filter(Boolean);
  if (env.OPENROUTER_API_KEY && models.length > 0) {
    providers.push(openRouterProvider({ apiKey: env.OPENROUTER_API_KEY, models, fetchFn }));
  }
  return providers;
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `npx vitest run aiProxy/test/providers.test.ts && npm run typecheck`
Expected: `9 passed`; typecheck exits 0.

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/functions/aiProxy/src/providers.ts EVE_MOBILE/functions/aiProxy/test/providers.test.ts
git commit -m "feat(aiProxy): add Gemini provider with OpenRouter free-model fallback"
```

---

## Task 7: `aiProxy` function — auth gate, feature routing, environment variables

**Files:**
- Create: `EVE_MOBILE/functions/aiProxy/src/handle.ts`
- Create: `EVE_MOBILE/functions/aiProxy/src/main.ts`
- Test: `EVE_MOBILE/functions/aiProxy/test/handle.test.ts`
- Modify: `EVE_MOBILE/appwrite.config.json` (append to `functions`)

**Interfaces:**
- Consumes: `generateWithFallback`, `providersFromEnv`, `AiProvider` (Task 6); `callerId`, `readJsonBody`, `FunctionContext` (Task 5).
- Produces: `EVE_SYSTEM_PROMPT`, `handleAiRequest(deps, uid, body)` returning `{ status, body }`, and the deployed `aiProxy` function (execute: `users`). Features: `ping` (reachability) and `checkIn` (one conversational reply). Roadmap M19 adds `doctorSummary` to the same switch.

- [ ] **Step 1: Write the failing tests**

Create `EVE_MOBILE/functions/aiProxy/test/handle.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { EVE_SYSTEM_PROMPT, handleAiRequest } from '../src/handle.js';
import type { AiPrompt, AiProvider } from '../src/providers.js';

function fakeProvider(reply: string, seen: AiPrompt[] = []): AiProvider {
  return {
    name: 'gemini',
    timeoutMs: 1000,
    async generate(prompt) {
      seen.push(prompt);
      return { text: reply, provider: 'gemini', model: 'fake' };
    },
  };
}

describe('handleAiRequest', () => {
  it('rejects anonymous callers', async () => {
    const result = await handleAiRequest({ providers: [fakeProvider('x')] }, null, { feature: 'ping' });
    expect(result.status).toBe(401);
  });

  it('ping reports configured providers without calling them', async () => {
    const seen: AiPrompt[] = [];
    const result = await handleAiRequest({ providers: [fakeProvider('x', seen)] }, 'u1', { feature: 'ping' });
    expect(result).toEqual({ status: 200, body: { ok: true, providers: ['gemini'] } });
    expect(seen).toHaveLength(0);
  });

  it('checkIn sends the Eve system prompt and returns the reply with its provider', async () => {
    const seen: AiPrompt[] = [];
    const result = await handleAiRequest({ providers: [fakeProvider('Thank you for sharing.', seen)] }, 'u1', {
      feature: 'checkIn',
      message: 'I slept badly.',
    });
    expect(result).toEqual({ status: 200, body: { reply: 'Thank you for sharing.', provider: 'gemini' } });
    expect(seen[0].system).toBe(EVE_SYSTEM_PROMPT);
    expect(seen[0].user).toBe('I slept badly.');
  });

  it('validates input and unknown features', async () => {
    expect((await handleAiRequest({ providers: [] }, 'u1', { feature: 'checkIn' })).status).toBe(400);
    expect((await handleAiRequest({ providers: [] }, 'u1', { feature: 'nope' })).status).toBe(400);
    expect((await handleAiRequest({ providers: [] }, 'u1', null)).status).toBe(400);
  });

  it('returns 503 when every provider fails', async () => {
    const failing: AiProvider = {
      name: 'gemini',
      timeoutMs: 1000,
      generate: async () => {
        throw new Error('down');
      },
    };
    const result = await handleAiRequest({ providers: [failing] }, 'u1', { feature: 'checkIn', message: 'hi' });
    expect(result.status).toBe(503);
  });

  it('the system prompt forbids diagnoses and emojis', () => {
    expect(EVE_SYSTEM_PROMPT).toContain('Never state or suggest a diagnosis');
    expect(EVE_SYSTEM_PROMPT).toContain('Do not use emojis');
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run aiProxy/test/handle.test.ts`
Expected: FAIL — `Failed to resolve import "../src/handle.js"`.

- [ ] **Step 3: Implement `EVE_MOBILE/functions/aiProxy/src/handle.ts`**

```ts
import { AllProvidersFailedError, generateWithFallback, type AiProvider } from './providers.js';

export const EVE_SYSTEM_PROMPT = [
  'You are Eve, a warm and formal health companion inside the EVE app for women.',
  'Reply in two to four short sentences. Do not use emojis.',
  'Never state or suggest a diagnosis. When something sounds medically concerning, recommend discussing it with a healthcare professional.',
  'Do not invent facts about the user beyond what she tells you.',
].join(' ');

export interface AiDeps {
  providers: AiProvider[];
  log?: (message: string) => void;
}

export interface AiResponse {
  status: number;
  body: Record<string, unknown>;
}

const MAX_MESSAGE_LENGTH = 2000;

export async function handleAiRequest(deps: AiDeps, uid: string | null, body: Record<string, unknown> | null): Promise<AiResponse> {
  if (!uid) return { status: 401, body: { error: 'Sign in required to use the AI assistant.' } };
  if (!body || typeof body.feature !== 'string') return { status: 400, body: { error: 'Missing "feature".' } };

  try {
    switch (body.feature) {
      case 'ping':
        return { status: 200, body: { ok: true, providers: deps.providers.map((p) => p.name) } };
      case 'checkIn': {
        const message = typeof body.message === 'string' ? body.message.trim() : '';
        if (!message || message.length > MAX_MESSAGE_LENGTH) {
          return { status: 400, body: { error: 'checkIn requires a "message" of 1-2000 characters.' } };
        }
        const result = await generateWithFallback(
          deps.providers,
          { system: EVE_SYSTEM_PROMPT, user: message, maxOutputTokens: 300 },
          deps.log,
        );
        return { status: 200, body: { reply: result.text, provider: result.provider } };
      }
      default:
        return { status: 400, body: { error: `Unknown feature "${body.feature}".` } };
    }
  } catch (e) {
    if (e instanceof AllProvidersFailedError) {
      deps.log?.(e.message);
      return { status: 503, body: { error: 'The assistant is unavailable right now. Please try again shortly.' } };
    }
    throw e;
  }
}
```

Note: a failing provider that throws a plain `Error` (as in the test) is reported by `generateWithFallback` as `network error` and the chain still ends in `AllProvidersFailedError` → 503.

- [ ] **Step 4: Implement the entrypoint `EVE_MOBILE/functions/aiProxy/src/main.ts`**

```ts
import { callerId, readJsonBody, type FunctionContext } from '../../shared/src/appwrite.js';
import { handleAiRequest } from './handle.js';
import { providersFromEnv } from './providers.js';

export default async (context: FunctionContext) => {
  const result = await handleAiRequest(
    { providers: providersFromEnv(process.env), log: (m) => context.log(m) },
    callerId(context),
    readJsonBody(context),
  );
  return context.res.json(result.body, result.status);
};
```

- [ ] **Step 5: Register the function — append to `functions` in `EVE_MOBILE/appwrite.config.json`**

```json
    {
      "$id": "aiProxy",
      "name": "aiProxy",
      "runtime": "node-22",
      "specification": "s-0.5vcpu-512mb",
      "execute": ["users"],
      "events": [],
      "scopes": ["rows.read"],
      "schedule": "",
      "timeout": 30,
      "enabled": true,
      "logging": true,
      "entrypoint": "dist/aiProxy/src/main.js",
      "commands": "npm ci && npm run build",
      "path": "functions"
    }
```

(`rows.read` is used by M19's `doctorSummary`, which reads her logs server-side.)

- [ ] **Step 6: Run to verify it passes**

Run: `npx vitest run aiProxy && npm run typecheck`
Expected: all `aiProxy` tests pass (9 providers + 6 handle).

- [ ] **Step 7: Choose models and set the secrets (never committed)**

List the models your Gemini key can use and pick the Pro-tier ID for `GEMINI_MODEL`:

```bash
curl -s -H "x-goog-api-key: $GEMINI_API_KEY" "https://generativelanguage.googleapis.com/v1beta/models" | grep '"name"'
```

List current free OpenRouter models and pick 2–3 for `OPENROUTER_MODELS` (free model availability changes often — re-check before a demo):

```bash
curl -s https://openrouter.ai/api/v1/models | grep -o '"id":"[^"]*:free"'
```

Deploy, then set the variables on the function (local project first; repeat against Cloud in Task 10):

```bash
cd EVE_MOBILE
appwrite push functions --function-id aiProxy --force
appwrite functions create-variable --function-id aiProxy --key GEMINI_API_KEY --value "<gemini key>" --secret true
appwrite functions create-variable --function-id aiProxy --key GEMINI_MODEL --value "<model id from the list>"
appwrite functions create-variable --function-id aiProxy --key OPENROUTER_API_KEY --value "<openrouter key>" --secret true
appwrite functions create-variable --function-id aiProxy --key OPENROUTER_MODELS --value "<id1>:free,<id2>:free"
```

Redeploy so the variables take effect: `appwrite push functions --function-id aiProxy --force`.

- [ ] **Step 8: Verify the deployed function**

Console → Functions → aiProxy → Execute, body `{"feature":"ping"}`, executed as the console admin (no end-user session). Expected: response `401 {"error":"Sign in required to use the AI assistant."}` — proves the auth gate. The signed-in path is verified from the app in roadmap M19.

To verify the fallback for real: temporarily set `GEMINI_MODEL` to a non-existent ID, redeploy, run a `checkIn` from the app (M19) — the execution log shows `aiProxy: gemini failed (HTTP 404), trying next provider` and the reply's `provider` is `openrouter`. Restore the model afterwards.

- [ ] **Step 9: Commit**

```bash
git add EVE_MOBILE/functions/aiProxy/src/handle.ts EVE_MOBILE/functions/aiProxy/src/main.ts EVE_MOBILE/functions/aiProxy/test/handle.test.ts EVE_MOBILE/appwrite.config.json
git commit -m "feat(aiProxy): add authenticated AI proxy function with checkIn feature"
```

---

## Task 8: Notification-eligibility pure function (TDD)

**Files:**
- Create: `EVE_MOBILE/functions/notifications/src/eligibility.ts`
- Test: `EVE_MOBILE/functions/notifications/test/eligibility.test.ts`

**Interfaces:**
- Consumes: `NOTIFICATION_TYPES`, `NotificationType` from `functions/shared/src/types.ts` (Plan 5 Task 1 — must run first; roadmap M13 precedes M17).
- Produces: `NOTIFICATION_SCHEDULE`, `dueNotificationTypes(enabledReminders, now)`.

- [ ] **Step 1: Write the failing tests**

Create `EVE_MOBILE/functions/notifications/test/eligibility.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { dueNotificationTypes } from '../src/eligibility.js';
import { NOTIFICATION_TYPES } from '../../shared/src/types.js';

const at = (h: number, m: number) => new Date(Date.UTC(2026, 7, 8, h, m));

describe('dueNotificationTypes', () => {
  it('returns nothing when no reminders are enabled', () => {
    expect(dueNotificationTypes([], at(7, 0))).toEqual([]);
  });

  it('returns morning at 07:00 UTC and anywhere in its 30-minute window', () => {
    expect(dueNotificationTypes(['morning'], at(7, 0))).toEqual(['morning']);
    expect(dueNotificationTypes(['morning'], at(7, 22))).toEqual(['morning']);
    expect(dueNotificationTypes(['morning'], at(9, 0))).toEqual([]);
  });

  it('returns several types due in the same slot, in canonical order', () => {
    expect(dueNotificationTypes(['cycle', 'appointment'], at(8, 10))).toEqual(['cycle', 'appointment']);
  });

  it('handles multi-slot types (medicine morning and evening)', () => {
    expect(dueNotificationTypes(['medicine'], at(9, 5))).toEqual(['medicine']);
    expect(dueNotificationTypes(['medicine'], at(21, 5))).toEqual(['medicine']);
    expect(dueNotificationTypes(['medicine'], at(14, 0))).toEqual([]);
  });

  it('ignores unknown values', () => {
    expect(dueNotificationTypes(['morning', 'not_a_type'], at(7, 0))).toEqual(['morning']);
  });

  it('covers all nine types across their slots', () => {
    const all = [...NOTIFICATION_TYPES];
    expect(dueNotificationTypes(all, at(7, 0))).toEqual(['morning']);
    expect(dueNotificationTypes(all, at(8, 0))).toEqual(['cycle', 'appointment']);
    expect(dueNotificationTypes(all, at(8, 30))).toEqual(['daily_tip']);
    expect(dueNotificationTypes(all, at(17, 30))).toEqual(['workout']);
    expect(dueNotificationTypes(all, at(21, 30))).toEqual(['sleep']);
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run notifications/test/eligibility.test.ts`
Expected: FAIL — `Failed to resolve import "../src/eligibility.js"`.

- [ ] **Step 3: Implement `EVE_MOBILE/functions/notifications/src/eligibility.ts`**

```ts
import { NOTIFICATION_TYPES, type NotificationType } from '../../shared/src/types.js';

interface ScheduleSlot {
  /** 0-23, UTC. Per-user time zones are a known V0 gap. */
  hour: number;
  /** 0 or 30 — the dispatcher runs every 30 minutes. */
  minute: 0 | 30;
}

/**
 * Fixed daily fire times per type. Eligibility only: whether a type is
 * enabled and "now" falls in one of its windows — not whether there is
 * an appointment today, which belongs to the feature owning that data.
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

const slotIndex = (hour: number, minute: number) => hour * 2 + (minute >= 30 ? 1 : 0);

export function dueNotificationTypes(enabledReminders: readonly string[], now: Date): NotificationType[] {
  const nowSlot = slotIndex(now.getUTCHours(), now.getUTCMinutes());
  return NOTIFICATION_TYPES.filter(
    (type) =>
      enabledReminders.includes(type) &&
      NOTIFICATION_SCHEDULE[type].some((slot) => slotIndex(slot.hour, slot.minute) === nowSlot),
  );
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `npx vitest run notifications/test/eligibility.test.ts`
Expected: `6 passed`.

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/functions/notifications/src/eligibility.ts EVE_MOBILE/functions/notifications/test/eligibility.test.ts
git commit -m "feat(notifications): add reminder eligibility filter"
```

---

## Task 9: Scheduled dispatch over Appwrite native push + client subscription

**Files:**
- Create: `EVE_MOBILE/functions/notifications/src/dispatch.ts`
- Create: `EVE_MOBILE/functions/notifications/src/main.ts`
- Test: `EVE_MOBILE/functions/notifications/test/dispatch.test.ts`
- Modify: `EVE_MOBILE/appwrite.config.json` (append to `functions`)
- Create: `EVE_MOBILE/app/lib/core/services/push_service.dart`
- Test: `EVE_MOBILE/app/test/core/services/push_service_test.dart`

**Interfaces:**
- Consumes: `dueNotificationTypes` (Task 8), `Db`, `serverDb` (Plan 5 Task 2), `TABLES` (Plan 5 Task 1), `serverMessaging` (Task 5); client: `AppwriteService.client` (Plan 2 Task 8).
- Produces: `Messenger`, `appwriteMessenger(messaging)`, `NOTIFICATION_COPY`, `dispatchDueNotifications(db, messenger, now)`, the deployed `notifications` function (cron `*/30 * * * *`); `PushService.start(onMessage)`/`stop()` on the client. Plan 7's `chatSystemMessages` reuses `Messenger`/`appwriteMessenger` to nudge the partner.

**Transport note (no FCM/APNs):** Appwrite's native push provider delivers over its own MQTT broker. On Android the SDK keeps delivering when the app is backgrounded or killed, via scheduled wake-ups (every 15–60 s awake; up to ~9 min in Doze unless `push.setForeground(true)`). **On iOS there is no background delivery without APNs** — messages arrive while the app is alive. For V0 this is acceptable (the demo is Android-first); adding APNs later is a Messaging provider plus one Appwrite console setting, with no code change in `dispatch.ts`.

- [ ] **Step 1: Write the failing dispatch tests**

Create `EVE_MOBILE/functions/notifications/test/dispatch.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { dispatchDueNotifications, NOTIFICATION_COPY, type Messenger } from '../src/dispatch.js';
import { MemoryDb } from '../../shared/test/memoryDb.js';

function recordingMessenger() {
  const sent: { uid: string; title: string; body: string; data: Record<string, string> }[] = [];
  const messenger: Messenger = {
    async pushToUser(uid, title, body, data) {
      sent.push({ uid, title, body, data });
    },
  };
  return { messenger, sent };
}

describe('dispatchDueNotifications', () => {
  it('pushes one message per due type to each eligible user only', async () => {
    const db = new MemoryDb();
    await db.createRow('preferences', 'u1', { enabledReminders: ['morning', 'water'] }, []);
    await db.createRow('preferences', 'u2', { enabledReminders: ['sleep'] }, []);
    await db.createRow('preferences', 'u3', { enabledReminders: [] }, []);
    const { messenger, sent } = recordingMessenger();

    const count = await dispatchDueNotifications(db, messenger, new Date(Date.UTC(2026, 7, 8, 7, 5)));

    expect(count).toBe(1);
    expect(sent).toEqual([
      { uid: 'u1', title: 'Eve', body: NOTIFICATION_COPY.morning, data: { notificationType: 'morning' } },
    ]);
  });

  it('keeps going when one push fails and reports only successes', async () => {
    const db = new MemoryDb();
    await db.createRow('preferences', 'u1', { enabledReminders: ['morning'] }, []);
    await db.createRow('preferences', 'u2', { enabledReminders: ['morning'] }, []);
    const sent: string[] = [];
    const messenger: Messenger = {
      async pushToUser(uid) {
        if (uid === 'u1') throw new Error('no targets');
        sent.push(uid);
      },
    };
    const count = await dispatchDueNotifications(db, messenger, new Date(Date.UTC(2026, 7, 8, 7, 0)));
    expect(count).toBe(1);
    expect(sent).toEqual(['u2']);
  });

  it('notification copy has no emojis', () => {
    for (const body of Object.values(NOTIFICATION_COPY)) {
      expect(body).not.toMatch(/\p{Extended_Pictographic}/u);
    }
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run notifications/test/dispatch.test.ts`
Expected: FAIL — `Failed to resolve import "../src/dispatch.js"`.

- [ ] **Step 3: Implement `EVE_MOBILE/functions/notifications/src/dispatch.ts`**

```ts
import { ID, type Messaging } from 'node-appwrite';
import type { Db } from '../../shared/src/db.js';
import { TABLES } from '../../shared/src/ids.js';
import type { NotificationType } from '../../shared/src/types.js';
import { dueNotificationTypes } from './eligibility.js';

export interface Messenger {
  pushToUser(uid: string, title: string, body: string, data: Record<string, string>): Promise<void>;
}

/** Appwrite native push addressed to a user — reaches every device she is subscribed on. */
export function appwriteMessenger(messaging: Messaging): Messenger {
  return {
    async pushToUser(uid, title, body, data) {
      await messaging.createPush({ messageId: ID.unique(), title, body, users: [uid], data });
    },
  };
}

export const NOTIFICATION_COPY: Record<NotificationType, string> = {
  morning: 'Good morning. Eve has a moment for you whenever you are ready.',
  medicine: 'A gentle reminder for your medication.',
  workout: "Today's workout is waiting whenever you are ready for it.",
  water: 'A short reminder to drink some water.',
  sleep: 'Consider winding down soon. Rest matters.',
  cycle: 'Your cycle tracker has an update worth a look.',
  appointment: 'You have an appointment reminder from Eve.',
  mood: 'How are you feeling right now? Eve would like to know.',
  daily_tip: 'Eve has a new insight for you today.',
};

/** Returns how many pushes were sent. One failing user never blocks the others. */
export async function dispatchDueNotifications(
  db: Db,
  messenger: Messenger,
  now: Date,
  log: (message: string) => void = () => undefined,
): Promise<number> {
  let sent = 0;
  for (const row of await db.listRows(TABLES.preferences)) {
    const enabled = (row.enabledReminders as string[] | null) ?? [];
    for (const type of dueNotificationTypes(enabled, now)) {
      try {
        await messenger.pushToUser(row.$id, 'Eve', NOTIFICATION_COPY[type], { notificationType: type });
        sent += 1;
      } catch (e) {
        log(`notifications: push ${type} to ${row.$id} failed: ${e instanceof Error ? e.message : String(e)}`);
      }
    }
  }
  return sent;
}
```

- [ ] **Step 4: Implement the entrypoint `EVE_MOBILE/functions/notifications/src/main.ts`**

```ts
import { serverMessaging, type FunctionContext } from '../../shared/src/appwrite.js';
import { serverDb } from '../../shared/src/db.js';
import { appwriteMessenger, dispatchDueNotifications } from './dispatch.js';

// Schedule: */30 * * * * (UTC).
export default async (context: FunctionContext) => {
  const sent = await dispatchDueNotifications(
    serverDb(context),
    appwriteMessenger(serverMessaging(context)),
    new Date(),
    (m) => context.log(m),
  );
  context.log(`notifications: sent ${sent} push message(s)`);
  return context.res.json({ sent });
};
```

- [ ] **Step 5: Register the function — append to `functions` in `EVE_MOBILE/appwrite.config.json`**

```json
    {
      "$id": "notifications",
      "name": "notifications",
      "runtime": "node-22",
      "specification": "s-0.5vcpu-512mb",
      "execute": [],
      "events": [],
      "scopes": ["rows.read", "messages.write", "targets.read"],
      "schedule": "*/30 * * * *",
      "timeout": 120,
      "enabled": true,
      "logging": true,
      "entrypoint": "dist/notifications/src/main.js",
      "commands": "npm ci && npm run build",
      "path": "functions"
    }
```

- [ ] **Step 6: Run the function tests**

Run: `npx vitest run notifications && npm run typecheck`
Expected: all notifications tests pass (6 eligibility + 3 dispatch).

- [ ] **Step 7: Write the failing client test**

Create `EVE_MOBILE/app/test/core/services/push_service_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:eve_app/core/services/push_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPush extends Mock implements Push {}

class MockPushSubscription extends Mock implements PushSubscription {}

void main() {
  setUpAll(() => registerFallbackValue((PushMessage _) {}));

  test('start subscribes to her own user channel with background delivery and decodes JSON data', () async {
    final push = MockPush();
    final subscription = MockPushSubscription();
    PushCallback? captured;
    when(() => push.subscribe(any(that: isNull), any(), background: any(named: 'background', that: isTrue), title: any(named: 'title', that: equals('Eve')))).thenAnswer((invocation) async {
      captured = invocation.positionalArguments[1] as PushCallback;
      return subscription;
    });

    final received = <Map<String, dynamic>>[];
    final service = PushService(push);
    await service.start(onMessage: received.add);
    captured!(PushMessage(
      topic: 'user/u1',
      payload: Uint8List.fromList(utf8.encode('{"notificationType":"morning"}')),
      qos: 1,
    ));

    expect(received.single['notificationType'], 'morning');
  });

  test('stop unsubscribes and closes the connection', () async {
    final push = MockPush();
    final subscription = MockPushSubscription();
    when(() => push.subscribe(any(that: isNull), any(), background: any(named: 'background', that: isTrue), title: any(named: 'title', that: equals('Eve')))).thenAnswer((_) async => subscription);

    final service = PushService(push);
    await service.start(onMessage: (_) {});
    await service.stop();

    verify(() => subscription.unsubscribe()).called(1);
    verify(() => push.close()).called(1);
  });
}
```

- [ ] **Step 8: Run to verify it fails**

Run (from `EVE_MOBILE/app/`): `flutter test test/core/services/push_service_test.dart`
Expected: FAIL — `push_service.dart` doesn't exist.

- [ ] **Step 9: Implement `EVE_MOBILE/app/lib/core/services/push_service.dart`**

```dart
import 'dart:convert';

import 'package:appwrite/appwrite.dart';

/// Appwrite native push (no FCM/APNs). Subscribing with `null` topics
/// listens on the signed-in user's own channel, which is what the server's
/// `messaging.createPush(users: [uid])` targets. Call [start] after sign-in
/// and [stop] on sign-out.
class PushService {
  PushService(this._push);

  final Push _push;
  PushSubscription? _subscription;

  Future<void> start({required void Function(Map<String, dynamic> data) onMessage}) async {
    _subscription ??= await _push.subscribe(
      null,
      (message) => onMessage(_decode(message.data)),
      background: true,
      title: 'Eve',
    );
  }

  Future<void> stop() async {
    _subscription?.unsubscribe();
    _subscription = null;
    _push.close();
  }

  static Map<String, dynamic> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {'body': raw};
    } on FormatException {
      return {'body': raw};
    }
  }
}
```

- [ ] **Step 10: Run to verify it passes**

Run: `flutter test test/core/services/push_service_test.dart`
Expected: `All tests passed!` (2 tests).

- [ ] **Step 11: Enable the push provider and deploy**

Console → Messaging → Providers → **Add provider → Push → Appwrite** (name `appwrite-push`, QoS 1, expiry 86400). Then:

```bash
cd EVE_MOBILE
appwrite push functions --function-id notifications --force
```

Add to `EVE_MOBILE/app/android/app/src/main/AndroidManifest.xml` inside `<application>` (notification icon) and before it (optional exact-alarm permission):

```xml
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

```xml
        <meta-data
            android:name="io.appwrite.flutter.push.notification_icon"
            android:resource="@mipmap/ic_launcher" />
```

Verification (after Plan 2 Task 8 and roadmap M16 wire `PushService.start` at sign-in): set her `preferences.enabledReminders` to `["morning"]` in the console, then Functions → notifications → Execute. Expected: execution log `notifications: sent 1 push message(s)` only when run in a `morning` slot; run it at another time and expect `sent 0`. For an immediate end-to-end check regardless of time, Console → Messaging → Create message → Push → target her user — the Android device shows an "Eve" notification even with the app swiped away (within the wake-up interval).

- [ ] **Step 12: Commit**

```bash
git add EVE_MOBILE/functions/notifications EVE_MOBILE/appwrite.config.json EVE_MOBILE/app/lib/core/services/push_service.dart EVE_MOBILE/app/test/core/services/push_service_test.dart EVE_MOBILE/app/android/app/src/main/AndroidManifest.xml
git commit -m "feat: schedule reminder dispatch over Appwrite native push"
```

---

## Task 10: Local vs. Cloud run commands

**Files:**
- Modify: `EVE_MOBILE/app/README.md`

**Interfaces:**
- Consumes: `AppEnv` (`APPWRITE_ENDPOINT`, `APPWRITE_PROJECT_ID`, `APPWRITE_SELF_SIGNED` dart-defines — Plan 2 Task 8).
- Produces: documented commands every milestone demo uses.

- [ ] **Step 1: Create the Cloud project**

At `cloud.appwrite.io`: create project **ID `eve-prod`**, region of choice. Register the Flutter platforms (Task 3 Step 5), enable Google OAuth (Task 3 Step 2) with the Cloud redirect URI, and add the Appwrite push provider (Task 9 Step 11). Then deploy everything against it:

```bash
cd EVE_MOBILE
appwrite login --endpoint https://<REGION>.cloud.appwrite.io/v1
appwrite push tables --all --force --project-id eve-prod
appwrite push functions --all --force --project-id eve-prod
```

Set the four `aiProxy` variables again on `eve-prod` (Task 7 Step 7, with `--project-id eve-prod`).

- [ ] **Step 2: Append to `EVE_MOBILE/app/README.md`**

```markdown
## Running against Appwrite

Local (Docker Appwrite from plans/03-tech-stack.md Task 1):

    # Android emulator reaches the host at 10.0.2.2
    flutter run --dart-define=APPWRITE_ENDPOINT=http://10.0.2.2/v1 --dart-define=APPWRITE_PROJECT_ID=eve-local

Production (Appwrite Cloud):

    flutter run --release --dart-define=APPWRITE_ENDPOINT=https://<REGION>.cloud.appwrite.io/v1 --dart-define=APPWRITE_PROJECT_ID=eve-prod

Backend:

    cd functions && npm test                        # all function unit tests (no Appwrite needed)
    cd .. && appwrite push functions --all --force  # deploy to the logged-in project
```

- [ ] **Step 3: Verify both targets boot**

Run the local command. Expected: the app launches to the welcome screen with no `general_unknown_origin` / connection errors in `flutter logs`. Run the production command on a device. Expected: same.

- [ ] **Step 4: Commit**

```bash
git add EVE_MOBILE/app/README.md
git commit -m "docs: document local and Cloud Appwrite run commands"
```

---

## Self-Review

**1. Spec coverage.** Appwrite project (local + Cloud) — Tasks 1, 2, 10. Google Sign-In — Task 3. Firebase packages removed, `appwrite`/`pdf`/`printing` added — Task 4. Functions package — Task 5. AI proxy with Gemini primary, OpenRouter free-model fallback on timeout/429/5xx/empty, keys only in function variables — Tasks 6, 7. Nine reminder types on a 30-minute cron over native push — Tasks 8, 9. Every server task is unit-tested without an Appwrite instance; every deploy has a manual console verification.

**2. Placeholder scan.** Model IDs are deliberately read from the provider's live model list at setup time (Task 7 Step 7) rather than hard-coded, because both providers rotate models; `GEMINI_MODEL` has a stable default in code so the function never runs model-less.

**3. Type consistency.** `FunctionContext`/`callerId`/`readJsonBody`/`serverMessaging` (Task 5) are used verbatim by Plans 5 and 7. `Messenger`/`appwriteMessenger` (Task 9) are reused by Plan 7. `NOTIFICATION_TYPES` comes from Plan 5's `types.ts`, matching `preferences.enabledReminders` enum elements in `appwrite.config.json`.
