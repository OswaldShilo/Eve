# EVE Mobile — Design Spec (V0 / Hackathon Build)

**Status:** Approved for planning
**Source material:** `EVE_PRD.md`, `EVE2_PRD.md`, `UI/mobile/mockv4.html`
**Purpose:** Ground truth for the 7 implementation plans in `EVE_MOBILE/plans/`. This doc is not itself an implementation plan — it's the locked scope and architecture that every plan below must stay consistent with.

---

## 1. What we're building

EVE is a Flutter (Android + iOS, single codebase) mobile app: a Duolingo-style mascot ("Eve", visually a pomegranate, internally "Pomme") that conversationally drives onboarding, a life-stage-personalized Home dashboard, symptom/mood logging, a Chat screen shared with an opt-in Partner, a color-coded Log calendar, and an AI-generated doctor-ready summary export. Backend is Firebase (Auth, Firestore, Cloud Functions, Cloud Messaging, Cloud Scheduler). AI calls (conversational check-ins, phase-aware insights, doctor summaries) go through a Cloud Function proxy to **Gemini** — never called directly from the Flutter client.

## 2. Locked decisions

| Decision | Value | Source |
|---|---|---|
| Frontend | Flutter (Dart), single codebase | EVE2_PRD §10.1 |
| State management | Riverpod | Chosen — PRD left open (Provider/Riverpod), Riverpod is the more current default |
| Backend | Firebase (Auth, Firestore, Cloud Functions, `firebase_messaging`, Cloud Scheduler) | EVE2_PRD §10.1 |
| Cloud Functions runtime | Node.js/TypeScript | Firebase's primary supported runtime |
| AI provider | Google Gemini, via Vertex AI/Genkit from a Cloud Function proxy | User decision, this session |
| PDF export | `pdf` + `printing` Flutter packages, client-side render from AI-generated text | EVE2_PRD §10.1 |
| Branch depth (hackathon scope) | 2 branches at full multi-screen depth (**Tracking my cycle**, **Currently pregnant**); 3 branches (**Trying to conceive**, **Postpartum**, **Perimenopause/Menopause**) collapsed into one combined symptoms+goals screen each, but fully selectable and functional | EVE2_PRD §4, §11 — confirmed by user this session |
| Gamification (streaks, Care Points, wardrobe unlockables, daily goal ring) | **Out of V0 scope**, deferred to roadmap | EVE2_PRD §7, §11 — explicit hackathon exclusion |
| Full E2E chat encryption | Described in architecture only, not implemented | EVE_PRD §10, EVE2_PRD §11 |
| Wearables / sleep correlation | Out of scope | Both PRDs |
| Diagnosis claims | Never — risk flags only, always "discuss with a professional" | EVE2_PRD §9 |
| Copy voice | Formal, warm, no emojis anywhere in-product | EVE2_PRD §6 |

## 3. The 7 plans and their boundaries

Each plan below is written independently via `/superpowers:writing-plans` and lives in `EVE_MOBILE/plans/`. They are sequenced so later plans can assume earlier ones exist as *design*, but the **build order** (which code gets written first) is defined only in Plan 4 — the other plans describe *what* to build, Plan 4 says *in what order*.

1. **`01-core-workflow.md`** — The canonical screen graph: every screen in the onboarding flow (23 screens) plus Home/Chat/Log, in Flutter-widget terms — not the HTML mock's DOM structure. Documents, per screen: purpose, fields collected, validation, mascot emotion + guidance copy, forward/back navigation rule, and which `surveyState`-equivalent fields it writes. This is the UX/flow spec the other plans implement against.
2. **`02-system-architecture.md`** — Layered Flutter app architecture (presentation / state / domain / data layers), the module-activation system (life-stage → visible Home modules, computed client-side per EVE2_PRD §10.3), folder structure, and how Cloud Functions fit around the client.
3. **`03-tech-stack.md`** — Concrete package versions, Firebase project setup, Cloud Scheduler jobs for the 9 notification types, environment/secrets handling for the Gemini proxy, local dev setup instructions.
4. **`04-build-roadmap.md`** — The literal one-by-one build order: base UI shell → mascot rig v0 → auth → onboarding screens in sequence → Home → Chat → Log → Partner Mode → doctor summary → polish. Each milestone is independently demoable.
5. **`05-data-model-firestore.md`** — Every collection from EVE2_PRD §10.2 as concrete Firestore field types, plus full security rules — this is where `partner_view` read/write restrictions are actually enforced in `firestore.rules`.
6. **`06-mascot-rig-plan.md`** — Flutter `CustomPainter`/`AnimationController` rebuild of the SVG rig documented in `mockv4.html` (body, crown, 3 seed-rows, eyes/pupils/eyelids, brows, mouth, arms), idle physics (float + periodic blink), the 5 emotion states (guilt, hype, sassy, hug, fertile) via shared path interpolation, and the peel-stage growth tied to onboarding progress.
7. **`07-partner-mode-consent.md`** — The server-side `partner_view` projection Cloud Function in isolation: what triggers a recompute, exactly which fields get copied per approved category, Eve's system-message generation into chat, and how this is *not* just a security-rules trick (cross-referenced with Plan 5's rules).

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

This is the exact field list Plan 5 must map into Firestore documents (per the EVE2_PRD §10.2 collection table: User Profile, Life-Stage Profile, Goals & Preferences, Notification Preferences, AI Assistant Scope, Theme, Partner Link, Partner Permissions).

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
        theme/
          eve_theme.dart              # light/dark/default ThemeData
        router/
          app_router.dart             # go_router config
        constants/
          firestore_paths.dart
        services/
          firebase_service.dart       # Auth/Firestore init wrappers
          ai_proxy_service.dart       # calls the Cloud Functions AI proxy endpoint
      features/
        onboarding/
          data/
            onboarding_repository.dart
          domain/
            onboarding_state.dart     # Riverpod state model (was `surveyState` in the mock)
          presentation/
            screens/                  # one file per screen, e.g. welcome_screen.dart
            widgets/
        home/
          data/
          domain/
            module_activation.dart    # life-stage -> visible module list (pure function)
          presentation/
        chat/
        log/
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
        models/
    test/                             # mirrors lib/ structure
    pubspec.yaml
  functions/                          # Firebase Cloud Functions (TypeScript)
    src/
      index.ts
      onUserCreate.ts                 # initializes new user's Firestore docs
      partnerView.ts                  # recomputes partner_view on relevant writes
      aiProxy.ts                      # Gemini proxy endpoint
      chatSystemMessages.ts           # Eve's system-generated chat nudges
      notifications/
        scheduler.ts                  # Cloud Scheduler-triggered notification dispatch
    test/
    package.json
    tsconfig.json
  firestore.rules
  firestore.indexes.json
  firebase.json
  plans/                              # this planning output (7 plans + this spec)
```

## 10. Canonical Firestore paths and cross-plan interface contracts

These are fixed now so Plans 1, 2, 3, 5, 6, and 7 can be written independently/in parallel without seeing each other's output, and still compose correctly.

**Firestore paths** (Plan 5 formalizes field types + security rules against these exact paths — it does not invent new ones):

```
users/{uid}                                 — User Profile doc (authId, name, age, height, weight, country, lifeStage, createdAt)
users/{uid}/lifeStageProfile/current        — Life-Stage Profile (type + stage-specific nested fields)
users/{uid}/logs/{logId}                    — Symptom/Mood Log entries (date, symptoms[], mood, painLevel, notes)
users/{uid}/preferences/goals               — Goals & Preferences (selectedGoals[], dietType, foodAllergies, cuisines[], workoutPreference[])
users/{uid}/preferences/notifications       — Notification Preferences (enabledReminders[])
users/{uid}/preferences/aiScope             — AI Assistant Scope (enabledHelpAreas[])
users/{uid}/preferences/theme               — Theme (selectedTheme)
users/{uid}/partnerLink/current             — Partner Link, written by primary user (partnerUserId, relationshipType, inviteStatus, linkedAt)
users/{uid}/partnerPermissions/current      — Partner Permissions (approvedCategories[], onlyApproveMode)
users/{uid}/partnerView/current             — Server-generated filtered projection; never written by any client
partnerLinks/{partnerUid}                   — Top-level reverse lookup, server-written only (primaryUserId, relationshipType, linkedAt) — lets the partner's client resolve which primary user's `partnerView`/`chat` to read without a Firestore query across all users
users/{uid}/chat/{messageId}                — Chat Messages, subcollection under the primary user (senderId: 'her'|'partner'|'system', messageText, timestamp, type)
```

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

## 8. Explicit non-goals for V0

- Gamification layer (streaks *earning*, Care Points, wardrobe unlockables, daily goal ring, streak freeze) — deferred per EVE2_PRD §7.
- Full 5-branch onboarding depth — only 2 branches get full multi-screen treatment (§2 above).
- Real E2E encryption on chat.
- Wearable/sleep integrations.
- MCP action integrations (quick-commerce ordering, calendar auto-scheduling) — pitch-only stretch ideas per EVE_PRD §9.
