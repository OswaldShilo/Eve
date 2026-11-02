# EVE Mobile — Design Spec (V0 / Hackathon Build)

**Status:** Approved for planning — **revised 2026-11-01: backend moved from Firebase/GCP to Appwrite** (see §2.1)
**Source material:** `EVE_PRD.md`, `EVE2_PRD.md`, `UI/mobile/mockv4.html`
**Purpose:** Ground truth for the 7 implementation plans in `EVE_MOBILE/plans/`. This doc is not itself an implementation plan — it's the locked scope and architecture that every plan below must stay consistent with.

---

## 1. What we're building

EVE is a Flutter (Android + iOS, single codebase) mobile app: a Duolingo-style mascot ("Eve", visually a pomegranate, internally "Pomme") that conversationally drives onboarding, a life-stage-personalized Home dashboard, symptom/mood logging, a Chat screen shared with an opt-in Partner, a color-coded Log calendar, and an AI-generated doctor-ready summary export. Backend is **Appwrite** (Auth with Google OAuth2, TablesDB, Functions, Realtime, Messaging with Appwrite-native push). AI calls (conversational check-ins, phase-aware insights, doctor summaries) go through an Appwrite Function proxy (`aiProxy`) to **Gemini** (primary, AI Studio API key) with automatic fallback to **free OpenRouter models** — neither is ever called directly from the Flutter client.

## 2. Locked decisions

| Decision | Value | Source |
|---|---|---|
| Frontend | Flutter (Dart), single codebase | EVE2_PRD §10.1 |
| State management | Riverpod | Chosen — PRD left open (Provider/Riverpod), Riverpod is the more current default |
| Backend | **Appwrite** — Auth (Google OAuth2), TablesDB, Functions, Realtime, Messaging. **No GCP / Firebase services anywhere.** | User decision 2026-11-01 (supersedes EVE2_PRD §10.1's Firebase) |
| Hosting | Appwrite Cloud for production; self-hosted Appwrite (Docker) for local development | User decision 2026-11-01 |
| Functions runtime | Node.js 22 / TypeScript (ESM), one shared `functions/` package, one Appwrite Function per entrypoint | Appwrite's primary supported runtime |
| Database model | TablesDB (tables/rows/columns — Appwrite's replacement for collections/documents since 1.8). Flat tables, no subcollections; owner-keyed singletons use `rowId = uid` | Appwrite has no subcollections |
| Access control | Row-level permissions (`rowSecurity: true`) set by the writer; server-only tables have **no** client write permissions at all; anything that needs field-content validation goes through a Function | §10 below, Plan 5 |
| AI provider | Gemini via AI Studio API key (`GEMINI_API_KEY`, model from `GEMINI_MODEL`) — primary; free OpenRouter models (`OPENROUTER_API_KEY`, `OPENROUTER_MODELS`) — automatic fallback on timeout / 429 / 5xx / empty output. Keys live only in the `aiProxy` Function's environment variables | User decision 2026-11-01 |
| Push notifications | Appwrite **native push** (Appwrite push provider, MQTT broker) — `messaging.createPush({ users: [uid] })` server-side, `Push(client).subscribe(null, …, background: true)` client-side. No FCM / APNs provider, no device-token table | Appwrite Flutter SDK ≥ 28 |
| Scheduled jobs | Appwrite Function `schedule` (cron, `*/30 * * * *`) | replaces Cloud Scheduler |
| PDF export | `pdf` + `printing` Flutter packages, client-side render from AI-generated text | EVE2_PRD §10.1 |
| Branch depth (hackathon scope) | 2 branches at full multi-screen depth (**Tracking my cycle**, **Currently pregnant**); 3 branches (**Trying to conceive**, **Postpartum**, **Perimenopause/Menopause**) collapsed into one combined symptoms+goals screen each, but fully selectable and functional | EVE2_PRD §4, §11 — confirmed by user this session |
| Gamification (streaks, Care Points, wardrobe unlockables, daily goal ring) | **Out of V0 scope**, deferred to roadmap | EVE2_PRD §7, §11 — explicit hackathon exclusion |
| Full E2E chat encryption | Described in architecture only, not implemented | EVE_PRD §10, EVE2_PRD §11 |
| Wearables / sleep correlation | Out of scope | Both PRDs |
| Diagnosis claims | Never — risk flags only, always "discuss with a professional" | EVE2_PRD §9 |
| Copy voice | Formal, warm, no emojis anywhere in-product | EVE2_PRD §6 |

### 2.1 Deviation from the PRDs (recorded here; the PRD files are left untouched)

`EVE2_PRD.md` §10.1/§10.3 and the pitch deck's architecture slide specify Firebase (Auth, Firestore, Cloud Functions, FCM, Cloud Scheduler) and Gemini via Vertex AI. On 2026-11-01 the team decided not to use GCP. Every PRD requirement is preserved; only the provider changes:

| PRD component | Replaced by | Notes |
|---|---|---|
| Firebase Auth (Google Sign-In) | Appwrite Account `createOAuth2Session(provider: OAuthProvider.google)` | The Google OAuth **client ID/secret** is still issued from a Google developer console — that is an OAuth credential, not GCP infrastructure (no billing, no services). |
| Firestore | Appwrite TablesDB | Subcollections flattened into tables keyed by `userId` (§10). |
| `firestore.rules` | Row permissions + server-only tables + Functions for writes needing content validation | Appwrite permissions are per-row allow/deny only — they cannot inspect field values (see Plan 7 "Why permissions alone aren't enough"). |
| Cloud Functions (Firestore triggers) | Appwrite Functions with `events` (`users.*.create`, `tablesdb.*.tables.<table>.rows.*.create/update/upsert/delete`) | Events are asynchronous and may be redelivered: every event-driven function is idempotent and recomputes from source state. |
| Cloud Functions (callable) | Appwrite Functions invoked via `Functions.createExecution` | Caller identity from the `x-appwrite-user-id` header. |
| FCM + Cloud Scheduler | Appwrite Messaging (native push) + Function cron `schedule` | Android background delivery runs through the SDK's own wake-ups; iOS gets messages while the app is alive (see Plan 3 Task 9 note). |
| Gemini via Vertex AI / Genkit | Gemini REST (`generativelanguage.googleapis.com`, AI Studio key) + OpenRouter fallback | AI Studio is an API key, not a GCP project the team operates. |
| Firestore live sync (chat) | Appwrite Realtime (`tablesdb.eve.tables.chat_messages.rows`) | Realtime only delivers rows the subscriber can read. |

## 3. The 7 plans and their boundaries

Each plan below is written independently via `/superpowers:writing-plans` and lives in `EVE_MOBILE/plans/`. They are sequenced so later plans can assume earlier ones exist as *design*, but the **build order** (which code gets written first) is defined only in Plan 4 — the other plans describe *what* to build, Plan 4 says *in what order*.

1. **`01-core-workflow.md`** — The canonical screen graph: every screen in the onboarding flow (23 screens) plus Home/Chat/Log, in Flutter-widget terms — not the HTML mock's DOM structure. Documents, per screen: purpose, fields collected, validation, mascot emotion + guidance copy, forward/back navigation rule, and which `surveyState`-equivalent fields it writes. This is the UX/flow spec the other plans implement against. Backend-agnostic.
2. **`02-system-architecture.md`** — Layered Flutter app architecture (presentation / state / domain / data layers), the module-activation system (life-stage → visible Home modules, computed client-side per EVE2_PRD §10.3), folder structure, the `AppwriteService` wrapper, and the repository interfaces every feature's UI depends on (so no widget imports the Appwrite SDK directly).
3. **`03-tech-stack.md`** — Concrete package versions, Appwrite project setup (local Docker + Cloud), Google OAuth2 wiring, the `functions/` TypeScript scaffold, the `aiProxy` Gemini→OpenRouter provider chain, the cron-scheduled notification dispatch for the 9 reminder types, environment/secrets handling, local dev setup instructions.
4. **`04-build-roadmap.md`** — The literal one-by-one build order: base UI shell → mascot rig v0 → auth → onboarding screens in sequence → Home → Chat → Log → Partner Mode → doctor summary → polish. Each milestone is independently demoable.
5. **`05-data-model-appwrite.md`** — Every table from EVE2_PRD §10.2 as concrete TablesDB columns in `appwrite.config.json`, TypeScript + Dart mirror types, the row-permission model, and the idempotent `onUserCreate` function.
6. **`06-mascot-rig-plan.md`** — Flutter `CustomPainter`/`AnimationController` rebuild of the SVG rig documented in `mockv4.html` (body, crown, 3 seed-rows, eyes/pupils/eyelids, brows, mouth, arms), idle physics (float + periodic blink), the 5 emotion states (guilt, hype, sassy, hug, fertile) via shared path interpolation, and the peel-stage growth tied to onboarding progress.
7. **`07-partner-mode-consent.md`** — The server-side `partner_views` projection Function in isolation: what triggers a recompute, exactly which fields get copied per approved category, the invite/accept link flow, the `sendChatMessage` function that makes chat sender identity unforgeable, and Eve's system-message generation into chat.

## 4. Reference: mascot rig anatomy (from `mockv4.html`)

Extracted so Plan 6 doesn't need to re-derive it from the HTML:

- **Body:** single closed SVG path shell (`body-main-shell`), outline + shadow-underside path, all on a `viewBox="0 -40 200 260"` canvas.
- **Crown/peel system:** `top-pith-liner` + `top-cream-pith` (interior reveal), `peel-crown-group` (5 paths: back-left, back-right, front-left, front-right, front-center), and 3 `seed-row` groups (1–3 seeds each) that fade/scale in progressively.
- **Peel-stage growth (`setMascotPeel(rig, percent)`):** driven by onboarding progress %. `< 35%`: crown flat, only seed-row-1 visible. `35–70%`: crown scales 1.08 + rotates -4°, seed-row-2 fades in. `≥ 70%`: crown scales 1.15 + rotates -8°, seed-row-3 fades in. This is the "growth" narrative — Eve visibly blooms as onboarding completes.
- **Eyes:** per-eye clip-path ellipse, pupil group (main circle + 2 highlight circles), eyelid rect that translates vertically to open/close. Blink = both eyelids translate to `(0,0)` for ~150ms, on a periodic timer inside the idle loop.
- **Brows + mouth:** single stroked path each, redrawn (different `d` attribute) per emotion — not swapped assets.
- **Arms:** two path groups with `transform-origin`, available for reactive gestures (not used for emotion state in the current mock, but present in the rig).
- **Fertile glow:** a separate ellipse behind the crown, opacity-only, used exclusively by the `fertile` emotion state.
- **Idle animation (`runIdleAnimation`):** single `requestAnimationFrame` loop — sine-wave vertical float (`Math.sin(idleTime) * 2`), applied to every live mascot instance simultaneously; blink trigger is time-modulo based, not per-instance random.
- **Emotion states (`setMascotEmotion`):** 5 named states (`caring`/`hug`/`concerned` grouped as one visual treatment, `warm`/`happy`/`positive` grouped, plus `hype`, `sassy`, `fertile`) each set: `mouth` path `d`, `browLeft`/`browRight` path `d`, `eyelid` resting Y offset, and `fertileGlow` opacity. All 5 states reuse the exact same path *elements* — only the `d` attribute and a couple of transforms change, never swapped SVG assets. This is the pattern Plan 6 must preserve in Flutter (interpolate between path definitions in a single `CustomPainter`, not swap between 5 separate painters).
- **Per-instance mascot:** the mock clones a `<template>` for every screen's mini-mascot plus Home/Chat/Log/Welcome/Completion instances, each with independently namespaced clip-path IDs. In Flutter this becomes one reusable `EveMascot` widget parameterized by size/emotion/peel-percent, not a singleton.

## 5. Reference: full onboarding screen sequence (from `mockv4.html`)

`screen-welcome → screen-auth → screen-profile → screen-lifestage` → **branch** → common screens → **partner (conditional)** → `screen-theme → screen-completion` → `screen-home`.

**Branch screens** (selected by `lifeStage`):
- `cycle`: `screen-cycle-info → screen-cycle-symptoms → screen-cycle-goals`
- `pregnant`: `screen-pregnant-due → screen-pregnant-meds → screen-pregnant-symptoms`
- `conceive` / `postpartum` / `menopause`: single `screen-simplified-branch` (combined symptoms + goals for that stage)

**Common screens** (all users): `screen-food → screen-workout → screen-notifications → screen-ai-scope → screen-partner-ask` → (if partner invited) `screen-partner-rel → screen-partner-perm` → `screen-theme → screen-completion`.

Every screen carries a mini mascot instance with a screen-specific guidance line and a contextual emotion (`neutral` default, `caring` on symptom/medical/permissions screens, `warm` on the theme screen) — see `surveyMascotConfigs` in the mock for the exact per-screen emotion assignment, which Plan 1 must reproduce screen-by-screen rather than defaulting everything to neutral.

## 6. Reference: data shape collected during onboarding (`surveyState` in the mock)

`name, age, height, weight, country, lifeStage, cycleLength, periodLength, flow, cycleSymptoms[], cycleGoals[], nutritionDiet, dueDate, dueMethod, highRisk, pregnancyType, medications, allergies, prenatalVitamins, pregnantSymptoms[], foodAllergies, cuisines[], workouts[], notifications[], aiScope[], partnerInvite, partnerRelation, partnerPermissions[], onlyApproveMaster, theme, simplifiedSymptoms[], simplifiedGoals[]`.

This is the exact field list Plan 5 must map into Appwrite tables (per the EVE2_PRD §10.2 collection table: User Profile, Life-Stage Profile, Goals & Preferences, Notification Preferences, AI Assistant Scope, Theme, Partner Link, Partner Permissions — the four preference documents are merged into the single `preferences` table, see §10).

## 7. Reference: Home / Chat / Log screens

- **Home:** greeting + phase badge header, hero card with mascot + speech bubble + 4 emotion-toggle chips (demo affordance — in real product these become auto-driven by check-in content, not manually clicked), bento grid (Next Cycle Phase, Check-in Streak *[streak display allowed as a static/read-only stat even though the earning mechanic is deferred — see Plan 4 scope note]*, Daily Recommendation full-width card), bottom nav (Home/Chat/Log).
- **Chat:** header with partner avatar/name/status, thread of `chat-bubble` types (`wife`, `partner`, `eve-system` — the last rendered distinctly with a mini mascot avatar), quick-reply chips, text input bar.
- **Log:** month header + nav arrows, color legend (Period=ruby, Fertile=teal, Symptom=purple, Appointment=orange), calendar grid with per-day dot indicators (multi-dot days supported), tap-to-select day shows a mascot-toast detail panel, FAB for new entry.

## 9. Canonical project folder structure

Every plan below must use these exact paths — this is what keeps 6 independently-written plans mutually consistent without cross-reading each other's full content.

```
EVE_MOBILE/
  app/                                # Flutter app
    lib/
      main.dart
      app.dart                        # MaterialApp/router root
      core/
        config/
          app_env.dart                # --dart-define backed endpoint/project id
        theme/
          eve_theme.dart              # light/dark/default ThemeData
        router/
          app_router.dart             # go_router config
        constants/
          appwrite_ids.dart           # database/table/function IDs + realtime channels (replaces firestore_paths.dart)
        providers/
          appwrite_providers.dart     # Riverpod providers for AppwriteService + current uid
        services/
          appwrite_service.dart       # Client/Account/TablesDB/Functions/Realtime wrapper (replaces firebase_service.dart)
          ai_proxy_service.dart       # calls the aiProxy Appwrite Function
          push_service.dart           # Appwrite native push subscription
      features/
        onboarding/
          data/
            onboarding_repository.dart          # abstract interface
            appwrite_onboarding_repository.dart # Appwrite implementation
            onboarding_value_mappers.dart       # UI labels -> canonical stored keys
          domain/
            onboarding_state.dart     # Riverpod state model (was `surveyState` in the mock)
          presentation/
            screens/                  # one file per screen, e.g. welcome_screen.dart
            widgets/
        home/
          data/                       # home_repository.dart (interface) + appwrite_home_repository.dart
          domain/
            module_activation.dart    # life-stage -> visible module list (pure function)
          presentation/
        chat/
          data/                       # chat_repository.dart (interface) + appwrite_chat_repository.dart
        log/
          data/                       # log_repository.dart (interface) + appwrite_log_repository.dart
        partner/
          domain/
            partner_permissions.dart
          presentation/
        mascot/
          eve_mascot.dart             # public widget: EveMascot(emotion, peelPercent, size)
          eve_mascot_painter.dart     # CustomPainter
          eve_rig_geometry.dart       # path data per body part
          eve_emotion.dart            # EveEmotion enum + path-interpolation data per state
      shared/
        widgets/
        models/                       # Dart mirrors of functions/shared/src/types.ts
    test/                             # mirrors lib/ structure
    pubspec.yaml
  functions/                          # ONE TypeScript package, many Appwrite Functions (ESM, Node 22)
    package.json
    tsconfig.json
    vitest.config.ts
    shared/
      src/
        types.ts                      # row shapes — source of truth for field names
        ids.ts                        # DATABASE_ID, TABLES, FUNCTION_IDS
        db.ts                         # Db port + node-appwrite TablesDB adapter
        permissions.ts                # ownerPermissions(), isOwnedBy()
        appwrite.ts                   # client from the function context (dynamic API key)
        http.ts                       # tiny request/response helpers for executions
      test/
        memoryDb.ts                   # in-memory Db used by every unit test
    onUserCreate/src/main.ts          # event: users.*.create — initializes a new user's rows
    partnerView/src/main.ts           # event: symptom_logs / life_stage_profiles / partner_permissions writes
    partnerView/src/recompute.ts
    partnerInvites/src/main.ts        # execution: createInvite / acceptInvite
    sendChatMessage/src/main.ts       # execution: the ONLY path a human chat message is written
    chatSystemMessages/src/main.ts    # event: symptom_logs create — Eve's partner nudges
    aiProxy/src/main.ts               # execution: Gemini -> OpenRouter proxy
    aiProxy/src/providers.ts
    aiProxy/src/doctorSummary.ts
    notifications/src/main.ts         # schedule: */30 * * * * — reminder dispatch
    notifications/src/eligibility.ts
    <name>/test/*.test.ts             # vitest, next to each function
  appwrite.config.json                # project, database, tables (+columns/indexes/permissions), functions
  plans/                              # this planning output (7 plans + this spec)
```

There is no `firestore.rules`, `firestore.indexes.json`, `firebase.json`, `.firebaserc`, `google-services.json` or `GoogleService-Info.plist` anywhere in this project. Every Appwrite Function in `appwrite.config.json` uses `"path": "functions"` and its own `"entrypoint": "dist/<name>/src/main.js"` — they share one `npm ci && npm run build`.

## 10. Canonical Appwrite IDs, tables and cross-plan interface contracts

These are fixed now so Plans 1, 2, 3, 5, 6, and 7 can be written independently/in parallel without seeing each other's output, and still compose correctly.

**Database:** one TablesDB database, ID `eve`. **Tables** (Plan 5 formalizes columns, indexes and permissions against these exact IDs — it does not invent new ones). "Writer" is who may create/update rows; "Readers" is who gets `read` on each row.

| Table ID | Row ID | Replaces (Firestore) | Columns (summary) | Writer | Readers |
|---|---|---|---|---|---|
| `profiles` | `uid` | `users/{uid}` | name, age, height (cm), weight (kg), country, lifeStage | created by `onUserCreate`; updated by her | her |
| `life_stage_profiles` | `uid` | `users/{uid}/lifeStageProfile/current` | type + flattened branch columns (cycle*, pregnant*, simplified*) | created by `onUserCreate`; updated by her | her |
| `symptom_logs` | unique | `users/{uid}/logs/{logId}` | userId, date, symptoms[], mood, painLevel, notes | her (table grants `create` to `users`; row perms owner-only) | her |
| `preferences` | `uid` | the four `users/{uid}/preferences/*` docs, merged | selectedGoals[], dietType, foodAllergies, cuisines[], workoutPreference[], enabledReminders[], enabledHelpAreas[], selectedTheme | created by `onUserCreate`; updated by her | her |
| `partner_links` | primary `uid` | `users/{uid}/partnerLink/current` | partnerUserId, relationshipType, inviteStatus, inviteCode, invitedAt, linkedAt | **server only** (`partnerInvites`) | her (+ partner once accepted) |
| `partner_permissions` | `uid` | `users/{uid}/partnerPermissions/current` | approvedCategories[], onlyApproveMode | created by `onUserCreate`; updated by her | her |
| `partner_views` | primary `uid` | `users/{uid}/partnerView/current` | approved-category projection (nullable columns) + recomputedAt | **server only** (`partnerView`) | her + linked partner |
| `partner_lookups` | partner `uid` | `partnerLinks/{partnerUid}` | primaryUserId, relationshipType, linkedAt | **server only** (`partnerInvites`) | partner |
| `chat_messages` | unique (system nudges: `sys-<logId>`) | `users/{uid}/chat/{messageId}` | threadUserId, senderRole (`her`/`partner`/`system`), senderUserId, messageText, sentAt, type, category, sourceLogId | **server only** (`sendChatMessage`, `chatSystemMessages`) | her + linked partner |

**Canonical stored values** (UI labels from `mockv4.html` are mapped to these keys on save — Plan 4 M14 `onboarding_value_mappers.dart`; every server function reads only these keys):

- `lifeStage` / `life_stage_profiles.type`: `cycle | conceive | pregnant | postpartum | menopause`
- `symptom_logs.mood`: `great | good | okay | low | difficult`
- `preferences.enabledReminders[]`: `morning | medicine | workout | water | sleep | cycle | appointment | mood | daily_tip`
- `preferences.enabledHelpAreas[]`: `healthQuestions | nutrition | workouts | mentalWellbeing | medicationReminders | doctorPrep`
- `preferences.selectedTheme`: `light | dark | default`
- `partner_permissions.approvedCategories[]`: `appointmentReminders | pregnancyMilestones | supportSuggestions | moodUpdates`
- `partner_links.inviteStatus`: `none | pending | accepted | declined`

**Function IDs** (same string is the folder name under `functions/`): `onUserCreate`, `partnerView`, `partnerInvites`, `sendChatMessage`, `chatSystemMessages`, `aiProxy`, `notifications`. Client-invoked ones (`partnerInvites`, `sendChatMessage`, `aiProxy`) take a JSON body `{ "action"|"feature": ..., ... }` and return JSON; caller identity is the `x-appwrite-user-id` header, never a body field.

**Realtime channel for chat:** `tablesdb.eve.tables.chat_messages.rows` with `Query.equal('threadUserId', <primaryUid>)`.

**Mascot interface** (Plan 6 owns the implementation; Plans 1, 2 consume this signature verbatim):

```dart
enum EveEmotion { neutral, caring, warm, hype, sassy, fertile }

class EveMascot extends StatelessWidget {
  const EveMascot({
    required this.emotion,
    this.peelPercent = 100,
    this.size = 120,
  });
  final EveEmotion emotion;
  final double peelPercent; // 0-100, drives crown/seed-row growth stage
  final double size;
}
```

`EveEmotion` values map directly to the mock's `setMascotEmotion` keys: `caring` covers the mock's `caring`/`hug`/`concerned` grouping, `warm` covers `warm`/`happy`/`positive`. `neutral` is the unstyled default. This is the canonical 6-value set — do not invent additional emotion names in any plan.

**Routing/state interface** (Plan 2 owns the implementation; Plan 1 consumes it):

- Named routes matching each screen ID from Section 5 above (e.g. `/onboarding/welcome`, `/onboarding/lifestage`, `/onboarding/cycle-info`, `/home`, `/chat`, `/log`).
- A Riverpod `StateNotifierProvider` (name it `onboardingStateProvider`) holding a model equivalent to the mock's `surveyState` (exact field list in Section 6 above).
- A pure function `List<Module> activeModules(LifeStage stage)` (module-activation lookup) that Plan 1's Home screen and Plan 2 both reference by this exact name/signature.

**Data-access interface** (Plan 2 Task 9 defines the abstract classes; Plan 4 M14/M16/M19 implement them against Appwrite):

- `OnboardingRepository.saveOnboarding(String uid, OnboardingState state) -> Future<String?>` (partner invite code, or null)
- `HomeRepository.loadDashboard(String uid) -> Future<HomeDashboardData>`
- `ChatRepository.threadIdFor(String uid) -> Future<String>`, `ChatRepository.watchThread(String threadUserId) -> Stream<List<ChatMessage>>`, `ChatRepository.sendMessage(String threadUserId, String text)`
- `LogRepository.watchLogs(String uid) -> Stream<List<SymptomLog>>`, `LogRepository.addLog(String uid, SymptomLog log)`
- Widgets and providers depend on these interfaces only; only `appwrite_*_repository.dart` files and `core/services/` import `package:appwrite`.

## 8. Explicit non-goals for V0

- Gamification layer (streaks *earning*, Care Points, wardrobe unlockables, daily goal ring, streak freeze) — deferred per EVE2_PRD §7.
- Full 5-branch onboarding depth — only 2 branches get full multi-screen treatment (§2 above).
- Real E2E encryption on chat.
- Wearable/sleep integrations.
- MCP action integrations (quick-commerce ordering, calendar auto-scheduling) — pitch-only stretch ideas per EVE_PRD §9.
