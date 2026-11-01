# EVE Mobile — Build Roadmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Revision (2026-11-01):** the backend moved from Firebase/GCP to **Appwrite**, and AI from Vertex/Gemini to **Gemini (AI Studio key) with free OpenRouter models as fallback** (design-spec §2.1). M0, M2, M13, M14, M16–M20 and the coordination notes were rewritten; the client-only milestones (M3–M12, M15) are unchanged apart from references. **M4–M12 are being built in parallel with this rewrite** — they never touch the backend, so they need no changes from it beyond M14a's small `AuthScreen` addition.

**Goal:** Sequence every task from `01-core-workflow.md`, `02-system-architecture.md`, `03-tech-stack.md`, `05-data-model-appwrite.md`, `06-mascot-rig-plan.md`, and `07-partner-mode-consent.md` into one practical, incrementally-demoable build order; resolve the file-ownership collisions those plans created by being drafted in parallel; and fill the gaps no sub-plan covers — wiring the real screens into the router, actually signing users in, persisting the completed onboarding survey, logging from the app, the partner join flow, and the doctor-ready AI summary + PDF export (in V0 scope per `EVE2_PRD.md` §11).

**Architecture:** 21 milestones (M0–M20), each ending in something you can run and see. Milestones reference other plans' tasks by number (`Plan 2 Task 3`) rather than repeating their content — go to that file for the real code. Milestones that do new work no plan wrote are spelled out here in full, in the same TDD, no-placeholders format as the other plans.

**Tech Stack:** Flutter (Dart ≥ 3.10) + Riverpod + go_router + `appwrite` 28.x; Appwrite (Auth with Google OAuth2, TablesDB, Functions, Realtime, Messaging with native push) — self-hosted via Docker locally, Appwrite Cloud in production; one TypeScript (Node 22, ESM) functions package with `node-appwrite` 31.x and Vitest; Gemini REST + OpenRouter via the `aiProxy` function; `pdf` + `printing` for client-side PDF export. Exactly as locked in `00-design-spec.md` §2.

## Global Constraints

- Package name is `eve_app` everywhere — Dart imports, `pubspec.yaml`'s `name:` field, and every plan's assumed `package:eve_app/...` prefix. Never `eve` or `eve_mobile`.
- No Firebase/GCP package, SDK, config file or service anywhere (design-spec §2). The Google OAuth client credential for Sign in with Google is the single, documented exception — it is a credential, not infrastructure (Plan 3 Task 3).
- `EVE_MOBILE/appwrite.config.json` is created once (Plan 3 Task 2) and only ever appended to: Plan 5 Task 3 fills `tables`; Plan 3 Tasks 7/9, Plan 5 Task 5 and Plan 7 Tasks 2–5 each append their own function entry. Never overwrite it.
- The `functions/` package (`package.json`, `tsconfig*.json`, `vitest.config.ts`, `shared/src/appwrite.ts`) is created once, by Plan 3 Task 5.
- `core/services/appwrite_service.dart` (Plan 2 Task 8) is the only Appwrite client wrapper; widgets depend on the repository interfaces (Plan 2 Task 9), never on `package:appwrite`.
- Every new task in this plan follows the same TDD discipline as the sub-plans: failing test first, verified failure, minimal implementation, verified pass, commit. No placeholders.
- Every server function test runs against `MemoryDb` — no Appwrite instance is needed for `npm test`. Deploys are verified manually against the local Docker Appwrite.
- Formal, warm, no-emoji copy voice (design-spec §2) applies to every new user-facing string introduced here.
- Never a diagnosis claim, ever — applies directly to the doctor-summary prompt in M19.

---

## Cross-Plan Coordination Notes

Read this section before executing any milestone that references it. The Appwrite rewrite resolved most Firebase-era collisions by construction; what remains is listed here.

### CN-1 — `app/pubspec.yaml`

Plan 3 Task 4 is the single source of the dependency set (Firebase packages removed, `appwrite`, `pdf`, `printing`, `intl` added; Dart/Flutter floors raised for `appwrite` 28.x). Plan 5 no longer creates a pubspec (its Dart model tests use `flutter_test`). Plan 2 Task 1's original pubspec is history. No `fake_cloud_firestore`/`test` dev-dependency is needed — repository tests use `mocktail`.

### CN-2 — Functions package and `appwrite.config.json`

Plan 3 Task 5 creates the package; Plan 3 Task 2 creates the config skeleton. Every later plan adds files under `functions/<name>/` and appends one entry to the config's `functions` array. All functions share `"path": "functions"` and `"commands": "npm ci && npm run build"`, each with its own `"entrypoint": "dist/<name>/src/main.js"`. `serverDb` lives in `shared/src/db.ts` (Plan 5 Task 2), not in `shared/src/appwrite.ts`, so the scaffold (M1) never depends on the schema work (M13).

### CN-3 — Client core migration

Plan 2 Tasks 1–7 are already built against Firebase. Plan 2 Task 8 deletes `firebase_service.dart`/`firestore_paths.dart` and their tests and adds `AppEnv`, `AppwriteIds`, `AppwriteService`, the providers and the new `main.dart`. It must run in the same commit as Plan 3 Task 4 (the pubspec swap) — between the two the app does not compile.

### CN-4 — Device push tokens (resolved by deletion)

The Firebase plan needed a `users/{uid}/fcmTokens` path. Appwrite native push addresses users (`messaging.createPush({ users: [uid] })`) and the client subscribes with `Push.subscribe(null, …)`, so there is no token table and the old Task R1 is gone.

### CN-5 — Canonical stored values

Plan 1 screens store the mock's display labels. Server functions and several Appwrite enum columns require the canonical keys in design-spec §10. M14's `onboarding_value_mappers.dart` is the one place labels become keys; Plan 7's category keys (`moodUpdates`, …) and Plan 3's reminder keys (`morning`, …) match it.

---

## Milestones

Each milestone lists the exact tasks to run (by plan and number) and what "done" looks like. Where a milestone does new work, the full task follows immediately after in the same format as the sub-plans.

### M0 — Appwrite project and native platform prep

Run: **Plan 3 Tasks 1–3** (local Docker Appwrite + `eve-local` project + CLI login, `appwrite.config.json` skeleton with the `eve` database, Google OAuth2 provider + Android callback activity + iOS deployment target + registered Flutter platforms).

**Demo:** `http://localhost/console` shows project `eve-local` with database `eve`, Google enabled under Auth → OAuth2 Providers, and Android/iOS platforms registered. `appwrite --version` prints 28.x and `appwrite push tables --all` succeeds.

### M1 — Flutter dependency set + functions scaffold (apply CN-1, CN-2)

The Flutter project itself already exists (Plan 2 Task 1, built). Run: **Plan 3 Task 5** (functions package + execution helpers). Plan 3 Task 4 (pubspec) is executed in M2 together with the migration (CN-3).

**Demo:** `npm test` in `functions/` passes the helper tests; `npm run build` emits `dist/`.

### M2 — Core services: Appwrite client, IDs, env (apply CN-3)

Run: **Plan 3 Task 4** and **Plan 2 Task 8** back to back, committed together. (Plan 2 Tasks 2–4 are already built; Task 8 replaces 2 and 3.)

**Demo:** `flutter test` passes (theme, onboarding state, module activation, router, and the new Appwrite IDs/service/provider tests); `grep -rn "firebase\|firestore" lib test pubspec.yaml` returns nothing; on an emulator the app boots against local Appwrite with no `general_unknown_origin` error.

### M3 — Onboarding state and module-activation system

Run: **Plan 2 Task 5** (`OnboardingState`/`OnboardingNotifier`/`onboardingStateProvider`), **Plan 2 Task 6** (`Module`/`LifeStage`/`lifeStageFromSurveyValue`/`activeModules`).

**Demo:** `flutter test test/features/onboarding/domain/ test/features/home/domain/` passes (13 tests: 5 + 8).

### M4 — Mascot rig core render + idle physics

Run: **Plan 6 Tasks 1–4** (`EveRigGeometry`, `EveEmotion` pose table, static `EveMascotPainter`, idle float + blink `AnimationController`).

**Demo:** drop a scratch `EveMascotPainter` into a throwaway `CustomPaint` in `main.dart` temporarily, `flutter run`, watch it idle-float and blink. Revert the scratch change before M5.

### M5 — Mascot rig polish: transitions, peel growth, public widget, goldens

Run: **Plan 6 Tasks 5–8** (emotion-transition lerp, peel-percent growth animation, public `EveMascot` widget, golden tests).

**Demo:** `flutter test test/features/mascot/` passes including goldens; a scratch screen cycling `EveMascot(emotion: ..., peelPercent: ...)` through all 6 emotions and 0/50/100 peel percentages shows smooth transitions.

### M6 — Router shell

Already built (Plan 2 Task 7). Its `main.dart` bootstrap was replaced in M2 by Plan 2 Task 8 Step 9 — nothing to run here.

**Demo:** `flutter run`, every route in design-spec §5/§7 is reachable via `appRouter.go(...)` in the debug console, each showing its `RouteLabelScreen` placeholder text.

### M7 — Onboarding screens, batch 1: shared widgets + bookends + profile/lifestage

Run: **Plan 1 Tasks 1–5** (`OnboardingScaffold`/`OptionList`/`SubChipRow`, Welcome, Auth, Profile, Life-Stage).

**Demo:** `flutter test test/features/onboarding/presentation/screens/{welcome,auth,profile,lifestage}_screen_test.dart` passes. Screens aren't reachable in the running app yet — router wiring is M12.

### M8 — Onboarding screens, batch 2: cycle branch full depth

Run: **Plan 1 Tasks 6–8** (Cycle Info, Cycle Symptoms, Cycle Goals).

**Demo:** widget tests for all three pass; each screen renders standalone via `flutter run -t` on a throwaway harness if you want to eyeball it before router wiring.

### M9 — Onboarding screens, batch 3: pregnant branch full depth

Run: **Plan 1 Tasks 9–11** (Pregnant Due-Date, Pregnant Medication & Care, Pregnant Symptoms).

**Demo:** widget tests for all three pass.

### M10 — Onboarding screens, batch 4: simplified branch + common survey

Run: **Plan 1 Tasks 12–16** (Simplified Branch, Food Preferences, Workout Preferences, Notification Preferences, AI Assistant Scope).

**Demo:** widget tests for all five pass.

### M11 — Onboarding screens, batch 5: partner + theme + completion + branching/peel logic

Run: **Plan 1 Tasks 17–21** (Partner Invite Ask, Partner Relationship, Partner Permissions, Theme, Completion), **Plan 1 Task 25** (`onboardingSequence`/`routeForScreen`), **Plan 1 Task 26** (`onboardingProgressPercent`).

**Demo:** `flutter test test/features/onboarding/` passes in full (all 20 screens + the two integration tasks). Every screen exists as a widget now; none are reachable in the running app yet.

### M12 — Wire real screens into the router (NEW — the router-wiring gap)

Plan 2 Task 7's interface note says "Plan 1 replaces each `RouteLabelScreen` builder... with the real screen widget for that route" — but no task in Plan 1 ever touches `app_router.dart` (it only builds the pure functions Task 25/26 above, explicitly handing the actual wiring to "Plan 2's router," which in turn assumed Plan 1 would do it). Nobody does. This task closes that gap: it's the one place that turns 20 standalone onboarding screens plus Home/Chat/Log into an actually-navigable app.

**Files:**
- Modify: `EVE_MOBILE/app/lib/core/router/app_router.dart`
- Modify: `EVE_MOBILE/app/test/core/router/app_router_test.dart`
- Modify: `EVE_MOBILE/app/test/app_test.dart`

**Interfaces:**
- Consumes: all 20 onboarding screen widgets (Plan 1 Tasks 2–21), `onboardingSequence`/`routeForScreen` (Plan 1 Task 25), `onboardingProgressPercent` (Plan 1 Task 26), `onboardingStateProvider` (Plan 2 Task 5), `HomeScreen`/`ChatScreen`/`LogScreen` (Plan 1 Tasks 22–24, built in M15 — this task's Home/Chat/Log routes use their default-data constructors until M16 upgrades them).
- Produces: every route in `appRouter` renders its real screen; onboarding `onContinue`/`onBack` navigate through the branch-aware sequence instead of a hardcoded list.

- [ ] **Step 1: Update the router test to assert on real screen content instead of placeholder labels**

Replace `EVE_MOBILE/app/test/core/router/app_router_test.dart`'s two `testWidgets` blocks (leave the route-paths `test` block unchanged):

```dart
  testWidgets('initial location renders the real Welcome screen', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: appRouter)));
    await tester.pumpAndSettle();

    expect(find.text('Begin Setup'), findsOneWidget);
  });

  testWidgets('navigating to /home renders the real Home screen', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: appRouter)));
    await tester.pumpAndSettle();

    appRouter.go('/home');
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, Maya'), findsOneWidget);
  });

  testWidgets('completing the Life-Stage screen advances into the cycle branch', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: appRouter)));
    await tester.pumpAndSettle();

    appRouter.go('/onboarding/lifestage');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tracking my cycle'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    await tester.pumpAndSettle();

    expect(find.text('Cycle Details'), findsOneWidget);
  });
```

Update `EVE_MOBILE/app/test/app_test.dart`'s single assertion the same way:

```dart
    expect(find.text('Begin Setup'), findsOneWidget);
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/core/router/app_router_test.dart test/app_test.dart
```

Expected: FAIL — `find.text('Begin Setup')` etc. find nothing, since `appRouter` still renders `RouteLabelScreen` placeholders.

- [ ] **Step 3: Replace `app_router.dart`'s route table with real screens**

Replace the full contents of `EVE_MOBILE/app/lib/core/router/app_router.dart`:

```dart
// EVE_MOBILE/app/lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:eve_app/features/onboarding/domain/onboarding_progress.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_sequence.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/screens/ai_scope_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/auth_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/completion_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/cycle_goals_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/cycle_info_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/cycle_symptoms_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/food_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/lifestage_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/notifications_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/partner_ask_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/partner_perm_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/partner_rel_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/pregnant_due_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/pregnant_meds_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/pregnant_symptoms_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/profile_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/simplified_branch_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/theme_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:eve_app/features/onboarding/presentation/screens/workout_screen.dart';
import 'package:eve_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:eve_app/features/home/presentation/screens/home_screen.dart';
import 'package:eve_app/features/log/presentation/screens/log_screen.dart';

/// Signature shared by every onboarding screen except the two bookends
/// (Welcome, Completion) — confirmed identical across Plan 1 Tasks 3–20.
typedef _MiddleScreenBuilder = Widget Function({
  required VoidCallback onContinue,
  required VoidCallback onBack,
  required double progressPercent,
});

final Map<String, _MiddleScreenBuilder> _middleScreenBuilders = {
  'auth': ({required onContinue, required onBack, required progressPercent}) =>
      AuthScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
  'profile': ({required onContinue, required onBack, required progressPercent}) =>
      ProfileScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
  'lifestage': ({required onContinue, required onBack, required progressPercent}) =>
      LifeStageScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
  'cycle-info': ({required onContinue, required onBack, required progressPercent}) =>
      CycleInfoScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
  'cycle-symptoms': ({required onContinue, required onBack, required progressPercent}) =>
      CycleSymptomsScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
  'cycle-goals': ({required onContinue, required onBack, required progressPercent}) =>
      CycleGoalsScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
  'pregnant-due': ({required onContinue, required onBack, required progressPercent}) =>
      PregnantDueScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
  'pregnant-meds': ({required onContinue, required onBack, required progressPercent}) =>
      PregnantMedsScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
  'pregnant-symptoms': ({required onContinue, required onBack, required progressPercent}) =>
      PregnantSymptomsScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
  'simplified-branch': ({required onContinue, required onBack, required progressPercent}) =>
      SimplifiedBranchScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
  'food': ({required onContinue, required onBack, required progressPercent}) =>
      FoodScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
  'workout': ({required onContinue, required onBack, required progressPercent}) =>
      WorkoutScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
  'notifications': ({required onContinue, required onBack, required progressPercent}) =>
      NotificationsScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
  'ai-scope': ({required onContinue, required onBack, required progressPercent}) =>
      AiScopeScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
  'partner-ask': ({required onContinue, required onBack, required progressPercent}) =>
      PartnerAskScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
  'partner-rel': ({required onContinue, required onBack, required progressPercent}) =>
      PartnerRelScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
  'partner-perm': ({required onContinue, required onBack, required progressPercent}) =>
      PartnerPermScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
  'theme': ({required onContinue, required onBack, required progressPercent}) =>
      ThemeScreen(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
};

/// Resolves one onboarding screen id to a live widget, computing its
/// position in the branch-aware sequence (Plan 1 Task 25) and progress
/// percent (Plan 1 Task 26) fresh on every build from the current
/// [onboardingStateProvider] value.
class _OnboardingFlowRoute extends ConsumerWidget {
  const _OnboardingFlowRoute({required this.screenId});

  final String screenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final sequence = onboardingSequence(state);
    final currentIndex = sequence.indexOf(screenId);

    void goToScreen(String id) => context.go(routeForScreen(id));

    void goNext() {
      if (currentIndex == -1 || currentIndex >= sequence.length - 1) {
        context.go('/home');
        return;
      }
      goToScreen(sequence[currentIndex + 1]);
    }

    void goBack() {
      if (currentIndex <= 0) {
        context.go('/onboarding/welcome');
        return;
      }
      goToScreen(sequence[currentIndex - 1]);
    }

    final progressPercent = currentIndex == -1
        ? 10.0
        : onboardingProgressPercent(currentIndex: currentIndex, totalScreens: sequence.length);

    final builder = _middleScreenBuilders[screenId];
    if (builder == null) {
      throw StateError('No screen builder registered for onboarding screen "$screenId".');
    }
    return builder(onContinue: goNext, onBack: goBack, progressPercent: progressPercent);
  }
}

GoRoute _onboardingRoute(String screenId) {
  return GoRoute(
    path: '/onboarding/$screenId',
    name: 'onboarding-$screenId',
    builder: (context, state) => _OnboardingFlowRoute(screenId: screenId),
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/onboarding/welcome',
  routes: [
    GoRoute(
      path: '/onboarding/welcome',
      name: 'onboarding-welcome',
      builder: (context, state) => WelcomeScreen(
        onContinue: () => context.go('/onboarding/auth'),
      ),
    ),
    ..._middleScreenBuilders.keys.map(_onboardingRoute),
    GoRoute(
      path: '/onboarding/completion',
      name: 'onboarding-completion',
      builder: (context, state) => CompletionScreen(
        onContinue: () => context.go('/home'),
      ),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => HomeScreen(
        onNavigateChat: () => context.go('/chat'),
        onNavigateLog: () => context.go('/log'),
      ),
    ),
    GoRoute(
      path: '/chat',
      name: 'chat',
      builder: (context, state) => ChatScreen(
        onNavigateHome: () => context.go('/home'),
        onNavigateLog: () => context.go('/log'),
      ),
    ),
    GoRoute(
      path: '/log',
      name: 'log',
      builder: (context, state) => LogScreen(
        onNavigateHome: () => context.go('/home'),
        onNavigateChat: () => context.go('/chat'),
      ),
    ),
  ],
);
```

Note: the route-paths test (`appRouter declares every screen ID...`) still passes unchanged — every path/name is identical to Plan 2 Task 7's version, only the `builder:` callbacks changed, exactly as that task's own interface note anticipated.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/core/router/app_router_test.dart test/app_test.dart
```

Expected: `All tests passed!` (6 tests: 4 unchanged from Plan 2 Task 7 plus this step's 2 new/updated ones — the exact count depends on which of Plan 2 Task 7's original 4 you kept vs. replaced; both `testWidgets` blocks replaced above count as edits, not additions, so the total stays 4 in `app_router_test.dart` + 1 in `app_test.dart` + the 1 new branching test = 6).

- [ ] **Step 5: Run the full test suite and static analysis**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test
flutter analyze
```

Expected: every test from M1–M11 still passes (the screens didn't change, only how they're reached); `flutter analyze` reports `No issues found!`.

- [ ] **Step 6: Commit**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE"
git add app/lib/core/router/app_router.dart app/test/core/router/app_router_test.dart app/test/app_test.dart
git commit -m "feat: wire real onboarding/Home/Chat/Log screens into app_router"
```

**Demo:** `flutter run`, walk the entire onboarding flow for real by tapping through the app — Welcome → Auth → Profile → Life-Stage → (pick "Tracking my cycle") → Cycle Info/Symptoms/Goals → Food → Workout → Notifications → AI Scope → Partner Ask → (skip or accept) → Theme → Completion → lands on Home. Repeat picking "Currently pregnant" and confirm the pregnant branch screens appear instead. The mascot's peel state visibly grows across the flow.

### M13 — Data layer: schema, storage port, Dart models, `onUserCreate` (apply CN-2)

Run: **Plan 5 Tasks 1–5** in order (IDs + types, `Db`/`MemoryDb`/permissions, `appwrite.config.json` tables + schema test, Dart models, `onUserCreate`). No emulator is needed for the tests — every function test runs against `MemoryDb`; each task ends with a push to the local Docker Appwrite.

The old Task R1 (`users/{uid}/fcmTokens` ratification) is **deleted**: Appwrite native push addresses users directly (`createPush({ users: [uid] })`), so there is no token table (CN-4).

**Demo (whole of M13):** `npm test` in `functions/` passes (types, db, schema, onUserCreate). `flutter test test/shared/models/` passes. Against local Appwrite: create a user in the console → within seconds the `onUserCreate` execution log lists 6 created tables and Databases → eve shows that user's row in `profiles`, `life_stage_profiles`, `preferences`, `partner_permissions`, `partner_links`, `partner_views`. Signed in as a second user, `TablesDB.getRow` on the first user's `symptom_logs`/`profiles` rows returns `404`/`401`.

### M14 — Persist onboarding on completion (NEW)

Plan 1's 20 onboarding screens only write to the in-memory `onboardingStateProvider`. This milestone saves that state when she taps "Enter EVE" on the Completion screen — mapping the UI's display labels to the canonical keys the server functions read (design-spec §10), and creating the partner invite through the `partnerInvites` function.

#### M14a — Real sign-in on the Auth route (NEW — nobody wired it)

Plan 1 Task 3 deliberately exposes both "Sign in with Google" and "Continue as Guest" as one `onContinue` (its scope stops at navigation), and M12 wires that straight to the next screen — so no plan ever signs anyone in, and `currentUidProvider` stays null. This step fixes that.

- [ ] **Step A1: Give `AuthScreen` a separate Google callback (Plan 1 Task 3's widget)**

Add an optional `onGoogleSignIn` to `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/auth_screen.dart` — when null it falls back to `onContinue`, so Plan 1's existing test (which taps both buttons and expects `continueCount == 2`) still passes unchanged:

```dart
  const AuthScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.onGoogleSignIn,
    this.progressPercent = 10,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final VoidCallback? onGoogleSignIn;
  final double progressPercent;
```

and in `build`, the Google button's `onPressed: onGoogleSignIn ?? onContinue,`.

Add to `EVE_MOBILE/app/test/features/onboarding/presentation/screens/auth_screen_test.dart`:

```dart
  testWidgets('AuthScreen routes the Google button to onGoogleSignIn when provided', (tester) async {
    var google = 0;
    var guest = 0;
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(onContinue: () => guest++, onBack: () {}, onGoogleSignIn: () => google++),
    ));
    await tester.tap(find.byKey(const Key('auth-google-button')));
    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(google, 1);
    expect(guest, 1);
  });
```

Run: `flutter test test/features/onboarding/presentation/screens/auth_screen_test.dart` — expected FAIL before the widget change (`No named parameter with the name 'onGoogleSignIn'`), PASS (2 tests) after.

- [ ] **Step A2: Sign in from the router**

In `EVE_MOBILE/app/lib/core/router/app_router.dart`, replace the `'auth'` entry of `_middleScreenBuilders` (M12 Step 3) with:

```dart
  'auth': ({required onContinue, required onBack, required progressPercent}) =>
      _AuthRoute(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
```

and add at the bottom of the file:

```dart
/// Signs in (Google or anonymous guest) before advancing, and records the
/// uid every repository call is keyed by.
class _AuthRoute extends ConsumerWidget {
  const _AuthRoute({required this.onContinue, required this.onBack, required this.progressPercent});

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  Future<void> _signIn(BuildContext context, WidgetRef ref, {required bool google}) async {
    final appwrite = ref.read(appwriteServiceProvider);
    try {
      if (await appwrite.currentUserId() == null) {
        google ? await appwrite.signInWithGoogle() : await appwrite.signInAsGuest();
      }
      ref.read(currentUidProvider.notifier).state = await appwrite.currentUserId();
      onContinue();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-in did not complete. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => AuthScreen(
        progressPercent: progressPercent,
        onBack: onBack,
        onGoogleSignIn: () => _signIn(context, ref, google: true),
        onContinue: () => _signIn(context, ref, google: false),
      );
}
```

(imports: `package:flutter_riverpod/flutter_riverpod.dart`, `package:eve_app/core/providers/appwrite_providers.dart`.)

- [ ] **Step A3: Verify manually and commit**

`flutter test && flutter analyze` must stay green (router tests never tap the auth buttons). On an emulator against local Appwrite: tap "Continue as Guest" → Console → Auth shows an anonymous user and `onUserCreate` ran; reinstall, tap "Sign in with Google" → Google consent → a Google user appears.

```bash
cd EVE_MOBILE
git add app/lib/features/onboarding/presentation/screens/auth_screen.dart app/test/features/onboarding/presentation/screens/auth_screen_test.dart app/lib/core/router/app_router.dart
git commit -m "feat(app): sign in with Google or as guest on the Auth screen"
```

#### M14b — Save the survey

**Step 0:** run **Plan 2 Task 9** first (repository interfaces + fakes) — it needs Plan 5 Task 4's models, which M13 just created.

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/data/onboarding_value_mappers.dart`
- Create: `EVE_MOBILE/app/lib/features/onboarding/data/appwrite_onboarding_repository.dart`
- Create: `EVE_MOBILE/app/lib/core/providers/repository_providers.dart`
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/widgets/partner_invite_code_dialog.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/data/onboarding_value_mappers_test.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/data/appwrite_onboarding_repository_test.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/widgets/partner_invite_code_dialog_test.dart`
- Modify: `EVE_MOBILE/app/lib/core/router/app_router.dart`

**Interfaces:**
- Consumes: `OnboardingState` (Plan 2 Task 5), `OnboardingRepository` (Plan 2 Task 9), `AppwriteService`, `AppwriteIds`, `appwriteServiceProvider`, `currentUidProvider` (Plan 2 Task 8), `UserProfile`/`LifeStageProfile` family/`Preferences`/`PartnerPermissions` (Plan 5 Task 4), the `partnerInvites` function (Plan 7 Task 3 — deployed in M18; until then `createInvite` returns `404 function not found` and M14's error path shows a retry message, see Step 9).
- Produces: `reminderKeys`, `helpAreaKeys`, `categoryKeys`, `themeKey`, `relationshipKey`, `profileFor`, `lifeStageProfileFor`, `preferencesFor`; `AppwriteOnboardingRepository`; `onboardingRepositoryProvider` (M16 adds the other three repository providers to the same file); `PartnerInviteCodeDialog`.

- [ ] **Step 1: Write the failing mapper tests**

Create `EVE_MOBILE/app/test/features/onboarding/data/onboarding_value_mappers_test.dart`:

```dart
import 'package:eve_app/features/onboarding/data/onboarding_value_mappers.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/shared/models/life_stage_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reminder labels map to the nine canonical keys; unknown values are dropped', () {
    expect(
      reminderKeys(const [
        'Morning reminder', 'Medication reminder', 'Workout reminder', 'Water intake reminder',
        'Sleep schedule reminder', 'Cycle tracking reminder', 'Appointment reminder',
        'Mood check-in reminder', 'Daily health insights', 'Something else',
      ]),
      ['morning', 'medicine', 'workout', 'water', 'sleep', 'cycle', 'appointment', 'mood', 'daily_tip'],
    );
    expect(reminderKeys(const ['morning']), ['morning']);
  });

  test('AI scope values map to help-area keys and Everything expands to all six', () {
    expect(helpAreaKeys(const ['Nutrition', 'Doctor prep']), ['nutrition', 'doctorPrep']);
    expect(helpAreaKeys(const ['Everything']), [
      'healthQuestions', 'nutrition', 'workouts', 'mentalWellbeing', 'medicationReminders', 'doctorPrep',
    ]);
  });

  test('partner permission labels map to category keys', () {
    expect(
      categoryKeys(const ['Appointment reminders', 'Pregnancy milestones', 'Support suggestions', 'Mood updates']),
      ['appointmentReminders', 'pregnancyMilestones', 'supportSuggestions', 'moodUpdates'],
    );
  });

  test('theme and relationship', () {
    expect(themeKey('Dark'), 'dark');
    expect(themeKey('Default'), 'default');
    expect(themeKey(''), 'default');
    expect(relationshipKey('Husband'), 'husband');
    expect(relationshipKey(''), isNull);
  });

  test('profileFor parses numeric strings and nulls blanks', () {
    final profile = profileFor(const OnboardingState(name: 'Asha', age: '29', height: '165', weight: '', lifeStage: 'cycle'));
    expect(profile.age, 29);
    expect(profile.height, 165);
    expect(profile.weight, isNull);
    expect(profile.country, isNull);
    expect(profile.lifeStage, 'cycle');
  });

  test('lifeStageProfileFor builds the branch the user chose', () {
    final cycle = lifeStageProfileFor(const OnboardingState(
      lifeStage: 'cycle', cycleLength: '30', periodLength: '6', flow: 'Moderate', cycleGoals: ['Improve nutrition'], nutritionDiet: 'Vegan',
    )) as CycleLifeStageProfile;
    expect(cycle.cycleLength, 30);
    expect(cycle.nutritionDiet, 'Vegan');

    final pregnant = lifeStageProfileFor(const OnboardingState(
      lifeStage: 'pregnant', dueDate: '2026-06-01', highRisk: 'Yes', prenatalVitamins: 'No',
    )) as PregnantLifeStageProfile;
    expect(pregnant.dueDate, DateTime.utc(2026, 6, 1));
    expect(pregnant.highRisk, isTrue);
    expect(pregnant.prenatalVitamins, isFalse);

    expect(lifeStageProfileFor(const OnboardingState(lifeStage: 'menopause')), isA<SimplifiedLifeStageProfile>());
    expect(lifeStageProfileFor(const OnboardingState()), isA<EmptyLifeStageProfile>());
  });

  test('preferencesFor uses canonical keys and the branch goals', () {
    final prefs = preferencesFor(const OnboardingState(
      lifeStage: 'menopause',
      simplifiedGoals: ['Sleep better'],
      notifications: ['Morning reminder'],
      aiScope: ['Everything'],
      theme: 'Light',
      foodAllergies: 'peanuts',
    ));
    expect(prefs.selectedGoals, ['Sleep better']);
    expect(prefs.enabledReminders, ['morning']);
    expect(prefs.enabledHelpAreas, hasLength(6));
    expect(prefs.selectedTheme, 'light');
    expect(prefs.foodAllergies, 'peanuts');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd EVE_MOBILE/app
flutter test test/features/onboarding/data/onboarding_value_mappers_test.dart
```

Expected: FAIL — `onboarding_value_mappers.dart` doesn't exist.

- [ ] **Step 3: Implement `EVE_MOBILE/app/lib/features/onboarding/data/onboarding_value_mappers.dart`**

```dart
import '../../../shared/models/life_stage_profile.dart';
import '../../../shared/models/preferences.dart';
import '../../../shared/models/user_profile.dart';
import '../domain/onboarding_state.dart';

// Onboarding screens (Plan 1) store the mock's display labels/values. The
// server reads canonical keys (design-spec §10) and several columns are
// Appwrite enums that reject anything else, so every enum-backed field is
// mapped here. Values that are already canonical pass through unchanged.

const _reminderKeys = {
  'Morning reminder': 'morning',
  'Medication reminder': 'medicine',
  'Workout reminder': 'workout',
  'Water intake reminder': 'water',
  'Sleep schedule reminder': 'sleep',
  'Cycle tracking reminder': 'cycle',
  'Appointment reminder': 'appointment',
  'Mood check-in reminder': 'mood',
  'Daily health insights': 'daily_tip',
};

const allHelpAreaKeys = [
  'healthQuestions',
  'nutrition',
  'workouts',
  'mentalWellbeing',
  'medicationReminders',
  'doctorPrep',
];

const _helpAreaKeys = {
  'Answer health questions': 'healthQuestions',
  'Nutrition': 'nutrition',
  'Workout': 'workouts',
  'Mental wellbeing': 'mentalWellbeing',
  'Medication reminders': 'medicationReminders',
  'Doctor prep': 'doctorPrep',
};

const _categoryKeys = {
  'Appointment reminders': 'appointmentReminders',
  'Pregnancy milestones': 'pregnancyMilestones',
  'Support suggestions': 'supportSuggestions',
  'Mood updates': 'moodUpdates',
};

const _themeKeys = {'Default': 'default', 'Light': 'light', 'Dark': 'dark'};

List<String> _mapKnown(List<String> values, Map<String, String> table) {
  final known = table.values.toSet();
  return [
    for (final value in values)
      if (table[value] != null) table[value]! else if (known.contains(value)) value,
  ];
}

List<String> reminderKeys(List<String> values) => _mapKnown(values, _reminderKeys);

List<String> helpAreaKeys(List<String> values) =>
    values.contains('Everything') ? List.of(allHelpAreaKeys) : _mapKnown(values, _helpAreaKeys);

List<String> categoryKeys(List<String> values) => _mapKnown(values, _categoryKeys);

String themeKey(String value) => _themeKeys[value] ?? (_themeKeys.containsValue(value) ? value : 'default');

String? relationshipKey(String value) => value.trim().isEmpty ? null : value.trim().toLowerCase();

String? _blankToNull(String value) => value.trim().isEmpty ? null : value.trim();

UserProfile profileFor(OnboardingState state) => UserProfile(
      name: state.name.trim(),
      age: int.tryParse(state.age),
      height: double.tryParse(state.height),
      weight: double.tryParse(state.weight),
      country: _blankToNull(state.country),
      lifeStage: state.lifeStage,
    );

LifeStageProfile lifeStageProfileFor(OnboardingState state) {
  switch (state.lifeStage) {
    case 'cycle':
      return CycleLifeStageProfile(
        cycleLength: int.tryParse(state.cycleLength),
        periodLength: int.tryParse(state.periodLength),
        flow: _blankToNull(state.flow),
        cycleSymptoms: state.cycleSymptoms,
        cycleGoals: state.cycleGoals,
        nutritionDiet: _blankToNull(state.nutritionDiet),
      );
    case 'pregnant':
      final due = DateTime.tryParse(state.dueDate);
      return PregnantLifeStageProfile(
        dueDate: due == null ? null : DateTime.utc(due.year, due.month, due.day),
        dueMethod: _blankToNull(state.dueMethod),
        highRisk: state.highRisk.isEmpty ? null : state.highRisk == 'Yes',
        pregnancyType: _blankToNull(state.pregnancyType),
        medications: _blankToNull(state.medications),
        allergies: _blankToNull(state.allergies),
        prenatalVitamins: state.prenatalVitamins.isEmpty ? null : state.prenatalVitamins == 'Yes',
        pregnantSymptoms: state.pregnantSymptoms,
      );
    case 'conceive':
    case 'postpartum':
    case 'menopause':
      return SimplifiedLifeStageProfile(
        type: state.lifeStage!,
        simplifiedSymptoms: state.simplifiedSymptoms,
        simplifiedGoals: state.simplifiedGoals,
      );
    default:
      return const EmptyLifeStageProfile();
  }
}

Preferences preferencesFor(OnboardingState state) => Preferences(
      selectedGoals: switch (state.lifeStage) {
        'cycle' => state.cycleGoals,
        'conceive' || 'postpartum' || 'menopause' => state.simplifiedGoals,
        _ => const <String>[],
      },
      dietType: _blankToNull(state.nutritionDiet),
      foodAllergies: state.foodAllergies,
      cuisines: state.cuisines,
      workoutPreference: state.workouts,
      enabledReminders: reminderKeys(state.notifications),
      enabledHelpAreas: helpAreaKeys(state.aiScope),
      selectedTheme: themeKey(state.theme),
    );
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/onboarding/data/onboarding_value_mappers_test.dart`
Expected: `All tests passed!` (7 tests).

- [ ] **Step 5: Write the failing repository test**

Create `EVE_MOBILE/app/test/features/onboarding/data/appwrite_onboarding_repository_test.dart`:

```dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:eve_app/core/services/appwrite_service.dart';
import 'package:eve_app/features/onboarding/data/appwrite_onboarding_repository.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppwriteService extends Mock implements AppwriteService {}

class MockTablesDB extends Mock implements TablesDB {}

class MockRow extends Mock implements models.Row {}

void main() {
  late MockAppwriteService appwrite;
  late MockTablesDB tables;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    appwrite = MockAppwriteService();
    tables = MockTablesDB();
    when(() => appwrite.tablesDb).thenReturn(tables);
    when(() => tables.updateRow(
          databaseId: any(named: 'databaseId'),
          tableId: any(named: 'tableId'),
          rowId: any(named: 'rowId'),
          data: any(named: 'data'),
        )).thenAnswer((_) async => MockRow());
  });

  List<String> updatedTables() => verify(() => tables.updateRow(
        databaseId: 'eve',
        tableId: captureAny(named: 'tableId'),
        rowId: 'u1',
        data: any(named: 'data'),
      )).captured.cast<String>();

  test('without a partner: updates profile, life stage and preferences only, returns null', () async {
    final code = await AppwriteOnboardingRepository(appwrite).saveOnboarding(
      'u1',
      const OnboardingState(name: 'Asha', lifeStage: 'cycle', notifications: ['Morning reminder'], partnerInvite: false),
    );

    expect(code, isNull);
    expect(updatedTables(), ['profiles', 'life_stage_profiles', 'preferences']);
    verifyNever(() => appwrite.executeJson(any(), any()));
  });

  test('with a partner: saves permissions with category keys and creates the invite', () async {
    when(() => appwrite.executeJson('partnerInvites', any())).thenAnswer((_) async => {'inviteCode': 'ABC234'});

    final code = await AppwriteOnboardingRepository(appwrite).saveOnboarding(
      'u1',
      const OnboardingState(
        lifeStage: 'pregnant',
        partnerInvite: true,
        partnerRelation: 'Husband',
        partnerPermissions: ['Mood updates'],
        onlyApproveMaster: true,
      ),
    );

    expect(code, 'ABC234');
    // One verify capturing tableId and data together: mocktail marks calls as
    // verified, so a second verify over the same calls would match nothing.
    final captured = verify(() => tables.updateRow(
          databaseId: 'eve',
          tableId: captureAny(named: 'tableId'),
          rowId: 'u1',
          data: captureAny(named: 'data'),
        )).captured;
    final tablesInOrder = [for (var i = 0; i < captured.length; i += 2) captured[i] as String];
    expect(tablesInOrder, ['profiles', 'life_stage_profiles', 'preferences', 'partner_permissions']);
    final permissionsData = captured[tablesInOrder.indexOf('partner_permissions') * 2 + 1] as Map;
    expect(permissionsData['approvedCategories'], ['moodUpdates']);
    verify(() => appwrite.executeJson('partnerInvites', {'action': 'createInvite', 'relationshipType': 'husband'})).called(1);
  });
}
```

- [ ] **Step 6: Run to verify it fails**

Run: `flutter test test/features/onboarding/data/appwrite_onboarding_repository_test.dart`
Expected: FAIL — `appwrite_onboarding_repository.dart` doesn't exist.

- [ ] **Step 7: Implement `EVE_MOBILE/app/lib/features/onboarding/data/appwrite_onboarding_repository.dart`**

```dart
import '../../../core/constants/appwrite_ids.dart';
import '../../../core/services/appwrite_service.dart';
import '../../../shared/models/partner_permissions.dart';
import '../domain/onboarding_state.dart';
import 'onboarding_repository.dart';
import 'onboarding_value_mappers.dart';

/// Saves the completed survey into the singleton rows `onUserCreate`
/// (Plan 5 Task 5) created at sign-up. Uses updateRow, not upsert: clients
/// have no create permission on these tables by design.
class AppwriteOnboardingRepository implements OnboardingRepository {
  AppwriteOnboardingRepository(this._appwrite);

  final AppwriteService _appwrite;

  Future<void> _update(String tableId, String uid, Map<String, dynamic> data) => _appwrite.tablesDb.updateRow(
        databaseId: AppwriteIds.databaseId,
        tableId: tableId,
        rowId: uid,
        data: data,
      );

  @override
  Future<String?> saveOnboarding(String uid, OnboardingState state) async {
    await _update(AppwriteIds.profiles, uid, profileFor(state).toRow());
    await _update(AppwriteIds.lifeStageProfiles, uid, lifeStageProfileFor(state).toRow());
    await _update(AppwriteIds.preferences, uid, preferencesFor(state).toRow());

    if (!state.partnerInvite) return null;

    await _update(
      AppwriteIds.partnerPermissions,
      uid,
      PartnerPermissions(
        approvedCategories: categoryKeys(state.partnerPermissions),
        onlyApproveMode: state.onlyApproveMaster,
      ).toRow(),
    );
    final result = await _appwrite.executeJson(AppwriteIds.fnPartnerInvites, {
      'action': 'createInvite',
      'relationshipType': relationshipKey(state.partnerRelation),
    });
    return result['inviteCode'] as String?;
  }
}
```

- [ ] **Step 8: Implement the provider file `EVE_MOBILE/app/lib/core/providers/repository_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/data/appwrite_onboarding_repository.dart';
import '../../features/onboarding/data/onboarding_repository.dart';
import 'appwrite_providers.dart';

/// Widgets read repositories through these providers; tests override them
/// with the fakes from test/support/fake_repositories.dart.
final onboardingRepositoryProvider =
    Provider<OnboardingRepository>((ref) => AppwriteOnboardingRepository(ref.watch(appwriteServiceProvider)));
```

Run: `flutter test test/features/onboarding/data/ && flutter analyze`
Expected: all onboarding data tests pass (7 + 2); no analyzer issues.

- [ ] **Step 9: Write the failing dialog test, implement the dialog**

Create `EVE_MOBILE/app/test/features/onboarding/presentation/widgets/partner_invite_code_dialog_test.dart`:

```dart
import 'package:eve_app/features/onboarding/presentation/widgets/partner_invite_code_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the code and closes on Done', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(context: context, builder: (_) => const PartnerInviteCodeDialog(code: 'ABC234')),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('ABC234'), findsOneWidget);
    expect(find.textContaining('Share this code with your partner'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(PartnerInviteCodeDialog), findsNothing);
  });
}
```

Run it — expected FAIL (file missing). Then create `EVE_MOBILE/app/lib/features/onboarding/presentation/widgets/partner_invite_code_dialog.dart`:

```dart
import 'package:flutter/material.dart';

class PartnerInviteCodeDialog extends StatelessWidget {
  const PartnerInviteCodeDialog({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your partner invite'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Share this code with your partner so they can join you in EVE. '
            'They will only ever see what you have chosen to share.',
          ),
          const SizedBox(height: 16),
          SelectableText(code, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 4)),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))],
    );
  }
}
```

Run again. Expected: `All tests passed!` (1 test).

- [ ] **Step 10: Wire the Completion route**

In `EVE_MOBILE/app/lib/core/router/app_router.dart`, replace the `/onboarding/completion` `GoRoute` (added in M12 Step 3) with:

```dart
    GoRoute(
      path: '/onboarding/completion',
      name: 'onboarding-completion',
      builder: (context, state) => Consumer(
        builder: (context, ref, _) => CompletionScreen(
          onContinue: () async {
            final uid = ref.read(currentUidProvider);
            String? inviteCode;
            if (uid != null) {
              try {
                inviteCode = await ref
                    .read(onboardingRepositoryProvider)
                    .saveOnboarding(uid, ref.read(onboardingStateProvider));
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('We could not save your answers. Please check your connection and try again.'),
                  ));
                }
                return;
              }
            }
            if (!context.mounted) return;
            if (inviteCode != null) {
              await showDialog<void>(context: context, builder: (_) => PartnerInviteCodeDialog(code: inviteCode!));
            }
            if (context.mounted) context.go('/home');
          },
        ),
      ),
    ),
```

Add the imports:

```dart
import 'package:eve_app/core/providers/appwrite_providers.dart';
import 'package:eve_app/core/providers/repository_providers.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/partner_invite_code_dialog.dart';
```

- [ ] **Step 11: Router test for the save path**

Add to `EVE_MOBILE/app/test/core/router/app_router_test.dart`:

```dart
  testWidgets('Completion saves onboarding through the repository and goes Home', (tester) async {
    final repo = FakeOnboardingRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        onboardingRepositoryProvider.overrideWithValue(repo),
        currentUidProvider.overrideWith((ref) => 'u1'),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ));
    appRouter.go('/onboarding/completion');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enter EVE'));
    await tester.pumpAndSettle();

    expect(repo.saved.single.$1, 'u1');
    expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/home');
  });
```

with imports `package:eve_app/core/providers/appwrite_providers.dart`, `package:eve_app/core/providers/repository_providers.dart` and `../../support/fake_repositories.dart`. (M16 overrides the Home repository provider in this same test file once `/home` reads data; until then `/home` renders its constructor defaults.)

- [ ] **Step 12: Run the full suite**

```bash
flutter test
flutter analyze
```

Expected: everything passes; no analyzer issues.

- [ ] **Step 13: Commit**

```bash
cd EVE_MOBILE
git add app/lib/features/onboarding/data app/lib/core/providers/repository_providers.dart app/lib/features/onboarding/presentation/widgets/partner_invite_code_dialog.dart app/lib/core/router/app_router.dart app/test/features/onboarding app/test/core/router/app_router_test.dart
git commit -m "feat(app): persist completed onboarding to Appwrite with canonical keys"
```

**Demo:** against local Appwrite (Plan 3 Task 10's local `--dart-define`s), sign in with Google, walk onboarding to completion with partner invite off, tap "Enter EVE" — Console → Databases → eve shows her `profiles`, `life_stage_profiles` and `preferences` rows with the entered values and canonical keys (`enabledReminders: ["morning", ...]`). With partner invite on (after M18 deploys `partnerInvites`), the invite-code dialog appears and `partner_links/<uid>` is `pending` with that code.

### M15 — Home/Chat/Log structural shells

Run: **Plan 1 Tasks 22–24** (Home, Chat, Log — all structure-only/placeholder-data per that plan's explicit scope boundary).

**Demo:** `flutter test test/features/home/ test/features/chat/ test/features/log/` passes. These aren't wired into the router yet if M12 ran before this milestone in your execution order — note M12 already referenced `HomeScreen`/`ChatScreen`/`LogScreen` by name, so in practice run M15 before M12 if executing strictly in file order; the dependency is "M15's screens must exist before M12 imports them," not the milestone numbers.

### M16 — Wire Home/Chat/Log to real Appwrite data (NEW)

**Files:**
- Create: `EVE_MOBILE/app/lib/core/services/live_rows.dart`
- Create: `EVE_MOBILE/app/lib/features/home/data/appwrite_home_repository.dart`
- Create: `EVE_MOBILE/app/lib/features/chat/data/appwrite_chat_repository.dart`
- Create: `EVE_MOBILE/app/lib/features/log/data/appwrite_log_repository.dart`
- Create: `EVE_MOBILE/app/lib/features/chat/presentation/chat_mapping.dart`
- Create: `EVE_MOBILE/app/lib/features/log/presentation/log_mapping.dart`
- Create: `EVE_MOBILE/app/lib/features/log/presentation/widgets/quick_log_sheet.dart`
- Modify: `EVE_MOBILE/app/lib/core/providers/repository_providers.dart`
- Modify: `EVE_MOBILE/app/lib/core/router/app_router.dart`
- Test: `EVE_MOBILE/app/test/core/services/live_rows_test.dart`
- Test: `EVE_MOBILE/app/test/features/home/data/appwrite_home_repository_test.dart`
- Test: `EVE_MOBILE/app/test/features/chat/data/appwrite_chat_repository_test.dart`
- Test: `EVE_MOBILE/app/test/features/log/data/appwrite_log_repository_test.dart`
- Test: `EVE_MOBILE/app/test/features/chat/presentation/chat_mapping_test.dart`
- Test: `EVE_MOBILE/app/test/features/log/presentation/log_mapping_test.dart`
- Test: `EVE_MOBILE/app/test/features/log/presentation/widgets/quick_log_sheet_test.dart`

**Interfaces:**
- Consumes: `AppwriteService`, `AppwriteIds`, providers (Plan 2 Task 8), repository interfaces + fakes (Plan 2 Task 9), `ChatMessage`/`SymptomLog`/`UserProfile`/`LifeStageProfile` (Plan 5 Task 4), `HomeScreen`/`ChatScreen`/`LogScreen`/`ChatMessageData`/`ChatSender`/`CalendarDayData` (Plan 1 Tasks 22–24), `EveEmotion` (Plan 6), the `sendChatMessage` function (Plan 7 Task 4 — deployed in M18; before that, sending shows the error snackbar).
- Produces: `liveRows<T>(...)`; `AppwriteHomeRepository`, `AppwriteChatRepository`, `AppwriteLogRepository`; `homeRepositoryProvider`, `chatRepositoryProvider`, `logRepositoryProvider`, `homeDashboardProvider`, `chatThreadIdProvider`, `chatMessagesProvider`, `logsProvider`; `chatMessageDataFor`, `calendarDaysFor`, `emotionForMood`; `QuickLogSheet`.

Cycle-phase prediction math (EVE_PRD §5.1) stays out of scope — the Home badge is a per-life-stage label, as before.

- [ ] **Step 1: Write the failing `liveRows` test**

Create `EVE_MOBILE/app/test/core/services/live_rows_test.dart`:

```dart
import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:eve_app/core/services/appwrite_service.dart';
import 'package:eve_app/core/services/live_rows.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppwriteService extends Mock implements AppwriteService {}

class MockTablesDB extends Mock implements TablesDB {}

class MockRealtime extends Mock implements Realtime {}

class MockRowList extends Mock implements models.RowList {}

class MockRow extends Mock implements models.Row {}

models.Row row(String id, Map<String, dynamic> data) {
  final r = MockRow();
  when(() => r.$id).thenReturn(id);
  when(() => r.data).thenReturn({...data, r'$id': id});
  return r;
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Object>[]);
    registerFallbackValue(<String>[]);
  });

  test('emits the initial page, then applies realtime creates and deletes for the owner only', () async {
    final appwrite = MockAppwriteService();
    final tables = MockTablesDB();
    final realtime = MockRealtime();
    final events = StreamController<RealtimeMessage>();
    when(() => appwrite.tablesDb).thenReturn(tables);
    when(() => appwrite.realtime).thenReturn(realtime);
    when(() => realtime.subscribe(any(), queries: any(named: 'queries'))).thenReturn(RealtimeSubscription(
      close: () async {},
      unsubscribe: () async => events.close(),
      update: ({channels, queries}) async {},
      channels: const ['tablesdb.eve.tables.symptom_logs.rows'],
      queries: const [],
      controller: events,
    ));
    final page = MockRowList();
    final first = row('a', {'userId': 'u1', 'n': 1}); // built outside when(): mocktail forbids nested stubbing
    when(() => page.rows).thenReturn([first]);
    when(() => tables.listRows(
          databaseId: any(named: 'databaseId'),
          tableId: any(named: 'tableId'),
          queries: any(named: 'queries'),
        )).thenAnswer((_) async => page);

    final stream = liveRows<int>(
      appwrite: appwrite,
      tableId: 'symptom_logs',
      ownerColumn: 'userId',
      ownerId: 'u1',
      orderColumn: 'n',
      fromRow: (data, id) => data['n'] as int,
      compare: (a, b) => a.compareTo(b),
    );
    final emissions = <List<int>>[];
    final sub = stream.listen(emissions.add);
    await pumpEventQueue();
    expect(emissions.last, [1]);

    events.add(RealtimeMessage(
      events: const ['tablesdb.eve.tables.symptom_logs.rows.b.create'],
      payload: const {r'$id': 'b', 'userId': 'u1', 'n': 2},
      channels: const [],
      timestamp: '',
    ));
    events.add(RealtimeMessage(
      events: const ['tablesdb.eve.tables.symptom_logs.rows.x.create'],
      payload: const {r'$id': 'x', 'userId': 'someone-else', 'n': 9},
      channels: const [],
      timestamp: '',
    ));
    await pumpEventQueue();
    expect(emissions.last, [1, 2]);

    events.add(RealtimeMessage(
      events: const ['tablesdb.eve.tables.symptom_logs.rows.a.delete'],
      payload: const {r'$id': 'a', 'userId': 'u1', 'n': 1},
      channels: const [],
      timestamp: '',
    ));
    await pumpEventQueue();
    expect(emissions.last, [2]);

    await sub.cancel();
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd EVE_MOBILE/app
flutter test test/core/services/live_rows_test.dart
```

Expected: FAIL — `live_rows.dart` doesn't exist.

- [ ] **Step 3: Implement `EVE_MOBILE/app/lib/core/services/live_rows.dart`**

```dart
import 'dart:async';

import 'package:appwrite/appwrite.dart';

import '../constants/appwrite_ids.dart';
import 'appwrite_service.dart';

/// Live list of one table's rows where [ownerColumn] == [ownerId]: the
/// current page, then every realtime create/update/delete. Subscribes
/// BEFORE listing so nothing written in between is missed; rows are keyed
/// by id so the overlap never duplicates. Realtime only delivers rows the
/// signed-in user may read, and the owner check below filters the rest.
Stream<List<T>> liveRows<T>({
  required AppwriteService appwrite,
  required String tableId,
  required String ownerColumn,
  required String ownerId,
  required String orderColumn,
  required T Function(Map<String, dynamic> data, String id) fromRow,
  required int Function(T a, T b) compare,
}) {
  final items = <String, T>{};
  RealtimeSubscription? subscription;
  late final StreamController<List<T>> controller;
  List<T> snapshot() => items.values.toList()..sort(compare);

  controller = StreamController<List<T>>(
    onListen: () async {
      subscription = appwrite.realtime.subscribe(
        ['tablesdb.${AppwriteIds.databaseId}.tables.$tableId.rows'],
        queries: [Query.equal(ownerColumn, ownerId)],
      );
      subscription!.stream.listen((message) {
        final payload = message.payload;
        if (payload[ownerColumn] != ownerId) return;
        final id = payload[r'$id'] as String;
        if (message.events.any((event) => event.endsWith('.delete'))) {
          items.remove(id);
        } else {
          items[id] = fromRow(payload, id);
        }
        if (!controller.isClosed) controller.add(snapshot());
      });
      try {
        final page = await appwrite.tablesDb.listRows(
          databaseId: AppwriteIds.databaseId,
          tableId: tableId,
          queries: [Query.equal(ownerColumn, ownerId), Query.orderAsc(orderColumn), Query.limit(500)],
        );
        for (final row in page.rows) {
          items.putIfAbsent(row.$id, () => fromRow(row.data, row.$id));
        }
        if (!controller.isClosed) controller.add(snapshot());
      } catch (error, stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      }
    },
    onCancel: () => subscription?.unsubscribe(),
  );
  return controller.stream;
}
```

Run: `flutter test test/core/services/live_rows_test.dart` — expected `All tests passed!` (1 test).

- [ ] **Step 4: Write the failing repository tests**

Create `EVE_MOBILE/app/test/features/home/data/appwrite_home_repository_test.dart`:

```dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:eve_app/core/services/appwrite_service.dart';
import 'package:eve_app/features/home/data/appwrite_home_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppwriteService extends Mock implements AppwriteService {}

class MockTablesDB extends Mock implements TablesDB {}

class MockRow extends Mock implements models.Row {}

void main() {
  late MockTablesDB tables;
  late AppwriteHomeRepository repo;

  void stubRow(String tableId, Map<String, dynamic>? data) {
    if (data == null) {
      when(() => tables.getRow(databaseId: 'eve', tableId: tableId, rowId: 'u1'))
          .thenThrow(AppwriteException('Row not found', 404));
      return;
    }
    // Stub the row before starting the getRow stub: mocktail forbids nested when().
    final row = MockRow();
    when(() => row.data).thenReturn(data);
    when(() => tables.getRow(databaseId: 'eve', tableId: tableId, rowId: 'u1')).thenAnswer((_) async => row);
  }

  setUp(() {
    tables = MockTablesDB();
    final appwrite = MockAppwriteService();
    when(() => appwrite.tablesDb).thenReturn(tables);
    repo = AppwriteHomeRepository(appwrite);
  });

  test('reads the real name and a per-life-stage badge', () async {
    stubRow('profiles', {'name': 'Priya'});
    stubRow('life_stage_profiles', {'type': 'menopause'});
    final data = await repo.loadDashboard('u1');
    expect(data.greetingName, 'Priya');
    expect(data.phaseBadge, 'Menopause Tracking Active');
  });

  test('falls back to a generic greeting and badge when rows are missing or empty', () async {
    stubRow('profiles', null);
    stubRow('life_stage_profiles', {'type': null});
    final data = await repo.loadDashboard('u1');
    expect(data.greetingName, 'there');
    expect(data.phaseBadge, 'Welcome to EVE');
  });
}
```

Create `EVE_MOBILE/app/test/features/chat/data/appwrite_chat_repository_test.dart`:

```dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:eve_app/core/services/appwrite_service.dart';
import 'package:eve_app/features/chat/data/appwrite_chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppwriteService extends Mock implements AppwriteService {}

class MockTablesDB extends Mock implements TablesDB {}

class MockRow extends Mock implements models.Row {}

void main() {
  late MockAppwriteService appwrite;
  late MockTablesDB tables;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    appwrite = MockAppwriteService();
    tables = MockTablesDB();
    when(() => appwrite.tablesDb).thenReturn(tables);
  });

  test('threadIdFor: her own uid when she has no partner lookup row', () async {
    when(() => tables.getRow(databaseId: 'eve', tableId: 'partner_lookups', rowId: 'her'))
        .thenThrow(AppwriteException('Row not found', 404));
    expect(await AppwriteChatRepository(appwrite).threadIdFor('her'), 'her');
  });

  test('threadIdFor: the primary user when the caller is a linked partner', () async {
    final row = MockRow();
    when(() => row.data).thenReturn({'primaryUserId': 'her'});
    when(() => tables.getRow(databaseId: 'eve', tableId: 'partner_lookups', rowId: 'him')).thenAnswer((_) async => row);
    expect(await AppwriteChatRepository(appwrite).threadIdFor('him'), 'her');
  });

  test('sendMessage goes through the sendChatMessage function, never a direct row write', () async {
    when(() => appwrite.executeJson('sendChatMessage', any())).thenAnswer((_) async => {'messageId': 'm1'});
    await AppwriteChatRepository(appwrite).sendMessage('her', 'On my way.');
    verify(() => appwrite.executeJson('sendChatMessage', {'threadUserId': 'her', 'text': 'On my way.'})).called(1);
    verifyNever(() => tables.createRow(
          databaseId: any(named: 'databaseId'),
          tableId: any(named: 'tableId'),
          rowId: any(named: 'rowId'),
          data: any(named: 'data'),
        ));
  });
}
```

Create `EVE_MOBILE/app/test/features/log/data/appwrite_log_repository_test.dart`:

```dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:eve_app/core/services/appwrite_service.dart';
import 'package:eve_app/features/log/data/appwrite_log_repository.dart';
import 'package:eve_app/shared/models/symptom_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppwriteService extends Mock implements AppwriteService {}

class MockTablesDB extends Mock implements TablesDB {}

class MockRow extends Mock implements models.Row {}

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  test('addLog creates an owner-only row with a unique id', () async {
    final appwrite = MockAppwriteService();
    final tables = MockTablesDB();
    when(() => appwrite.tablesDb).thenReturn(tables);
    when(() => tables.createRow(
          databaseId: any(named: 'databaseId'),
          tableId: any(named: 'tableId'),
          rowId: any(named: 'rowId'),
          data: any(named: 'data'),
          permissions: any(named: 'permissions'),
        )).thenAnswer((_) async => MockRow());

    await AppwriteLogRepository(appwrite).addLog(
      'u1',
      SymptomLog(userId: 'u1', date: DateTime.utc(2026, 3, 14), mood: 'low', painLevel: 3),
    );

    final captured = verify(() => tables.createRow(
          databaseId: 'eve',
          tableId: 'symptom_logs',
          rowId: captureAny(named: 'rowId'),
          data: captureAny(named: 'data'),
          permissions: captureAny(named: 'permissions'),
        )).captured;
    expect(captured[0], isNot('u1')); // ID.unique(), not a fixed id
    expect((captured[1] as Map)['mood'], 'low');
    expect(captured[2], ['read("user:u1")', 'update("user:u1")', 'delete("user:u1")']);
  });
}
```

Run: `flutter test test/features/home/data test/features/chat/data test/features/log/data`
Expected: FAIL — the three `appwrite_*_repository.dart` files don't exist.

- [ ] **Step 5: Implement the repositories**

`EVE_MOBILE/app/lib/features/home/data/appwrite_home_repository.dart`:

```dart
import 'package:appwrite/appwrite.dart';

import '../../../core/constants/appwrite_ids.dart';
import '../../../core/services/appwrite_service.dart';
import '../../../shared/models/life_stage_profile.dart';
import '../../../shared/models/user_profile.dart';
import 'home_repository.dart';

class AppwriteHomeRepository implements HomeRepository {
  AppwriteHomeRepository(this._appwrite);

  final AppwriteService _appwrite;

  Future<Map<String, dynamic>?> _row(String tableId, String uid) async {
    try {
      final row = await _appwrite.tablesDb.getRow(databaseId: AppwriteIds.databaseId, tableId: tableId, rowId: uid);
      return row.data;
    } on AppwriteException catch (e) {
      if (e.code == 404) return null; // onUserCreate not finished yet
      rethrow;
    }
  }

  @override
  Future<HomeDashboardData> loadDashboard(String uid) async {
    final profileData = await _row(AppwriteIds.profiles, uid);
    final lifeStageData = await _row(AppwriteIds.lifeStageProfiles, uid);

    final name = profileData == null ? '' : UserProfile.fromRow(profileData).name;
    final lifeStage = lifeStageData == null ? const EmptyLifeStageProfile() : LifeStageProfile.fromRow(lifeStageData);
    final type = lifeStage.type;
    final phaseBadge = switch (type) {
      null => 'Welcome to EVE',
      'pregnant' => 'Pregnancy Tracking Active',
      'cycle' => 'Cycle Tracking Active',
      _ => '${type[0].toUpperCase()}${type.substring(1)} Tracking Active',
    };
    return HomeDashboardData(greetingName: name.isEmpty ? 'there' : name, phaseBadge: phaseBadge);
  }
}
```

`EVE_MOBILE/app/lib/features/chat/data/appwrite_chat_repository.dart`:

```dart
import 'package:appwrite/appwrite.dart';

import '../../../core/constants/appwrite_ids.dart';
import '../../../core/services/appwrite_service.dart';
import '../../../core/services/live_rows.dart';
import '../../../shared/models/chat_message.dart';
import 'chat_repository.dart';

class AppwriteChatRepository implements ChatRepository {
  AppwriteChatRepository(this._appwrite);

  final AppwriteService _appwrite;

  @override
  Future<String> threadIdFor(String uid) async {
    try {
      final lookup = await _appwrite.tablesDb.getRow(
        databaseId: AppwriteIds.databaseId,
        tableId: AppwriteIds.partnerLookups,
        rowId: uid,
      );
      return lookup.data['primaryUserId'] as String;
    } on AppwriteException catch (e) {
      if (e.code == 404) return uid; // she is the primary user
      rethrow;
    }
  }

  @override
  Stream<List<ChatMessage>> watchThread(String threadUserId) => liveRows<ChatMessage>(
        appwrite: _appwrite,
        tableId: AppwriteIds.chatMessages,
        ownerColumn: 'threadUserId',
        ownerId: threadUserId,
        orderColumn: 'sentAt',
        fromRow: (data, id) => ChatMessage.fromRow(data, id: id),
        compare: (a, b) => a.sentAt.compareTo(b.sentAt),
      );

  @override
  Future<void> sendMessage(String threadUserId, String text) async {
    await _appwrite.executeJson(AppwriteIds.fnSendChatMessage, {'threadUserId': threadUserId, 'text': text});
  }
}
```

`EVE_MOBILE/app/lib/features/log/data/appwrite_log_repository.dart`:

```dart
import 'package:appwrite/appwrite.dart';

import '../../../core/constants/appwrite_ids.dart';
import '../../../core/services/appwrite_service.dart';
import '../../../core/services/live_rows.dart';
import '../../../shared/models/symptom_log.dart';
import 'log_repository.dart';

class AppwriteLogRepository implements LogRepository {
  AppwriteLogRepository(this._appwrite);

  final AppwriteService _appwrite;

  @override
  Stream<List<SymptomLog>> watchLogs(String uid) => liveRows<SymptomLog>(
        appwrite: _appwrite,
        tableId: AppwriteIds.symptomLogs,
        ownerColumn: 'userId',
        ownerId: uid,
        orderColumn: 'date',
        fromRow: (data, id) => SymptomLog.fromRow(data, id: id),
        compare: (a, b) => a.date.compareTo(b.date),
      );

  /// Owner-only permissions are what lets the server functions trust this
  /// row's userId (Plan 5 assumption 7).
  @override
  Future<void> addLog(String uid, SymptomLog log) async {
    await _appwrite.tablesDb.createRow(
      databaseId: AppwriteIds.databaseId,
      tableId: AppwriteIds.symptomLogs,
      rowId: ID.unique(),
      data: log.toRow(),
      permissions: [
        Permission.read(Role.user(uid)),
        Permission.update(Role.user(uid)),
        Permission.delete(Role.user(uid)),
      ],
    );
  }
}
```

Run: `flutter test test/features/home/data test/features/chat/data test/features/log/data`
Expected: `All tests passed!` (2 + 3 + 1).

- [ ] **Step 6: Write the failing mapping tests**

Create `EVE_MOBILE/app/test/features/chat/presentation/chat_mapping_test.dart`:

```dart
import 'package:eve_app/features/chat/presentation/chat_mapping.dart';
import 'package:eve_app/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:eve_app/shared/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('senderRole maps to the Plan 1 bubble types', () {
    ChatMessage message(String role) => ChatMessage(
          threadUserId: 'her', senderRole: role, messageText: role, sentAt: DateTime.utc(2026), type: 'text',
        );
    expect(chatMessageDataFor(message('her')).sender, ChatSender.wife);
    expect(chatMessageDataFor(message('partner')).sender, ChatSender.partner);
    expect(chatMessageDataFor(message('system')).sender, ChatSender.eveSystem);
    expect(chatMessageDataFor(message('her')).text, 'her');
  });
}
```

Create `EVE_MOBILE/app/test/features/log/presentation/log_mapping_test.dart`:

```dart
import 'package:eve_app/features/log/presentation/log_mapping.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/shared/models/symptom_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calendarDaysFor keeps the given month, one entry per day (latest wins), sorted', () {
    final days = calendarDaysFor([
      // Local times: calendar days are her local days, so UTC fixtures would
      // shift across midnight in timezones far from UTC (e.g. IST).
      SymptomLog(userId: 'u1', date: DateTime(2026, 3, 14, 8), symptoms: const ['Cramps'], mood: 'low'),
      SymptomLog(userId: 'u1', date: DateTime(2026, 3, 2), mood: 'great', notes: 'Felt strong.'),
      SymptomLog(userId: 'u1', date: DateTime(2026, 3, 14, 20), mood: 'okay'),
      SymptomLog(userId: 'u1', date: DateTime(2026, 4, 1), mood: 'good'),
    ], month: DateTime(2026, 3));

    expect(days.map((d) => d.dayNumber), [2, 14]);
    expect(days.first.detail, 'Felt strong.');
    expect(days.first.emotion, EveEmotion.hype);
    expect(days.last.emotion, EveEmotion.neutral);
    expect(days.last.detail, 'No symptoms logged');
  });

  test('emotionForMood', () {
    expect(emotionForMood('difficult'), EveEmotion.caring);
    expect(emotionForMood(null), EveEmotion.neutral);
  });
}
```

Run both — expected FAIL (files missing).

- [ ] **Step 7: Implement the mappings**

`EVE_MOBILE/app/lib/features/chat/presentation/chat_mapping.dart`:

```dart
import '../../../shared/models/chat_message.dart';
import 'widgets/chat_bubble.dart';

ChatMessageData chatMessageDataFor(ChatMessage message) => ChatMessageData(
      sender: switch (message.senderRole) {
        'partner' => ChatSender.partner,
        'system' => ChatSender.eveSystem,
        _ => ChatSender.wife,
      },
      text: message.messageText,
    );
```

`EVE_MOBILE/app/lib/features/log/presentation/log_mapping.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/symptom_log.dart';
import '../../mascot/eve_emotion.dart';
import 'widgets/calendar_day_cell.dart';

const _symptomPurple = Color(0xFF9B51E0);

EveEmotion emotionForMood(String? mood) => switch (mood) {
      'great' || 'good' => EveEmotion.hype,
      'low' || 'difficult' => EveEmotion.caring,
      _ => EveEmotion.neutral,
    };

/// One calendar entry per day of [month]; when a day has several logs the
/// latest one is shown.
List<CalendarDayData> calendarDaysFor(List<SymptomLog> logs, {required DateTime month}) {
  final byDay = <int, SymptomLog>{};
  final inMonth = logs.where((log) {
    final local = log.date.toLocal();
    return local.year == month.year && local.month == month.month;
  }).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  for (final log in inMonth) {
    byDay[log.date.toLocal().day] = log;
  }
  final days = byDay.keys.toList()..sort();
  return [
    for (final day in days)
      CalendarDayData(
        dayNumber: day,
        dotColors: byDay[day]!.symptoms.isNotEmpty ? const [_symptomPurple] : const [],
        dateTitle: DateFormat('MMMM d').format(byDay[day]!.date.toLocal()),
        detail: byDay[day]!.notes.isNotEmpty
            ? byDay[day]!.notes
            : (byDay[day]!.symptoms.isEmpty ? 'No symptoms logged' : byDay[day]!.symptoms.join(', ')),
        emotion: emotionForMood(byDay[day]!.mood),
      ),
  ];
}
```

Run both mapping tests — expected `All tests passed!` (1 + 2).

- [ ] **Step 8: Quick-log sheet (so logs can actually be created from the app)**

Plan 1's `LogScreen` exposes `onNewEntry` but no plan builds the entry form; without it the partner-nudge demo (M18) needs console-seeded rows. Create `EVE_MOBILE/app/test/features/log/presentation/widgets/quick_log_sheet_test.dart`:

```dart
import 'package:eve_app/features/log/presentation/widgets/quick_log_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('collects mood, symptoms, pain and notes and returns canonical keys', (tester) async {
    QuickLogResult? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: QuickLogSheet(onSave: (result) async => saved = result)),
    ));

    await tester.tap(find.text('Difficult'));
    await tester.tap(find.text('Cramps'));
    await tester.drag(find.byType(Slider), const Offset(400, 0));
    await tester.enterText(find.byType(TextField), 'Long day.');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved!.mood, 'difficult');
    expect(saved!.symptoms, ['Cramps']);
    expect(saved!.painLevel, 10);
    expect(saved!.notes, 'Long day.');
  });
}
```

Run — expected FAIL. Then create `EVE_MOBILE/app/lib/features/log/presentation/widgets/quick_log_sheet.dart`:

```dart
import 'package:flutter/material.dart';

class QuickLogResult {
  const QuickLogResult({required this.mood, required this.symptoms, required this.painLevel, required this.notes});

  final String? mood;
  final List<String> symptoms;
  final int painLevel;
  final String notes;
}

class QuickLogSheet extends StatefulWidget {
  const QuickLogSheet({super.key, required this.onSave});

  final Future<void> Function(QuickLogResult result) onSave;

  @override
  State<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<QuickLogSheet> {
  static const _moods = {'Great': 'great', 'Good': 'good', 'Okay': 'okay', 'Low': 'low', 'Difficult': 'difficult'};
  static const _symptoms = ['Cramps', 'Headache', 'Bloating', 'Fatigue', 'Back pain', 'Nausea'];

  String? _mood;
  final _selectedSymptoms = <String>{};
  double _pain = 0;
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(QuickLogResult(
      mood: _mood,
      symptoms: _symptoms.where(_selectedSymptoms.contains).toList(),
      painLevel: _pain.round(),
      notes: _notes.text.trim(),
    ));
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How are you feeling today?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in _moods.entries)
              ChoiceChip(
                label: Text(entry.key),
                selected: _mood == entry.value,
                onSelected: (_) => setState(() => _mood = entry.value),
              ),
          ]),
          const SizedBox(height: 16),
          const Text('Symptoms', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final symptom in _symptoms)
              FilterChip(
                label: Text(symptom),
                selected: _selectedSymptoms.contains(symptom),
                onSelected: (on) => setState(() => on ? _selectedSymptoms.add(symptom) : _selectedSymptoms.remove(symptom)),
              ),
          ]),
          const SizedBox(height: 16),
          Text('Pain level: ${_pain.round()} of 10', style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(value: _pain, min: 0, max: 10, divisions: 10, onChanged: (v) => setState(() => _pain = v)),
          TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)'), maxLines: 2),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _saving ? null : _save, child: const Text('Save')),
          ),
        ],
      ),
    );
  }
}
```

Run — expected `All tests passed!` (1 test).

- [ ] **Step 9: Providers**

Append to `EVE_MOBILE/app/lib/core/providers/repository_providers.dart`:

```dart
final homeRepositoryProvider =
    Provider<HomeRepository>((ref) => AppwriteHomeRepository(ref.watch(appwriteServiceProvider)));

final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => AppwriteChatRepository(ref.watch(appwriteServiceProvider)));

final logRepositoryProvider =
    Provider<LogRepository>((ref) => AppwriteLogRepository(ref.watch(appwriteServiceProvider)));

final homeDashboardProvider = FutureProvider.family<HomeDashboardData, String>(
  (ref, uid) => ref.watch(homeRepositoryProvider).loadDashboard(uid),
);

final chatThreadIdProvider = FutureProvider.family<String, String>(
  (ref, uid) => ref.watch(chatRepositoryProvider).threadIdFor(uid),
);

final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>(
  (ref, threadUserId) => ref.watch(chatRepositoryProvider).watchThread(threadUserId),
);

final logsProvider = StreamProvider.family<List<SymptomLog>, String>(
  (ref, uid) => ref.watch(logRepositoryProvider).watchLogs(uid),
);
```

with the matching imports (`home_repository.dart`, `appwrite_home_repository.dart`, `chat_repository.dart`, `appwrite_chat_repository.dart`, `log_repository.dart`, `appwrite_log_repository.dart`, `shared/models/chat_message.dart`, `shared/models/symptom_log.dart`).

- [ ] **Step 10: Wire `/home`, `/chat`, `/log`**

In `EVE_MOBILE/app/lib/core/router/app_router.dart` replace the three routes (added in M12 Step 3) with:

```dart
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => Consumer(builder: (context, ref, _) {
        final uid = ref.watch(currentUidProvider);
        if (uid == null) return const HomeScreen();
        return ref.watch(homeDashboardProvider(uid)).when(
              data: (data) => HomeScreen(
                greetingName: data.greetingName,
                phaseBadge: data.phaseBadge,
                onNavigateChat: () => context.go('/chat'),
                onNavigateLog: () => context.go('/log'),
              ),
              loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
              error: (_, __) => HomeScreen(onNavigateChat: () => context.go('/chat'), onNavigateLog: () => context.go('/log')),
            );
      }),
    ),
    GoRoute(
      path: '/chat',
      name: 'chat',
      builder: (context, state) => Consumer(builder: (context, ref, _) {
        final uid = ref.watch(currentUidProvider);
        final fallback = ChatScreen(onNavigateHome: () => context.go('/home'), onNavigateLog: () => context.go('/log'));
        if (uid == null) return fallback;
        final threadId = ref.watch(chatThreadIdProvider(uid)).valueOrNull;
        if (threadId == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return ref.watch(chatMessagesProvider(threadId)).when(
              data: (messages) => ChatScreen(
                thread: messages.map(chatMessageDataFor).toList(),
                onSendMessage: (text) async {
                  try {
                    await ref.read(chatRepositoryProvider).sendMessage(threadId, text);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Your message was not sent. Please try again.')),
                      );
                    }
                  }
                },
                onNavigateHome: () => context.go('/home'),
                onNavigateLog: () => context.go('/log'),
              ),
              loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
              error: (_, __) => fallback,
            );
      }),
    ),
    GoRoute(
      path: '/log',
      name: 'log',
      builder: (context, state) => Consumer(builder: (context, ref, _) {
        final uid = ref.watch(currentUidProvider);
        final now = DateTime.now();
        final fallback = LogScreen(onNavigateHome: () => context.go('/home'), onNavigateChat: () => context.go('/chat'));
        if (uid == null) return fallback;
        return ref.watch(logsProvider(uid)).when(
              data: (logs) => LogScreen(
                monthLabel: DateFormat('MMMM yyyy').format(now),
                days: calendarDaysFor(logs, month: now),
                onNavigateHome: () => context.go('/home'),
                onNavigateChat: () => context.go('/chat'),
                onNewEntry: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (sheetContext) => QuickLogSheet(
                    onSave: (result) async {
                      await ref.read(logRepositoryProvider).addLog(
                            uid,
                            SymptomLog(
                              userId: uid,
                              date: DateTime.now().toUtc(),
                              symptoms: result.symptoms,
                              mood: result.mood,
                              painLevel: result.painLevel,
                              notes: result.notes,
                            ),
                          );
                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
              ),
              loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
              error: (_, __) => fallback,
            );
      }),
    ),
```

Imports to add: `package:intl/intl.dart`, `package:eve_app/core/providers/repository_providers.dart` (already there from M14), `package:eve_app/features/chat/presentation/chat_mapping.dart`, `package:eve_app/features/log/presentation/log_mapping.dart`, `package:eve_app/features/log/presentation/widgets/quick_log_sheet.dart`, `package:eve_app/shared/models/symptom_log.dart`.

- [ ] **Step 11: Router tests with fakes**

Add to `EVE_MOBILE/app/test/core/router/app_router_test.dart` (reusing `test/support/fake_repositories.dart`):

```dart
  testWidgets('Home shows the signed-in user name from the repository', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWith((ref) => 'u1'),
        homeRepositoryProvider.overrideWithValue(FakeHomeRepository(const HomeDashboardDataFixture().data)),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ));
    appRouter.go('/home');
    await tester.pumpAndSettle();
    expect(find.text('Welcome back, Priya'), findsOneWidget);
  });

  testWidgets('Chat sends through the repository and renders the new message', (tester) async {
    final chat = FakeChatRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWith((ref) => 'u1'),
        chatRepositoryProvider.overrideWithValue(chat),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ));
    appRouter.go('/chat');
    await tester.pumpAndSettle();
    await chat.sendMessage('u1', 'Hello from the test');
    await tester.pumpAndSettle();
    expect(find.text('Hello from the test'), findsOneWidget);
  });
```

Also add the Home repository override to M14's Completion test (it now lands on a data-driven `/home`): `homeRepositoryProvider.overrideWithValue(FakeHomeRepository(const HomeDashboardDataFixture().data)),`.

- [ ] **Step 12: Run everything**

```bash
flutter test
flutter analyze
```

Expected: all tests pass; `No issues found!`; `grep -rln "package:appwrite" lib/features | grep -v "/data/appwrite_"` prints nothing (widgets never import the SDK).

- [ ] **Step 13: Commit**

```bash
cd EVE_MOBILE
git add app/lib/core app/lib/features app/test
git commit -m "feat(app): wire Home, Chat and Log to Appwrite with realtime updates"
```

**Demo:** against local Appwrite, sign in and finish onboarding — Home greets her by name with the life-stage badge. On Log, tap the add button, log "Difficult" with cramps — a purple dot appears on today immediately (realtime). Edit that row's `notes` in the console — the detail text updates without a refresh. Chat send works once M18 deploys `sendChatMessage`.

### M17 — Notifications backend (Appwrite native push)

Run: **Plan 3 Task 8** (eligibility), **Plan 3 Task 9** (dispatch function + `PushService`). Then start push at sign-in:

- [ ] **Step 1: Start `PushService` whenever a user is signed in**

Add to `EVE_MOBILE/app/lib/core/providers/appwrite_providers.dart`:

```dart
final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(Push(ref.watch(appwriteServiceProvider).client));
  ref.onDispose(service.stop);
  return service;
});
```

(imports `package:appwrite/appwrite.dart`, `../services/push_service.dart`), plus a lifecycle provider in the same file:

```dart
/// Keeps push subscribed exactly while someone is signed in. Watched by
/// EveApp, so it also runs for the uid seeded in main.dart (WidgetRef.listen
/// has no fireImmediately in Riverpod 2).
final pushLifecycleProvider = Provider<void>((ref) {
  final push = ref.watch(pushServiceProvider);
  ref.watch(currentUidProvider) == null ? push.stop() : push.start(onMessage: (_) {});
});
```

and in `EVE_MOBILE/app/lib/app.dart`'s `EveApp.build`, before returning `MaterialApp.router`: `ref.watch(pushLifecycleProvider);`. (The earlier draft used `ref.listen(..., fireImmediately: true)`, which does not compile: `WidgetRef.listen` has no `fireImmediately` parameter in Riverpod 2.)

`app_test.dart` passes unchanged (verified): with `currentUidProvider` null only `stop()` runs.

- [ ] **Step 2: Verify and commit**

`flutter test && flutter analyze` green. Commit:

```bash
cd EVE_MOBILE
git add app/lib/core/providers/appwrite_providers.dart app/lib/app.dart app/test/app_test.dart
git commit -m "feat(app): subscribe to Appwrite push while signed in"
```

**Demo:** set her `preferences.enabledReminders` to include the type due in the current 30-minute UTC slot (Plan 3 Task 8's schedule), execute `notifications` from the console — the device shows an "Eve" notification, including with the app swiped away (Android, within the SDK's wake-up interval). Console → Messaging lists the sent message.

### M18 — Partner consent engine + partner join

Run: **Plan 7 Tasks 1–5**, then **N9** below, then **Plan 7 Task 6** (the end-to-end scenario needs N9's join screen).

#### N9 — Partner join screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/partner/presentation/partner_join_screen.dart`
- Test: `EVE_MOBILE/app/test/features/partner/presentation/partner_join_screen_test.dart`
- Modify: `EVE_MOBILE/app/lib/core/router/app_router.dart`

**Interfaces:**
- Consumes: `AppwriteService.executeJson`, `signInWithGoogle`, `currentUidProvider` (Plan 2 Task 8); `partnerInvites.acceptInvite` (Plan 7 Task 3).
- Produces: `PartnerJoinScreen` (constructor-driven, `onSubmit(code)` returns an error string or null), route `/partner/join`. After joining, the partner lands on `/chat`, whose `chatThreadIdProvider` (M16) resolves to her thread via `partner_lookups`.

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/partner/presentation/partner_join_screen_test.dart
import 'package:eve_app/features/partner/presentation/partner_join_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('submits the uppercased code and shows a server error', (tester) async {
    String? submitted;
    await tester.pumpWidget(MaterialApp(
      home: PartnerJoinScreen(onSubmit: (code) async {
        submitted = code;
        return 'This invite code is not valid.';
      }),
    ));

    await tester.enterText(find.byType(TextField), 'abc234');
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(submitted, 'ABC234');
    expect(find.text('This invite code is not valid.'), findsOneWidget);
  });
}
```

Run: `flutter test test/features/partner/presentation/partner_join_screen_test.dart` — expected FAIL (file missing).

- [ ] **Step 2: Implement `EVE_MOBILE/app/lib/features/partner/presentation/partner_join_screen.dart`**

```dart
import 'package:flutter/material.dart';

class PartnerJoinScreen extends StatefulWidget {
  const PartnerJoinScreen({super.key, required this.onSubmit});

  /// Returns null on success, or a message to show.
  final Future<String?> Function(String code) onSubmit;

  @override
  State<PartnerJoinScreen> createState() => _PartnerJoinScreenState();
}

class _PartnerJoinScreenState extends State<PartnerJoinScreen> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit(_code.text.trim().toUpperCase());
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join your partner')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enter the six-character code your partner shared with you. '
                'You will see only what she chooses to share.'),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Invite code'),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _busy ? null : _submit, child: const Text('Join')),
          ],
        ),
      ),
    );
  }
}
```

Run the test — expected `All tests passed!` (1 test).

- [ ] **Step 3: Route + entry point**

Add to `appRouter`'s routes in `EVE_MOBILE/app/lib/core/router/app_router.dart`:

```dart
    GoRoute(
      path: '/partner/join',
      name: 'partner-join',
      builder: (context, state) => Consumer(
        builder: (context, ref, _) => PartnerJoinScreen(
          onSubmit: (code) async {
            final appwrite = ref.read(appwriteServiceProvider);
            try {
              if (await appwrite.currentUserId() == null) await appwrite.signInWithGoogle();
              ref.read(currentUidProvider.notifier).state = await appwrite.currentUserId();
              await appwrite.executeJson(AppwriteIds.fnPartnerInvites, {'action': 'acceptInvite', 'inviteCode': code});
              if (context.mounted) context.go('/chat');
              return null;
            } on FunctionCallException catch (e) {
              return e.message;
            } catch (_) {
              return 'Something went wrong. Please try again.';
            }
          },
        ),
      ),
    ),
```

(imports: `package:eve_app/core/constants/appwrite_ids.dart`, `package:eve_app/core/services/appwrite_service.dart`, `package:eve_app/features/partner/presentation/partner_join_screen.dart`.)

Entry point: in the `/onboarding/welcome` route builder, wrap `WelcomeScreen` so partners can bypass onboarding:

```dart
      builder: (context, state) => Stack(
        children: [
          WelcomeScreen(onContinue: () => context.go('/onboarding/auth')),
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: SafeArea(
              child: TextButton(
                key: const Key('welcome-partner-join'),
                onPressed: () => context.go('/partner/join'),
                child: const Text('Joining a partner? Enter an invite code'),
              ),
            ),
          ),
        ],
      ),
```

Also add `'/partner/join'` to `_expectedRoutePaths` in that test file (the route-set test asserts the exact set). Then add to `EVE_MOBILE/app/test/core/router/app_router_test.dart`:

```dart
  testWidgets('Welcome links partners to the join screen', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: appRouter)));
    appRouter.go('/onboarding/welcome');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome-partner-join')));
    await tester.pumpAndSettle();
    expect(find.text('Join your partner'), findsOneWidget);
  });
```

- [ ] **Step 4: Run and commit**

```bash
cd EVE_MOBILE/app
flutter test
flutter analyze
cd ..
git add app/lib/features/partner/presentation app/test/features/partner app/lib/core/router/app_router.dart app/test/core/router/app_router_test.dart
git commit -m "feat(app): add partner join screen and route"
```

**Known V0 gap (flagged, not built):** the partner sees the shared chat (with Eve's nudges) but no dedicated dashboard rendering `partner_views`. The row is readable by him and ready; a partner Home card is a follow-up.

**Demo (whole of M18):** Plan 7 Task 6's scenario end to end on two devices: invite → join with the code → her approved mood update produces a `partner_views` change, an Eve system message in the shared chat, and a push on his device; revoking clears it; a forged system message from his session is rejected.

### M19 — Doctor-ready summary export (NEW — the identified V0 scope gap)

`EVE2_PRD.md` §11 requires "a doctor summary export that performs one real AI call and formats the result" in V0. Plan 3 Task 7 ships `aiProxy` with `ping`/`checkIn`; this milestone adds `doctorSummary`.

#### N5 — `doctorSummary` feature in `aiProxy` (server reads her logs itself)

**Files:**
- Create: `EVE_MOBILE/functions/aiProxy/src/doctorSummary.ts`
- Modify: `EVE_MOBILE/functions/aiProxy/src/handle.ts`
- Modify: `EVE_MOBILE/functions/aiProxy/src/main.ts`
- Test: `EVE_MOBILE/functions/aiProxy/test/doctorSummary.test.ts`

**Interfaces:**
- Consumes: `Db`, `serverDb`, `isOwnedBy`, `TABLES` (Plan 5), `generateWithFallback` (Plan 3 Task 6), `handleAiRequest`/`AiDeps` (Plan 3 Task 7).
- Produces: `DoctorSummaryLogEntry`, `buildDoctorSummaryPrompt(logs)`, `loadLogsForSummary(db, uid, days, now)`, and `feature: 'doctorSummary'` → `{ summary, provider, logCount }`.

**Why server-side reads:** the client could send any "logs" it likes; reading her own rows (with `isOwnedBy`) means the summary is always built from what she actually logged, and the payload stays small.

- [ ] **Step 1: Write the failing tests**

Create `EVE_MOBILE/functions/aiProxy/test/doctorSummary.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { buildDoctorSummaryPrompt, loadLogsForSummary } from '../src/doctorSummary.js';
import { handleAiRequest } from '../src/handle.js';
import type { AiPrompt, AiProvider } from '../src/providers.js';
import { ownerPermissions } from '../../shared/src/permissions.js';
import { MemoryDb } from '../../shared/test/memoryDb.js';

const NOW = new Date('2026-03-20T00:00:00.000Z');

describe('buildDoctorSummaryPrompt', () => {
  it('states plainly when there is no data', () => {
    expect(buildDoctorSummaryPrompt([])).toContain('No symptom or mood logs were recorded');
  });

  it('lists entries chronologically, marks missing fields, forbids diagnoses', () => {
    const prompt = buildDoctorSummaryPrompt([
      { date: '2026-03-04', symptoms: ['cramps'], mood: 'okay', painLevel: 4, notes: 'Felt tired.' },
      { date: '2026-03-02', symptoms: [], mood: null, painLevel: null, notes: '' },
    ]);
    expect(prompt.indexOf('2026-03-02')).toBeLessThan(prompt.indexOf('2026-03-04'));
    expect(prompt).toContain('Symptoms: cramps');
    expect(prompt).toContain('Symptoms: none reported');
    expect(prompt).toContain('Mood: not reported');
    expect(prompt).toContain('never state a diagnosis');
  });
});

describe('loadLogsForSummary', () => {
  it('returns only her owned logs inside the window', async () => {
    const db = new MemoryDb();
    await db.createRow('symptom_logs', 'a', { userId: 'u1', date: '2026-03-10T08:00:00.000Z', symptoms: ['cramps'], mood: 'low', painLevel: 5, notes: '' }, ownerPermissions('u1'));
    await db.createRow('symptom_logs', 'old', { userId: 'u1', date: '2025-10-01T08:00:00.000Z', symptoms: [], mood: null, painLevel: null, notes: '' }, ownerPermissions('u1'));
    await db.createRow('symptom_logs', 'forged', { userId: 'u1', date: '2026-03-11T08:00:00.000Z', symptoms: ['x'], mood: 'great', painLevel: 0, notes: '' }, ownerPermissions('attacker'));

    const logs = await loadLogsForSummary(db, 'u1', 90, NOW);
    expect(logs).toEqual([{ date: '2026-03-10', symptoms: ['cramps'], mood: 'low', painLevel: 5, notes: '' }]);
  });
});

describe('handleAiRequest doctorSummary', () => {
  it('builds the prompt from server-read logs and returns the summary', async () => {
    const db = new MemoryDb();
    await db.createRow('symptom_logs', 'a', { userId: 'u1', date: '2026-03-10T08:00:00.000Z', symptoms: ['cramps'], mood: 'low', painLevel: 5, notes: '' }, ownerPermissions('u1'));
    const seen: AiPrompt[] = [];
    const provider: AiProvider = {
      name: 'gemini',
      timeoutMs: 1000,
      async generate(prompt) {
        seen.push(prompt);
        return { text: 'Overview: cramps once.', provider: 'gemini', model: 'fake' };
      },
    };

    const result = await handleAiRequest({ providers: [provider], db, now: () => NOW }, 'u1', { feature: 'doctorSummary', days: 30 });

    expect(result).toEqual({ status: 200, body: { summary: 'Overview: cramps once.', provider: 'gemini', logCount: 1 } });
    expect(seen[0].user).toContain('Date: 2026-03-10');
  });
});
```

Run: `npx vitest run aiProxy/test/doctorSummary.test.ts` — expected FAIL (`../src/doctorSummary.js` missing).

- [ ] **Step 2: Implement `EVE_MOBILE/functions/aiProxy/src/doctorSummary.ts`**

```ts
import type { Db } from '../../shared/src/db.js';
import { TABLES } from '../../shared/src/ids.js';
import { isOwnedBy } from '../../shared/src/permissions.js';

export interface DoctorSummaryLogEntry {
  date: string; // YYYY-MM-DD
  symptoms: string[];
  mood: string | null;
  painLevel: number | null;
  notes: string;
}

export const DOCTOR_SUMMARY_SYSTEM_PROMPT =
  "You write factual clinical summaries of a patient's self-reported symptom and mood log for her doctor. " +
  'Use only the data given, never invent values, never state a diagnosis, and close by recommending she discuss these patterns with her doctor. Do not use emojis.';

export function buildDoctorSummaryPrompt(logs: DoctorSummaryLogEntry[]): string {
  if (logs.length === 0) {
    return 'No symptom or mood logs were recorded in the selected period. State this plainly and do not fabricate any data.';
  }
  const lines = [...logs]
    .sort((a, b) => a.date.localeCompare(b.date))
    .map((log) => {
      const parts = [
        `Date: ${log.date}`,
        `Symptoms: ${log.symptoms.length > 0 ? log.symptoms.join(', ') : 'none reported'}`,
        `Mood: ${log.mood ?? 'not reported'}`,
        `Pain level (0-10): ${log.painLevel ?? 'not reported'}`,
      ];
      if (log.notes.trim()) parts.push(`Notes: ${log.notes.trim()}`);
      return parts.join(' | ');
    });
  return [
    'Rules: use only the data below, never invent symptoms or values, never state a diagnosis, and close with a line recommending she discuss these patterns with her doctor.',
    'Format: a short overview paragraph, then a "Notable patterns" section, then a "Log entries" section listing each date.',
    '',
    `Log entries (${logs.length} total):`,
    ...lines,
  ].join('\n');
}

export async function loadLogsForSummary(db: Db, uid: string, days: number, now: Date): Promise<DoctorSummaryLogEntry[]> {
  const since = now.getTime() - days * 24 * 60 * 60 * 1000;
  const rows = await db.listRows(TABLES.symptomLogs, {
    equal: { userId: uid },
    orderBy: { column: 'date', direction: 'asc' },
    limit: 1000,
  });
  return rows
    .filter((row) => isOwnedBy(row, uid) && Date.parse(String(row.date)) >= since)
    .map((row) => ({
      date: String(row.date).slice(0, 10),
      symptoms: (row.symptoms as string[] | null) ?? [],
      mood: (row.mood as string | null) ?? null,
      painLevel: (row.painLevel as number | null) ?? null,
      notes: (row.notes as string | null) ?? '',
    }));
}
```

- [ ] **Step 3: Extend `handle.ts` and `main.ts`**

In `EVE_MOBILE/functions/aiProxy/src/handle.ts`: add `db?: Db; now?: () => Date;` to `AiDeps` (import `type Db` from `../../shared/src/db.js` and `{ buildDoctorSummaryPrompt, DOCTOR_SUMMARY_SYSTEM_PROMPT, loadLogsForSummary }` from `./doctorSummary.js`), and add this case to the `switch` before `default`:

```ts
      case 'doctorSummary': {
        if (!deps.db) throw new Error('aiProxy: doctorSummary requires a Db');
        const days = typeof body.days === 'number' && body.days > 0 && body.days <= 365 ? body.days : 90;
        const logs = await loadLogsForSummary(deps.db, uid, days, (deps.now ?? (() => new Date()))());
        const result = await generateWithFallback(
          deps.providers,
          { system: DOCTOR_SUMMARY_SYSTEM_PROMPT, user: buildDoctorSummaryPrompt(logs), maxOutputTokens: 1200 },
          deps.log,
        );
        return { status: 200, body: { summary: result.text, provider: result.provider, logCount: logs.length } };
      }
```

In `EVE_MOBILE/functions/aiProxy/src/main.ts`, pass the database: `{ providers: providersFromEnv(process.env), db: serverDb(context), log: (m) => context.log(m) }` (import `serverDb` from `../../shared/src/db.js`).

Run: `npx vitest run aiProxy && npm run typecheck` — expected all aiProxy tests pass (9 + 6 + 4).

- [ ] **Step 4: Deploy and commit**

```bash
cd EVE_MOBILE
appwrite push functions --function-id aiProxy --force
git add functions/aiProxy
git commit -m "feat(aiProxy): generate doctor-ready summaries from her own logs"
```

#### N6 — `ai_proxy_service.dart` client

**Files:**
- Create: `EVE_MOBILE/app/lib/core/services/ai_proxy_service.dart`
- Test: `EVE_MOBILE/app/test/core/services/ai_proxy_service_test.dart`

**Interfaces:**
- Consumes: `AppwriteService.executeJson`, `AppwriteIds.fnAiProxy` (Plan 2 Task 8).
- Produces: `AiProxyService.generateDoctorSummary({int days = 90})`, `AiProxyService.checkIn(message)`.

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/core/services/ai_proxy_service_test.dart
import 'package:eve_app/core/services/ai_proxy_service.dart';
import 'package:eve_app/core/services/appwrite_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppwriteService extends Mock implements AppwriteService {}

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  test('generateDoctorSummary calls aiProxy with feature doctorSummary and returns the text', () async {
    final appwrite = MockAppwriteService();
    when(() => appwrite.executeJson('aiProxy', {'feature': 'doctorSummary', 'days': 90}))
        .thenAnswer((_) async => {'summary': 'Overview: mild cramps recorded once.', 'provider': 'gemini', 'logCount': 1});

    expect(await AiProxyService(appwrite).generateDoctorSummary(), 'Overview: mild cramps recorded once.');
  });

  test('throws StateError when the response has no summary', () async {
    final appwrite = MockAppwriteService();
    when(() => appwrite.executeJson(any(), any())).thenAnswer((_) async => <String, dynamic>{});
    expect(() => AiProxyService(appwrite).generateDoctorSummary(), throwsStateError);
  });

  test('checkIn returns the reply', () async {
    final appwrite = MockAppwriteService();
    when(() => appwrite.executeJson('aiProxy', {'feature': 'checkIn', 'message': 'I slept badly.'}))
        .thenAnswer((_) async => {'reply': 'Thank you for telling me.', 'provider': 'openrouter'});
    expect(await AiProxyService(appwrite).checkIn('I slept badly.'), 'Thank you for telling me.');
  });
}
```

Run — expected FAIL (file missing).

- [ ] **Step 2: Implement `EVE_MOBILE/app/lib/core/services/ai_proxy_service.dart`**

```dart
import '../constants/appwrite_ids.dart';
import 'appwrite_service.dart';

/// Client for the aiProxy Appwrite Function — the only way the app reaches
/// an AI model (EVE2_PRD §10.1). Keys never leave the server.
class AiProxyService {
  AiProxyService(this._appwrite);

  final AppwriteService _appwrite;

  Future<String> generateDoctorSummary({int days = 90}) async {
    final result = await _appwrite.executeJson(AppwriteIds.fnAiProxy, {'feature': 'doctorSummary', 'days': days});
    final summary = result['summary'] as String?;
    if (summary == null) throw StateError('aiProxy returned no summary text.');
    return summary;
  }

  Future<String> checkIn(String message) async {
    final result = await _appwrite.executeJson(AppwriteIds.fnAiProxy, {'feature': 'checkIn', 'message': message});
    final reply = result['reply'] as String?;
    if (reply == null) throw StateError('aiProxy returned no reply.');
    return reply;
  }
}
```

Run — expected `All tests passed!` (3 tests). Commit:

```bash
cd EVE_MOBILE
git add app/lib/core/services/ai_proxy_service.dart app/test/core/services/ai_proxy_service_test.dart
git commit -m "feat(app): add AiProxyService client for the aiProxy function"
```

#### N7 — `DoctorSummaryScreen` + PDF export

**Files:**
- Create: `EVE_MOBILE/app/lib/features/home/presentation/screens/doctor_summary_screen.dart`
- Test: `EVE_MOBILE/app/test/features/home/presentation/screens/doctor_summary_screen_test.dart`

**Interfaces:**
- Consumes: `pdf`/`printing` packages (in the merged pubspec per CN-1).
- Produces: `DoctorSummaryScreen`, taking `logs` and a `generateSummary` callback as constructor params (same "structure takes data via constructor" pattern Plan 1 used throughout, so this screen is independently testable without touching Appwrite or any AI provider).

- [ ] **Step 1: Write the failing tests**

Create `EVE_MOBILE/app/test/features/home/presentation/screens/doctor_summary_screen_test.dart`:

```dart
// EVE_MOBILE/app/test/features/home/presentation/screens/doctor_summary_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/home/presentation/screens/doctor_summary_screen.dart';

void main() {
  testWidgets('DoctorSummaryScreen generates and displays a summary, then shows the export button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DoctorSummaryScreen(
        logs: const [
          {'date': '2026-03-04', 'symptoms': ['cramps']},
        ],
        generateSummary: (logs) async => 'Overview: mild cramps recorded once.',
      ),
    ));

    expect(find.text('Generate Summary'), findsOneWidget);
    await tester.tap(find.byKey(const Key('generate-summary-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Overview: mild cramps recorded once.'), findsOneWidget);
    expect(find.byKey(const Key('export-pdf-button')), findsOneWidget);
  });

  testWidgets('DoctorSummaryScreen disables the button and explains when there are no logs', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DoctorSummaryScreen(logs: const [], generateSummary: (logs) async => ''),
    ));

    final button = tester.widget<ElevatedButton>(find.byKey(const Key('generate-summary-button')));
    expect(button.onPressed, isNull);
    expect(find.text('No logs to summarize yet'), findsOneWidget);
  });

  testWidgets('DoctorSummaryScreen shows an error message when generation fails', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DoctorSummaryScreen(
        logs: const [
          {'date': '2026-03-04'},
        ],
        generateSummary: (logs) async => throw Exception('network error'),
      ),
    ));

    await tester.tap(find.byKey(const Key('generate-summary-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('summary-error-text')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/home/presentation/screens/doctor_summary_screen_test.dart
```

Expected: FAIL — `doctor_summary_screen.dart` doesn't exist.

- [ ] **Step 3: Implement `DoctorSummaryScreen`**

Create `EVE_MOBILE/app/lib/features/home/presentation/screens/doctor_summary_screen.dart`:

```dart
// EVE_MOBILE/app/lib/features/home/presentation/screens/doctor_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DoctorSummaryScreen extends StatefulWidget {
  const DoctorSummaryScreen({super.key, required this.logs, required this.generateSummary});

  final List<Map<String, dynamic>> logs;
  final Future<String> Function(List<Map<String, dynamic>> logs) generateSummary;

  @override
  State<DoctorSummaryScreen> createState() => _DoctorSummaryScreenState();
}

class _DoctorSummaryScreenState extends State<DoctorSummaryScreen> {
  String? _summary;
  String? _error;
  bool _loading = false;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await widget.generateSummary(widget.logs);
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not generate the summary. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportPdf() async {
    final summary = _summary;
    if (summary == null) return;

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('EVE Doctor-Ready Summary', style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Text(summary),
            ],
          ),
        ),
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'eve-doctor-summary.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor-Ready Summary')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_summary == null && !_loading)
              ElevatedButton(
                key: const Key('generate-summary-button'),
                onPressed: widget.logs.isEmpty ? null : _generate,
                child: Text(widget.logs.isEmpty ? 'No logs to summarize yet' : 'Generate Summary'),
              ),
            if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            if (_error != null)
              Text(_error!, key: const Key('summary-error-text'), style: const TextStyle(color: Colors.red)),
            if (_summary != null) ...[
              Expanded(child: SingleChildScrollView(child: Text(_summary!, key: const Key('summary-text')))),
              const SizedBox(height: 12),
              ElevatedButton(
                key: const Key('export-pdf-button'),
                onPressed: _exportPdf,
                child: const Text('Export as PDF'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/home/presentation/screens/doctor_summary_screen_test.dart
```

Expected: `All tests passed!` (3 tests).

- [ ] **Step 5: Commit**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE"
git add app/lib/features/home/presentation/screens/doctor_summary_screen.dart app/test/features/home/presentation/screens/doctor_summary_screen_test.dart
git commit -m "feat: add DoctorSummaryScreen with PDF export"
```

#### N8 — Home entry point + `/doctor-summary` route wiring

**Files:**
- Modify: `EVE_MOBILE/app/lib/features/home/presentation/screens/home_screen.dart`
- Modify: `EVE_MOBILE/app/test/features/home/presentation/screens/home_screen_test.dart`
- Modify: `EVE_MOBILE/app/lib/core/router/app_router.dart`
- Modify: `EVE_MOBILE/app/test/core/router/app_router_test.dart`

**Interfaces:**
- Consumes: `HomeScreen` (Plan 1 Task 22), `logsProvider`, `currentUidProvider`, `appwriteServiceProvider` (M16 / Plan 2 Task 8), `DoctorSummaryScreen` (N7), `AiProxyService` (N6).
- Produces: a reachable `/doctor-summary` route from a real Home-screen affordance. The screen receives her logs only to decide whether there is anything to summarize; the server reads the logs it summarizes itself (N5).

- [ ] **Step 1: Write the failing test for the new Home affordance**

Add to `EVE_MOBILE/app/test/features/home/presentation/screens/home_screen_test.dart`:

```dart
  testWidgets('HomeScreen shows a doctor summary entry point that invokes onNavigateDoctorSummary', (tester) async {
    var tapped = false;

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(onNavigateDoctorSummary: () => tapped = true),
    ));

    await tester.tap(find.byKey(const Key('home-doctor-summary-button')));
    expect(tapped, isTrue);
  });
```

Run: `flutter test test/features/home/presentation/screens/home_screen_test.dart`
Expected: FAIL — `The named parameter 'onNavigateDoctorSummary' isn't defined.`

- [ ] **Step 2: Add the affordance to `HomeScreen`**

In `EVE_MOBILE/app/lib/features/home/presentation/screens/home_screen.dart`, add the constructor param and field:

```dart
    this.onNavigateLog,
    this.onNavigateDoctorSummary,
  });

  final String greetingName;
  final String phaseBadge;
  final List<BentoCardData> bentoCards;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateChat;
  final VoidCallback? onNavigateLog;
  final VoidCallback? onNavigateDoctorSummary;
```

Replace the header `Row` (greeting + phase badge Chip) so the badge sits beside a new icon button:

```dart
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back, ${widget.greetingName}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    const Text('Current status overview', style: TextStyle(color: Color(0xFF666666))),
                  ],
                ),
                Row(
                  children: [
                    Chip(label: Text(widget.phaseBadge)),
                    IconButton(
                      key: const Key('home-doctor-summary-button'),
                      icon: const Icon(Icons.summarize_outlined),
                      tooltip: 'Doctor-Ready Summary',
                      onPressed: widget.onNavigateDoctorSummary,
                    ),
                  ],
                ),
              ],
            ),
```

Run the Home screen test file — expected `All tests passed!` (the original 3 plus this one).

- [ ] **Step 3: Wire the route and the Home entry point**

In `EVE_MOBILE/app/lib/core/router/app_router.dart`, add `onNavigateDoctorSummary: () => context.go('/doctor-summary'),` to both `HomeScreen(...)` constructions in the `/home` route (`data:` and `error:` cases from M16), and add:

```dart
    GoRoute(
      path: '/doctor-summary',
      name: 'doctor-summary',
      builder: (context, state) => Consumer(builder: (context, ref, _) {
        final uid = ref.watch(currentUidProvider);
        if (uid == null) return const Scaffold(body: Center(child: Text('Please sign in to create a summary.')));
        return ref.watch(logsProvider(uid)).when(
              data: (logs) => DoctorSummaryScreen(
                logs: [for (final log in logs) log.toRow()],
                generateSummary: (_) => AiProxyService(ref.read(appwriteServiceProvider)).generateDoctorSummary(),
              ),
              loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
              error: (_, __) => const Scaffold(body: Center(child: Text('Your logs could not be loaded.'))),
            );
      }),
    ),
```

Imports: `package:eve_app/core/services/ai_proxy_service.dart`, `package:eve_app/features/home/presentation/screens/doctor_summary_screen.dart`.

- [ ] **Step 4: Router test**

Add `'/doctor-summary'` to `_expectedRoutePaths` (the route-set test asserts the exact set), then add to `EVE_MOBILE/app/test/core/router/app_router_test.dart`:

```dart
  testWidgets('Doctor summary is disabled with an explanation when she has no logs', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWith((ref) => 'u1'),
        logRepositoryProvider.overrideWithValue(FakeLogRepository()),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ));
    appRouter.go('/doctor-summary');
    await tester.pumpAndSettle();
    expect(find.text('No logs to summarize yet'), findsOneWidget);
  });
```

- [ ] **Step 5: Run the full suite and static analysis**

```bash
cd EVE_MOBILE/app
flutter test
flutter analyze
```

Expected: all tests pass; `No issues found!`.

- [ ] **Step 6: Commit**

```bash
cd EVE_MOBILE
git add app/lib/features/home/presentation/screens/home_screen.dart app/test/features/home/presentation/screens/home_screen_test.dart app/lib/core/router/app_router.dart app/test/core/router/app_router_test.dart
git commit -m "feat(app): wire doctor-summary entry point and route into Home"
```

**Demo (whole of M19):** against local Appwrite with real `GEMINI_API_KEY`/`OPENROUTER_*` variables on `aiProxy`, add 2–3 logs from the Log screen, tap the summary icon on Home, tap "Generate Summary" — a model-written summary appears that references only the logged symptoms/moods, names no diagnosis, and ends by recommending she discuss it with her doctor. The `aiProxy` execution log shows which provider answered. Tap "Export as PDF" — the OS share sheet opens with a well-formed PDF. Then set `GEMINI_MODEL` to an invalid ID, redeploy, generate again — the summary still appears and the log shows the OpenRouter fallback.

### M20 — Production run and final polish

Run: **Plan 3 Task 10** (Cloud project `eve-prod`, push tables + functions, function variables, documented run commands).

**Demo:** `flutter run --release --dart-define=APPWRITE_ENDPOINT=https://<REGION>.cloud.appwrite.io/v1 --dart-define=APPWRITE_PROJECT_ID=eve-prod` on a real Android device — sign in with Google, complete onboarding (rows land in Appwrite Cloud), invite a partner and join from a second device, exchange chat messages live, log a difficult day and watch the partner nudge arrive, receive a scheduled reminder, and export a doctor summary — with no local Appwrite running and no GCP project anywhere.

---

## Self-Review

**1. Spec coverage.**
- Every task in Plans 1, 2, 3, 5, 6 and 7 is assigned to a milestone in dependency order: Appwrite project → scaffold → client migration → state → mascot → router → screens → router wiring → data layer → sign-in + persistence → real-data wiring → notifications → partner consent → doctor summary → production.
- No GCP anywhere: Firebase packages and files are removed in M2, Firestore rules are replaced by row permissions + server-only tables (Plan 5, schema-tested), Cloud Functions by Appwrite Functions, FCM + Cloud Scheduler by Appwrite native push + cron, Vertex by Gemini REST with OpenRouter fallback.
- Gaps the Firebase-era plans left open and this revision closes: sign-in was never actually performed (M14a), logs could not be created from the app (M16 Step 8), the partner had no way to join (M18 N9, backed by Plan 7 Task 3), and the client could forge chat sender identity (Plan 7 Task 4 — sends go through a function).
- The doctor-ready summary export (EVE2_PRD §11) is built end to end in M19: server-side log read, Gemini→OpenRouter call, client service, screen, PDF export, Home entry point.

**2. Placeholder scan.** No TBD/"implement later" in any new task. Deliberately manual boundaries are stated as such: OAuth consent, push delivery on a device, and live AI output are verified by hand against local Appwrite because no unit test can exercise them; everything around them is unit-tested with fakes/mocks.

**3. Type consistency.** `AppwriteService`/`AppwriteIds`/`currentUidProvider`/`appwriteServiceProvider` (Plan 2 Task 8) are used verbatim by M14/M16–M19. Repository interfaces and fakes come from Plan 2 Task 9 and are overridden by name (`onboardingRepositoryProvider`, `homeRepositoryProvider`, `chatRepositoryProvider`, `logRepositoryProvider`). Function request bodies match their handlers: `partnerInvites` `{action, relationshipType|inviteCode}`, `sendChatMessage` `{threadUserId, text}`, `aiProxy` `{feature, message|days}`. Stored vocabularies match design-spec §10 through `onboarding_value_mappers.dart`. Plan 1 screen constructor names used in the router (`HomeScreen`, `ChatScreen`, `LogScreen.onNewEntry`, `CompletionScreen.onContinue`, `AuthScreen`) match Plan 1 Tasks 3, 21–24.

**Known V0 gaps, stated rather than hidden:** reminder times are fixed UTC slots (no per-user time zone); iOS receives push only while the app is alive (no APNs); revoking a partner category takes effect on the next recompute (seconds), not instantaneously; there is no unlink flow and no partner-side dashboard for `partner_views` beyond the shared chat.

---

## Execution Handoff

Plan complete and saved to `EVE_MOBILE/plans/04-build-roadmap.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
