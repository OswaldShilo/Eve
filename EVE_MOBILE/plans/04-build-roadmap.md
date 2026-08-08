# EVE Mobile — Build Roadmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sequence every task from `01-core-workflow.md`, `02-system-architecture.md`, `03-tech-stack.md`, `05-data-model-firestore.md`, `06-mascot-rig-plan.md`, and `07-partner-mode-consent.md` into one practical, incrementally-demoable build order; resolve the file-ownership collisions those six plans created by being drafted in parallel; and fill three gaps no sub-plan covers — wiring the real onboarding/Home/Chat/Log screens into the actual router (Plan 1 built them as standalone constructor-driven widgets and explicitly never touched `app_router.dart`), persisting the completed onboarding survey to Firestore, and the doctor-ready AI summary + PDF export feature (in V0 scope per `EVE2_PRD.md` §11, assigned to no sub-plan).

**Architecture:** 21 milestones (M0–M20), each ending in something you can run and see. Milestones reference other plans' tasks by number (`Plan 2 Task 3`) rather than repeating their content — go to that file for the real code. Milestones that do new work neither plan wrote are spelled out here in full, in the same TDD, no-placeholders format as the other six plans.

**Tech Stack:** Flutter (Dart) + Riverpod + go_router; Firebase (Auth, Firestore, Cloud Functions/TypeScript, `firebase_messaging`, Cloud Scheduler); Gemini via a Cloud Functions proxy; `pdf` + `printing` for client-side PDF export. Exactly as locked in `00-design-spec.md` §2 — nothing in this plan changes that.

## Global Constraints

- Package name is `eve_app` everywhere — Dart imports, `pubspec.yaml`'s `name:` field, and every plan's assumed `package:eve_app/...` prefix. Never `eve` or `eve_mobile` (see Coordination Note CN-1 — one of the six plans drifted from this).
- The canonical Cloud Functions project scaffold (`functions/package.json`, `tsconfig.json`, `jest.config.js`, `src/index.ts`) is created exactly once, by Plan 3 Task 6. Two other plans independently wrote their own competing versions of these same files — see CN-2 for the exact skip/merge instructions before executing those tasks.
- `firestore.rules`/`firebase.json` are each created exactly once and merged into thereafter, never overwritten — see CN-2.
- `core/services/firebase_service.dart` is the merged file defined in CN-3, combining Plan 2 Task 3's class and Plan 3 Task 11's emulator-aware initializer — not either plan's file verbatim.
- Every new task in this plan (marked `N#` or `R1`) follows the same TDD discipline as the six sub-plans: failing test first, verified failure, minimal implementation, verified pass, commit. No placeholders.
- Formal, warm, no-emoji copy voice (design-spec §2) applies to any new user-facing string introduced here (the doctor-summary screen).
- Never a diagnosis claim, ever — applies directly to the doctor-summary prompt in M19.

---

## Cross-Plan Coordination Notes

Read this section before executing any milestone that references it. These are the real conflicts found after all six sub-plans were written independently; each one is a place where two or three plans create or modify the same file with incompatible content. Apply the instruction here in place of the conflicting plan step(s) — the six plan files are left as-written (each is individually correct and internally consistent), only the *execution order and merge behavior* changes.

### CN-1 — `app/pubspec.yaml` (Plan 2 Task 1, Plan 5 Task 2, Plan 3 Task 5)

Three plans write this file. Plan 2 Task 1 creates it first with a minimal dependency set and `name: eve_app`. Plan 5 Task 2 Step 2 creates a second, dependency-free version, also `name: eve_app`, explicitly flagged in that plan as "merge, do not overwrite, if both exist." Plan 3 Task 5 creates a third, fullest version — but with `name: eve` (no `_app` suffix), which would break all ~150 `package:eve_app/...` imports across Plans 1, 2, 5, and 6 if executed literally.

**Instruction:** when you reach Plan 3 Task 5 (in M1 below), do not use its literal `pubspec.yaml` content. Use this merged version instead — identical to Plan 3 Task 5's dependency list and versions (the newest, most complete set) with three changes: `name: eve_app` (not `eve`), `test: ^1.25.0` added to `dev_dependencies` (Plan 5's pure-Dart model tests import `package:test/test.dart`), and `fake_cloud_firestore: ^3.1.0` added to `dev_dependencies` (needed starting M14 by this plan's own new tasks, added now so no later task has to touch this file a fourth time):

```yaml
name: eve_app
description: EVE — AI-powered adaptive health companion (Hack26 build).
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: '^3.9.0'
  flutter: '>=3.35.0'

dependencies:
  flutter:
    sdk: flutter

  flutter_riverpod: ^3.0.0
  go_router: ^15.1.2
  google_fonts: ^6.2.1
  firebase_core: ^4.6.0
  firebase_auth: ^6.3.0
  cloud_firestore: ^6.2.0
  firebase_messaging: ^16.4.3
  cloud_functions: ^6.0.0
  google_sign_in: ^7.1.0
  flutter_local_notifications: ^19.1.0
  pdf: ^3.11.3
  printing: ^5.14.2
  intl: ^0.20.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  mocktail: ^1.0.4
  test: ^1.25.0
  fake_cloud_firestore: ^3.1.0

flutter:
  uses-material-design: true
```

When you reach Plan 5 Task 2 (in M13 below), **skip Step 2 entirely** (do not create/overwrite `pubspec.yaml` — the merged version above already exists by then); run every other step unchanged.

### CN-2 — Cloud Functions scaffold and `firebase.json` (Plan 3 Task 1/6, Plan 5 Task 3/4, Plan 7 Task 1)

Three plans independently scaffold the Cloud Functions project. Plan 3 Task 6 creates `functions/package.json` (`firebase-admin ^13.0.0`, `firebase-functions ^6.1.0`), `tsconfig.json`, `jest.config.js`, and `src/index.ts`. Plan 7 Task 1 creates its own competing versions of all four files (older `firebase-admin ^12.1.0`/`firebase-functions ^5.0.1`, a self-starting `firebase emulators:exec` test script instead of a plain `jest` script). Plan 5 Task 3 and Plan 7 Task 1 also both create `firebase.json` independently of Plan 3 Task 1's version (Plan 7 explicitly flags "merge the `emulators` block in rather than overwriting" as its own fallback instruction).

**Instruction:** Plan 3 Task 6 is canonical — it runs first (M1 below) and its `package.json`/`tsconfig.json`/`jest.config.js`/`src/index.ts` are never re-created.

- When you reach **Plan 5 Task 3** (M13): its `firebase.json` step must *merge*, not overwrite — take the file Plan 3 Task 1 already created and add Plan 5's `auth`/`ui` emulator blocks and `firestore`/`functions` ports (they're already present from Plan 3 Task 1, so in practice this is a no-op verification, not an edit). Its `jest.config.js` "Test:" listing is also a no-op — Plan 3 Task 6's `jest.config.js` (`roots: ['<rootDir>/test']`) already matches where Plan 5's rules tests live.
- When you reach **Plan 5 Task 4** (M13): its `src/index.ts` step is a **modify**, not a create — append `export { onUserCreate } from './onUserCreate';` to the existing file rather than replacing it. While there, fix the stale comment above the exports block (it currently says `// - onUserCreate: implemented in Plan 2` — correct it to `// - onUserCreate: implemented in Plan 5`).
- When you reach **Plan 7 Task 1** (M18): **skip Steps 1, 2, 3, and 6** (`package.json`, `tsconfig.json`, `jest.config.js`, `src/index.ts` — all four already exist from Plan 3 Task 6). Run **Steps 4, 5, 7, 8, 9** unchanged (`emulatorEnv.ts`, `testUtils.ts` are new files; the `firebase.json` step is a no-op merge like above since Plan 3 Task 1 already has every port Plan 7 needs; installing deps and committing only touches the genuinely new files). Wherever a later Plan 7 task says "create/modify `src/index.ts`," treat it as append, matching Plan 3 Task 6's existing file.
- Standardize on Plan 3 Task 6's `"test": "jest"` script (not Plan 7's self-starting `firebase emulators:exec` variant) for the whole `functions/` project. This means every task in M13/M17/M18 whose tests need the Firestore/Auth emulator (Plan 5 Task 3, Plan 5 Task 4, Plan 7 Tasks 2–6) requires `firebase emulators:start --only firestore,auth,functions` running in a separate terminal before `npm test` — call this out explicitly in each of those milestones below.

### CN-3 — `core/services/firebase_service.dart` and Firebase bootstrap (Plan 2 Task 3, Plan 2 Task 7, Plan 3 Task 11)

Plan 2 Task 3 defines `firebase_service.dart` as a `FirebaseService` class (`.auth`/`.firestore` getters, DI-friendly for mocktail tests) with a `static Future<void> initializeApp()` bootstrap method that Plan 2 Task 7 wires into `main.dart`. Plan 3 Task 11 independently defines the *same file path* as a completely different shape: a top-level `initializeFirebase()` function that also does emulator-vs-production switching via a new `AppEnv` class, with its own `main.dart` wiring. Both are needed — the class for DI in tests/repositories, the function for real Firebase bootstrap with emulator support — but they can't both "create" the same file from scratch.

**Instruction:** execute Plan 2 Task 3 first (M2 below) — its `FirebaseService` class and its 2 tests stand as written, except **drop the `static Future<void> initializeApp()` method** (superseded below; Task 3's own tests never exercise it, so removing it doesn't break anything). Later, when you reach Plan 3 Task 11 (also M2), **do not create a second `firebase_service.dart`** — instead append `initializeFirebase()` to the existing file, and create `app_env.dart` as Plan 3 Task 11 Step 1 describes. The merged file:

```dart
// EVE_MOBILE/app/lib/core/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import '../config/app_env.dart';

/// Thin, testable wrapper around the two Firebase SDKs this app's core
/// layer needs directly: Auth and Firestore. Accepts optional
/// `auth`/`firestore` instances so tests can inject mocks instead of
/// touching the real Firebase SDKs (Plan 2 Task 3's original two tests
/// pass unchanged against this class).
class FirebaseService {
  FirebaseService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
}

/// Initializes Firebase and, when [AppEnv.useEmulator] is true, redirects
/// Auth/Firestore/Functions to the local emulator suite. Must be awaited
/// before any other code touches FirebaseAuth.instance,
/// FirebaseFirestore.instance, FirebaseFunctions.instance, or constructs a
/// [FirebaseService] — including `core/services/ai_proxy_service.dart`'s
/// `FirebaseFunctions.instance.httpsCallable('aiProxy')` call (M19).
Future<void> initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (AppEnv.useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(AppEnv.emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(AppEnv.emulatorHost, 8080);
    FirebaseFunctions.instance.useFunctionsEmulator(AppEnv.emulatorHost, 5001);
  }
}
```

And **when you reach Plan 2 Task 7 Step 4** (M6 below), use `initializeFirebase()` in `main.dart`, not `FirebaseService.initializeApp()`:

```dart
// EVE_MOBILE/app/lib/main.dart
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

This requires Plan 3 Task 2 (which generates `firebase_options.dart` via `flutterfire configure`) and Plan 3 Task 11 to both have already run before Plan 2 Task 7 — M2 sequences them in that order for exactly this reason.

### CN-4 — FCM device token Firestore path (ratified in R1, M13)

Plan 3 Task 9 needs a place to store each device's FCM token but design-spec §10 never defined one; Plan 3 self-flagged `users/{uid}/fcmTokens/{token}` as "flagged for Plan 5 to ratify or relocate." Task R1 below ratifies it: adds the path constant, the security rule, and their tests.

---

## Milestones

Each milestone lists the exact tasks to run (by plan and number) and what "done" looks like. Where a milestone does new work, the full task follows immediately after in the same format as the six sub-plans.

### M0 — Firebase project and native platform prep

Run: **Plan 3 Tasks 1–4** (`firebase.json`/`.firebaserc` init, Auth providers + `firebase_options.dart`, Android SHA-1, iOS URL scheme).

**Demo:** `firebase projects:list` shows the `eve-hack26` project; `firebase emulators:start` boots cleanly with no functions/rules deployed yet.

### M1 — Flutter app scaffold and dependency set (apply CN-1)

Run: **Plan 2 Task 1** (`flutter create`, canonical folder tree, temporary `main.dart`/`app.dart`), then **Plan 3 Task 5** using CN-1's merged `pubspec.yaml` in place of its literal content.

**Demo:** `flutter analyze` reports no issues; `flutter run` boots to the temporary `Scaffold(body: Center(child: Text('EVE')))`.

### M2 — Core services: paths, theme, Firebase bootstrap (apply CN-3)

Run: **Plan 2 Task 2** (`FirestorePaths`), **Plan 2 Task 3** (`FirebaseService` class, per CN-3's instruction to drop `initializeApp()`), **Plan 2 Task 4** (`EveTheme`), then **Plan 3 Task 11** (`initializeFirebase()` + `AppEnv`, merged into the same file per CN-3).

**Demo:** `flutter test test/core/` passes (paths, theme, service tests); no router or screens exist yet, this milestone is unit-test-only.

### M3 — Onboarding state and module-activation system

Run: **Plan 2 Task 5** (`OnboardingState`/`OnboardingNotifier`/`onboardingStateProvider`), **Plan 2 Task 6** (`Module`/`LifeStage`/`lifeStageFromSurveyValue`/`activeModules`).

**Demo:** `flutter test test/features/onboarding/domain/ test/features/home/domain/` passes (13 tests: 5 + 8).

### M4 — Mascot rig core render + idle physics

Run: **Plan 6 Tasks 1–4** (`EveRigGeometry`, `EveEmotion` pose table, static `EveMascotPainter`, idle float + blink `AnimationController`).

**Demo:** drop a scratch `EveMascotPainter` into a throwaway `CustomPaint` in `main.dart` temporarily, `flutter run`, watch it idle-float and blink. Revert the scratch change before M5.

### M5 — Mascot rig polish: transitions, peel growth, public widget, goldens

Run: **Plan 6 Tasks 5–8** (emotion-transition lerp, peel-percent growth animation, public `EveMascot` widget, golden tests).

**Demo:** `flutter test test/features/mascot/` passes including goldens; a scratch screen cycling `EveMascot(emotion: ..., peelPercent: ...)` through all 6 emotions and 0/50/100 peel percentages shows smooth transitions.

### M6 — Router shell (apply CN-3 continuation)

Run: **Plan 2 Task 7**, with Step 4's `main.dart` content replaced by CN-3's version (`initializeFirebase()` instead of `FirebaseService.initializeApp()`).

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

### M13 — Data layer: Firestore schema, rules, `onUserCreate` (apply CN-1, CN-2, CN-4)

Run: **Plan 5 Task 1** (TypeScript types), **Plan 5 Task 2** (Dart mirror models, skipping Step 2 per CN-1), **Plan 5 Task 3** (`firestore.rules` + rules tests, merging `firebase.json` per CN-2 — start `firebase emulators:start --only firestore,auth` in a separate terminal first, per CN-2's test-script standardization), **Plan 5 Task 4** (`onUserCreate`, appending to `index.ts` per CN-2), then **Task R1** below.

#### Task R1 (ratification): FCM device token Firestore path

**Files:**
- Modify: `EVE_MOBILE/app/lib/core/constants/firestore_paths.dart`
- Modify: `EVE_MOBILE/app/test/core/constants/firestore_paths_test.dart`
- Modify: `EVE_MOBILE/firestore.rules`
- Modify: `EVE_MOBILE/functions/test/rules/firestore.rules.test.ts`

**Interfaces:**
- Consumes: `FirestorePaths` (Plan 2 Task 2), the real `firestore.rules` (Plan 5 Task 3, must exist before this task runs).
- Produces: `FirestorePaths.fcmTokensCollection(uid)` / `.fcmToken(uid, token)`, and an owner-only rule for `users/{uid}/fcmTokens/{token}` — the exact path Plan 3 Task 9 (M17) writes to and self-flagged as unratified.

- [ ] **Step 1: Write the failing Dart test**

Add to `EVE_MOBILE/app/test/core/constants/firestore_paths_test.dart` (inside the existing `group('FirestorePaths')`):

```dart
    test('fcmTokensCollection returns users/{uid}/fcmTokens', () {
      expect(FirestorePaths.fcmTokensCollection('u1'), 'users/u1/fcmTokens');
    });

    test('fcmToken returns users/{uid}/fcmTokens/{token}', () {
      expect(FirestorePaths.fcmToken('u1', 'tok1'), 'users/u1/fcmTokens/tok1');
    });
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/core/constants/firestore_paths_test.dart
```

Expected: FAIL — `The method 'fcmTokensCollection' isn't defined for the class 'FirestorePaths'`.

- [ ] **Step 3: Implement the two new path builders**

Add to `EVE_MOBILE/app/lib/core/constants/firestore_paths.dart`, inside the `FirestorePaths` class:

```dart
  static String fcmTokensCollection(String uid) => 'users/$uid/fcmTokens';

  static String fcmToken(String uid, String token) =>
      'users/$uid/fcmTokens/$token';
```

- [ ] **Step 4: Run to verify it passes**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/core/constants/firestore_paths_test.dart
```

Expected: `All tests passed!` (16 tests — 14 from Plan 2 Task 2 plus these 2).

- [ ] **Step 5: Write the failing rules test**

Add to `EVE_MOBILE/functions/test/rules/firestore.rules.test.ts` (same file/pattern as Plan 5 Task 3's other rule tests):

```ts
test('(g) only the owner can read or write her own FCM tokens; nobody else can', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(
    setDoc(doc(alice, 'users/alice/fcmTokens/tok1'), { createdAt: serverTimestamp() }),
  );
  await assertSucceeds(getDoc(doc(alice, 'users/alice/fcmTokens/tok1')));

  await seedPartnerLink('alice', 'bob');
  const bob = testEnv.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(bob, 'users/alice/fcmTokens/tok1')));
  await assertFails(setDoc(doc(bob, 'users/alice/fcmTokens/tok2'), { createdAt: serverTimestamp() }));
});
```

- [ ] **Step 6: Run to verify it fails**

```bash
cd EVE_MOBILE/functions && npm test
```

Expected: FAIL on test (g) — `firestore.rules` has no `fcmTokens` match block yet, so the default (no matching rule → deny) makes even Alice's own read/write fail.

- [ ] **Step 7: Add the rule**

Add to `EVE_MOBILE/firestore.rules`, alongside the other `users/{uid}/...` owner-only blocks:

```
    // users/{uid}/fcmTokens/{token} — device push tokens. Owner only,
    // never shared with a partner. Ratified in 04-build-roadmap.md Task R1
    // (Plan 3 Task 9 self-flagged this path as unratified by design-spec §10).
    match /users/{uid}/fcmTokens/{token} {
      allow read, write: if isOwner(uid);
    }
```

- [ ] **Step 8: Run to verify it passes**

```bash
cd EVE_MOBILE/functions && npm test
```

Expected: all rules tests pass, including (g).

- [ ] **Step 9: Commit**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE"
git add app/lib/core/constants/firestore_paths.dart app/test/core/constants/firestore_paths_test.dart firestore.rules functions/test/rules/firestore.rules.test.ts
git commit -m "feat: ratify users/{uid}/fcmTokens path and security rule"
```

**Demo (whole of M13):** create a new user against the Auth emulator; the Firestore emulator UI shows the full doc set (`users/{uid}`, `lifeStageProfile/current`, all four `preferences/*`, `partnerLink/current`, `partnerPermissions/current`, `partnerView/current`) appear in a single batch. `npm test` in `functions/` passes every rules test including R1's. Manually attempting to read another seeded user's `logs` subcollection from a different authenticated context is denied.

### M14 — Persist onboarding to Firestore on completion (NEW)

Plan 1's 20 onboarding screens only ever write to the in-memory `onboardingStateProvider` — nothing in Plans 1, 2, or 5 ever saves that state to Firestore. This task adds the missing write, triggered when the user taps "Enter EVE" on the Completion screen.

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/data/onboarding_repository.dart`
- Create: `EVE_MOBILE/app/lib/core/providers/firebase_providers.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/data/onboarding_repository_test.dart`
- Test: `EVE_MOBILE/app/test/core/providers/firebase_providers_test.dart`
- Modify: `EVE_MOBILE/app/lib/core/router/app_router.dart`

**Interfaces:**
- Consumes: `OnboardingState` (Plan 2 Task 5), `FirestorePaths` (Plan 2 Task 2, extended by R1), the Dart mirror model classes `LifeStageProfile`/`CycleLifeStageProfile`/`PregnantLifeStageProfile`/`SimplifiedLifeStageProfile`/`EmptyLifeStageProfile`, `GoalsPreferences`, `NotificationPreferences`, `AiScopePreferences`, `ThemePreferences`, `PartnerLink`, `PartnerPermissions` (all Plan 5 Task 2).
- Produces: `OnboardingRepository.saveOnboarding(uid, state)`, `firestoreProvider`/`firebaseAuthProvider`/`currentUidProvider` (consumed by N2/N3/N4/N7 in M16/M19 too).

**Known, deliberately unaddressed casing mismatch:** several onboarding screens capture literal human-readable labels (`state.highRisk` is `'Yes'`/`'No'`, `state.dueMethod` is `'Expected due date'`/etc., `state.flow` is `'Light'`/`'Moderate'`/`'Heavy'`) where Plan 5's Dart model doc-comments describe lowercase/camelCase enum-like values (`'light' | 'moderate' | 'heavy'`). Since these fields are untyped `String`s at the Firestore layer with no server-side validation, this is a data-quality inconsistency, not a functional bug — flagged here rather than silently redesigning either plan's already-written, already-tested code.

- [ ] **Step 1: Write the failing test for the shared Firebase providers**

Create `EVE_MOBILE/app/test/core/providers/firebase_providers_test.dart`:

```dart
// EVE_MOBILE/app/test/core/providers/firebase_providers_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eve_app/core/providers/firebase_providers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('firestoreProvider can be overridden with a fake instance', () {
    final fake = FakeFirebaseFirestore();
    final container = ProviderContainer(overrides: [firestoreProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    expect(container.read(firestoreProvider), same(fake));
    expect(container.read(firestoreProvider), isA<FirebaseFirestore>());
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/core/providers/firebase_providers_test.dart
```

Expected: FAIL — `firebase_providers.dart` doesn't exist.

- [ ] **Step 3: Implement the shared providers**

Create `EVE_MOBILE/app/lib/core/providers/firebase_providers.dart`:

```dart
// EVE_MOBILE/app/lib/core/providers/firebase_providers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overridable in tests with `firestoreProvider.overrideWithValue(fake)`
/// (`FakeFirebaseFirestore` from `package:fake_cloud_firestore`) instead of
/// touching the real Firebase SDK.
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// Null before sign-in or in any test that doesn't override
/// [firebaseAuthProvider] with a signed-in mock.
final currentUidProvider = Provider<String?>((ref) => ref.watch(firebaseAuthProvider).currentUser?.uid);
```

- [ ] **Step 4: Run to verify it passes**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/core/providers/firebase_providers_test.dart
```

Expected: `All tests passed!` (1 test).

- [ ] **Step 5: Write the failing test for `OnboardingRepository`**

Create `EVE_MOBILE/app/test/features/onboarding/data/onboarding_repository_test.dart`:

```dart
// EVE_MOBILE/app/test/features/onboarding/data/onboarding_repository_test.dart
import 'package:eve_app/core/constants/firestore_paths.dart';
import 'package:eve_app/features/onboarding/data/onboarding_repository.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/shared/models/life_stage_profile.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnboardingRepository.saveOnboarding', () {
    test('writes a full cycle-branch profile without partner docs when partnerInvite is false', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = OnboardingRepository(firestore: firestore);
      const state = OnboardingState(
        name: 'Asha',
        age: '29',
        height: '165',
        weight: '58',
        country: 'India',
        lifeStage: 'cycle',
        cycleLength: '28',
        periodLength: '5',
        flow: 'Moderate',
        cycleSymptoms: ['cramps'],
        cycleGoals: ['betterNutrition'],
        nutritionDiet: 'vegan',
        foodAllergies: 'peanuts',
        cuisines: ['indian'],
        workouts: ['yoga'],
        notifications: ['morningReminder'],
        aiScope: ['nutrition'],
        theme: 'dark',
        partnerInvite: false,
      );

      await repo.saveOnboarding('uid-1', state);

      final userDoc = await firestore.doc(FirestorePaths.userDoc('uid-1')).get();
      expect(userDoc.data()!['name'], 'Asha');
      expect(userDoc.data()!['age'], 29);

      final lifeStageDoc = await firestore.doc(FirestorePaths.lifeStageProfile('uid-1')).get();
      final lifeStageProfile = LifeStageProfile.fromMap(lifeStageDoc.data()!);
      expect(lifeStageProfile, isA<CycleLifeStageProfile>());
      expect((lifeStageProfile as CycleLifeStageProfile).cycleLength, 28);

      final goalsDoc = await firestore.doc(FirestorePaths.goalsPreferences('uid-1')).get();
      expect(goalsDoc.data()!['selectedGoals'], ['betterNutrition']);

      final partnerLinkDoc = await firestore.doc(FirestorePaths.partnerLink('uid-1')).get();
      expect(partnerLinkDoc.exists, isFalse);
    });

    test('writes partnerLink and partnerPermissions when partnerInvite is true', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = OnboardingRepository(firestore: firestore);
      const state = OnboardingState(
        lifeStage: 'pregnant',
        dueDate: '2026-06-01',
        dueMethod: 'Expected due date',
        highRisk: 'No',
        pregnancyType: 'Single',
        prenatalVitamins: 'Yes',
        partnerInvite: true,
        partnerRelation: 'Husband',
        partnerPermissions: ['Mood updates'],
        onlyApproveMaster: true,
      );

      await repo.saveOnboarding('uid-2', state);

      final lifeStageDoc = await firestore.doc(FirestorePaths.lifeStageProfile('uid-2')).get();
      final profile = LifeStageProfile.fromMap(lifeStageDoc.data()!) as PregnantLifeStageProfile;
      expect(profile.highRisk, isFalse);
      expect(profile.prenatalVitamins, isTrue);

      final partnerLinkDoc = await firestore.doc(FirestorePaths.partnerLink('uid-2')).get();
      expect(partnerLinkDoc.data()!['relationshipType'], 'Husband');
      expect(partnerLinkDoc.data()!['inviteStatus'], 'pending');

      final partnerPermsDoc = await firestore.doc(FirestorePaths.partnerPermissions('uid-2')).get();
      expect(partnerPermsDoc.data()!['approvedCategories'], ['Mood updates']);
      expect(partnerPermsDoc.data()!['onlyApproveMode'], isTrue);
    });
  });
}
```

- [ ] **Step 6: Run to verify it fails**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/onboarding/data/onboarding_repository_test.dart
```

Expected: FAIL — `onboarding_repository.dart` doesn't exist.

- [ ] **Step 7: Implement `OnboardingRepository`**

Create `EVE_MOBILE/app/lib/features/onboarding/data/onboarding_repository.dart`:

```dart
// EVE_MOBILE/app/lib/features/onboarding/data/onboarding_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eve_app/core/constants/firestore_paths.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/shared/models/life_stage_profile.dart';
import 'package:eve_app/shared/models/partner_link.dart';
import 'package:eve_app/shared/models/partner_permissions.dart';
import 'package:eve_app/shared/models/preferences.dart';

/// Persists the completed onboarding survey to Firestore. Called once, from
/// the Completion screen's `onContinue` (see 04-build-roadmap.md M14).
/// `onUserCreate` (Plan 5 Task 4) already initialized every one of these
/// docs with empty/default shells when the Auth account was created — this
/// overwrites them with the real captured values, except `users/{uid}`,
/// which is merged so `authId`/`createdAt` set by `onUserCreate` survive.
class OnboardingRepository {
  OnboardingRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Future<void> saveOnboarding(String uid, OnboardingState state) async {
    final batch = _firestore.batch();

    batch.set(
      _firestore.doc(FirestorePaths.userDoc(uid)),
      {
        'name': state.name,
        'age': int.tryParse(state.age),
        'height': num.tryParse(state.height),
        'weight': num.tryParse(state.weight),
        'country': state.country.isEmpty ? null : state.country,
        'lifeStage': state.lifeStage,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(_firestore.doc(FirestorePaths.lifeStageProfile(uid)), _lifeStageProfileFor(state).toMap());

    batch.set(
      _firestore.doc(FirestorePaths.goalsPreferences(uid)),
      GoalsPreferences(
        selectedGoals: _selectedGoalsFor(state),
        dietType: state.nutritionDiet.isEmpty ? null : state.nutritionDiet,
        foodAllergies: state.foodAllergies,
        cuisines: state.cuisines,
        workoutPreference: state.workouts,
      ).toMap(),
    );

    batch.set(
      _firestore.doc(FirestorePaths.notificationPreferences(uid)),
      NotificationPreferences(enabledReminders: state.notifications).toMap(),
    );

    batch.set(
      _firestore.doc(FirestorePaths.aiScope(uid)),
      AiScopePreferences(enabledHelpAreas: state.aiScope).toMap(),
    );

    batch.set(
      _firestore.doc(FirestorePaths.theme(uid)),
      ThemePreferences(selectedTheme: state.theme.isEmpty ? 'default' : state.theme).toMap(),
    );

    if (state.partnerInvite) {
      batch.set(
        _firestore.doc(FirestorePaths.partnerLink(uid)),
        PartnerLink(
          partnerUserId: null,
          relationshipType: state.partnerRelation.isEmpty ? null : state.partnerRelation,
          inviteStatus: 'pending',
          invitedAt: DateTime.now(),
          linkedAt: null,
        ).toMap(),
      );

      batch.set(
        _firestore.doc(FirestorePaths.partnerPermissions(uid)),
        PartnerPermissions(
          approvedCategories: state.partnerPermissions,
          onlyApproveMode: state.onlyApproveMaster,
        ).toMap(),
      );
    }

    await batch.commit();
  }

  LifeStageProfile _lifeStageProfileFor(OnboardingState state) {
    switch (state.lifeStage) {
      case 'cycle':
        return CycleLifeStageProfile(
          cycleLength: int.tryParse(state.cycleLength) ?? 28,
          periodLength: int.tryParse(state.periodLength) ?? 5,
          flow: state.flow,
          cycleSymptoms: state.cycleSymptoms,
          cycleGoals: state.cycleGoals,
          nutritionDiet: state.nutritionDiet.isEmpty ? null : state.nutritionDiet,
        );
      case 'pregnant':
        return PregnantLifeStageProfile(
          dueDate: DateTime.tryParse(state.dueDate),
          dueMethod: state.dueMethod,
          highRisk: state.highRisk == 'Yes',
          pregnancyType: state.pregnancyType,
          medications: state.medications.isEmpty ? null : state.medications,
          allergies: state.allergies.isEmpty ? null : state.allergies,
          prenatalVitamins: state.prenatalVitamins == 'Yes',
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

  List<String> _selectedGoalsFor(OnboardingState state) {
    switch (state.lifeStage) {
      case 'cycle':
      case 'conceive':
        return state.cycleGoals;
      case 'postpartum':
      case 'menopause':
        return state.simplifiedGoals;
      default:
        return const [];
    }
  }
}
```

- [ ] **Step 8: Run to verify it passes**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/onboarding/data/onboarding_repository_test.dart
```

Expected: `All tests passed!` (2 tests).

- [ ] **Step 9: Wire it into the Completion route**

Modify `EVE_MOBILE/app/lib/core/router/app_router.dart` — replace the `/onboarding/completion` `GoRoute` (added in M12 Step 3) with:

```dart
    GoRoute(
      path: '/onboarding/completion',
      name: 'onboarding-completion',
      builder: (context, state) => Consumer(
        builder: (context, ref, _) => CompletionScreen(
          onContinue: () async {
            final uid = ref.read(currentUidProvider);
            if (uid != null) {
              final onboardingState = ref.read(onboardingStateProvider);
              await OnboardingRepository(firestore: ref.read(firestoreProvider))
                  .saveOnboarding(uid, onboardingState);
            }
            if (context.mounted) context.go('/home');
          },
        ),
      ),
    ),
```

Add the two new imports this requires to the top of the file:

```dart
import 'package:eve_app/core/providers/firebase_providers.dart';
import 'package:eve_app/features/onboarding/data/onboarding_repository.dart';
```

This is glue code that touches the real Firebase SDK through `ref.read(firestoreProvider)`/`ref.read(currentUidProvider)` — it isn't unit-testable under `flutter test` without a signed-in emulator user, matching how Plan 3 Task 7 treats its own real-SDK-touching code (verified manually against the emulator, not asserted in a widget test). Verify it manually per this milestone's Demo line below.

- [ ] **Step 10: Run the full test suite**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test
flutter analyze
```

Expected: every prior test still passes; `flutter analyze` reports `No issues found!`.

- [ ] **Step 11: Commit**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE"
git add app/lib/core/providers/firebase_providers.dart app/lib/features/onboarding/data/onboarding_repository.dart app/test/core/providers/firebase_providers_test.dart app/test/features/onboarding/data/onboarding_repository_test.dart app/lib/core/router/app_router.dart
git commit -m "feat: persist completed onboarding survey to Firestore"
```

**Demo:** run against the emulator suite (`USE_FIREBASE_EMULATOR=true` per Plan 3 Task 12), sign in, walk onboarding to completion, tap "Enter EVE" — the Firestore emulator UI shows `lifeStageProfile/current`, all four `preferences/*` docs, and (if partner invite was accepted) `partnerLink/current`/`partnerPermissions/current` populated with the exact values entered.

### M15 — Home/Chat/Log structural shells

Run: **Plan 1 Tasks 22–24** (Home, Chat, Log — all structure-only/placeholder-data per that plan's explicit scope boundary).

**Demo:** `flutter test test/features/home/ test/features/chat/ test/features/log/` passes. These aren't wired into the router yet if M12 ran before this milestone in your execution order — note M12 already referenced `HomeScreen`/`ChatScreen`/`LogScreen` by name, so in practice run M15 before M12 if executing strictly in file order; the dependency is "M15's screens must exist before M12 imports them," not the milestone numbers.

### M16 — Wire Home/Chat/Log to real Firestore data (NEW)

**Files:**
- Create: `EVE_MOBILE/app/lib/features/home/data/home_repository.dart`
- Create: `EVE_MOBILE/app/lib/features/chat/data/chat_repository.dart`
- Create: `EVE_MOBILE/app/lib/features/log/data/log_repository.dart`
- Test: `EVE_MOBILE/app/test/features/home/data/home_repository_test.dart`
- Test: `EVE_MOBILE/app/test/features/chat/data/chat_repository_test.dart`
- Test: `EVE_MOBILE/app/test/features/log/data/log_repository_test.dart`
- Modify: `EVE_MOBILE/app/lib/core/router/app_router.dart`

**Interfaces:**
- Consumes: `firestoreProvider` (M14), `FirestorePaths` (Plan 2 Task 2), `LifeStageProfile` family + `ChatMessage` + `SymptomLog` (Plan 5 Task 2), `HomeScreen`/`ChatScreen`/`LogScreen`/`BentoCardData`/`ChatMessageData`/`ChatSender`/`CalendarDayData` (Plan 1 Tasks 22–24), `EveEmotion` (Plan 6).
- Produces: `homeDashboardProvider`, `chatThreadProvider`, `monthLogsProvider` (all `Provider.family<..., String>` keyed by uid), `ChatRepository.sendMessage`.

Cycle-phase/ovulation prediction math (EVE_PRD §5.1) is out of scope for this task — it wires the placeholder constructor params Plan 1 flagged as deferred (name, phase badge text, chat thread, calendar days) to real Firestore reads, it does not add new prediction algorithms nobody has speced yet. The Home phase badge below is a static per-branch label, not a computed cycle day.

- [ ] **Step 1: Write the failing test for the Home dashboard provider**

Create `EVE_MOBILE/app/test/features/home/data/home_repository_test.dart`:

```dart
// EVE_MOBILE/app/test/features/home/data/home_repository_test.dart
import 'package:eve_app/core/constants/firestore_paths.dart';
import 'package:eve_app/core/providers/firebase_providers.dart';
import 'package:eve_app/features/home/data/home_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('homeDashboardProvider reads the real name and a cycle-branch phase badge', () async {
    final fake = FakeFirebaseFirestore();
    await fake.doc(FirestorePaths.userDoc('u1')).set({'name': 'Priya'});
    await fake.doc(FirestorePaths.lifeStageProfile('u1')).set({
      'type': 'cycle',
      'cycleLength': 28,
      'periodLength': 5,
      'flow': 'Moderate',
      'cycleSymptoms': [],
      'cycleGoals': [],
    });

    final container = ProviderContainer(overrides: [firestoreProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final data = await container.read(homeDashboardProvider('u1').future);

    expect(data.greetingName, 'Priya');
    expect(data.phaseBadge, 'Cycle Tracking Active');
  });

  test('homeDashboardProvider falls back to a generic greeting and badge before onboarding completes', () async {
    final fake = FakeFirebaseFirestore();
    final container = ProviderContainer(overrides: [firestoreProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final data = await container.read(homeDashboardProvider('u2').future);

    expect(data.greetingName, 'there');
    expect(data.phaseBadge, 'Welcome to EVE');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/home/data/home_repository_test.dart
```

Expected: FAIL — `home_repository.dart` doesn't exist.

- [ ] **Step 3: Implement `home_repository.dart`**

Create `EVE_MOBILE/app/lib/features/home/data/home_repository.dart`:

```dart
// EVE_MOBILE/app/lib/features/home/data/home_repository.dart
import 'package:eve_app/core/constants/firestore_paths.dart';
import 'package:eve_app/core/providers/firebase_providers.dart';
import 'package:eve_app/shared/models/life_stage_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeDashboardData {
  const HomeDashboardData({required this.greetingName, required this.phaseBadge});
  final String greetingName;
  final String phaseBadge;
}

final homeDashboardProvider = FutureProvider.family<HomeDashboardData, String>((ref, uid) async {
  final firestore = ref.watch(firestoreProvider);
  final profileSnap = await firestore.doc(FirestorePaths.userDoc(uid)).get();
  final lifeStageSnap = await firestore.doc(FirestorePaths.lifeStageProfile(uid)).get();

  final rawName = profileSnap.data()?['name'] as String?;
  final greetingName = (rawName == null || rawName.isEmpty) ? 'there' : rawName;

  final lifeStageProfile = lifeStageSnap.exists
      ? LifeStageProfile.fromMap(lifeStageSnap.data()!)
      : const EmptyLifeStageProfile();

  final String phaseBadge;
  if (lifeStageProfile is CycleLifeStageProfile) {
    phaseBadge = 'Cycle Tracking Active';
  } else if (lifeStageProfile is PregnantLifeStageProfile) {
    phaseBadge = 'Pregnancy Tracking Active';
  } else if (lifeStageProfile is SimplifiedLifeStageProfile) {
    final type = lifeStageProfile.type;
    final titled = type.isEmpty ? type : '${type[0].toUpperCase()}${type.substring(1)}';
    phaseBadge = '$titled Tracking Active';
  } else {
    phaseBadge = 'Welcome to EVE';
  }

  return HomeDashboardData(greetingName: greetingName, phaseBadge: phaseBadge);
});
```

- [ ] **Step 4: Run to verify it passes**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/home/data/home_repository_test.dart
```

Expected: `All tests passed!` (2 tests).

- [ ] **Step 5: Write the failing test for the chat repository/provider**

Create `EVE_MOBILE/app/test/features/chat/data/chat_repository_test.dart`:

```dart
// EVE_MOBILE/app/test/features/chat/data/chat_repository_test.dart
import 'package:eve_app/core/constants/firestore_paths.dart';
import 'package:eve_app/core/providers/firebase_providers.dart';
import 'package:eve_app/features/chat/data/chat_repository.dart';
import 'package:eve_app/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chatThreadProvider maps senderId to ChatSender in timestamp order', () async {
    final fake = FakeFirebaseFirestore();
    final now = DateTime.utc(2026, 1, 1, 9);
    await fake.collection(FirestorePaths.chatCollection('u1')).add({
      'senderId': 'her', 'messageText': 'Hi', 'timestamp': now, 'type': 'text',
    });
    await fake.collection(FirestorePaths.chatCollection('u1')).add({
      'senderId': 'system', 'messageText': 'Eve: check in on her', 'timestamp': now.add(const Duration(minutes: 1)), 'type': 'system',
    });

    final container = ProviderContainer(overrides: [firestoreProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final messages = await container.read(chatThreadProvider('u1').future);

    expect(messages.map((m) => m.sender), [ChatSender.wife, ChatSender.eveSystem]);
    expect(messages.map((m) => m.text), ['Hi', 'Eve: check in on her']);
  });

  test('ChatRepository.sendMessage writes a text message authored by her', () async {
    final fake = FakeFirebaseFirestore();
    final repo = ChatRepository(firestore: fake);

    await repo.sendMessage('u1', 'Feeling better today.');

    final snapshot = await fake.collection(FirestorePaths.chatCollection('u1')).get();
    expect(snapshot.docs, hasLength(1));
    expect(snapshot.docs.first.data()['senderId'], 'her');
    expect(snapshot.docs.first.data()['type'], 'text');
  });
}
```

- [ ] **Step 6: Run to verify it fails**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/chat/data/chat_repository_test.dart
```

Expected: FAIL — `chat_repository.dart` doesn't exist.

- [ ] **Step 7: Implement `chat_repository.dart`**

Create `EVE_MOBILE/app/lib/features/chat/data/chat_repository.dart`:

```dart
// EVE_MOBILE/app/lib/features/chat/data/chat_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eve_app/core/constants/firestore_paths.dart';
import 'package:eve_app/core/providers/firebase_providers.dart';
import 'package:eve_app/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:eve_app/shared/models/chat_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatThreadProvider = StreamProvider.family<List<ChatMessageData>, String>((ref, uid) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(FirestorePaths.chatCollection(uid))
      .orderBy('timestamp')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final message = ChatMessage.fromMap(doc.data());
            return ChatMessageData(sender: _senderFor(message.senderId), text: message.messageText);
          }).toList());
});

ChatSender _senderFor(String senderId) {
  switch (senderId) {
    case 'partner':
      return ChatSender.partner;
    case 'system':
      return ChatSender.eveSystem;
    default:
      return ChatSender.wife;
  }
}

class ChatRepository {
  ChatRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Future<void> sendMessage(String uid, String text) {
    return _firestore.collection(FirestorePaths.chatCollection(uid)).add(
          ChatMessage(senderId: 'her', messageText: text, timestamp: DateTime.now(), type: 'text').toMap(),
        );
  }
}
```

- [ ] **Step 8: Run to verify it passes**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/chat/data/chat_repository_test.dart
```

Expected: `All tests passed!` (2 tests).

- [ ] **Step 9: Write the failing test for the log repository/provider**

Create `EVE_MOBILE/app/test/features/log/data/log_repository_test.dart`:

```dart
// EVE_MOBILE/app/test/features/log/data/log_repository_test.dart
import 'package:eve_app/core/constants/firestore_paths.dart';
import 'package:eve_app/core/providers/firebase_providers.dart';
import 'package:eve_app/features/log/data/log_repository.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monthLogsProvider maps each log to a CalendarDayData with a mood-derived emotion', () async {
    final fake = FakeFirebaseFirestore();
    final date = DateTime.utc(2026, 3, 14);
    await fake.collection(FirestorePaths.logsCollection('u1')).add({
      'date': date, 'symptoms': ['cramps'], 'mood': 'low', 'painLevel': 6, 'notes': '', 'createdAt': date, 'updatedAt': date,
    });

    final container = ProviderContainer(overrides: [firestoreProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final days = await container.read(monthLogsProvider('u1').future);

    expect(days, hasLength(1));
    expect(days.first.dayNumber, 14);
    expect(days.first.emotion, EveEmotion.caring);
  });
}
```

- [ ] **Step 10: Run to verify it fails**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/log/data/log_repository_test.dart
```

Expected: FAIL — `log_repository.dart` doesn't exist.

- [ ] **Step 11: Implement `log_repository.dart`**

Create `EVE_MOBILE/app/lib/features/log/data/log_repository.dart`:

```dart
// EVE_MOBILE/app/lib/features/log/data/log_repository.dart
import 'package:eve_app/core/constants/firestore_paths.dart';
import 'package:eve_app/core/providers/firebase_providers.dart';
import 'package:eve_app/features/log/presentation/widgets/calendar_day_cell.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/shared/models/symptom_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final monthLogsProvider = StreamProvider.family<List<CalendarDayData>, String>((ref, uid) {
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection(FirestorePaths.logsCollection(uid)).snapshots().map(
        (snapshot) => snapshot.docs.map((doc) {
          final log = SymptomLog.fromMap(doc.data());
          return CalendarDayData(
            dayNumber: log.date.day,
            dotColors: log.symptoms.isNotEmpty ? const [Color(0xFF9B51E0)] : const [],
            dateTitle: DateFormat('MMMM d').format(log.date),
            detail: log.notes.isNotEmpty
                ? log.notes
                : (log.symptoms.isEmpty ? 'No symptoms logged' : log.symptoms.join(', ')),
            emotion: _emotionForMood(log.mood),
          );
        }).toList(),
      );
});

EveEmotion _emotionForMood(String? mood) {
  switch (mood) {
    case 'great':
    case 'good':
      return EveEmotion.hype;
    case 'low':
    case 'difficult':
      return EveEmotion.caring;
    default:
      return EveEmotion.neutral;
  }
}
```

- [ ] **Step 12: Run to verify it passes**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/log/data/log_repository_test.dart
```

Expected: `All tests passed!` (1 test).

- [ ] **Step 13: Wire the three providers into the router's Home/Chat/Log routes**

Modify `EVE_MOBILE/app/lib/core/router/app_router.dart` — replace the `/home`, `/chat`, `/log` `GoRoute`s (added in M12 Step 3) with:

```dart
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => Consumer(
        builder: (context, ref, _) {
          final uid = ref.watch(currentUidProvider);
          if (uid == null) {
            return const HomeScreen();
          }
          final dashboard = ref.watch(homeDashboardProvider(uid));
          return dashboard.when(
            data: (data) => HomeScreen(
              greetingName: data.greetingName,
              phaseBadge: data.phaseBadge,
              onNavigateChat: () => context.go('/chat'),
              onNavigateLog: () => context.go('/log'),
            ),
            loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
            error: (error, stack) => const HomeScreen(),
          );
        },
      ),
    ),
    GoRoute(
      path: '/chat',
      name: 'chat',
      builder: (context, state) => Consumer(
        builder: (context, ref, _) {
          final uid = ref.watch(currentUidProvider);
          if (uid == null) {
            return ChatScreen(onNavigateHome: () => context.go('/home'), onNavigateLog: () => context.go('/log'));
          }
          final thread = ref.watch(chatThreadProvider(uid));
          final firestore = ref.watch(firestoreProvider);
          return thread.when(
            data: (messages) => ChatScreen(
              thread: messages,
              onSendMessage: (text) => ChatRepository(firestore: firestore).sendMessage(uid, text),
              onNavigateHome: () => context.go('/home'),
              onNavigateLog: () => context.go('/log'),
            ),
            loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
            error: (error, stack) =>
                ChatScreen(onNavigateHome: () => context.go('/home'), onNavigateLog: () => context.go('/log')),
          );
        },
      ),
    ),
    GoRoute(
      path: '/log',
      name: 'log',
      builder: (context, state) => Consumer(
        builder: (context, ref, _) {
          final uid = ref.watch(currentUidProvider);
          if (uid == null) {
            return LogScreen(onNavigateHome: () => context.go('/home'), onNavigateChat: () => context.go('/chat'));
          }
          final days = ref.watch(monthLogsProvider(uid));
          return days.when(
            data: (data) => LogScreen(
              monthLabel: DateFormat('MMMM yyyy').format(DateTime.now()),
              days: data,
              onNavigateHome: () => context.go('/home'),
              onNavigateChat: () => context.go('/chat'),
            ),
            loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
            error: (error, stack) =>
                LogScreen(onNavigateHome: () => context.go('/home'), onNavigateChat: () => context.go('/chat')),
          );
        },
      ),
    ),
```

Add the required imports to the top of `app_router.dart`:

```dart
import 'package:intl/intl.dart';
import 'package:eve_app/core/providers/firebase_providers.dart';
import 'package:eve_app/features/chat/data/chat_repository.dart';
import 'package:eve_app/features/home/data/home_repository.dart';
import 'package:eve_app/features/log/data/log_repository.dart';
```

- [ ] **Step 14: Run the full test suite and static analysis**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test
flutter analyze
```

Expected: all tests pass; `flutter analyze` reports `No issues found!`.

- [ ] **Step 15: Commit**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE"
git add app/lib/features/home/data app/lib/features/chat/data app/lib/features/log/data app/test/features/home/data app/test/features/chat/data app/test/features/log/data app/lib/core/router/app_router.dart
git commit -m "feat: wire Home/Chat/Log to real Firestore data"
```

**Demo:** against the emulator, seed a log document with `symptoms`/`mood`/`notes` for a signed-in user via the Firestore emulator UI — Home's greeting shows the real name, the Log calendar shows a purple dot on that day, tapping it shows the real notes. Send a chat message from the running app — it appears immediately (Firestore stream), and a second emulator session signed in as the same user sees it too.

### M17 — Notifications backend

Run: **Plan 3 Task 8** (`dueNotificationTypes` eligibility function), **Plan 3 Task 9** (`dispatchScheduledNotifications` Cloud Scheduler wiring — now writes to the ratified `users/{uid}/fcmTokens` path from R1), **Plan 3 Task 10** (full emulator run verification).

**Demo:** seed a user doc with `preferences/notifications.enabledReminders` containing `'morning'` and a token under `fcmTokens`; manually invoke `dispatchScheduledNotifications` against the Functions emulator at 07:00 UTC and confirm it identifies that user as eligible (check emulator logs — actually sending the FCM push isn't verifiable against the emulator, only the eligibility computation is).

### M18 — Partner consent engine (apply CN-2 continuation)

Run: **Plan 7 Task 1** with Steps 1/2/3/6 skipped per CN-2, then **Plan 7 Tasks 2–6** unchanged (start `firebase emulators:start --only firestore,auth,functions` first, per CN-2's test-script standardization).

**Demo:** seed a primary user with `partnerPermissions.approvedCategories = ['Mood updates']`, write a qualifying low-mood log entry — `partnerView/current` recomputes with a derived `moodReminders` entry (not the raw log), and a system chat message appears in `users/{uid}/chat` addressed to the partner. Toggle `onlyApproveMode` off/on and confirm `Task 6`'s full scenario suite (`npm test` in `functions/`) still passes.

### M19 — Doctor-ready summary export (NEW — the identified V0 scope gap)

`EVE2_PRD.md` §11 requires "a doctor summary export that performs one real AI call and formats the result" in V0. No sub-plan builds it: Plan 3 Task 7 only ships `aiProxy`'s authentication shell ("prompt construction, Gemini SDK calls, and response parsing... are implemented by whichever plan builds that feature, not here"), and `ai_proxy_service.dart` — named in design-spec §9's canonical folder structure — is referenced by three different plans' comments but created by none of them.

#### N5 — Extend `aiProxy` with real doctor-summary generation

**Files:**
- Create: `EVE_MOBILE/functions/src/doctorSummary.ts`
- Modify: `EVE_MOBILE/functions/src/aiProxy.ts`
- Test: `EVE_MOBILE/functions/test/doctorSummary.test.ts`
- Modify: `EVE_MOBILE/functions/package.json`

**Interfaces:**
- Consumes: `GEMINI_API_KEY` secret (Plan 3 Task 7).
- Produces: `buildDoctorSummaryPrompt(logs)` (pure, fully unit-tested), the `aiProxy` callable's `feature: 'doctorSummary'` branch (verified manually against the emulator, per the same boundary Plan 3 Task 7 itself drew between shell-reachability tests and actual external-API behavior).

**Implementation note — deviation from design-spec §2's "via Vertex AI/Genkit":** this uses the `@google/generative-ai` SDK directly against the Gemini API, not a full Vertex AI/Genkit setup. Both satisfy "Google Gemini, from a Cloud Function proxy, never called directly from the client" — the proxy pattern and provider are unchanged. Vertex AI/Genkit's IAM/service-account/flow-config overhead isn't worth it for a single prompt-in/text-out call under hackathon time constraints; flagged here the same way Plan 3 self-flagged its own pragmatic choices.

- [ ] **Step 1: Write the failing prompt-builder tests**

Create `EVE_MOBILE/functions/test/doctorSummary.test.ts`:

```ts
import { buildDoctorSummaryPrompt } from '../src/doctorSummary';

describe('buildDoctorSummaryPrompt', () => {
  it('includes an explicit no-data instruction when logs is empty', () => {
    const prompt = buildDoctorSummaryPrompt([]);
    expect(prompt).toContain('No symptom or mood logs were recorded');
  });

  it('includes every log entry date and formats missing fields as not reported', () => {
    const prompt = buildDoctorSummaryPrompt([
      { date: '2026-03-04', symptoms: ['cramps'], mood: 'okay', painLevel: 4, notes: 'Felt tired.' },
      { date: '2026-03-02', symptoms: [], mood: null, painLevel: null, notes: '' },
    ]);
    expect(prompt).toContain('Date: 2026-03-04');
    expect(prompt).toContain('Symptoms: cramps');
    expect(prompt).toContain('Date: 2026-03-02');
    expect(prompt).toContain('Symptoms: none reported');
    expect(prompt).toContain('Mood: not reported');
  });

  it('sorts entries chronologically regardless of input order', () => {
    const prompt = buildDoctorSummaryPrompt([
      { date: '2026-03-04', symptoms: [], mood: null, painLevel: null, notes: '' },
      { date: '2026-03-02', symptoms: [], mood: null, painLevel: null, notes: '' },
    ]);
    expect(prompt.indexOf('2026-03-02')).toBeLessThan(prompt.indexOf('2026-03-04'));
  });

  it('always instructs the model never to state a diagnosis', () => {
    const prompt = buildDoctorSummaryPrompt([
      { date: '2026-03-04', symptoms: ['cramps'], mood: 'okay', painLevel: 4, notes: '' },
    ]);
    expect(prompt).toContain('never state a diagnosis');
  });
});
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd EVE_MOBILE/functions
npm test -- doctorSummary
```

Expected: FAIL — `Cannot find module '../src/doctorSummary'`.

- [ ] **Step 3: Implement `buildDoctorSummaryPrompt`**

Create `EVE_MOBILE/functions/src/doctorSummary.ts`:

```ts
export interface DoctorSummaryLogEntry {
  date: string; // ISO date, e.g. '2026-03-04'
  symptoms: string[];
  mood: string | null;
  painLevel: number | null;
  notes: string;
}

export function buildDoctorSummaryPrompt(logs: DoctorSummaryLogEntry[]): string {
  if (logs.length === 0) {
    return 'No symptom or mood logs were recorded in the selected period. State this plainly and do not fabricate any data.';
  }

  const lines = logs
    .slice()
    .sort((a, b) => a.date.localeCompare(b.date))
    .map((log) => {
      const parts = [`Date: ${log.date}`];
      parts.push(`Symptoms: ${log.symptoms.length > 0 ? log.symptoms.join(', ') : 'none reported'}`);
      parts.push(`Mood: ${log.mood ?? 'not reported'}`);
      parts.push(`Pain level (0-10): ${log.painLevel ?? 'not reported'}`);
      if (log.notes.trim().length > 0) {
        parts.push(`Notes: ${log.notes.trim()}`);
      }
      return parts.join(' | ');
    });

  return [
    "You are generating a factual clinical summary from a patient's self-reported symptom and mood log for her upcoming doctor visit.",
    'Rules: use only the data below, never invent symptoms or values, never state a diagnosis, and close with a line recommending she discuss these patterns with her doctor.',
    'Format: a short overview paragraph, then a "Notable patterns" section, then a "Log entries" section listing each date.',
    '',
    `Log entries (${logs.length} total):`,
    ...lines,
  ].join('\n');
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
cd EVE_MOBILE/functions
npm test -- doctorSummary
```

Expected: `PASS` (4 tests).

- [ ] **Step 5: Add the Gemini SDK dependency**

Add to `EVE_MOBILE/functions/package.json`'s `dependencies`:

```json
    "@google/generative-ai": "^0.21.0",
```

Run:

```bash
cd EVE_MOBILE/functions
npm install
```

- [ ] **Step 6: Extend `aiProxy.ts` to route the `doctorSummary` feature through Gemini**

Replace the full contents of `EVE_MOBILE/functions/src/aiProxy.ts`:

```ts
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { buildDoctorSummaryPrompt, DoctorSummaryLogEntry } from './doctorSummary';

export const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');

/**
 * Callable AI proxy. This is the only place in the entire codebase that may
 * read GEMINI_API_KEY — the Flutter client never sees it, per EVE2_PRD
 * §10.1/§10.3 ("never called directly from the client").
 *
 * `request.data.feature` selects the AI feature. Only 'doctorSummary' is
 * implemented (04-build-roadmap.md M19); an absent/unrecognized feature
 * falls back to the reachability-check shape Plan 3 Task 7 originally
 * shipped, so that task's own emulator verification still holds.
 */
export const aiProxy = onCall({ secrets: [GEMINI_API_KEY] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required to use the AI assistant.');
  }

  const apiKey = GEMINI_API_KEY.value();
  if (!apiKey) {
    throw new HttpsError('failed-precondition', 'GEMINI_API_KEY secret is not configured.');
  }

  const feature = request.data?.feature;

  if (feature === 'doctorSummary') {
    const logs = request.data?.logs;
    if (!Array.isArray(logs)) {
      throw new HttpsError('invalid-argument', 'doctorSummary requires a "logs" array.');
    }

    const prompt = buildDoctorSummaryPrompt(logs as DoctorSummaryLogEntry[]);
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' });
    const result = await model.generateContent(prompt);

    return { summary: result.response.text() };
  }

  return { ok: true, keyLoaded: apiKey.length > 0 };
});
```

- [ ] **Step 7: Build and verify against the emulator**

```bash
cd EVE_MOBILE/functions
npm run build
firebase emulators:start --only functions,firestore,auth
```

In a second terminal, with a real or dummy key in `.secret.local` (Plan 3 Task 7 Step 3):

```bash
curl -X POST http://localhost:5001/eve-hack26/us-central1/aiProxy \
  -H "Content-Type: application/json" \
  -d '{"data":{}}'
```

Expected: `"status":"UNAUTHENTICATED"` (same as Plan 3 Task 7's own check — proves the shell still works after this change). Actually invoking `feature: 'doctorSummary'` requires a real Auth ID token and a real `GEMINI_API_KEY`; verify that path manually from the running Flutter app in M19's Demo below rather than via `curl`.

- [ ] **Step 8: Commit**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE"
git add functions/src/doctorSummary.ts functions/src/aiProxy.ts functions/test/doctorSummary.test.ts functions/package.json functions/package-lock.json
git commit -m "feat: generate real doctor-ready summaries via aiProxy's doctorSummary feature"
```

#### N6 — `ai_proxy_service.dart` client

**Files:**
- Create: `EVE_MOBILE/app/lib/core/services/ai_proxy_service.dart`
- Test: `EVE_MOBILE/app/test/core/services/ai_proxy_service_test.dart`

**Interfaces:**
- Consumes: `FirebaseFunctions` (`cloud_functions` package, already in the merged pubspec per CN-1).
- Produces: `AiProxyService.generateDoctorSummary(logs)` — the exact call `ai_proxy_service.dart` was reserved for in design-spec §9.

- [ ] **Step 1: Write the failing test**

Create `EVE_MOBILE/app/test/core/services/ai_proxy_service_test.dart`:

```dart
// EVE_MOBILE/app/test/core/services/ai_proxy_service_test.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:eve_app/core/services/ai_proxy_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult extends Mock implements HttpsCallableResult<Map<String, dynamic>> {}

void main() {
  test('generateDoctorSummary calls aiProxy with feature doctorSummary and returns the summary text', () async {
    final mockFunctions = MockFirebaseFunctions();
    final mockCallable = MockHttpsCallable();
    final mockResult = MockHttpsCallableResult();

    when(() => mockFunctions.httpsCallable('aiProxy')).thenReturn(mockCallable);
    when(() => mockCallable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => mockResult);
    when(() => mockResult.data).thenReturn({'summary': 'Overview: mild cramps recorded once.'});

    final service = AiProxyService(functions: mockFunctions);
    final summary = await service.generateDoctorSummary([
      {'date': '2026-03-04', 'symptoms': ['cramps'], 'mood': 'okay', 'painLevel': 4, 'notes': ''},
    ]);

    expect(summary, 'Overview: mild cramps recorded once.');
    final captured = verify(() => mockCallable.call<Map<String, dynamic>>(captureAny())).captured.single as Map;
    expect(captured['feature'], 'doctorSummary');
  });

  test('throws a StateError when aiProxy returns no summary field', () async {
    final mockFunctions = MockFirebaseFunctions();
    final mockCallable = MockHttpsCallable();
    final mockResult = MockHttpsCallableResult();

    when(() => mockFunctions.httpsCallable('aiProxy')).thenReturn(mockCallable);
    when(() => mockCallable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => mockResult);
    when(() => mockResult.data).thenReturn(<String, dynamic>{});

    final service = AiProxyService(functions: mockFunctions);

    expect(() => service.generateDoctorSummary([]), throwsStateError);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/core/services/ai_proxy_service_test.dart
```

Expected: FAIL — `ai_proxy_service.dart` doesn't exist.

- [ ] **Step 3: Implement `AiProxyService`**

Create `EVE_MOBILE/app/lib/core/services/ai_proxy_service.dart`:

```dart
// EVE_MOBILE/app/lib/core/services/ai_proxy_service.dart
import 'package:cloud_functions/cloud_functions.dart';

/// Client for the `aiProxy` Cloud Function (Plan 3 Task 7, extended in
/// 04-build-roadmap.md N5). The only way the Flutter client ever reaches
/// Gemini — never called directly, per EVE2_PRD §10.1.
class AiProxyService {
  AiProxyService({FirebaseFunctions? functions}) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<String> generateDoctorSummary(List<Map<String, dynamic>> logs) async {
    final callable = _functions.httpsCallable('aiProxy');
    final result = await callable.call<Map<String, dynamic>>({
      'feature': 'doctorSummary',
      'logs': logs,
    });

    final summary = result.data['summary'] as String?;
    if (summary == null) {
      throw StateError('aiProxy returned no summary text.');
    }
    return summary;
  }
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/core/services/ai_proxy_service_test.dart
```

Expected: `All tests passed!` (2 tests).

- [ ] **Step 5: Commit**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE"
git add app/lib/core/services/ai_proxy_service.dart app/test/core/services/ai_proxy_service_test.dart
git commit -m "feat: add AiProxyService client for doctor-summary generation"
```

#### N7 — `DoctorSummaryScreen` + PDF export

**Files:**
- Create: `EVE_MOBILE/app/lib/features/home/presentation/screens/doctor_summary_screen.dart`
- Test: `EVE_MOBILE/app/test/features/home/presentation/screens/doctor_summary_screen_test.dart`

**Interfaces:**
- Consumes: `pdf`/`printing` packages (in the merged pubspec per CN-1).
- Produces: `DoctorSummaryScreen`, taking `logs` and a `generateSummary` callback as constructor params (same "structure takes data via constructor" pattern Plan 1 used throughout, so this screen is independently testable without touching Firebase/Gemini).

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
              pw.Text('EVE Doctor-Ready Summary', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
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
- Create: `EVE_MOBILE/app/lib/features/home/data/doctor_summary_logs_provider.dart`
- Test: `EVE_MOBILE/app/test/features/home/data/doctor_summary_logs_provider_test.dart`
- Modify: `EVE_MOBILE/app/lib/core/router/app_router.dart`

**Interfaces:**
- Consumes: `HomeScreen` (Plan 1 Task 22), `SymptomLog` (Plan 5 Task 2), `firestoreProvider` (M14), `DoctorSummaryScreen`/`AiProxyService` (N7/N6).
- Produces: a reachable `/doctor-summary` route from a real Home-screen affordance.

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

- [ ] **Step 2: Run to verify it fails**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/home/presentation/screens/home_screen_test.dart
```

Expected: FAIL — `The named parameter 'onNavigateDoctorSummary' isn't defined.`

- [ ] **Step 3: Add the affordance to `HomeScreen`**

In `EVE_MOBILE/app/lib/features/home/presentation/screens/home_screen.dart`, add the new constructor param and field:

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

Replace the header `Row` (greeting + phase badge Chip) so the phase badge sits alongside a new icon button:

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

- [ ] **Step 4: Run to verify it passes**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/home/presentation/screens/home_screen_test.dart
```

Expected: `All tests passed!` (4 tests: the original 3 plus this one).

- [ ] **Step 5: Write the failing test for the logs provider**

Create `EVE_MOBILE/app/test/features/home/data/doctor_summary_logs_provider_test.dart`:

```dart
// EVE_MOBILE/app/test/features/home/data/doctor_summary_logs_provider_test.dart
import 'package:eve_app/core/constants/firestore_paths.dart';
import 'package:eve_app/core/providers/firebase_providers.dart';
import 'package:eve_app/features/home/data/doctor_summary_logs_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('doctorSummaryLogsProvider maps SymptomLog docs into aiProxy-shaped maps, ordered by date', () async {
    final fake = FakeFirebaseFirestore();
    final earlier = DateTime.utc(2026, 3, 2);
    final later = DateTime.utc(2026, 3, 4);
    await fake.collection(FirestorePaths.logsCollection('u1')).add({
      'date': later, 'symptoms': ['cramps'], 'mood': 'okay', 'painLevel': 4, 'notes': '', 'createdAt': later, 'updatedAt': later,
    });
    await fake.collection(FirestorePaths.logsCollection('u1')).add({
      'date': earlier, 'symptoms': [], 'mood': null, 'painLevel': null, 'notes': '', 'createdAt': earlier, 'updatedAt': earlier,
    });

    final container = ProviderContainer(overrides: [firestoreProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);

    final logs = await container.read(doctorSummaryLogsProvider('u1').future);

    expect(logs, hasLength(2));
    expect(logs.first['date'], '2026-03-02');
    expect(logs.last['date'], '2026-03-04');
    expect(logs.last['symptoms'], ['cramps']);
  });
}
```

- [ ] **Step 6: Run to verify it fails**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/home/data/doctor_summary_logs_provider_test.dart
```

Expected: FAIL — `doctor_summary_logs_provider.dart` doesn't exist.

- [ ] **Step 7: Implement the provider**

Create `EVE_MOBILE/app/lib/features/home/data/doctor_summary_logs_provider.dart`:

```dart
// EVE_MOBILE/app/lib/features/home/data/doctor_summary_logs_provider.dart
import 'package:eve_app/core/constants/firestore_paths.dart';
import 'package:eve_app/core/providers/firebase_providers.dart';
import 'package:eve_app/shared/models/symptom_log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final doctorSummaryLogsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, uid) async {
  final firestore = ref.watch(firestoreProvider);
  final snapshot = await firestore.collection(FirestorePaths.logsCollection(uid)).orderBy('date').get();

  return snapshot.docs.map((doc) {
    final log = SymptomLog.fromMap(doc.data());
    return {
      'date': DateFormat('yyyy-MM-dd').format(log.date),
      'symptoms': log.symptoms,
      'mood': log.mood,
      'painLevel': log.painLevel,
      'notes': log.notes,
    };
  }).toList();
});
```

- [ ] **Step 8: Run to verify it passes**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/home/data/doctor_summary_logs_provider_test.dart
```

Expected: `All tests passed!` (1 test).

- [ ] **Step 9: Wire the route and the Home entry point**

Modify `EVE_MOBILE/app/lib/core/router/app_router.dart`: add `onNavigateDoctorSummary: () => context.go('/doctor-summary')` to the `/home` route's `HomeScreen(...)` construction (both the `data:` and `error:` cases added in M16 Step 13), and add a new route:

```dart
    GoRoute(
      path: '/doctor-summary',
      name: 'doctor-summary',
      builder: (context, state) => Consumer(
        builder: (context, ref, _) {
          final uid = ref.watch(currentUidProvider);
          if (uid == null) {
            return const Scaffold(body: Center(child: Text('Sign in required.')));
          }
          final logsAsync = ref.watch(doctorSummaryLogsProvider(uid));
          return logsAsync.when(
            data: (logs) => DoctorSummaryScreen(
              logs: logs,
              generateSummary: (logs) => AiProxyService().generateDoctorSummary(logs),
            ),
            loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
            error: (error, stack) => const Scaffold(body: Center(child: Text('Could not load your logs.'))),
          );
        },
      ),
    ),
```

Add the required imports:

```dart
import 'package:eve_app/core/services/ai_proxy_service.dart';
import 'package:eve_app/features/home/data/doctor_summary_logs_provider.dart';
import 'package:eve_app/features/home/presentation/screens/doctor_summary_screen.dart';
```

- [ ] **Step 10: Run the full test suite and static analysis**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test
flutter analyze
```

Expected: all tests pass; `flutter analyze` reports `No issues found!`.

- [ ] **Step 11: Commit**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE"
git add app/lib/features/home/presentation/screens/home_screen.dart app/test/features/home/presentation/screens/home_screen_test.dart app/lib/features/home/data/doctor_summary_logs_provider.dart app/test/features/home/data/doctor_summary_logs_provider_test.dart app/lib/core/router/app_router.dart
git commit -m "feat: wire doctor-summary entry point and route into Home"
```

**Demo (whole of M19):** seed 2–3 realistic log entries for a signed-in emulator user, run the app against a real (not dummy) `GEMINI_API_KEY`, tap the summary icon on Home, tap "Generate Summary" — a real Gemini-authored paragraph appears referencing the seeded symptoms/mood without inventing anything or naming a diagnosis, then tap "Export as PDF" and confirm the OS share sheet opens with a well-formed PDF attached.

### M20 — Production run and final polish

Run: **Plan 3 Task 12** (documented emulator-vs-production `--dart-define` run commands).

**Demo:** `flutter run --dart-define=USE_FIREBASE_EMULATOR=false` boots the full app against the real `eve-hack26` Firebase project — sign in with a real Google account, complete onboarding, see it land in Firestore, exchange a chat message, and generate a real doctor summary, all without touching the emulator.

---

## Self-Review

**1. Spec coverage.**
- Every task in Plans 1, 2, 3, 5, 6, and 7 is assigned to exactly one milestone (M0–M18), in an order that respects every real dependency discovered while auditing them (Firebase project → app scaffold → core services → state → mascot → router → screens → router wiring → data layer → persistence → real-data wiring → notifications → partner consent). ✅
- The three real cross-plan file collisions found (`pubspec.yaml`, the Cloud Functions scaffold + `firebase.json`, `firebase_service.dart`/bootstrap) are each resolved with an exact merged artifact or skip/append instruction (CN-1/CN-2/CN-3), not just flagged. ✅
- The one path Plan 3 self-flagged as unratified (`fcmTokens`) is ratified with its own TDD task (R1). ✅
- The router-wiring gap (nobody ever replaces `RouteLabelScreen` with real screens) is closed in M12, with all 20 onboarding screens plus Home/Chat/Log reachable by the end of that milestone. ✅
- The onboarding-completion-never-writes-to-Firestore gap is closed in M14. ✅
- Plan 1's explicit "real data wiring deferred to Plan 4" note for Home/Chat/Log (Tasks 22–24) is closed in M16. ✅
- The doctor-ready summary export — explicit V0 scope per `EVE2_PRD.md` §11, assigned to no sub-plan — is fully built in M19 (N5–N8): real Gemini call, real client, real screen, real PDF export, real router entry point. ✅
- `04-build-roadmap.md` itself required the writing-plans header (Goal/Architecture/Tech Stack/Global Constraints) since it's produced by the same skill as the other six — present above. ✅

**2. Placeholder scan.** No "TBD"/"implement later"/"similar to Task N" patterns in any new (`N#`/`R1`) task — every step with code shows the full code. The one intentionally-untested boundary (Completion route's Firestore write, `/doctor-summary` route's live Gemini call) is called out explicitly as "verified manually against the emulator," matching the same boundary Plan 3 Task 7 itself already drew for Firebase-SDK-touching glue code that `flutter test`/Jest can't exercise without a live backend — not a placeholder, a stated testing-strategy boundary.

**3. Type consistency.** `OnboardingRepository.saveOnboarding(uid, state)` uses the exact `OnboardingState` field names/types fixed in Plan 2 Task 5 (post-reconciliation) throughout. `firestoreProvider`/`currentUidProvider` (M14) are the single source every later milestone (N2/N3/N4 in M16, N7/N8 in M19) reads from — no milestone re-declares a competing provider. `HomeScreen`/`ChatScreen`/`LogScreen` constructor param names used in M12's and M16's router wiring match Plan 1 Tasks 22–24 exactly, verified against each task's actual `class ... extends StatelessWidget`/`StatefulWidget` constructor. The `_middleScreenBuilders` map in M12 uses the exact 18 screen-id strings Plan 1 Task 25's `onboardingSequence()` produces (`auth`, `profile`, `lifestage`, `cycle-info`, `cycle-symptoms`, `cycle-goals`, `pregnant-due`, `pregnant-meds`, `pregnant-symptoms`, `simplified-branch`, `food`, `workout`, `notifications`, `ai-scope`, `partner-ask`, `partner-rel`, `partner-perm`, `theme`) — cross-checked one-for-one against that task's test fixtures.

---

## Execution Handoff

Plan complete and saved to `EVE_MOBILE/plans/04-build-roadmap.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
