# EVE Mobile — System Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the foundational Flutter app scaffolding — project init, canonical folder structure, theming, routing shell, core Riverpod state, the module-activation lookup, and the Appwrite client wrapper plus repository interfaces — that every other EVE_MOBILE plan assumes already exists.

**Status (2026-11-01):** Tasks 1–7 are implemented in `EVE_MOBILE/app/` (commit `d422cf2`) and were written against Firebase. The backend has since moved to Appwrite (design-spec §2.1). Tasks 2, 3 and 7's `main.dart` bootstrap are superseded by **Task 8** (migration), and **Task 9** adds the repository interfaces. Tasks 1–7 are kept below as the record of what was built.

**Architecture:** A layered Flutter app: `core/` holds cross-cutting singletons (theme, router, Appwrite IDs, `AppwriteService`, `AppEnv`) with no feature-specific knowledge; `features/<name>/domain` holds pure Dart state/logic (Riverpod notifiers, lookup functions) with zero Flutter widget dependencies where possible; `features/<name>/data` holds an abstract repository interface plus its Appwrite implementation, so widgets never import `package:appwrite`; `features/<name>/presentation` holds widgets (out of scope here except placeholder route targets). Routing is a single flat `go_router` table of named routes, one per screen ID from the design spec, pointing at placeholder widgets until Plan 1 supplies the real screens.

**Tech Stack:** Flutter (Dart) + Riverpod (`flutter_riverpod`, `StateNotifierProvider`) + `go_router` + `google_fonts` + Appwrite (`appwrite` 28.x — Account, TablesDB, Functions, Realtime) + `mocktail` for test doubles. (Tasks 1–7 as originally built used `firebase_core`/`firebase_auth`/`cloud_firestore`; Task 8 removes them.) Exact version pins are Plan 3's (`03-tech-stack.md`) responsibility — this plan uses caret-range floors only.

## Global Constraints

- Frontend is Flutter (Dart), single codebase, per design-spec.md §2.
- State management is Riverpod, per design-spec.md §2. The onboarding state provider MUST be named `onboardingStateProvider` and MUST be a `StateNotifierProvider`, per design-spec.md §10.
- Backend is Appwrite (design-spec §2). No Firebase/GCP package may remain after Task 8. Server functions, schema and push are out of scope here (Plans 3/5/7).
- The project folder structure MUST match design-spec.md §9 exactly — every plan depends on these exact paths to compose without cross-reading each other's full content.
- Appwrite database/table/function IDs MUST match design-spec.md §10 exactly (`AppwriteIds`, Task 8).
- Only `core/services/`, `core/providers/` and `features/*/data/appwrite_*_repository.dart` may import `package:appwrite` — everything else depends on the Task 9 interfaces.
- `List<Module> activeModules(LifeStage stage)` MUST use that exact function name and signature — design-spec.md §10 fixes this as the cross-plan contract Plan 1's Home screen consumes.
- Brand colors are fixed hex values (design-spec.md task brief): `--ruby-main: #FF2A6D`, `--ruby-dark: #2A000E`, `--ruby-blush: #FFA0B8`, `--ruby-soft: #FFF0F4`, `--partner-blue: #3D7BFF`, `--fertile-teal: #2EC4B6`, `--symptom-purple: #9B51E0`, `--appointment-orange: #FF9F1C`.
- Fonts are Google Fonts: Fredoka for display text, Quicksand for body text, via the `google_fonts` package — never bundle static font assets for these.
- No emojis anywhere in-product copy (design-spec.md §2). This plan produces no user-facing copy, but any label text added must stay emoji-free.
- Out of scope for this plan (owned by other plans — do not implement here): the `EveMascot` widget (Plan 6), real onboarding/Home/Chat/Log screen widgets (Plan 1), the table schema and permissions (Plan 5), the AI proxy and all Appwrite Functions (Plans 3/7), notification dispatch (Plan 3). This plan creates only the `app/` (Flutter client) folder subtree — `functions/` and `appwrite.config.json` at the `EVE_MOBILE/` root are left for the plans that own them.

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
flutter create --org com.shilo.eve --project-name eve_app --platforms android,ios app
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

> **Superseded by Task 8** (Appwrite migration): `firestore_paths.dart` and its test are deleted there and replaced by `appwrite_ids.dart`. Kept as the record of what was built.

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

> **Superseded by Task 8**: `firebase_service.dart` and its test are deleted there and replaced by `appwrite_service.dart`. Kept as the record of what was built.

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

> The `main.dart` written in Step 4 below (`await FirebaseService.initializeApp()`) is **superseded by Task 8 Step 9**. Everything else in this task stands.

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

## Task 8: Migrate the client core from Firebase to Appwrite

> Tasks 1–7 above are **already implemented** in `EVE_MOBILE/app/` (commit `d422cf2`) against Firebase. This task replaces the two Firebase-specific pieces (Tasks 2 and 3) and the bootstrap line Task 7 added to `main.dart`. Run it together with Plan 3 Task 4 (the pubspec swap) — roadmap M2.

**Files:**
- Delete: `EVE_MOBILE/app/lib/core/services/firebase_service.dart`
- Delete: `EVE_MOBILE/app/test/core/services/firebase_service_test.dart`
- Delete: `EVE_MOBILE/app/lib/core/constants/firestore_paths.dart`
- Delete: `EVE_MOBILE/app/test/core/constants/firestore_paths_test.dart`
- Create: `EVE_MOBILE/app/lib/core/config/app_env.dart`
- Create: `EVE_MOBILE/app/lib/core/constants/appwrite_ids.dart`
- Create: `EVE_MOBILE/app/lib/core/services/appwrite_service.dart`
- Create: `EVE_MOBILE/app/lib/core/providers/appwrite_providers.dart`
- Modify: `EVE_MOBILE/app/lib/main.dart`
- Test: `EVE_MOBILE/app/test/core/constants/appwrite_ids_test.dart`
- Test: `EVE_MOBILE/app/test/core/services/appwrite_service_test.dart`
- Test: `EVE_MOBILE/app/test/core/providers/appwrite_providers_test.dart`

**Interfaces:**
- Consumes: `appwrite` 28.x (Plan 3 Task 4's pubspec), design-spec §10 IDs.
- Produces: `AppEnv.endpoint`/`.projectId`/`.selfSigned`; `AppwriteIds.*`; `AppwriteService` (`client`, `account`, `tablesDb`, `functions`, `realtime`, `signInWithGoogle()`, `signInAsGuest()`, `currentUserId()`, `signOut()`, `executeJson(functionId, body)`); `FunctionCallException`; `appwriteServiceProvider`, `currentUidProvider` (`StateProvider<String?>`). These replace `FirestorePaths`, `FirebaseService` and `FirebaseService.initializeApp()` everywhere.

- [ ] **Step 1: Confirm nothing else imports the Firebase files**

```bash
cd EVE_MOBILE/app
grep -rn "firebase_service\|firestore_paths\|package:firebase\|package:cloud_firestore" lib test
```

Expected: hits only in the four files being deleted and `lib/main.dart`.

- [ ] **Step 2: Delete the Firebase files**

```bash
git rm lib/core/services/firebase_service.dart test/core/services/firebase_service_test.dart lib/core/constants/firestore_paths.dart test/core/constants/firestore_paths_test.dart
```

- [ ] **Step 3: Write the failing tests**

Create `EVE_MOBILE/app/test/core/constants/appwrite_ids_test.dart`:

```dart
import 'package:eve_app/core/constants/appwrite_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('database, table and function IDs match design-spec §10', () {
    expect(AppwriteIds.databaseId, 'eve');
    expect(AppwriteIds.profiles, 'profiles');
    expect(AppwriteIds.lifeStageProfiles, 'life_stage_profiles');
    expect(AppwriteIds.symptomLogs, 'symptom_logs');
    expect(AppwriteIds.preferences, 'preferences');
    expect(AppwriteIds.partnerLinks, 'partner_links');
    expect(AppwriteIds.partnerPermissions, 'partner_permissions');
    expect(AppwriteIds.partnerViews, 'partner_views');
    expect(AppwriteIds.partnerLookups, 'partner_lookups');
    expect(AppwriteIds.chatMessages, 'chat_messages');
    expect(AppwriteIds.fnPartnerInvites, 'partnerInvites');
    expect(AppwriteIds.fnSendChatMessage, 'sendChatMessage');
    expect(AppwriteIds.fnAiProxy, 'aiProxy');
  });

  test('chat realtime channel', () {
    expect(AppwriteIds.chatMessagesChannel, 'tablesdb.eve.tables.chat_messages.rows');
  });
}
```

Create `EVE_MOBILE/app/test/core/services/appwrite_service_test.dart`:

```dart
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:eve_app/core/services/appwrite_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockClient extends Mock implements Client {}

class MockAccount extends Mock implements Account {}

class MockTablesDB extends Mock implements TablesDB {}

class MockFunctions extends Mock implements Functions {}

class MockRealtime extends Mock implements Realtime {}

class MockUser extends Mock implements models.User {}

class MockExecution extends Mock implements models.Execution {}

void main() {
  late MockAccount account;
  late MockFunctions functions;
  late AppwriteService service;

  setUp(() {
    account = MockAccount();
    functions = MockFunctions();
    service = AppwriteService(
      client: MockClient(),
      account: account,
      tablesDb: MockTablesDB(),
      functions: functions,
      realtime: MockRealtime(),
    );
  });

  test('currentUserId returns the signed-in user id', () async {
    final user = MockUser();
    when(() => user.$id).thenReturn('u1');
    when(() => account.get()).thenAnswer((_) async => user);
    expect(await service.currentUserId(), 'u1');
  });

  test('currentUserId returns null when there is no session (401)', () async {
    when(() => account.get()).thenThrow(AppwriteException('missing scope', 401));
    expect(await service.currentUserId(), isNull);
  });

  test('executeJson sends a synchronous JSON execution and decodes the response', () async {
    final execution = MockExecution();
    when(() => execution.responseStatusCode).thenReturn(200);
    when(() => execution.responseBody).thenReturn('{"inviteCode":"ABC234"}');
    when(() => functions.createExecution(
          functionId: any(named: 'functionId'),
          body: any(named: 'body'),
          xasync: any(named: 'xasync'),
        )).thenAnswer((_) async => execution);

    final result = await service.executeJson('partnerInvites', {'action': 'createInvite'});

    expect(result, {'inviteCode': 'ABC234'});
    verify(() => functions.createExecution(
          functionId: 'partnerInvites',
          body: '{"action":"createInvite"}',
          xasync: false,
        )).called(1);
  });

  test('executeJson throws FunctionCallException with the server message on 4xx/5xx', () async {
    final execution = MockExecution();
    when(() => execution.responseStatusCode).thenReturn(403);
    when(() => execution.responseBody).thenReturn('{"error":"You are not part of this conversation."}');
    when(() => functions.createExecution(
          functionId: any(named: 'functionId'),
          body: any(named: 'body'),
          xasync: any(named: 'xasync'),
        )).thenAnswer((_) async => execution);

    expect(
      () => service.executeJson('sendChatMessage', {}),
      throwsA(isA<FunctionCallException>()
          .having((e) => e.statusCode, 'statusCode', 403)
          .having((e) => e.message, 'message', 'You are not part of this conversation.')),
    );
  });
}
```

Create `EVE_MOBILE/app/test/core/providers/appwrite_providers_test.dart`:

```dart
import 'package:eve_app/core/providers/appwrite_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('currentUidProvider defaults to null and can be set after sign-in', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(currentUidProvider), isNull);
    container.read(currentUidProvider.notifier).state = 'u1';
    expect(container.read(currentUidProvider), 'u1');
  });
}
```

- [ ] **Step 4: Run to verify they fail**

```bash
flutter test test/core/constants/appwrite_ids_test.dart test/core/services/appwrite_service_test.dart test/core/providers/appwrite_providers_test.dart
```

Expected: FAIL — the three `lib/` files don't exist.

- [ ] **Step 5: Implement `EVE_MOBILE/app/lib/core/config/app_env.dart`**

```dart
/// Build-time configuration, set with --dart-define (see app/README.md).
/// Defaults target the local Docker Appwrite as seen from an Android
/// emulator (10.0.2.2 is the host machine).
class AppEnv {
  AppEnv._();

  static const String endpoint =
      String.fromEnvironment('APPWRITE_ENDPOINT', defaultValue: 'http://10.0.2.2/v1');

  static const String projectId =
      String.fromEnvironment('APPWRITE_PROJECT_ID', defaultValue: 'eve-local');

  /// Only for a self-hosted instance with a self-signed certificate.
  static const bool selfSigned = bool.fromEnvironment('APPWRITE_SELF_SIGNED');
}
```

- [ ] **Step 6: Implement `EVE_MOBILE/app/lib/core/constants/appwrite_ids.dart`**

```dart
/// Canonical Appwrite IDs — must match design-spec §10 and
/// functions/shared/src/ids.ts exactly. Replaces FirestorePaths.
class AppwriteIds {
  AppwriteIds._();

  static const String databaseId = 'eve';

  static const String profiles = 'profiles';
  static const String lifeStageProfiles = 'life_stage_profiles';
  static const String symptomLogs = 'symptom_logs';
  static const String preferences = 'preferences';
  static const String partnerLinks = 'partner_links';
  static const String partnerPermissions = 'partner_permissions';
  static const String partnerViews = 'partner_views';
  static const String partnerLookups = 'partner_lookups';
  static const String chatMessages = 'chat_messages';

  static const String fnPartnerInvites = 'partnerInvites';
  static const String fnSendChatMessage = 'sendChatMessage';
  static const String fnAiProxy = 'aiProxy';

  /// Realtime channel for every chat row the subscriber can read.
  static const String chatMessagesChannel = 'tablesdb.$databaseId.tables.$chatMessages.rows';
}
```

- [ ] **Step 7: Implement `EVE_MOBILE/app/lib/core/services/appwrite_service.dart`**

```dart
import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as enums;

import '../config/app_env.dart';

/// Thrown when an Appwrite Function execution returns a 4xx/5xx status.
class FunctionCallException implements Exception {
  FunctionCallException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'FunctionCallException($statusCode): $message';
}

/// Thin, testable wrapper around the Appwrite SDK services the client uses.
/// Every service can be injected so tests never touch the network. Only
/// repositories (`features/*/data/appwrite_*_repository.dart`) and
/// `core/services/` may use this class — widgets depend on repository
/// interfaces instead (Task 9).
class AppwriteService {
  AppwriteService({
    required this.client,
    Account? account,
    TablesDB? tablesDb,
    Functions? functions,
    Realtime? realtime,
  })  : account = account ?? Account(client),
        tablesDb = tablesDb ?? TablesDB(client),
        functions = functions ?? Functions(client),
        realtime = realtime ?? Realtime(client);

  factory AppwriteService.fromEnv() {
    final client = Client().setEndpoint(AppEnv.endpoint).setProject(AppEnv.projectId);
    if (AppEnv.selfSigned) client.setSelfSigned();
    return AppwriteService(client: client);
  }

  final Client client;
  final Account account;
  final TablesDB tablesDb;
  final Functions functions;
  final Realtime realtime;

  /// Opens the Google consent screen; resolves once the session exists.
  Future<void> signInWithGoogle() => account.createOAuth2Session(provider: enums.OAuthProvider.google);

  /// "Continue as Guest": an anonymous Appwrite account (still a real user
  /// id, so onUserCreate initializes her rows). Can be upgraded later.
  Future<void> signInAsGuest() => account.createAnonymousSession();

  /// The signed-in user's id, or null when there is no session.
  Future<String?> currentUserId() async {
    try {
      return (await account.get()).$id;
    } on AppwriteException catch (e) {
      if (e.code == 401) return null;
      rethrow;
    }
  }

  Future<void> signOut() => account.deleteSession(sessionId: 'current');

  /// Runs a function synchronously with a JSON body and returns its JSON
  /// response. Caller identity reaches the function as x-appwrite-user-id.
  Future<Map<String, dynamic>> executeJson(String functionId, Map<String, dynamic> body) async {
    final execution = await functions.createExecution(
      functionId: functionId,
      body: jsonEncode(body),
      xasync: false,
    );
    final decoded = execution.responseBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(execution.responseBody) as Map<String, dynamic>;
    if (execution.responseStatusCode >= 400) {
      throw FunctionCallException(
        execution.responseStatusCode,
        (decoded['error'] as String?) ?? 'Request failed.',
      );
    }
    return decoded;
  }
}
```

- [ ] **Step 8: Implement `EVE_MOBILE/app/lib/core/providers/appwrite_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/appwrite_service.dart';

/// Overridden in main.dart with the instance built from AppEnv, and in
/// tests with an AppwriteService made of mocks.
final appwriteServiceProvider = Provider<AppwriteService>((ref) => AppwriteService.fromEnv());

/// The signed-in user's id. Seeded in main.dart from the existing session
/// and set by the Auth screen after signInWithGoogle(); null when signed out.
final currentUidProvider = StateProvider<String?>((ref) => null);
```

- [ ] **Step 9: Replace `EVE_MOBILE/app/lib/main.dart`**

```dart
import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers/appwrite_providers.dart';
import 'core/services/appwrite_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appwrite = AppwriteService.fromEnv();
  String? uid;
  try {
    uid = await appwrite.currentUserId();
  } on AppwriteException {
    uid = null; // offline or server unreachable: start signed-out, retry at sign-in
  }
  runApp(ProviderScope(
    overrides: [
      appwriteServiceProvider.overrideWithValue(appwrite),
      currentUidProvider.overrideWith((ref) => uid),
    ],
    child: const EveApp(),
  ));
}
```

- [ ] **Step 10: Run the whole suite and analyzer**

```bash
flutter test
flutter analyze
```

Expected: every test passes (the 7 new ones plus all Task 4–7 tests); `flutter analyze` reports `No issues found!`; `grep -rn "firebase\|firestore" lib test pubspec.yaml` returns nothing.

- [ ] **Step 11: Manual sign-in check (local Appwrite, Plan 3 Tasks 1–3 done)**

Temporarily add to the `/onboarding/auth` placeholder a button calling `ref.read(appwriteServiceProvider).signInWithGoogle()` then `ref.read(currentUidProvider.notifier).state = await ref.read(appwriteServiceProvider).currentUserId()`, run on an emulator with the local `--dart-define`s, sign in. Expected: the Google consent screen opens in a browser tab, returns to the app, a user appears in Console → Auth, and the `onUserCreate` execution (Plan 5 Task 5, if deployed) creates her rows. Revert the scratch button — Plan 1's real Auth screen replaces it.

- [ ] **Step 12: Commit (with Plan 3 Task 4's pubspec)**

```bash
git add -A lib/core test/core lib/main.dart pubspec.yaml pubspec.lock
git commit -m "refactor(app): replace Firebase core with AppwriteService, AppwriteIds and AppEnv"
```

---

## Task 9: Repository interfaces (UI never imports Appwrite)

> Runs after Plan 5 Task 4 (the Dart models it references) — roadmap M14 Step 0.

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/data/onboarding_repository.dart`
- Create: `EVE_MOBILE/app/lib/features/home/data/home_repository.dart`
- Create: `EVE_MOBILE/app/lib/features/chat/data/chat_repository.dart`
- Create: `EVE_MOBILE/app/lib/features/log/data/log_repository.dart`
- Create: `EVE_MOBILE/app/test/support/fake_repositories.dart`
- Test: `EVE_MOBILE/app/test/support/fake_repositories_test.dart`
- Delete: the `.gitkeep` files in `lib/features/{onboarding,home}/data/` once a real file exists there

**Interfaces:**
- Consumes: `OnboardingState` (Task 5), `ChatMessage`, `SymptomLog` (Plan 5 Task 4).
- Produces: `OnboardingRepository`, `HomeDashboardData`, `HomeRepository`, `ChatRepository`, `LogRepository` (abstract, exact signatures from design-spec §10 "Data-access interface"), and in-memory fakes `FakeOnboardingRepository`, `FakeHomeRepository`, `FakeChatRepository`, `FakeLogRepository` that roadmap M14/M16/M19 widget and router tests reuse. The Appwrite implementations live beside each interface and are written in roadmap M14/M16.

- [ ] **Step 1: Write the failing test**

Create `EVE_MOBILE/app/test/support/fake_repositories_test.dart`:

```dart
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/shared/models/symptom_log.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_repositories.dart';

void main() {
  test('FakeOnboardingRepository records saves', () async {
    final repo = FakeOnboardingRepository();
    await repo.saveOnboarding('u1', const OnboardingState(name: 'Asha'));
    expect(repo.saved.single.$1, 'u1');
    expect(repo.saved.single.$2.name, 'Asha');
  });

  test('FakeChatRepository streams sent messages as her', () async {
    final repo = FakeChatRepository();
    final stream = repo.watchThread('u1');
    await repo.sendMessage('u1', 'Hello');
    final messages = await stream.firstWhere((m) => m.isNotEmpty);
    expect(messages.single.senderRole, 'her');
    expect(messages.single.messageText, 'Hello');
  });

  test('FakeLogRepository streams added logs', () async {
    final repo = FakeLogRepository();
    await repo.addLog('u1', SymptomLog(userId: 'u1', date: DateTime.utc(2026, 3, 14), mood: 'low'));
    final logs = await repo.watchLogs('u1').first;
    expect(logs.single.mood, 'low');
  });

  test('FakeHomeRepository returns its configured dashboard', () async {
    final repo = FakeHomeRepository(const HomeDashboardDataFixture().data);
    expect((await repo.loadDashboard('u1')).greetingName, 'Priya');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/support/fake_repositories_test.dart`
Expected: FAIL — `fake_repositories.dart` doesn't exist.

- [ ] **Step 3: Create the interfaces**

`EVE_MOBILE/app/lib/features/onboarding/data/onboarding_repository.dart`:

```dart
import '../domain/onboarding_state.dart';

/// Persists the completed onboarding survey. Implemented against Appwrite by
/// AppwriteOnboardingRepository (roadmap M14).
abstract class OnboardingRepository {
  /// Returns the partner invite code when she chose to invite a partner,
  /// otherwise null.
  Future<String?> saveOnboarding(String uid, OnboardingState state);
}
```

`EVE_MOBILE/app/lib/features/home/data/home_repository.dart`:

```dart
/// What the Home header needs. Real cycle-phase math is out of V0 scope;
/// [phaseBadge] is a per-life-stage label.
class HomeDashboardData {
  const HomeDashboardData({required this.greetingName, required this.phaseBadge});

  final String greetingName;
  final String phaseBadge;
}

abstract class HomeRepository {
  Future<HomeDashboardData> loadDashboard(String uid);
}
```

`EVE_MOBILE/app/lib/features/chat/data/chat_repository.dart`:

```dart
import '../../../shared/models/chat_message.dart';

/// One thread per couple, keyed by the primary user's uid. Sending goes
/// through the sendChatMessage function — the client never writes rows.
abstract class ChatRepository {
  /// Her own uid when she is the primary user; the primary user's uid when
  /// the signed-in user is a linked partner.
  Future<String> threadIdFor(String uid);

  Stream<List<ChatMessage>> watchThread(String threadUserId);

  Future<void> sendMessage(String threadUserId, String text);
}
```

`EVE_MOBILE/app/lib/features/log/data/log_repository.dart`:

```dart
import '../../../shared/models/symptom_log.dart';

abstract class LogRepository {
  /// Her logs, oldest first, updating live.
  Stream<List<SymptomLog>> watchLogs(String uid);

  Future<void> addLog(String uid, SymptomLog log);
}
```

- [ ] **Step 4: Create the fakes**

`EVE_MOBILE/app/test/support/fake_repositories.dart`:

```dart
import 'dart:async';

import 'package:eve_app/features/chat/data/chat_repository.dart';
import 'package:eve_app/features/home/data/home_repository.dart';
import 'package:eve_app/features/log/data/log_repository.dart';
import 'package:eve_app/features/onboarding/data/onboarding_repository.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/shared/models/chat_message.dart';
import 'package:eve_app/shared/models/symptom_log.dart';

class FakeOnboardingRepository implements OnboardingRepository {
  final List<(String, OnboardingState)> saved = [];

  String? inviteCodeToReturn;

  @override
  Future<String?> saveOnboarding(String uid, OnboardingState state) async {
    saved.add((uid, state));
    return state.partnerInvite ? inviteCodeToReturn : null;
  }
}

class HomeDashboardDataFixture {
  const HomeDashboardDataFixture();

  HomeDashboardData get data => const HomeDashboardData(greetingName: 'Priya', phaseBadge: 'Cycle Tracking Active');
}

class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository(this.data);

  final HomeDashboardData data;

  @override
  Future<HomeDashboardData> loadDashboard(String uid) async => data;
}

class FakeChatRepository implements ChatRepository {
  final _messages = <ChatMessage>[];
  final _controller = StreamController<List<ChatMessage>>.broadcast();

  @override
  Future<String> threadIdFor(String uid) async => uid;

  @override
  Stream<List<ChatMessage>> watchThread(String threadUserId) async* {
    yield List.unmodifiable(_messages);
    yield* _controller.stream;
  }

  @override
  Future<void> sendMessage(String threadUserId, String text) async {
    _messages.add(ChatMessage(
      threadUserId: threadUserId,
      senderRole: 'her',
      senderUserId: threadUserId,
      messageText: text,
      sentAt: DateTime.now().toUtc(),
      type: 'text',
    ));
    _controller.add(List.unmodifiable(_messages));
  }
}

class FakeLogRepository implements LogRepository {
  final _logs = <SymptomLog>[];
  final _controller = StreamController<List<SymptomLog>>.broadcast();

  @override
  Stream<List<SymptomLog>> watchLogs(String uid) async* {
    yield List.unmodifiable(_logs);
    yield* _controller.stream;
  }

  @override
  Future<void> addLog(String uid, SymptomLog log) async {
    _logs.add(log);
    _controller.add(List.unmodifiable(_logs));
  }
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/support/fake_repositories_test.dart && flutter analyze`
Expected: `All tests passed!` (4 tests); no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/onboarding/data lib/features/home/data lib/features/chat/data lib/features/log/data test/support
git commit -m "feat(app): add repository interfaces and in-memory fakes"
```

---

## Self-Review

**1. Spec coverage** — walking the task brief point by point:
- Flutter project init + exact pubspec structure + canonical folder structure from design-spec.md §9, with `.gitkeep`/placeholder files: Task 1.
- `onboardingStateProvider` `StateNotifierProvider` holding the full §6 field list, unit-tested: Task 5.
- Module-activation pure function `activeModules(LifeStage)` implementing the EVE2_PRD.md §5 table, with one test per life stage: Task 6.
- `go_router` router with named routes for every screen ID in design-spec.md §5 (plus §7's Home/Chat/Log), wired to placeholder screens: Task 7.
- `EveTheme` light/dark/default matching the 8 CSS custom properties and the Fredoka/Quicksand `google_fonts` pairing, widget-tested: Task 4.
- ~~`FirebaseService` + `firestore_paths.dart` (Tasks 2 and 3)~~ → `AppwriteService` + `AppwriteIds` + `AppEnv` + providers, with Firebase fully removed: Task 8.
- Repository interfaces so UI never depends on Appwrite, plus reusable fakes: Task 9.
- Boundaries respected: no `EveMascot` implementation, no real onboarding/Home/Chat/Log screens, no schema/permissions, no AI proxy/Appwrite Functions, no notification dispatch — all explicitly called out in Global Constraints and left untouched by every task.

**2. Placeholder scan** — no "TBD"/"implement later"/"add appropriate handling" language anywhere; every step has complete, runnable code; every test has real assertions against real values (exact hex colors, exact Firestore path strings, exact module sets, exact route paths).

**3. Type consistency** — `LifeStage` is defined once in Task 5 (`onboarding_state.dart`) and imported by Task 6 (`module_activation.dart`) rather than redefined. `onboardingStateProvider`, `OnboardingNotifier.updateFields`, `OnboardingState.copyWith`, `Module`, `activeModules`, `FirestorePaths.*`, `FirebaseService.auth`/`.firestore`/`.initializeApp()`, `EveColors.*`, `EveTheme.defaultTheme()/.light()/.dark()`, `appRouter`, `RouteLabelScreen`, and `EveApp` are each defined exactly once and referenced with identical names/signatures everywhere else they're used across Tasks 1–7.

**Assumptions flagged for the other plans:**
- `activeModules` treats `partnerMode` as always present in the returned list for every life stage (matching the table's "Optional" marking as "not life-stage-gated"); actual partner-mode visibility given `partnerInvite` status is left to the consuming screen (Plan 1), not this pure function.
- The distinction between the "default" and "light" theme modes is not specified beyond "light, dark, or default" in EVE2_PRD.md §4 — this plan treats `defaultTheme()` as the branded ruby-soft-background theme and `light()` as a neutral white-background variant of the same palette, both `Brightness.light`. Plan 1 should treat this as the concrete definition unless told otherwise.
- `/onboarding/simplified-branch` is one shared route for the conceive/postpartum/perimenopause branches, per design-spec.md §5's own wording ("single screen-simplified-branch") — not three separate routes.
- This plan scaffolds only `EVE_MOBILE/app/` (the Flutter client). `EVE_MOBILE/functions/` and `appwrite.config.json` are left for Plans 3, 5, and 7.
- `currentUidProvider` is a `StateProvider<String?>` (seeded in `main.dart`, set by the Auth screen) rather than derived from the SDK, because Appwrite's `account.get()` is async — this keeps every consumer's read synchronous.
