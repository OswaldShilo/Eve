# EVE Mobile — System Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the foundational Flutter app scaffolding — project init, canonical folder structure, theming, routing shell, core Riverpod state, the module-activation lookup, and a Firebase Auth/Firestore wrapper — that every other EVE_MOBILE plan assumes already exists.

**Architecture:** A layered Flutter app: `core/` holds cross-cutting singletons (theme, router, Firestore path constants, Firebase wrapper) with no feature-specific knowledge; `features/<name>/domain` holds pure Dart state/logic (Riverpod notifiers, lookup functions) with zero Flutter widget dependencies where possible; `features/<name>/presentation` holds widgets (out of scope here except placeholder route targets). Routing is a single flat `go_router` table of named routes, one per screen ID from the design spec, pointing at placeholder widgets until Plan 1 supplies the real screens.

**Tech Stack:** Flutter (Dart) + Riverpod (`flutter_riverpod`, `StateNotifierProvider`) + `go_router` + `google_fonts` + Firebase (`firebase_core`, `firebase_auth`, `cloud_firestore`) + `mocktail` for test doubles. Exact version pins are Plan 3's (`03-tech-stack.md`) responsibility — this plan uses caret-range floors only.

## Global Constraints

- Frontend is Flutter (Dart), single codebase, per design-spec.md §2.
- State management is Riverpod, per design-spec.md §2. The onboarding state provider MUST be named `onboardingStateProvider` and MUST be a `StateNotifierProvider`, per design-spec.md §10.
- Backend is Firebase (Auth, Firestore) for this plan's scope; Cloud Functions/Cloud Scheduler/`firebase_messaging` are out of scope here (Plan 3/7).
- The project folder structure MUST match design-spec.md §9 exactly — every plan depends on these exact paths to compose without cross-reading each other's full content.
- Firestore path constants MUST match design-spec.md §10 exactly, character for character, including collection/document segment names.
- `List<Module> activeModules(LifeStage stage)` MUST use that exact function name and signature — design-spec.md §10 fixes this as the cross-plan contract Plan 1's Home screen consumes.
- Brand colors are fixed hex values (design-spec.md task brief): `--ruby-main: #FF2A6D`, `--ruby-dark: #2A000E`, `--ruby-blush: #FFA0B8`, `--ruby-soft: #FFF0F4`, `--partner-blue: #3D7BFF`, `--fertile-teal: #2EC4B6`, `--symptom-purple: #9B51E0`, `--appointment-orange: #FF9F1C`.
- Fonts are Google Fonts: Fredoka for display text, Quicksand for body text, via the `google_fonts` package — never bundle static font assets for these.
- No emojis anywhere in-product copy (design-spec.md §2). This plan produces no user-facing copy, but any label text added must stay emoji-free.
- Out of scope for this plan (owned by other plans — do not implement here): the `EveMascot` widget (Plan 6), real onboarding/Home/Chat/Log screen widgets (Plan 1), `firestore.rules` (Plan 5), the AI proxy and any Cloud Functions (Plan 3/7), notification scheduling (Plan 3). This plan creates only the `app/` (Flutter client) folder subtree — `functions/`, `firestore.rules`, `firestore.indexes.json`, and `firebase.json` at the `EVE_MOBILE/` root are left for the plans that own them.

---

## Task 1: Flutter project init and canonical folder structure

**Files:**
- Create: `EVE_MOBILE/app/pubspec.yaml`
- Create: `EVE_MOBILE/app/lib/main.dart`
- Create: `EVE_MOBILE/app/lib/app.dart`
- Create: directory tree under `EVE_MOBILE/app/lib/` and `EVE_MOBILE/app/test/` per design-spec.md §9 (with `.gitkeep` placeholders in directories no later task in this plan populates)
- Delete: `EVE_MOBILE/app/test/widget_test.dart` (default `flutter create` counter-app test — references a `MyApp` class that won't exist)

**Interfaces:**
- Consumes: nothing (first task).
- Produces: the `eve_app` Dart package (import prefix `package:eve_app/...`) that every later task and every other plan's Flutter code imports from; the exact directory tree later tasks write files into.

- [ ] **Step 1: Run `flutter create` to scaffold the app**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE"
flutter create --org com.thinkroot.eve --project-name eve_app --platforms android,ios app
```

Expected: command completes and prints "All done!" with `app/` containing `lib/`, `test/`, `android/`, `ios/`, `pubspec.yaml`.

- [ ] **Step 2: Overwrite `pubspec.yaml` with the canonical dependency set**

Replace the full contents of `EVE_MOBILE/app/pubspec.yaml` with:

```yaml
name: eve_app
description: EVE — an AI-powered adaptive health companion for women.
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: '>=3.19.0'

# NOTE: the ranges below are floors only, to keep this plan runnable.
# 03-tech-stack.md is the source of truth for exact pinned versions —
# check there before tightening or loosening any of these.
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.0
  go_router: ^14.0.0
  google_fonts: ^6.2.0
  firebase_core: ^2.27.0
  firebase_auth: ^4.17.0
  cloud_firestore: ^4.15.0
  cupertino_icons: ^1.0.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  mocktail: ^1.0.3

flutter:
  uses-material-design: true
```

- [ ] **Step 3: Fetch dependencies**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter pub get
```

Expected: exits 0, prints "Got dependencies!".

- [ ] **Step 4: Create the canonical directory tree**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
mkdir -p lib/core/theme lib/core/router lib/core/constants lib/core/services
mkdir -p lib/features/onboarding/data lib/features/onboarding/domain
mkdir -p lib/features/onboarding/presentation/screens lib/features/onboarding/presentation/widgets
mkdir -p lib/features/home/data lib/features/home/domain lib/features/home/presentation
mkdir -p lib/features/chat lib/features/log
mkdir -p lib/features/partner/domain lib/features/partner/presentation
mkdir -p lib/features/mascot
mkdir -p lib/shared/widgets lib/shared/models
mkdir -p test/core/theme test/core/router test/core/constants test/core/services
mkdir -p test/features/onboarding/data test/features/onboarding/domain
mkdir -p test/features/onboarding/presentation/screens test/features/onboarding/presentation/widgets
mkdir -p test/features/home/data test/features/home/domain test/features/home/presentation
mkdir -p test/features/chat test/features/log
mkdir -p test/features/partner/domain test/features/partner/presentation
mkdir -p test/features/mascot
mkdir -p test/shared/widgets test/shared/models
```

- [ ] **Step 5: Add `.gitkeep` to directories this plan leaves empty**

These directories belong to other plans (Plan 1, 3, 6, 7) and stay empty until those plans populate them:

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
touch lib/features/onboarding/data/.gitkeep
touch lib/features/onboarding/presentation/screens/.gitkeep
touch lib/features/onboarding/presentation/widgets/.gitkeep
touch lib/features/home/data/.gitkeep
touch lib/features/home/presentation/.gitkeep
touch lib/features/chat/.gitkeep
touch lib/features/log/.gitkeep
touch lib/features/partner/domain/.gitkeep
touch lib/features/partner/presentation/.gitkeep
touch lib/features/mascot/.gitkeep
touch lib/shared/widgets/.gitkeep
touch lib/shared/models/.gitkeep
touch test/features/onboarding/data/.gitkeep
touch test/features/onboarding/presentation/screens/.gitkeep
touch test/features/onboarding/presentation/widgets/.gitkeep
touch test/features/home/data/.gitkeep
touch test/features/home/presentation/.gitkeep
touch test/features/chat/.gitkeep
touch test/features/log/.gitkeep
touch test/features/partner/domain/.gitkeep
touch test/features/partner/presentation/.gitkeep
touch test/features/mascot/.gitkeep
touch test/shared/widgets/.gitkeep
touch test/shared/models/.gitkeep
```

(`lib/core/theme`, `lib/core/router`, `lib/core/constants`, `lib/core/services`, `lib/features/onboarding/domain`, `lib/features/home/domain` and their `test/` mirrors are NOT given `.gitkeep` — Tasks 2–7 below populate them with real files.)

- [ ] **Step 6: Replace the default counter-app `lib/main.dart` and `lib/app.dart` with temporary bootstrap stubs**

Replace the full contents of `EVE_MOBILE/app/lib/app.dart` with:

```dart
import 'package:flutter/material.dart';

/// Temporary bootstrap root. Task 7 of 02-system-architecture.md replaces
/// this with the real MaterialApp.router wiring (go_router + EveTheme).
class EveApp extends StatelessWidget {
  const EveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('EVE')),
      ),
    );
  }
}
```

Replace the full contents of `EVE_MOBILE/app/lib/main.dart` with:

```dart
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  runApp(const EveApp());
}
```

- [ ] **Step 7: Delete the default counter-app test**

```bash
rm -f "D:/Projects/favourites/eve/EVE_MOBILE/app/test/widget_test.dart"
```

(It references a `MyApp` class removed in Step 6. `test/` intentionally has zero test files until Task 2 adds the first one.)

- [ ] **Step 8: Verify the scaffold compiles cleanly**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 9: Commit**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE"
git add app/
git commit -m "chore: scaffold Flutter app and canonical folder structure"
```

---

## Task 2: Firestore path constants

**Files:**
- Create: `EVE_MOBILE/app/lib/core/constants/firestore_paths.dart`
- Test: `EVE_MOBILE/app/test/core/constants/firestore_paths_test.dart`

**Interfaces:**
- Consumes: nothing beyond the Task 1 scaffold.
- Produces: `FirestorePaths` static methods, one per canonical path in design-spec.md §10, consumed by Task 3 (`FirebaseService` callers) and by Plans 1, 5, 7 for every Firestore read/write.

- [ ] **Step 1: Write the failing test**

Create `EVE_MOBILE/app/test/core/constants/firestore_paths_test.dart`:

```dart
import 'package:eve_app/core/constants/firestore_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestorePaths', () {
    test('userDoc returns users/{uid}', () {
      expect(FirestorePaths.userDoc('u1'), 'users/u1');
    });

    test('lifeStageProfile returns users/{uid}/lifeStageProfile/current', () {
      expect(
        FirestorePaths.lifeStageProfile('u1'),
        'users/u1/lifeStageProfile/current',
      );
    });

    test('logsCollection returns users/{uid}/logs', () {
      expect(FirestorePaths.logsCollection('u1'), 'users/u1/logs');
    });

    test('log returns users/{uid}/logs/{logId}', () {
      expect(FirestorePaths.log('u1', 'l1'), 'users/u1/logs/l1');
    });

    test('goalsPreferences returns users/{uid}/preferences/goals', () {
      expect(
        FirestorePaths.goalsPreferences('u1'),
        'users/u1/preferences/goals',
      );
    });

    test(
        'notificationPreferences returns '
        'users/{uid}/preferences/notifications', () {
      expect(
        FirestorePaths.notificationPreferences('u1'),
        'users/u1/preferences/notifications',
      );
    });

    test('aiScope returns users/{uid}/preferences/aiScope', () {
      expect(FirestorePaths.aiScope('u1'), 'users/u1/preferences/aiScope');
    });

    test('theme returns users/{uid}/preferences/theme', () {
      expect(FirestorePaths.theme('u1'), 'users/u1/preferences/theme');
    });

    test('partnerLink returns users/{uid}/partnerLink/current', () {
      expect(
        FirestorePaths.partnerLink('u1'),
        'users/u1/partnerLink/current',
      );
    });

    test(
        'partnerPermissions returns '
        'users/{uid}/partnerPermissions/current', () {
      expect(
        FirestorePaths.partnerPermissions('u1'),
        'users/u1/partnerPermissions/current',
      );
    });

    test('partnerView returns users/{uid}/partnerView/current', () {
      expect(
        FirestorePaths.partnerView('u1'),
        'users/u1/partnerView/current',
      );
    });

    test('partnerLinksReverse returns partnerLinks/{partnerUid}', () {
      expect(FirestorePaths.partnerLinksReverse('p1'), 'partnerLinks/p1');
    });

    test('chatCollection returns users/{uid}/chat', () {
      expect(FirestorePaths.chatCollection('u1'), 'users/u1/chat');
    });

    test('chatMessage returns users/{uid}/chat/{messageId}', () {
      expect(FirestorePaths.chatMessage('u1', 'm1'), 'users/u1/chat/m1');
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/core/constants/firestore_paths_test.dart
```

Expected: FAIL — `Error: Error when reading 'lib/core/constants/firestore_paths.dart': No such file or directory`.

- [ ] **Step 3: Implement `FirestorePaths`**

Create `EVE_MOBILE/app/lib/core/constants/firestore_paths.dart`:

```dart
/// Canonical Firestore path builders. Every path here matches
/// design-spec.md §10 exactly — this is the single source of truth other
/// plans (1, 5, 7) read and write against. Do not invent new paths
/// elsewhere; add a builder here instead.
class FirestorePaths {
  FirestorePaths._();

  static String userDoc(String uid) => 'users/$uid';

  static String lifeStageProfile(String uid) =>
      'users/$uid/lifeStageProfile/current';

  static String logsCollection(String uid) => 'users/$uid/logs';

  static String log(String uid, String logId) => 'users/$uid/logs/$logId';

  static String goalsPreferences(String uid) =>
      'users/$uid/preferences/goals';

  static String notificationPreferences(String uid) =>
      'users/$uid/preferences/notifications';

  static String aiScope(String uid) => 'users/$uid/preferences/aiScope';

  static String theme(String uid) => 'users/$uid/preferences/theme';

  static String partnerLink(String uid) => 'users/$uid/partnerLink/current';

  static String partnerPermissions(String uid) =>
      'users/$uid/partnerPermissions/current';

  static String partnerView(String uid) => 'users/$uid/partnerView/current';

  static String partnerLinksReverse(String partnerUid) =>
      'partnerLinks/$partnerUid';

  static String chatCollection(String uid) => 'users/$uid/chat';

  static String chatMessage(String uid, String messageId) =>
      'users/$uid/chat/$messageId';
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/core/constants/firestore_paths_test.dart
```

Expected: `All tests passed!` (14 tests).

- [ ] **Step 5: Commit**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE"
git add app/lib/core/constants/firestore_paths.dart app/test/core/constants/firestore_paths_test.dart
git commit -m "feat: add canonical Firestore path constants"
```

---

## Task 3: FirebaseService (Auth + Firestore init wrapper)

**Files:**
- Create: `EVE_MOBILE/app/lib/core/services/firebase_service.dart`
- Test: `EVE_MOBILE/app/test/core/services/firebase_service_test.dart`

**Interfaces:**
- Consumes: `firebase_auth`'s `FirebaseAuth`, `cloud_firestore`'s `FirebaseFirestore`, `firebase_core`'s `Firebase.initializeApp()` (all from Task 1's pubspec).
- Produces: `FirebaseService` class with `.auth` (`FirebaseAuth`), `.firestore` (`FirebaseFirestore`) instance getters and a `static Future<void> initializeApp()` bootstrap method. Task 7's `main.dart` calls `FirebaseService.initializeApp()`. Plan 3's `ai_proxy_service.dart` and Plan 1's repositories construct `FirebaseService()` to get typed Auth/Firestore handles — this plan does not implement any AI proxy calls or repository logic, only the wrapper itself.

- [ ] **Step 1: Write the failing test**

Create `EVE_MOBILE/app/test/core/services/firebase_service_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eve_app/core/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

void main() {
  group('FirebaseService', () {
    test('exposes the auth instance it was constructed with', () {
      final mockAuth = MockFirebaseAuth();
      final mockFirestore = MockFirebaseFirestore();

      final service = FirebaseService(
        auth: mockAuth,
        firestore: mockFirestore,
      );

      expect(service.auth, same(mockAuth));
    });

    test('exposes the firestore instance it was constructed with', () {
      final mockAuth = MockFirebaseAuth();
      final mockFirestore = MockFirebaseFirestore();

      final service = FirebaseService(
        auth: mockAuth,
        firestore: mockFirestore,
      );

      expect(service.firestore, same(mockFirestore));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/core/services/firebase_service_test.dart
```

Expected: FAIL — `Error: Error when reading 'lib/core/services/firebase_service.dart': No such file or directory`.

- [ ] **Step 3: Implement `FirebaseService`**

Create `EVE_MOBILE/app/lib/core/services/firebase_service.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Thin, testable wrapper around the two Firebase SDKs this app's core
/// layer needs directly: Auth and Firestore. AI proxy calls and any
/// Cloud Functions invocation live in `ai_proxy_service.dart` (Plan 3),
/// not here.
///
/// Accepts optional `auth`/`firestore` instances so tests can inject
/// mocks instead of touching the real Firebase SDKs (which require
/// native platform initialization `flutter test` does not provide).
class FirebaseService {
  FirebaseService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  /// Initializes the Firebase app. Must be called once, before
  /// `runApp`, with `WidgetsFlutterBinding.ensureInitialized()` called
  /// first. Requires the native `google-services.json` /
  /// `GoogleService-Info.plist` config files Plan 3 sets up — not
  /// exercised by this plan's unit tests.
  static Future<void> initializeApp() => Firebase.initializeApp();
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/core/services/firebase_service_test.dart
```

Expected: `All tests passed!` (2 tests).

- [ ] **Step 5: Commit**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE"
git add app/lib/core/services/firebase_service.dart app/test/core/services/firebase_service_test.dart
git commit -m "feat: add FirebaseService Auth/Firestore wrapper"
```

---

## Task 4: EveTheme (light / dark / default)

**Files:**
- Create: `EVE_MOBILE/app/lib/core/theme/eve_theme.dart`
- Test: `EVE_MOBILE/app/test/core/theme/eve_theme_test.dart`

**Interfaces:**
- Consumes: `google_fonts` package (Task 1's pubspec).
- Produces: `EveColors` (8 named color constants) and `EveTheme.defaultTheme()`, `EveTheme.light()`, `EveTheme.dark()` — all `ThemeData`. Task 7's `app.dart` calls `EveTheme.defaultTheme()`/`EveTheme.dark()`. Plan 1's onboarding Theme screen reads `EveColors` and calls these three factories by name when the user picks light/dark/default.

- [ ] **Step 1: Write the failing test**

Create `EVE_MOBILE/app/test/core/theme/eve_theme_test.dart`:

```dart
import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    // Prevent google_fonts from attempting a network fetch during tests;
    // fall back to the bundled/system font instead.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('EveColors', () {
    test('matches the locked brand hex values', () {
      expect(EveColors.rubyMain, const Color(0xFFFF2A6D));
      expect(EveColors.rubyDark, const Color(0xFF2A000E));
      expect(EveColors.rubyBlush, const Color(0xFFFFA0B8));
      expect(EveColors.rubySoft, const Color(0xFFFFF0F4));
      expect(EveColors.partnerBlue, const Color(0xFF3D7BFF));
      expect(EveColors.fertileTeal, const Color(0xFF2EC4B6));
      expect(EveColors.symptomPurple, const Color(0xFF9B51E0));
      expect(EveColors.appointmentOrange, const Color(0xFFFF9F1C));
    });
  });

  group('EveTheme', () {
    Future<ThemeData> resolve(ThemeData theme, WidgetTester tester) async {
      late ThemeData resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              resolved = Theme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return resolved;
    }

    testWidgets('defaultTheme is light, ruby-branded, on a soft background',
        (tester) async {
      final theme = await resolve(EveTheme.defaultTheme(), tester);

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, EveColors.rubyMain);
      expect(theme.scaffoldBackgroundColor, EveColors.rubySoft);
    });

    testWidgets('light is a plain light theme on a white background',
        (tester) async {
      final theme = await resolve(EveTheme.light(), tester);

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, EveColors.rubyMain);
      expect(theme.scaffoldBackgroundColor, Colors.white);
    });

    testWidgets('dark uses ruby-dark as the background with the same accent',
        (tester) async {
      final theme = await resolve(EveTheme.dark(), tester);

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, EveColors.rubyMain);
      expect(theme.scaffoldBackgroundColor, EveColors.rubyDark);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/core/theme/eve_theme_test.dart
```

Expected: FAIL — `Error: Error when reading 'lib/core/theme/eve_theme.dart': No such file or directory`.

- [ ] **Step 3: Implement `EveTheme`**

Create `EVE_MOBILE/app/lib/core/theme/eve_theme.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// EVE's brand color tokens, ported 1:1 from the CSS custom properties in
/// `UI/mobile/mockv4.html`. Do not redefine these elsewhere — import this
/// class instead.
class EveColors {
  EveColors._();

  static const Color rubyMain = Color(0xFFFF2A6D);
  static const Color rubyDark = Color(0xFF2A000E);
  static const Color rubyBlush = Color(0xFFFFA0B8);
  static const Color rubySoft = Color(0xFFFFF0F4);
  static const Color partnerBlue = Color(0xFF3D7BFF);
  static const Color fertileTeal = Color(0xFF2EC4B6);
  static const Color symptomPurple = Color(0xFF9B51E0);
  static const Color appointmentOrange = Color(0xFFFF9F1C);
}

/// Central theme factory for EVE. Produces the three `ThemeData` modes
/// offered on the onboarding Theme screen and consumed by `app.dart`:
/// `defaultTheme`, `light`, and `dark`.
class EveTheme {
  EveTheme._();

  static TextTheme _textTheme(Color bodyColor, Color displayColor) {
    return TextTheme(
      displayLarge: GoogleFonts.fredoka(
        color: displayColor,
        fontSize: 32,
        fontWeight: FontWeight.w600,
      ),
      displayMedium: GoogleFonts.fredoka(
        color: displayColor,
        fontSize: 26,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.fredoka(
        color: displayColor,
        fontSize: 22,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: GoogleFonts.quicksand(color: bodyColor, fontSize: 16),
      bodyMedium: GoogleFonts.quicksand(color: bodyColor, fontSize: 14),
      labelLarge: GoogleFonts.quicksand(
        color: bodyColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// The app's default branded theme: ruby palette on a soft blush
  /// background. Used before the onboarding Theme screen sets an
  /// explicit preference.
  static ThemeData defaultTheme() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: EveColors.rubySoft,
      colorScheme: const ColorScheme.light(
        primary: EveColors.rubyMain,
        secondary: EveColors.fertileTeal,
        surface: EveColors.rubySoft,
        error: EveColors.appointmentOrange,
      ),
      textTheme: _textTheme(EveColors.rubyDark, EveColors.rubyDark),
    );
  }

  /// A plain light theme: same ruby accent, neutral white surfaces.
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: EveColors.rubyMain,
        secondary: EveColors.fertileTeal,
        surface: Colors.white,
        error: EveColors.appointmentOrange,
      ),
      textTheme: _textTheme(EveColors.rubyDark, EveColors.rubyDark),
    );
  }

  /// The dark theme: ruby-dark background, same ruby-main accent, blush
  /// text for contrast.
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: EveColors.rubyDark,
      colorScheme: const ColorScheme.dark(
        primary: EveColors.rubyMain,
        secondary: EveColors.fertileTeal,
        surface: EveColors.rubyDark,
        error: EveColors.appointmentOrange,
      ),
      textTheme: _textTheme(EveColors.rubyBlush, EveColors.rubyBlush),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/core/theme/eve_theme_test.dart
```

Expected: `All tests passed!` (4 tests).

- [ ] **Step 5: Commit**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE"
git add app/lib/core/theme/eve_theme.dart app/test/core/theme/eve_theme_test.dart
git commit -m "feat: add EveTheme light/dark/default ThemeData"
```

---

## Task 5: OnboardingState model and `onboardingStateProvider`

> **Reconciliation note (post-parallel-drafting):** this task originally typed `OnboardingState` fields (`int? age`, `double? height`, `LifeStage? lifeStage`, etc.) and exposed a single `updateFields({...32 named params})` entry point. Plan 1 (`01-core-workflow.md`), written in parallel, needed a generic per-field write API to keep 20+ screen widgets simple and committed to a concrete contract in its Global Constraints section: **all fields are `String`/`List<String>` (mirroring the mock's raw HTML-form-input `surveyState` exactly, never parsed into `int`/`double`/enum at this layer), and the notifier exposes `setField(String field, Object? value)` + `toggleListField(String field, String value)`.** Rewritten below to match Plan 1's contract verbatim, since 26 already-written tasks in Plan 1 depend on it and only this one task needs to change. The domain-level `LifeStage` enum used by Task 6's `activeModules` is unaffected — see the reconciliation note at the top of Task 6 for how the two are bridged.

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/domain/onboarding_state.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/domain/onboarding_state_test.dart`

**Interfaces:**
- Consumes: `flutter_riverpod` (Task 1's pubspec).
- Produces: `OnboardingState` (immutable, one `String`/`List<String>`/`bool` field per design-spec.md §6, defaults to `''`/`const []`/`false` — never `null`, so screens can interpolate fields directly without null-checks); `OnboardingNotifier` (`StateNotifier<OnboardingState>` with `setField(String field, Object? value)`, `toggleListField(String field, String value)`, and `reset()`); `onboardingStateProvider` (`StateNotifierProvider<OnboardingNotifier, OnboardingState>`) — the exact name design-spec.md §10 fixes. Plan 1's onboarding screens call `ref.read(onboardingStateProvider.notifier).setField('name', v)` / `.toggleListField('cycleSymptoms', v)` and read `ref.watch(onboardingStateProvider)`.

- [ ] **Step 1: Write the failing test**

Create `EVE_MOBILE/app/test/features/onboarding/domain/onboarding_state_test.dart`:

```dart
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('onboardingStateProvider', () {
    test('starts with an empty OnboardingState', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(onboardingStateProvider);

      expect(state.name, '');
      expect(state.lifeStage, isNull);
      expect(state.cycleSymptoms, isEmpty);
    });

    test('setField writes a scalar field and exposes it via the provider',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(onboardingStateProvider.notifier)
          .setField('lifeStage', 'pregnant');

      expect(
        container.read(onboardingStateProvider).lifeStage,
        'pregnant',
      );
    });

    test('setField merges new values without clobbering unrelated ones', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(onboardingStateProvider.notifier);
      notifier.setField('name', 'Asha');
      notifier.setField('age', '29');
      notifier.setField('country', 'India');

      final state = container.read(onboardingStateProvider);
      expect(state.name, 'Asha');
      expect(state.age, '29');
      expect(state.country, 'India');
    });

    test('toggleListField adds a value on first toggle and removes it on '
        'second toggle', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(onboardingStateProvider.notifier);
      notifier.toggleListField('cycleSymptoms', 'cramps');
      notifier.toggleListField('cycleSymptoms', 'bloating');

      expect(
        container.read(onboardingStateProvider).cycleSymptoms,
        ['cramps', 'bloating'],
      );

      notifier.toggleListField('cycleSymptoms', 'cramps');

      expect(
        container.read(onboardingStateProvider).cycleSymptoms,
        ['bloating'],
      );
    });

    test('reset restores the initial empty state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(onboardingStateProvider.notifier);
      notifier.setField('name', 'Asha');
      notifier.reset();

      expect(container.read(onboardingStateProvider).name, '');
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/onboarding/domain/onboarding_state_test.dart
```

Expected: FAIL — `Error: Error when reading 'lib/features/onboarding/domain/onboarding_state.dart': No such file or directory`.

- [ ] **Step 3: Implement `OnboardingState` and `OnboardingNotifier`**

Create `EVE_MOBILE/app/lib/features/onboarding/domain/onboarding_state.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mirrors the mock's `surveyState` object field-for-field
/// (design-spec.md §6), including its types: every field is the raw
/// string/list/bool value an HTML form input would produce — never parsed
/// into int/double/enum at this layer. `lifeStage` holds the raw selector
/// value ('cycle' | 'conceive' | 'pregnant' | 'postpartum' | 'menopause'),
/// matching `mockv4.html`'s `selectLifeStage()` calls exactly. Every
/// onboarding screen writes into one or more of these fields via
/// [OnboardingNotifier.setField] / [OnboardingNotifier.toggleListField].
class OnboardingState {
  const OnboardingState({
    this.name,
    this.age,
    this.height,
    this.weight,
    this.country,
    this.lifeStage,
    this.cycleLength = '',
    this.periodLength = '',
    this.flow = '',
    this.cycleSymptoms = const [],
    this.cycleGoals = const [],
    this.nutritionDiet = '',
    this.dueDate = '',
    this.dueMethod = '',
    this.highRisk = '',
    this.pregnancyType = '',
    this.medications = '',
    this.allergies = '',
    this.prenatalVitamins = '',
    this.pregnantSymptoms = const [],
    this.foodAllergies = '',
    this.cuisines = const [],
    this.workouts = const [],
    this.notifications = const [],
    this.aiScope = const [],
    this.partnerInvite = false,
    this.partnerRelation = '',
    this.partnerPermissions = const [],
    this.onlyApproveMaster = false,
    this.theme = '',
    this.simplifiedSymptoms = const [],
    this.simplifiedGoals = const [],
  });

  final String name, age, height, weight, country;
  final String? lifeStage;
  final String cycleLength, periodLength, flow;
  final List<String> cycleSymptoms, cycleGoals;
  final String nutritionDiet;
  final String dueDate,
      dueMethod,
      highRisk,
      pregnancyType,
      medications,
      allergies,
      prenatalVitamins;
  final List<String> pregnantSymptoms;
  final String foodAllergies;
  final List<String> cuisines, workouts, notifications, aiScope;
  final bool partnerInvite;
  final String partnerRelation;
  final List<String> partnerPermissions;
  final bool onlyApproveMaster;
  final String theme;
  final List<String> simplifiedSymptoms, simplifiedGoals;

  OnboardingState copyWith({
    String? name,
    String? age,
    String? height,
    String? weight,
    String? country,
    String? lifeStage,
    String? cycleLength,
    String? periodLength,
    String? flow,
    List<String>? cycleSymptoms,
    List<String>? cycleGoals,
    String? nutritionDiet,
    String? dueDate,
    String? dueMethod,
    String? highRisk,
    String? pregnancyType,
    String? medications,
    String? allergies,
    String? prenatalVitamins,
    List<String>? pregnantSymptoms,
    String? foodAllergies,
    List<String>? cuisines,
    List<String>? workouts,
    List<String>? notifications,
    List<String>? aiScope,
    bool? partnerInvite,
    String? partnerRelation,
    List<String>? partnerPermissions,
    bool? onlyApproveMaster,
    String? theme,
    List<String>? simplifiedSymptoms,
    List<String>? simplifiedGoals,
  }) {
    return OnboardingState(
      name: name ?? this.name,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      country: country ?? this.country,
      lifeStage: lifeStage ?? this.lifeStage,
      cycleLength: cycleLength ?? this.cycleLength,
      periodLength: periodLength ?? this.periodLength,
      flow: flow ?? this.flow,
      cycleSymptoms: cycleSymptoms ?? this.cycleSymptoms,
      cycleGoals: cycleGoals ?? this.cycleGoals,
      nutritionDiet: nutritionDiet ?? this.nutritionDiet,
      dueDate: dueDate ?? this.dueDate,
      dueMethod: dueMethod ?? this.dueMethod,
      highRisk: highRisk ?? this.highRisk,
      pregnancyType: pregnancyType ?? this.pregnancyType,
      medications: medications ?? this.medications,
      allergies: allergies ?? this.allergies,
      prenatalVitamins: prenatalVitamins ?? this.prenatalVitamins,
      pregnantSymptoms: pregnantSymptoms ?? this.pregnantSymptoms,
      foodAllergies: foodAllergies ?? this.foodAllergies,
      cuisines: cuisines ?? this.cuisines,
      workouts: workouts ?? this.workouts,
      notifications: notifications ?? this.notifications,
      aiScope: aiScope ?? this.aiScope,
      partnerInvite: partnerInvite ?? this.partnerInvite,
      partnerRelation: partnerRelation ?? this.partnerRelation,
      partnerPermissions: partnerPermissions ?? this.partnerPermissions,
      onlyApproveMaster: onlyApproveMaster ?? this.onlyApproveMaster,
      theme: theme ?? this.theme,
      simplifiedSymptoms: simplifiedSymptoms ?? this.simplifiedSymptoms,
      simplifiedGoals: simplifiedGoals ?? this.simplifiedGoals,
    );
  }
}

/// Field names accepted by [OnboardingNotifier.setField] — every scalar
/// (`String`/`bool`) field in [OnboardingState]. Kept as a constant so a
/// typo in a screen's `setField('lifeStag', ...)` call fails loudly via
/// `ArgumentError` instead of silently no-op-ing.
const _scalarFields = {
  'name', 'age', 'height', 'weight', 'country', 'lifeStage', 'cycleLength',
  'periodLength', 'flow', 'nutritionDiet', 'dueDate', 'dueMethod',
  'highRisk', 'pregnancyType', 'medications', 'allergies',
  'prenatalVitamins', 'foodAllergies', 'partnerInvite', 'partnerRelation',
  'onlyApproveMaster', 'theme',
};

/// Field names accepted by [OnboardingNotifier.toggleListField] — every
/// `List<String>` field in [OnboardingState].
const _listFields = {
  'cycleSymptoms', 'cycleGoals', 'pregnantSymptoms', 'cuisines', 'workouts',
  'notifications', 'aiScope', 'partnerPermissions', 'simplifiedSymptoms',
  'simplifiedGoals',
};

/// Holds and mutates [OnboardingState] across every onboarding screen.
/// Mirrors the mock's dynamic `surveyState[key] = val` / `toggleMultiSelect`
/// pattern (design-spec.md §4/§6) with two generic entry points rather than
/// 32 individually-named setters, so every screen widget in Plan 1
/// (`01-core-workflow.md`) can write to any field through the same two
/// methods — e.g. the Life-Stage screen calls
/// `setField('lifeStage', 'pregnant')`, the Cycle Symptoms screen calls
/// `toggleListField('cycleSymptoms', 'cramps')`.
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  /// Writes a single scalar (`String` or `bool`) field by name.
  void setField(String field, Object? value) {
    if (!_scalarFields.contains(field)) {
      throw ArgumentError.value(field, 'field', 'Not a known scalar field');
    }
    switch (field) {
      case 'name':
        state = state.copyWith(name: value as String);
      case 'age':
        state = state.copyWith(age: value as String);
      case 'height':
        state = state.copyWith(height: value as String);
      case 'weight':
        state = state.copyWith(weight: value as String);
      case 'country':
        state = state.copyWith(country: value as String);
      case 'lifeStage':
        state = state.copyWith(lifeStage: value as String);
      case 'cycleLength':
        state = state.copyWith(cycleLength: value as String);
      case 'periodLength':
        state = state.copyWith(periodLength: value as String);
      case 'flow':
        state = state.copyWith(flow: value as String);
      case 'nutritionDiet':
        state = state.copyWith(nutritionDiet: value as String);
      case 'dueDate':
        state = state.copyWith(dueDate: value as String);
      case 'dueMethod':
        state = state.copyWith(dueMethod: value as String);
      case 'highRisk':
        state = state.copyWith(highRisk: value as String);
      case 'pregnancyType':
        state = state.copyWith(pregnancyType: value as String);
      case 'medications':
        state = state.copyWith(medications: value as String);
      case 'allergies':
        state = state.copyWith(allergies: value as String);
      case 'prenatalVitamins':
        state = state.copyWith(prenatalVitamins: value as String);
      case 'foodAllergies':
        state = state.copyWith(foodAllergies: value as String);
      case 'partnerInvite':
        state = state.copyWith(partnerInvite: value as bool);
      case 'partnerRelation':
        state = state.copyWith(partnerRelation: value as String);
      case 'onlyApproveMaster':
        state = state.copyWith(onlyApproveMaster: value as bool);
      case 'theme':
        state = state.copyWith(theme: value as String);
    }
  }

  /// Toggles membership of [value] in the named `List<String>` field —
  /// adds it if absent, removes it if present. Mirrors the mock's
  /// `toggleMultiSelect(key, value, el)`.
  void toggleListField(String field, String value) {
    if (!_listFields.contains(field)) {
      throw ArgumentError.value(field, 'field', 'Not a known list field');
    }
    List<String> current;
    switch (field) {
      case 'cycleSymptoms':
        current = state.cycleSymptoms;
      case 'cycleGoals':
        current = state.cycleGoals;
      case 'pregnantSymptoms':
        current = state.pregnantSymptoms;
      case 'cuisines':
        current = state.cuisines;
      case 'workouts':
        current = state.workouts;
      case 'notifications':
        current = state.notifications;
      case 'aiScope':
        current = state.aiScope;
      case 'partnerPermissions':
        current = state.partnerPermissions;
      case 'simplifiedSymptoms':
        current = state.simplifiedSymptoms;
      case 'simplifiedGoals':
        current = state.simplifiedGoals;
      default:
        return;
    }
    final next = current.contains(value)
        ? (List<String>.from(current)..remove(value))
        : (List<String>.from(current)..add(value));
    switch (field) {
      case 'cycleSymptoms':
        state = state.copyWith(cycleSymptoms: next);
      case 'cycleGoals':
        state = state.copyWith(cycleGoals: next);
      case 'pregnantSymptoms':
        state = state.copyWith(pregnantSymptoms: next);
      case 'cuisines':
        state = state.copyWith(cuisines: next);
      case 'workouts':
        state = state.copyWith(workouts: next);
      case 'notifications':
        state = state.copyWith(notifications: next);
      case 'aiScope':
        state = state.copyWith(aiScope: next);
      case 'partnerPermissions':
        state = state.copyWith(partnerPermissions: next);
      case 'simplifiedSymptoms':
        state = state.copyWith(simplifiedSymptoms: next);
      case 'simplifiedGoals':
        state = state.copyWith(simplifiedGoals: next);
    }
  }

  /// Restores the initial empty state — used when a user restarts
  /// onboarding or signs out.
  void reset() => state = const OnboardingState();
}

/// The cross-plan state contract fixed by design-spec.md §10. Plan 1's
/// onboarding screens and this plan's own consumers reference this exact
/// provider name.
final onboardingStateProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(),
);
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/onboarding/domain/onboarding_state_test.dart
```

Expected: `All tests passed!` (5 tests).

- [ ] **Step 5: Commit**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE"
git add app/lib/features/onboarding/domain/onboarding_state.dart app/test/features/onboarding/domain/onboarding_state_test.dart
git commit -m "feat: add OnboardingState model and onboardingStateProvider"
```

---

## Task 6: Module-activation lookup

**Files:**
- Create: `EVE_MOBILE/app/lib/features/home/domain/module_activation.dart`
- Test: `EVE_MOBILE/app/test/features/home/domain/module_activation_test.dart`

**Interfaces:**
- Consumes: nothing from Task 5 — `LifeStage` is defined in this file, not in `onboarding_state.dart`. (**Reconciliation note:** Task 5 was rewritten to match Plan 1's contract, which stores `lifeStage` as the raw onboarding-selector `String` — `'cycle' | 'conceive' | 'pregnant' | 'postpartum' | 'menopause'` — not this domain enum. `LifeStage` lives here instead, and `lifeStageFromSurveyValue` below is the adapter between the two. Note the name mismatch this bridges: the survey's raw value is `'menopause'`, the domain enum's value is `LifeStage.perimenopause`.)
- Produces: `Module` enum (7 values), `LifeStage` enum (5 values: `cycle, conceive, pregnant, postpartum, perimenopause`), `LifeStage? lifeStageFromSurveyValue(String raw)`, and `List<Module> activeModules(LifeStage stage)` — the exact `activeModules` name/signature design-spec.md §10 fixes. Plan 4's Home screen wiring calls `activeModules(lifeStageFromSurveyValue(ref.watch(onboardingStateProvider).lifeStage!)!)` to decide which bento-grid cards to render.

- [ ] **Step 1: Write the failing test**

Create `EVE_MOBILE/app/test/features/home/domain/module_activation_test.dart`:

```dart
import 'package:eve_app/features/home/domain/module_activation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('activeModules', () {
    test(
        'cycle (general tracking) returns cycle, symptom, nutrition, '
        'partner, and doctor-summary modules', () {
      expect(
        activeModules(LifeStage.cycle),
        unorderedEquals(<Module>[
          Module.cycleOvulationTracking,
          Module.symptomMoodLogging,
          Module.nutritionFitness,
          Module.partnerMode,
          Module.doctorSummaryExport,
        ]),
      );
    });

    test('conceive returns the same module set as general tracking', () {
      expect(
        activeModules(LifeStage.conceive),
        unorderedEquals(<Module>[
          Module.cycleOvulationTracking,
          Module.symptomMoodLogging,
          Module.nutritionFitness,
          Module.partnerMode,
          Module.doctorSummaryExport,
        ]),
      );
    });

    test(
        'pregnant excludes cycle tracking and postpartum recovery, '
        'includes pregnancy milestones', () {
      expect(
        activeModules(LifeStage.pregnant),
        unorderedEquals(<Module>[
          Module.symptomMoodLogging,
          Module.nutritionFitness,
          Module.pregnancyMilestones,
          Module.partnerMode,
          Module.doctorSummaryExport,
        ]),
      );
    });

    test(
        'postpartum excludes cycle tracking and pregnancy milestones, '
        'includes postpartum recovery', () {
      expect(
        activeModules(LifeStage.postpartum),
        unorderedEquals(<Module>[
          Module.symptomMoodLogging,
          Module.nutritionFitness,
          Module.postpartumRecovery,
          Module.partnerMode,
          Module.doctorSummaryExport,
        ]),
      );
    });

    test(
        'perimenopause excludes cycle tracking, pregnancy milestones, '
        'and postpartum recovery', () {
      expect(
        activeModules(LifeStage.perimenopause),
        unorderedEquals(<Module>[
          Module.symptomMoodLogging,
          Module.nutritionFitness,
          Module.partnerMode,
          Module.doctorSummaryExport,
        ]),
      );
    });

    test('symptomMoodLogging and doctorSummaryExport are present for every '
        'life stage', () {
      for (final stage in LifeStage.values) {
        expect(activeModules(stage), contains(Module.symptomMoodLogging));
        expect(activeModules(stage), contains(Module.doctorSummaryExport));
      }
    });
  });

  group('lifeStageFromSurveyValue', () {
    test('maps every raw onboarding selector value to its LifeStage', () {
      expect(lifeStageFromSurveyValue('cycle'), LifeStage.cycle);
      expect(lifeStageFromSurveyValue('conceive'), LifeStage.conceive);
      expect(lifeStageFromSurveyValue('pregnant'), LifeStage.pregnant);
      expect(lifeStageFromSurveyValue('postpartum'), LifeStage.postpartum);
      expect(lifeStageFromSurveyValue('menopause'), LifeStage.perimenopause);
    });

    test('returns null for an empty or unrecognized value', () {
      expect(lifeStageFromSurveyValue(''), isNull);
      expect(lifeStageFromSurveyValue('not-a-stage'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/home/domain/module_activation_test.dart
```

Expected: FAIL — `Error: Error when reading 'lib/features/home/domain/module_activation.dart': No such file or directory`.

- [ ] **Step 3: Implement `Module` and `activeModules`**

Create `EVE_MOBILE/app/lib/features/home/domain/module_activation.dart`:

```dart
/// The five life stages selectable on the onboarding Life-Stage screen,
/// as a domain enum. Note this is a *different* representation from
/// `OnboardingState.lifeStage` (a raw `String`, matching the mock's
/// `surveyState` field-for-field per design-spec.md §6) — use
/// [lifeStageFromSurveyValue] to convert between the two.
enum LifeStage { cycle, conceive, pregnant, postpartum, perimenopause }

/// Converts the raw onboarding-selector value stored in
/// `OnboardingState.lifeStage` (`'cycle' | 'conceive' | 'pregnant' |
/// 'postpartum' | 'menopause'`, per `mockv4.html`'s `selectLifeStage()`
/// calls) into the domain [LifeStage] enum. Note the one name mismatch:
/// the survey's raw value is `'menopause'`, mapped here to
/// `LifeStage.perimenopause`. Returns `null` for an empty or unrecognized
/// value (e.g. before onboarding's Life-Stage screen has been completed).
LifeStage? lifeStageFromSurveyValue(String raw) {
  switch (raw) {
    case 'cycle':
      return LifeStage.cycle;
    case 'conceive':
      return LifeStage.conceive;
    case 'pregnant':
      return LifeStage.pregnant;
    case 'postpartum':
      return LifeStage.postpartum;
    case 'menopause':
      return LifeStage.perimenopause;
    default:
      return null;
  }
}

/// The seven modules whose visibility on Home is driven by life stage,
/// per EVE2_PRD.md §5's personalization table.
enum Module {
  cycleOvulationTracking,
  symptomMoodLogging,
  nutritionFitness,
  pregnancyMilestones,
  postpartumRecovery,
  partnerMode,
  doctorSummaryExport,
}

/// Pure, on-device lookup from a stored [LifeStage] to the modules
/// visible on that user's Home dashboard. No backend round-trip needed —
/// per EVE2_PRD.md §10.3, the active module set is computable entirely
/// client-side from `lifeStage`.
///
/// `partnerMode` is marked "Optional" for every life stage in the
/// personalization table (EVE2_PRD.md §5): it is never life-stage-gated,
/// only user-consent-gated via `partnerInvite`. This function returns it
/// as always-eligible for every stage; whether it is actually shown
/// depends on the user's partner-invite status, which is outside this
/// function's scope.
List<Module> activeModules(LifeStage stage) {
  switch (stage) {
    case LifeStage.cycle:
      return const [
        Module.cycleOvulationTracking,
        Module.symptomMoodLogging,
        Module.nutritionFitness,
        Module.partnerMode,
        Module.doctorSummaryExport,
      ];
    case LifeStage.conceive:
      return const [
        Module.cycleOvulationTracking,
        Module.symptomMoodLogging,
        Module.nutritionFitness,
        Module.partnerMode,
        Module.doctorSummaryExport,
      ];
    case LifeStage.pregnant:
      return const [
        Module.symptomMoodLogging,
        Module.nutritionFitness,
        Module.pregnancyMilestones,
        Module.partnerMode,
        Module.doctorSummaryExport,
      ];
    case LifeStage.postpartum:
      return const [
        Module.symptomMoodLogging,
        Module.nutritionFitness,
        Module.postpartumRecovery,
        Module.partnerMode,
        Module.doctorSummaryExport,
      ];
    case LifeStage.perimenopause:
      return const [
        Module.symptomMoodLogging,
        Module.nutritionFitness,
        Module.partnerMode,
        Module.doctorSummaryExport,
      ];
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/features/home/domain/module_activation_test.dart
```

Expected: `All tests passed!` (8 tests).

- [ ] **Step 5: Commit**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE"
git add app/lib/features/home/domain/module_activation.dart app/test/features/home/domain/module_activation_test.dart
git commit -m "feat: add module-activation lookup (activeModules)"
```

---

## Task 7: App router and navigation shell

**Files:**
- Create: `EVE_MOBILE/app/lib/core/router/app_router.dart`
- Modify: `EVE_MOBILE/app/lib/app.dart`
- Modify: `EVE_MOBILE/app/lib/main.dart`
- Test: `EVE_MOBILE/app/test/core/router/app_router_test.dart`
- Test: `EVE_MOBILE/app/test/app_test.dart`

**Interfaces:**
- Consumes: `go_router` (Task 1's pubspec), `EveTheme` (Task 4), `FirebaseService` (Task 3), `flutter_riverpod`'s `ProviderScope`/`ConsumerWidget`.
- Produces: `appRouter` (`GoRouter`, top-level final) with one named route per screen ID from design-spec.md §5 and §7; `RouteLabelScreen` (placeholder widget Plan 1 replaces route-by-route); `EveApp` (`ConsumerWidget`, the `MaterialApp.router` root). Plan 1 replaces each `RouteLabelScreen` builder in `appRouter`'s route table with the real screen widget for that route — it does not need to touch the route table's paths/names, only the `builder:` callbacks.

- [ ] **Step 1: Write the failing tests**

Create `EVE_MOBILE/app/test/core/router/app_router_test.dart`:

```dart
import 'package:eve_app/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _expectedRoutePaths = <String>{
  '/onboarding/welcome',
  '/onboarding/auth',
  '/onboarding/profile',
  '/onboarding/lifestage',
  '/onboarding/cycle-info',
  '/onboarding/cycle-symptoms',
  '/onboarding/cycle-goals',
  '/onboarding/pregnant-due',
  '/onboarding/pregnant-meds',
  '/onboarding/pregnant-symptoms',
  '/onboarding/simplified-branch',
  '/onboarding/food',
  '/onboarding/workout',
  '/onboarding/notifications',
  '/onboarding/ai-scope',
  '/onboarding/partner-ask',
  '/onboarding/partner-rel',
  '/onboarding/partner-perm',
  '/onboarding/theme',
  '/onboarding/completion',
  '/home',
  '/chat',
  '/log',
};

void main() {
  setUp(() {
    appRouter.go('/onboarding/welcome');
  });

  test(
      'appRouter declares every screen ID from design-spec.md §5 and §7',
      () {
    final paths = appRouter.configuration.routes
        .whereType<GoRoute>()
        .map((route) => route.path)
        .toSet();

    expect(paths, equals(_expectedRoutePaths));
  });

  testWidgets('initial location renders the welcome placeholder',
      (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
    await tester.pumpAndSettle();

    expect(find.text('onboarding-welcome'), findsOneWidget);
  });

  testWidgets('navigating to /home renders the home placeholder',
      (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
    await tester.pumpAndSettle();

    appRouter.go('/home');
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets(
      'navigating to /onboarding/lifestage renders that placeholder',
      (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
    await tester.pumpAndSettle();

    appRouter.go('/onboarding/lifestage');
    await tester.pumpAndSettle();

    expect(find.text('onboarding-lifestage'), findsOneWidget);
  });
}
```

Create `EVE_MOBILE/app/test/app_test.dart`:

```dart
import 'package:eve_app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('EveApp boots to the onboarding welcome placeholder',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EveApp()));
    await tester.pumpAndSettle();

    expect(find.text('onboarding-welcome'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/core/router/app_router_test.dart test/app_test.dart
```

Expected: FAIL — `Error: Error when reading 'lib/core/router/app_router.dart': No such file or directory`.

- [ ] **Step 3: Implement `app_router.dart`**

Create `EVE_MOBILE/app/lib/core/router/app_router.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Temporary placeholder for every route this app declares. Plan 1
/// (`01-core-workflow.md`) replaces each of these `builder:` callbacks
/// with the real screen widget for that route; this plan only needs the
/// route table and navigation shell to exist and be testable.
class RouteLabelScreen extends StatelessWidget {
  const RouteLabelScreen({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(label, key: const Key('routeLabel')),
      ),
    );
  }
}

GoRoute _placeholderRoute(String path, String name) {
  return GoRoute(
    path: path,
    name: name,
    builder: (context, state) => RouteLabelScreen(label: name),
  );
}

/// The app-wide route table. Every screen ID from design-spec.md §5 (the
/// onboarding sequence) and §7 (Home/Chat/Log) has a named route here.
/// `/onboarding/simplified-branch` is intentionally a single shared route
/// for the conceive/postpartum/perimenopause branches — design-spec.md §5
/// itself calls this "a single screen-simplified-branch"; the screen
/// reads `lifeStage` off `onboardingStateProvider` to vary its copy.
final GoRouter appRouter = GoRouter(
  initialLocation: '/onboarding/welcome',
  routes: [
    _placeholderRoute('/onboarding/welcome', 'onboarding-welcome'),
    _placeholderRoute('/onboarding/auth', 'onboarding-auth'),
    _placeholderRoute('/onboarding/profile', 'onboarding-profile'),
    _placeholderRoute('/onboarding/lifestage', 'onboarding-lifestage'),
    _placeholderRoute('/onboarding/cycle-info', 'onboarding-cycle-info'),
    _placeholderRoute(
      '/onboarding/cycle-symptoms',
      'onboarding-cycle-symptoms',
    ),
    _placeholderRoute('/onboarding/cycle-goals', 'onboarding-cycle-goals'),
    _placeholderRoute('/onboarding/pregnant-due', 'onboarding-pregnant-due'),
    _placeholderRoute(
      '/onboarding/pregnant-meds',
      'onboarding-pregnant-meds',
    ),
    _placeholderRoute(
      '/onboarding/pregnant-symptoms',
      'onboarding-pregnant-symptoms',
    ),
    _placeholderRoute(
      '/onboarding/simplified-branch',
      'onboarding-simplified-branch',
    ),
    _placeholderRoute('/onboarding/food', 'onboarding-food'),
    _placeholderRoute('/onboarding/workout', 'onboarding-workout'),
    _placeholderRoute(
      '/onboarding/notifications',
      'onboarding-notifications',
    ),
    _placeholderRoute('/onboarding/ai-scope', 'onboarding-ai-scope'),
    _placeholderRoute('/onboarding/partner-ask', 'onboarding-partner-ask'),
    _placeholderRoute('/onboarding/partner-rel', 'onboarding-partner-rel'),
    _placeholderRoute('/onboarding/partner-perm', 'onboarding-partner-perm'),
    _placeholderRoute('/onboarding/theme', 'onboarding-theme'),
    _placeholderRoute('/onboarding/completion', 'onboarding-completion'),
    _placeholderRoute('/home', 'home'),
    _placeholderRoute('/chat', 'chat'),
    _placeholderRoute('/log', 'log'),
  ],
);
```

- [ ] **Step 4: Wire `app.dart` and `main.dart` to the router, theme, and Firebase**

Replace the full contents of `EVE_MOBILE/app/lib/app.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/eve_theme.dart';

/// The MaterialApp/router root. Screens are supplied by the route table
/// in `core/router/app_router.dart`; Plan 1 replaces the placeholder
/// screens currently wired there with the real onboarding/Home/Chat/Log
/// widgets.
class EveApp extends ConsumerWidget {
  const EveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'EVE',
      debugShowCheckedModeBanner: false,
      theme: EveTheme.defaultTheme(),
      darkTheme: EveTheme.dark(),
      routerConfig: appRouter,
    );
  }
}
```

Replace the full contents of `EVE_MOBILE/app/lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initializeApp();
  runApp(const ProviderScope(child: EveApp()));
}
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test test/core/router/app_router_test.dart test/app_test.dart
```

Expected: `All tests passed!` (5 tests: 4 in `app_router_test.dart`, 1 in `app_test.dart`).

- [ ] **Step 6: Run the full test suite and static analysis**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE/app"
flutter test
flutter analyze
```

Expected: all tests pass (30 tests across Tasks 2–7 combined: 14 + 2 + 4 + 5 + 6 + 5 — `flutter test` prints the running total), and `flutter analyze` prints `No issues found!`.

- [ ] **Step 7: Commit**

```bash
cd "D:/Projects/favourites/eve/EVE_MOBILE"
git add app/lib/core/router/app_router.dart app/lib/app.dart app/lib/main.dart app/test/core/router/app_router_test.dart app/test/app_test.dart
git commit -m "feat: add go_router navigation shell and wire app.dart/main.dart"
```

---

## Self-Review

**1. Spec coverage** — walking the task brief point by point:
- Flutter project init + exact pubspec structure + canonical folder structure from design-spec.md §9, with `.gitkeep`/placeholder files: Task 1.
- `onboardingStateProvider` `StateNotifierProvider` holding the full §6 field list, unit-tested: Task 5.
- Module-activation pure function `activeModules(LifeStage)` implementing the EVE2_PRD.md §5 table, with one test per life stage: Task 6.
- `go_router` router with named routes for every screen ID in design-spec.md §5 (plus §7's Home/Chat/Log), wired to placeholder screens: Task 7.
- `EveTheme` light/dark/default matching the 8 CSS custom properties and the Fredoka/Quicksand `google_fonts` pairing, widget-tested: Task 4.
- `FirebaseService` Auth + Firestore init wrapper, with `firestore_paths.dart` constants matching design-spec.md §10 exactly: Tasks 2 and 3.
- Boundaries respected: no `EveMascot` implementation, no real onboarding/Home/Chat/Log screens, no `firestore.rules`, no AI proxy/Cloud Functions, no notification scheduling — all explicitly called out in Global Constraints and left untouched by every task.

**2. Placeholder scan** — no "TBD"/"implement later"/"add appropriate handling" language anywhere; every step has complete, runnable code; every test has real assertions against real values (exact hex colors, exact Firestore path strings, exact module sets, exact route paths).

**3. Type consistency** — `LifeStage` is defined once in Task 5 (`onboarding_state.dart`) and imported by Task 6 (`module_activation.dart`) rather than redefined. `onboardingStateProvider`, `OnboardingNotifier.updateFields`, `OnboardingState.copyWith`, `Module`, `activeModules`, `FirestorePaths.*`, `FirebaseService.auth`/`.firestore`/`.initializeApp()`, `EveColors.*`, `EveTheme.defaultTheme()/.light()/.dark()`, `appRouter`, `RouteLabelScreen`, and `EveApp` are each defined exactly once and referenced with identical names/signatures everywhere else they're used across Tasks 1–7.

**Assumptions flagged for the other plans:**
- `activeModules` treats `partnerMode` as always present in the returned list for every life stage (matching the table's "Optional" marking as "not life-stage-gated"); actual partner-mode visibility given `partnerInvite` status is left to the consuming screen (Plan 1), not this pure function.
- The distinction between the "default" and "light" theme modes is not specified beyond "light, dark, or default" in EVE2_PRD.md §4 — this plan treats `defaultTheme()` as the branded ruby-soft-background theme and `light()` as a neutral white-background variant of the same palette, both `Brightness.light`. Plan 1 should treat this as the concrete definition unless told otherwise.
- `/onboarding/simplified-branch` is one shared route for the conceive/postpartum/perimenopause branches, per design-spec.md §5's own wording ("single screen-simplified-branch") — not three separate routes.
- This plan scaffolds only `EVE_MOBILE/app/` (the Flutter client). `EVE_MOBILE/functions/`, `firestore.rules`, `firestore.indexes.json`, and `firebase.json` at the `EVE_MOBILE/` root are left for Plans 3, 5, and 7 to create, since design-spec.md's own plan boundaries (§3) assign Cloud Functions and security rules to those plans.
