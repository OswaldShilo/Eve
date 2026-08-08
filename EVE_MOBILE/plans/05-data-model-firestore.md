# Data Model & Firestore Schema Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn every collection listed in `00-design-spec.md` §10 into a concrete, field-typed schema — expressed identically in TypeScript (Cloud Functions) and Dart (Flutter client) — plus a complete, tested `firestore.rules` file enforcing owner/partner/system access boundaries, and the `onUserCreate` Cloud Function that initializes a new user's full document set atomically.

**Architecture:** One shared TypeScript type-definitions module (`functions/src/types.ts`) is the source of truth for field names/types; a hand-written Dart mirror (`app/lib/shared/models/*.dart`) agrees with it field-for-field. `firestore.rules` is a single declarative file enforcing per-collection access, verified against the Firebase Firestore Emulator using `@firebase/rules-unit-testing`. `onUserCreate` is a `functions.auth.user().onCreate` (v1) trigger that writes every document in one atomic `WriteBatch`, verified with `firebase-functions-test` running against the same emulator.

**Tech Stack:** Firebase (Firestore, Auth, Cloud Functions v1 auth trigger), Node.js/TypeScript for Cloud Functions, Dart (plain classes, no codegen) for the Flutter client, Jest + ts-jest, `@firebase/rules-unit-testing`, `firebase-functions-test`, `firebase-tools` (emulator), Dart's `package:test`.

## Global Constraints

- Backend is Firebase (Auth, Firestore, Cloud Functions); Cloud Functions runtime is Node.js/TypeScript. [`EVE2_PRD.md` §10.1; `00-design-spec.md` §2]
- Firestore paths and field lists MUST match `00-design-spec.md` §10 EXACTLY — this plan formalizes types against those paths, it does not invent new ones. [`00-design-spec.md` §10]
- `users/{uid}/partnerView/current` is a server-generated filtered projection — never written by any client, including the profile owner herself. [`EVE2_PRD.md` §10.2, §10.3; `00-design-spec.md` §10]
- A partner (resolved via `partnerLinks/{request.auth.uid}.primaryUserId == uid`) may read ONLY `users/{uid}/partnerView/current` and `users/{uid}/chat/**` — never `logs`, `lifeStageProfile`, or raw `preferences/*` documents. [`EVE2_PRD.md` §8]
- Chat messages with `type: 'system'` may only be created by a Cloud Function via the Admin SDK (which bypasses security rules) — never by a client, because a client-spoofed system message would undermine the partner-nudge mechanism. [`EVE2_PRD.md` §8, §10.3]
- Gamification fields (`currentStreak`, `carePoints`, `unlockedWardrobeItems`, `lastFreezeUsed`, etc.) are explicitly out of V0 scope — no Streak & Points collection is created by this plan. [`EVE2_PRD.md` §7; `00-design-spec.md` §8]
- No diagnosis claims — this plan does not add any field implying a diagnostic verdict (e.g. no `diagnosis` field); risk-flag text generation belongs to the AI proxy, out of this plan's scope. [`EVE2_PRD.md` §9]
- This plan does NOT implement the `partnerView` recompute function (the trigger that watches `logs`/`lifeStageProfile`/`partnerPermissions` writes and regenerates the filtered projection) — that is `07-partner-mode-consent.md`'s job. This plan only defines the schema `partnerView` documents conform to and the security rules protecting them. [explicit task boundary, this brief]
- Copy voice constraints (formal, warm, no emojis) do not apply to this plan's deliverables — there is no user-facing copy in schema/rules/function code.
- All automated tests in this plan run against the Firebase Emulator Suite (Firestore + Auth emulators) — no test may reach a real Firebase project. [explicit instruction, this brief]

---

## Assumptions made explicit (no spec value existed to copy verbatim)

These are called out here, once, so no task silently invents them:

1. **Units:** `users/{uid}.height` is centimeters, `.weight` is kilograms. Neither PRD states units; this is the most common convention and is documented inline in both the TS and Dart types.
2. **`mood` vocabulary** on `logs/{logId}`: neither PRD enumerates mood values. This plan defines a 5-point scale (`'great' | 'good' | 'okay' | 'low' | 'difficult'`) as a reasonable placeholder vocabulary. Plan 1 (screen-by-screen field spec) or product decisions may need to reconcile this with whatever mood picker UI it defines — flagged as a cross-plan follow-up, not resolved unilaterally here.
3. **Simplified-branch vocab** (`conceive` / `postpartum` / `menopause` life-stage profiles): `00-design-spec.md` §6's field list uses one generic pair — `simplifiedSymptoms[]`, `simplifiedGoals[]` — reused across all three branches (not per-branch field names), so this plan follows that literally and stores free-form `string[]` for both, without a Firestore-rules-enforced enum, matching that the actual per-branch option vocabulary (given explicitly for menopause only in `EVE2_PRD.md` §4, and only partially implied for conceive/postpartum) is a UI-layer (Plan 1) concern, not a data-layer one.
4. **`chat.type`** is modeled as `'text' | 'system'` (not a larger set) — `EVE2_PRD.md` §10.2 says the field "includes both human messages and Eve's system-generated nudges," and this plan's task boundary explicitly requires a `'system'` value to exist and be rule-gated; quick-reply chips are treated as a UI affordance that produces an ordinary `'text'` message when tapped, not a distinct persisted type.
5. **`partnerView/current`'s per-category fields** (`appointmentReminders`, `pregnancyMilestones`, `supportSuggestions`, `moodReminders`) are typed here only as the *container* shape (`unknown[] | null`) that Plan 7's recompute function must write into — this plan does not define the shape of the items inside those arrays, since that is Plan 7's content-shape decision per this plan's explicit task boundary.
6. **Dart models have no `cloud_firestore` dependency.** `app/pubspec.yaml` created by this plan is a minimal, dependency-free Dart package (not a Flutter package) so the model classes and their tests can run with plain `dart test`, with no coordination dependency on Plan 2/3's Flutter project scaffolding. Timestamps are modeled as `DateTime?` with duck-typed acceptance of anything exposing `.toDate()` (i.e. a real Firestore `Timestamp`), so the repository layer (owned by other plans/features) can pass either a `DateTime` or a `Timestamp` straight through. **Coordination flag:** Plan 2/3 will very likely also touch `app/pubspec.yaml` to add Flutter/`cloud_firestore`/Riverpod dependencies — whoever executes second should merge, not overwrite.

---

## Task 1: Shared TypeScript Firestore type definitions

**Files:**
- Create: `EVE_MOBILE/functions/package.json`
- Create: `EVE_MOBILE/functions/tsconfig.json`
- Create: `EVE_MOBILE/functions/src/types.ts`

**Interfaces:**
- Consumes: canonical paths/field lists from `00-design-spec.md` §10, onboarding field list from §6, branch descriptions from `EVE2_PRD.md` §4.
- Produces (exact names later tasks import): `LifeStage`, `UserProfile`, `CycleFlow`, `CycleSymptom`, `CycleGoal`, `DietType`, `CycleLifeStageProfile`, `DueMethod`, `PregnancyType`, `PregnantSymptom`, `PregnantLifeStageProfile`, `SimplifiedLifeStageProfile`, `LifeStageProfile`, `Mood`, `SymptomLog`, `GoalsPreferences`, `NotificationReminder`, `NotificationPreferences`, `AiHelpArea`, `AiScopePreferences`, `Theme`, `ThemePreferences`, `RelationshipType`, `InviteStatus`, `PartnerLink`, `PermissionCategory`, `PartnerPermissions`, `PartnerView`, `PartnerLinkReverseLookup`, `ChatSenderId`, `ChatMessageType`, `ChatMessage`.

- [ ] **Step 1: Verify Node.js is available**

Run: `node --version`
Expected: `v18.x` or higher (Firebase Cloud Functions Gen 1/2 support Node 18/20). If missing, install Node 20 LTS before continuing.

- [ ] **Step 2: Create `EVE_MOBILE/functions/package.json`**

```json
{
  "name": "eve-functions",
  "version": "0.1.0",
  "private": true,
  "engines": {
    "node": "20"
  },
  "main": "lib/index.js",
  "scripts": {
    "build": "tsc",
    "test:types": "tsc --noEmit",
    "test:emulator": "firebase emulators:exec --only firestore --project demo-eve-test \"jest --runInBand\""
  },
  "dependencies": {
    "firebase-admin": "^12.1.0",
    "firebase-functions": "^5.0.1"
  },
  "devDependencies": {
    "typescript": "^5.4.5",
    "jest": "^29.7.0",
    "ts-jest": "^29.1.2",
    "@types/jest": "^29.5.12",
    "@types/node": "^20.12.7",
    "firebase-functions-test": "^3.3.0",
    "@firebase/rules-unit-testing": "^3.0.3",
    "firebase": "^10.11.1",
    "firebase-tools": "^13.7.3"
  }
}
```

- [ ] **Step 3: Create `EVE_MOBILE/functions/tsconfig.json`**

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "noImplicitReturns": true,
    "noUnusedLocals": true,
    "outDir": "lib",
    "sourceMap": true,
    "strict": true,
    "target": "es2020",
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true
  },
  "include": ["src", "test"]
}
```

- [ ] **Step 4: Install dependencies**

Run (from `EVE_MOBILE/functions/`): `npm install`
Expected: exits 0, creates `node_modules/` and `package-lock.json`.

- [ ] **Step 5: Write `EVE_MOBILE/functions/src/types.ts`**

```typescript
import type { Timestamp } from 'firebase-admin/firestore';

// ---------------------------------------------------------------------------
// users/{uid} — User Profile. Created empty by onUserCreate, filled in
// incrementally as onboarding screens (Plan 1) write to it.
// ---------------------------------------------------------------------------
export type LifeStage = 'cycle' | 'conceive' | 'pregnant' | 'postpartum' | 'menopause';

export interface UserProfile {
  authId: string;
  name: string;
  age: number | null;
  height: number | null; // centimeters — see plan assumption note
  weight: number | null; // kilograms — see plan assumption note
  country: string | null;
  lifeStage: LifeStage | null;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

// ---------------------------------------------------------------------------
// users/{uid}/lifeStageProfile/current — single flexible document,
// discriminated by `type`. Nested shape per branch cross-referenced from
// design-spec §6 (surveyState field list) and EVE2_PRD §4 (branch narrative).
// ---------------------------------------------------------------------------
export type CycleFlow = 'light' | 'moderate' | 'heavy';

export type CycleSymptom =
  | 'cramps'
  | 'acne'
  | 'headache'
  | 'breastTenderness'
  | 'bloating'
  | 'moodSwings'
  | 'backPain'
  | 'fatigue'
  | 'foodCravings'
  | 'nausea'
  | 'none';

export type CycleGoal =
  | 'predictNextPeriod'
  | 'understandMyBody'
  | 'improveFitness'
  | 'betterNutrition'
  | 'improveMentalWellbeing';

export type DietType = 'veg' | 'nonveg' | 'vegan';

export interface CycleLifeStageProfile {
  type: 'cycle';
  cycleLength: number;
  periodLength: number;
  flow: CycleFlow;
  cycleSymptoms: CycleSymptom[];
  cycleGoals: CycleGoal[];
  // Set only when cycleGoals includes 'betterNutrition' (its onboarding sub-choice).
  nutritionDiet: DietType | null;
}

export type DueMethod = 'dueDate' | 'lastPeriod' | 'doctorEstimate';
export type PregnancyType = 'single' | 'twins';
export type PregnantSymptom =
  | 'morningSickness'
  | 'swelling'
  | 'backPain'
  | 'heartburn'
  | 'headache'
  | 'none';

export interface PregnantLifeStageProfile {
  type: 'pregnant';
  dueDate: Timestamp | null;
  dueMethod: DueMethod;
  highRisk: boolean;
  pregnancyType: PregnancyType;
  medications: string | null; // free text, e.g. "prenatal vitamins, iron"
  allergies: string | null; // free text; filters food suggestions downstream
  prenatalVitamins: boolean;
  pregnantSymptoms: PregnantSymptom[];
}

// conceive / postpartum / menopause — hackathon-collapsed single combined
// symptoms+goals screen per design-spec §2. Vocabulary is stage-dependent
// and NOT enforced as a closed enum here (see plan assumption note 3).
export interface SimplifiedLifeStageProfile {
  type: 'conceive' | 'postpartum' | 'menopause';
  simplifiedSymptoms: string[];
  simplifiedGoals: string[];
}

// Shell state written by onUserCreate, before she reaches the life-stage
// selector screen during onboarding.
export interface EmptyLifeStageProfile {
  type: null;
}

export type LifeStageProfile =
  | CycleLifeStageProfile
  | PregnantLifeStageProfile
  | SimplifiedLifeStageProfile
  | EmptyLifeStageProfile;

// ---------------------------------------------------------------------------
// users/{uid}/logs/{logId} — Symptom/Mood Log entries.
// ---------------------------------------------------------------------------
export type Mood = 'great' | 'good' | 'okay' | 'low' | 'difficult';

export interface SymptomLog {
  date: Timestamp;
  symptoms: string[];
  mood: Mood | null;
  painLevel: number | null; // 0-10
  notes: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

// ---------------------------------------------------------------------------
// users/{uid}/preferences/goals
// ---------------------------------------------------------------------------
export interface GoalsPreferences {
  selectedGoals: string[];
  dietType: DietType | null;
  foodAllergies: string;
  cuisines: string[];
  workoutPreference: string[];
}

// ---------------------------------------------------------------------------
// users/{uid}/preferences/notifications
// ---------------------------------------------------------------------------
export type NotificationReminder =
  | 'morningReminder'
  | 'medicineReminder'
  | 'workoutReminder'
  | 'waterReminder'
  | 'sleepReminder'
  | 'cycleReminder'
  | 'appointmentReminder'
  | 'moodReminder'
  | 'dailyAiTip';

export interface NotificationPreferences {
  enabledReminders: NotificationReminder[];
}

// ---------------------------------------------------------------------------
// users/{uid}/preferences/aiScope
// ---------------------------------------------------------------------------
export type AiHelpArea =
  | 'healthQuestions'
  | 'nutrition'
  | 'workouts'
  | 'mentalWellbeing'
  | 'medicationReminders'
  | 'doctorPrep';

export interface AiScopePreferences {
  // Selecting "everything" on the onboarding screen expands to all 6 values
  // at write time — the literal string 'everything' is never stored.
  enabledHelpAreas: AiHelpArea[];
}

// ---------------------------------------------------------------------------
// users/{uid}/preferences/theme
// ---------------------------------------------------------------------------
export type Theme = 'light' | 'dark' | 'default';

export interface ThemePreferences {
  selectedTheme: Theme;
}

// ---------------------------------------------------------------------------
// users/{uid}/partnerLink/current — written by the primary user.
// ---------------------------------------------------------------------------
export type RelationshipType = 'husband' | 'boyfriend' | 'partner';
export type InviteStatus = 'none' | 'pending' | 'accepted' | 'declined';

export interface PartnerLink {
  partnerUserId: string | null;
  relationshipType: RelationshipType | null;
  inviteStatus: InviteStatus;
  invitedAt: Timestamp | null;
  linkedAt: Timestamp | null;
}

// ---------------------------------------------------------------------------
// users/{uid}/partnerPermissions/current
// ---------------------------------------------------------------------------
export type PermissionCategory =
  | 'appointmentReminders'
  | 'pregnancyMilestones'
  | 'supportSuggestions'
  | 'moodReminders';

export interface PartnerPermissions {
  approvedCategories: PermissionCategory[];
  onlyApproveMode: boolean;
}

// ---------------------------------------------------------------------------
// users/{uid}/partnerView/current — server-generated only. This is the
// CONTAINER contract; per-category item shapes are finalized by Plan 7
// (07-partner-mode-consent.md), which owns the recompute function that
// populates these fields.
// ---------------------------------------------------------------------------
export interface PartnerView {
  primaryUserId: string;
  approvedCategories: PermissionCategory[];
  lastUpdatedAt: Timestamp;
  appointmentReminders: unknown[] | null;
  pregnancyMilestones: unknown[] | null;
  supportSuggestions: unknown[] | null;
  moodReminders: unknown[] | null;
}

// ---------------------------------------------------------------------------
// partnerLinks/{partnerUid} — top-level reverse lookup, server-written only.
// ---------------------------------------------------------------------------
export interface PartnerLinkReverseLookup {
  primaryUserId: string;
  relationshipType: RelationshipType;
  linkedAt: Timestamp;
}

// ---------------------------------------------------------------------------
// users/{uid}/chat/{messageId}
// ---------------------------------------------------------------------------
export type ChatSenderId = 'her' | 'partner' | 'system';
export type ChatMessageType = 'text' | 'system';

export interface ChatMessage {
  senderId: ChatSenderId;
  messageText: string;
  timestamp: Timestamp;
  type: ChatMessageType;
}
```

- [ ] **Step 6: Verify the module compiles**

Run (from `EVE_MOBILE/functions/`): `npm run test:types`
Expected: exits 0, no output (no type errors).

- [ ] **Step 7: Commit**

```bash
git add EVE_MOBILE/functions/package.json EVE_MOBILE/functions/tsconfig.json EVE_MOBILE/functions/src/types.ts EVE_MOBILE/functions/package-lock.json
git commit -m "feat(functions): add shared Firestore TypeScript type definitions"
```

---

## Task 2: Dart mirror model classes

**Files:**
- Create: `EVE_MOBILE/app/pubspec.yaml`
- Create: `EVE_MOBILE/app/lib/shared/models/user_profile.dart`
- Create: `EVE_MOBILE/app/lib/shared/models/life_stage_profile.dart`
- Create: `EVE_MOBILE/app/lib/shared/models/symptom_log.dart`
- Create: `EVE_MOBILE/app/lib/shared/models/preferences.dart`
- Create: `EVE_MOBILE/app/lib/shared/models/partner_link.dart`
- Create: `EVE_MOBILE/app/lib/shared/models/partner_permissions.dart`
- Create: `EVE_MOBILE/app/lib/shared/models/partner_view.dart`
- Create: `EVE_MOBILE/app/lib/shared/models/chat_message.dart`
- Test: `EVE_MOBILE/app/test/shared/models/firestore_models_test.dart`

**Interfaces:**
- Consumes: field names/types from Task 1's `functions/src/types.ts` (must mirror exactly).
- Produces (exact names later plans reference): `UserProfile`, `LifeStageProfile` (abstract) + `EmptyLifeStageProfile`/`CycleLifeStageProfile`/`PregnantLifeStageProfile`/`SimplifiedLifeStageProfile`, `SymptomLog`, `GoalsPreferences`/`NotificationPreferences`/`AiScopePreferences`/`ThemePreferences`, `PartnerLink`, `PartnerPermissions`, `PartnerView`, `ChatMessage`. Every class exposes `Map<String, dynamic> toMap()` and a `factory X.fromMap(Map<String, dynamic> map)`.

- [ ] **Step 1: Verify Dart SDK is available**

Run: `dart --version`
Expected: prints a Dart SDK version `3.x`. If missing, install the Dart SDK (or a Flutter SDK, which bundles it) before continuing.

- [ ] **Step 2: Create `EVE_MOBILE/app/pubspec.yaml`**

```yaml
name: eve_app
description: >
  EVE mobile app. This pubspec currently covers only the pure-Dart shared
  model layer (Plan 5); Plan 2/3 extend it with the full Flutter/Firebase
  dependency set — merge, do not overwrite, if both exist.
publish_to: 'none'
environment:
  sdk: '>=3.3.0 <4.0.0'
dev_dependencies:
  test: ^1.25.0
```

- [ ] **Step 3: Write the failing test for `UserProfile`**

Create `EVE_MOBILE/app/test/shared/models/firestore_models_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:eve_app/shared/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('round-trips through toMap/fromMap', () {
      final createdAt = DateTime.utc(2026, 1, 1);
      final updatedAt = DateTime.utc(2026, 1, 2);
      final profile = UserProfile(
        authId: 'uid-1',
        name: 'Priya',
        age: 29,
        height: 165,
        weight: 58,
        country: 'India',
        lifeStage: 'cycle',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final map = profile.toMap();
      final roundTripped = UserProfile.fromMap(map);

      expect(roundTripped.authId, 'uid-1');
      expect(roundTripped.name, 'Priya');
      expect(roundTripped.age, 29);
      expect(roundTripped.height, 165);
      expect(roundTripped.weight, 58);
      expect(roundTripped.country, 'India');
      expect(roundTripped.lifeStage, 'cycle');
      expect(roundTripped.createdAt, createdAt);
      expect(roundTripped.updatedAt, updatedAt);
    });

    test('handles null optional fields', () {
      final profile = UserProfile(
        authId: 'uid-2',
        name: '',
        age: null,
        height: null,
        weight: null,
        country: null,
        lifeStage: null,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final roundTripped = UserProfile.fromMap(profile.toMap());
      expect(roundTripped.age, isNull);
      expect(roundTripped.lifeStage, isNull);
    });
  });
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run (from `EVE_MOBILE/app/`): `dart pub get && dart test test/shared/models/firestore_models_test.dart`
Expected: FAIL — `Error: Not found: 'package:eve_app/shared/models/user_profile.dart'` (file doesn't exist yet).

- [ ] **Step 5: Implement `EVE_MOBILE/app/lib/shared/models/user_profile.dart`**

```dart
/// Mirrors functions/src/types.ts `UserProfile`.
/// Firestore path: users/{uid}
class UserProfile {
  const UserProfile({
    required this.authId,
    required this.name,
    required this.age,
    required this.height, // centimeters
    required this.weight, // kilograms
    required this.country,
    required this.lifeStage, // 'cycle' | 'conceive' | 'pregnant' | 'postpartum' | 'menopause' | null
    required this.createdAt,
    required this.updatedAt,
  });

  final String authId;
  final String name;
  final int? age;
  final num? height;
  final num? weight;
  final String? country;
  final String? lifeStage;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      authId: map['authId'] as String,
      name: map['name'] as String,
      age: map['age'] as int?,
      height: map['height'] as num?,
      weight: map['weight'] as num?,
      country: map['country'] as String?,
      lifeStage: map['lifeStage'] as String?,
      createdAt: _parseTimestamp(map['createdAt'])!,
      updatedAt: _parseTimestamp(map['updatedAt'])!,
    );
  }

  Map<String, dynamic> toMap() => {
        'authId': authId,
        'name': name,
        'age': age,
        'height': height,
        'weight': weight,
        'country': country,
        'lifeStage': lifeStage,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}

/// Shared by every model file in this directory. Accepts either a Dart
/// [DateTime] or anything duck-typed like a Firestore `Timestamp` (i.e.
/// exposing a no-arg `toDate()` returning a DateTime), so these models stay
/// dependency-free of `cloud_firestore` while still accepting real Firestore
/// documents once a repository layer reads them.
DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  try {
    final dynamic converted = (value as dynamic).toDate();
    if (converted is DateTime) return converted;
  } catch (_) {
    // fall through to the error below
  }
  throw ArgumentError('Unsupported timestamp value: $value');
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `dart test test/shared/models/firestore_models_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 7: Write the failing test for `LifeStageProfile`**

Append to `EVE_MOBILE/app/test/shared/models/firestore_models_test.dart` (add import `package:eve_app/shared/models/life_stage_profile.dart` at the top):

```dart
  group('LifeStageProfile', () {
    test('cycle branch round-trips', () {
      final profile = CycleLifeStageProfile(
        cycleLength: 28,
        periodLength: 5,
        flow: 'moderate',
        cycleSymptoms: const ['cramps', 'bloating'],
        cycleGoals: const ['predictNextPeriod', 'betterNutrition'],
        nutritionDiet: 'vegan',
      );
      final roundTripped = LifeStageProfile.fromMap(profile.toMap());
      expect(roundTripped, isA<CycleLifeStageProfile>());
      final cycle = roundTripped as CycleLifeStageProfile;
      expect(cycle.cycleLength, 28);
      expect(cycle.cycleSymptoms, ['cramps', 'bloating']);
      expect(cycle.nutritionDiet, 'vegan');
    });

    test('pregnant branch round-trips', () {
      final dueDate = DateTime.utc(2026, 6, 1);
      final profile = PregnantLifeStageProfile(
        dueDate: dueDate,
        dueMethod: 'dueDate',
        highRisk: false,
        pregnancyType: 'single',
        medications: 'iron',
        allergies: null,
        prenatalVitamins: true,
        pregnantSymptoms: const ['morningSickness'],
      );
      final roundTripped = LifeStageProfile.fromMap(profile.toMap());
      expect(roundTripped, isA<PregnantLifeStageProfile>());
      final pregnant = roundTripped as PregnantLifeStageProfile;
      expect(pregnant.dueDate, dueDate);
      expect(pregnant.prenatalVitamins, true);
    });

    test('simplified branches (conceive/postpartum/menopause) round-trip', () {
      final profile = SimplifiedLifeStageProfile(
        type: 'menopause',
        simplifiedSymptoms: const ['hotFlashes', 'sleepDisturbances'],
        simplifiedGoals: const ['manageSymptoms'],
      );
      final roundTripped = LifeStageProfile.fromMap(profile.toMap());
      expect(roundTripped, isA<SimplifiedLifeStageProfile>());
      expect((roundTripped as SimplifiedLifeStageProfile).type, 'menopause');
    });

    test('empty shell round-trips', () {
      final roundTripped = LifeStageProfile.fromMap(const EmptyLifeStageProfile().toMap());
      expect(roundTripped, isA<EmptyLifeStageProfile>());
    });
  });
```

- [ ] **Step 8: Run to verify it fails**

Run: `dart test test/shared/models/firestore_models_test.dart`
Expected: FAIL — `life_stage_profile.dart` not found.

- [ ] **Step 9: Implement `EVE_MOBILE/app/lib/shared/models/life_stage_profile.dart`**

```dart
/// Mirrors functions/src/types.ts `LifeStageProfile` discriminated union.
/// Firestore path: users/{uid}/lifeStageProfile/current
abstract class LifeStageProfile {
  const LifeStageProfile();

  Map<String, dynamic> toMap();

  factory LifeStageProfile.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String?;
    switch (type) {
      case 'cycle':
        return CycleLifeStageProfile.fromMap(map);
      case 'pregnant':
        return PregnantLifeStageProfile.fromMap(map);
      case 'conceive':
      case 'postpartum':
      case 'menopause':
        return SimplifiedLifeStageProfile.fromMap(map);
      case null:
        return const EmptyLifeStageProfile();
      default:
        throw ArgumentError('Unknown lifeStageProfile type: $type');
    }
  }
}

/// Shell state written by onUserCreate, before onboarding reaches the
/// life-stage selector screen.
class EmptyLifeStageProfile extends LifeStageProfile {
  const EmptyLifeStageProfile();

  @override
  Map<String, dynamic> toMap() => {'type': null};
}

class CycleLifeStageProfile extends LifeStageProfile {
  const CycleLifeStageProfile({
    required this.cycleLength,
    required this.periodLength,
    required this.flow, // 'light' | 'moderate' | 'heavy'
    required this.cycleSymptoms,
    required this.cycleGoals,
    this.nutritionDiet, // 'veg' | 'nonveg' | 'vegan', set only if cycleGoals includes 'betterNutrition'
  });

  final int cycleLength;
  final int periodLength;
  final String flow;
  final List<String> cycleSymptoms;
  final List<String> cycleGoals;
  final String? nutritionDiet;

  factory CycleLifeStageProfile.fromMap(Map<String, dynamic> map) {
    return CycleLifeStageProfile(
      cycleLength: map['cycleLength'] as int,
      periodLength: map['periodLength'] as int,
      flow: map['flow'] as String,
      cycleSymptoms: List<String>.from(map['cycleSymptoms'] as List),
      cycleGoals: List<String>.from(map['cycleGoals'] as List),
      nutritionDiet: map['nutritionDiet'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'type': 'cycle',
        'cycleLength': cycleLength,
        'periodLength': periodLength,
        'flow': flow,
        'cycleSymptoms': cycleSymptoms,
        'cycleGoals': cycleGoals,
        'nutritionDiet': nutritionDiet,
      };
}

class PregnantLifeStageProfile extends LifeStageProfile {
  const PregnantLifeStageProfile({
    required this.dueDate,
    required this.dueMethod, // 'dueDate' | 'lastPeriod' | 'doctorEstimate'
    required this.highRisk,
    required this.pregnancyType, // 'single' | 'twins'
    required this.medications,
    required this.allergies,
    required this.prenatalVitamins,
    required this.pregnantSymptoms,
  });

  final DateTime? dueDate;
  final String dueMethod;
  final bool highRisk;
  final String pregnancyType;
  final String? medications;
  final String? allergies;
  final bool prenatalVitamins;
  final List<String> pregnantSymptoms;

  factory PregnantLifeStageProfile.fromMap(Map<String, dynamic> map) {
    return PregnantLifeStageProfile(
      dueDate: _parseNullableTimestamp(map['dueDate']),
      dueMethod: map['dueMethod'] as String,
      highRisk: map['highRisk'] as bool,
      pregnancyType: map['pregnancyType'] as String,
      medications: map['medications'] as String?,
      allergies: map['allergies'] as String?,
      prenatalVitamins: map['prenatalVitamins'] as bool,
      pregnantSymptoms: List<String>.from(map['pregnantSymptoms'] as List),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'type': 'pregnant',
        'dueDate': dueDate,
        'dueMethod': dueMethod,
        'highRisk': highRisk,
        'pregnancyType': pregnancyType,
        'medications': medications,
        'allergies': allergies,
        'prenatalVitamins': prenatalVitamins,
        'pregnantSymptoms': pregnantSymptoms,
      };
}

class SimplifiedLifeStageProfile extends LifeStageProfile {
  const SimplifiedLifeStageProfile({
    required this.type, // 'conceive' | 'postpartum' | 'menopause'
    required this.simplifiedSymptoms,
    required this.simplifiedGoals,
  });

  final String type;
  final List<String> simplifiedSymptoms;
  final List<String> simplifiedGoals;

  factory SimplifiedLifeStageProfile.fromMap(Map<String, dynamic> map) {
    return SimplifiedLifeStageProfile(
      type: map['type'] as String,
      simplifiedSymptoms: List<String>.from(map['simplifiedSymptoms'] as List),
      simplifiedGoals: List<String>.from(map['simplifiedGoals'] as List),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'type': type,
        'simplifiedSymptoms': simplifiedSymptoms,
        'simplifiedGoals': simplifiedGoals,
      };
}

DateTime? _parseNullableTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final dynamic converted = (value as dynamic).toDate();
  if (converted is DateTime) return converted;
  throw ArgumentError('Unsupported timestamp value: $value');
}
```

- [ ] **Step 10: Run to verify it passes**

Run: `dart test test/shared/models/firestore_models_test.dart`
Expected: PASS (6 tests so far).

- [ ] **Step 11: Write failing tests for the remaining 6 model files**

Append to the same test file (add the 6 new imports at the top: `package:eve_app/shared/models/symptom_log.dart`, `preferences.dart`, `partner_link.dart`, `partner_permissions.dart`, `partner_view.dart`, `chat_message.dart`):

```dart
  group('SymptomLog', () {
    test('round-trips', () {
      final date = DateTime.utc(2026, 3, 4);
      final log = SymptomLog(
        date: date,
        symptoms: const ['cramps', 'fatigue'],
        mood: 'okay',
        painLevel: 4,
        notes: 'Felt tired by evening.',
        createdAt: date,
        updatedAt: date,
      );
      final roundTripped = SymptomLog.fromMap(log.toMap());
      expect(roundTripped.symptoms, ['cramps', 'fatigue']);
      expect(roundTripped.painLevel, 4);
      expect(roundTripped.mood, 'okay');
    });
  });

  group('Preferences', () {
    test('GoalsPreferences round-trips', () {
      const goals = GoalsPreferences(
        selectedGoals: ['predictNextPeriod'],
        dietType: 'vegan',
        foodAllergies: 'peanuts',
        cuisines: ['indian', 'italian'],
        workoutPreference: ['yoga', 'walking'],
      );
      final roundTripped = GoalsPreferences.fromMap(goals.toMap());
      expect(roundTripped.dietType, 'vegan');
      expect(roundTripped.workoutPreference, ['yoga', 'walking']);
    });

    test('NotificationPreferences round-trips', () {
      const prefs = NotificationPreferences(enabledReminders: ['morningReminder', 'dailyAiTip']);
      final roundTripped = NotificationPreferences.fromMap(prefs.toMap());
      expect(roundTripped.enabledReminders, ['morningReminder', 'dailyAiTip']);
    });

    test('AiScopePreferences round-trips', () {
      const prefs = AiScopePreferences(enabledHelpAreas: ['nutrition', 'doctorPrep']);
      final roundTripped = AiScopePreferences.fromMap(prefs.toMap());
      expect(roundTripped.enabledHelpAreas, ['nutrition', 'doctorPrep']);
    });

    test('ThemePreferences round-trips', () {
      const prefs = ThemePreferences(selectedTheme: 'dark');
      final roundTripped = ThemePreferences.fromMap(prefs.toMap());
      expect(roundTripped.selectedTheme, 'dark');
    });
  });

  group('PartnerLink', () {
    test('round-trips with nulls before an invite is accepted', () {
      const link = PartnerLink(
        partnerUserId: null,
        relationshipType: 'husband',
        inviteStatus: 'pending',
        invitedAt: null,
        linkedAt: null,
      );
      final roundTripped = PartnerLink.fromMap(link.toMap());
      expect(roundTripped.inviteStatus, 'pending');
      expect(roundTripped.partnerUserId, isNull);
    });
  });

  group('PartnerPermissions', () {
    test('round-trips', () {
      const perms = PartnerPermissions(
        approvedCategories: ['moodReminders', 'appointmentReminders'],
        onlyApproveMode: true,
      );
      final roundTripped = PartnerPermissions.fromMap(perms.toMap());
      expect(roundTripped.onlyApproveMode, true);
      expect(roundTripped.approvedCategories, ['moodReminders', 'appointmentReminders']);
    });
  });

  group('PartnerView', () {
    test('round-trips the container shape', () {
      final now = DateTime.utc(2026, 1, 1);
      final view = PartnerView(
        primaryUserId: 'uid-1',
        approvedCategories: const ['moodReminders'],
        lastUpdatedAt: now,
        appointmentReminders: null,
        pregnancyMilestones: null,
        supportSuggestions: null,
        moodReminders: const [],
      );
      final roundTripped = PartnerView.fromMap(view.toMap());
      expect(roundTripped.primaryUserId, 'uid-1');
      expect(roundTripped.moodReminders, isEmpty);
    });
  });

  group('ChatMessage', () {
    test('round-trips a text message', () {
      final ts = DateTime.utc(2026, 1, 1, 9);
      final message = ChatMessage(
        senderId: 'her',
        messageText: 'Feeling okay today.',
        timestamp: ts,
        type: 'text',
      );
      final roundTripped = ChatMessage.fromMap(message.toMap());
      expect(roundTripped.senderId, 'her');
      expect(roundTripped.type, 'text');
    });

    test('round-trips a system message', () {
      final ts = DateTime.utc(2026, 1, 1, 9);
      final message = ChatMessage(
        senderId: 'system',
        messageText: 'She logged a difficult day today.',
        timestamp: ts,
        type: 'system',
      );
      final roundTripped = ChatMessage.fromMap(message.toMap());
      expect(roundTripped.senderId, 'system');
      expect(roundTripped.type, 'system');
    });
  });
```

- [ ] **Step 12: Run to verify all 6 groups fail**

Run: `dart test test/shared/models/firestore_models_test.dart`
Expected: FAIL — missing files for `symptom_log.dart`, `preferences.dart`, `partner_link.dart`, `partner_permissions.dart`, `partner_view.dart`, `chat_message.dart`.

- [ ] **Step 13: Implement `EVE_MOBILE/app/lib/shared/models/symptom_log.dart`**

```dart
/// Mirrors functions/src/types.ts `SymptomLog`.
/// Firestore path: users/{uid}/logs/{logId}
class SymptomLog {
  const SymptomLog({
    required this.date,
    required this.symptoms,
    required this.mood, // 'great' | 'good' | 'okay' | 'low' | 'difficult' | null
    required this.painLevel, // 0-10
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final DateTime date;
  final List<String> symptoms;
  final String? mood;
  final int? painLevel;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SymptomLog.fromMap(Map<String, dynamic> map) {
    return SymptomLog(
      date: _parseTimestamp(map['date'])!,
      symptoms: List<String>.from(map['symptoms'] as List),
      mood: map['mood'] as String?,
      painLevel: map['painLevel'] as int?,
      notes: map['notes'] as String,
      createdAt: _parseTimestamp(map['createdAt'])!,
      updatedAt: _parseTimestamp(map['updatedAt'])!,
    );
  }

  Map<String, dynamic> toMap() => {
        'date': date,
        'symptoms': symptoms,
        'mood': mood,
        'painLevel': painLevel,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}

DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final dynamic converted = (value as dynamic).toDate();
  if (converted is DateTime) return converted;
  throw ArgumentError('Unsupported timestamp value: $value');
}
```

- [ ] **Step 14: Implement `EVE_MOBILE/app/lib/shared/models/preferences.dart`**

```dart
/// Mirrors functions/src/types.ts GoalsPreferences / NotificationPreferences /
/// AiScopePreferences / ThemePreferences.
/// Firestore paths: users/{uid}/preferences/{goals|notifications|aiScope|theme}

class GoalsPreferences {
  const GoalsPreferences({
    required this.selectedGoals,
    required this.dietType, // 'veg' | 'nonveg' | 'vegan' | null
    required this.foodAllergies,
    required this.cuisines,
    required this.workoutPreference,
  });

  final List<String> selectedGoals;
  final String? dietType;
  final String foodAllergies;
  final List<String> cuisines;
  final List<String> workoutPreference;

  factory GoalsPreferences.fromMap(Map<String, dynamic> map) {
    return GoalsPreferences(
      selectedGoals: List<String>.from(map['selectedGoals'] as List),
      dietType: map['dietType'] as String?,
      foodAllergies: map['foodAllergies'] as String,
      cuisines: List<String>.from(map['cuisines'] as List),
      workoutPreference: List<String>.from(map['workoutPreference'] as List),
    );
  }

  Map<String, dynamic> toMap() => {
        'selectedGoals': selectedGoals,
        'dietType': dietType,
        'foodAllergies': foodAllergies,
        'cuisines': cuisines,
        'workoutPreference': workoutPreference,
      };
}

class NotificationPreferences {
  const NotificationPreferences({required this.enabledReminders});

  final List<String> enabledReminders;

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      enabledReminders: List<String>.from(map['enabledReminders'] as List),
    );
  }

  Map<String, dynamic> toMap() => {'enabledReminders': enabledReminders};
}

class AiScopePreferences {
  const AiScopePreferences({required this.enabledHelpAreas});

  final List<String> enabledHelpAreas;

  factory AiScopePreferences.fromMap(Map<String, dynamic> map) {
    return AiScopePreferences(
      enabledHelpAreas: List<String>.from(map['enabledHelpAreas'] as List),
    );
  }

  Map<String, dynamic> toMap() => {'enabledHelpAreas': enabledHelpAreas};
}

class ThemePreferences {
  const ThemePreferences({required this.selectedTheme}); // 'light' | 'dark' | 'default'

  final String selectedTheme;

  factory ThemePreferences.fromMap(Map<String, dynamic> map) {
    return ThemePreferences(selectedTheme: map['selectedTheme'] as String);
  }

  Map<String, dynamic> toMap() => {'selectedTheme': selectedTheme};
}
```

- [ ] **Step 15: Implement `EVE_MOBILE/app/lib/shared/models/partner_link.dart`**

```dart
/// Mirrors functions/src/types.ts `PartnerLink`.
/// Firestore path: users/{uid}/partnerLink/current
class PartnerLink {
  const PartnerLink({
    required this.partnerUserId,
    required this.relationshipType, // 'husband' | 'boyfriend' | 'partner' | null
    required this.inviteStatus, // 'none' | 'pending' | 'accepted' | 'declined'
    required this.invitedAt,
    required this.linkedAt,
  });

  final String? partnerUserId;
  final String? relationshipType;
  final String inviteStatus;
  final DateTime? invitedAt;
  final DateTime? linkedAt;

  factory PartnerLink.fromMap(Map<String, dynamic> map) {
    return PartnerLink(
      partnerUserId: map['partnerUserId'] as String?,
      relationshipType: map['relationshipType'] as String?,
      inviteStatus: map['inviteStatus'] as String,
      invitedAt: _parseTimestamp(map['invitedAt']),
      linkedAt: _parseTimestamp(map['linkedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'partnerUserId': partnerUserId,
        'relationshipType': relationshipType,
        'inviteStatus': inviteStatus,
        'invitedAt': invitedAt,
        'linkedAt': linkedAt,
      };
}

DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final dynamic converted = (value as dynamic).toDate();
  if (converted is DateTime) return converted;
  throw ArgumentError('Unsupported timestamp value: $value');
}
```

- [ ] **Step 16: Implement `EVE_MOBILE/app/lib/shared/models/partner_permissions.dart`**

```dart
/// Mirrors functions/src/types.ts `PartnerPermissions`.
/// Firestore path: users/{uid}/partnerPermissions/current
class PartnerPermissions {
  const PartnerPermissions({
    required this.approvedCategories,
    required this.onlyApproveMode,
  });

  final List<String> approvedCategories;
  final bool onlyApproveMode;

  factory PartnerPermissions.fromMap(Map<String, dynamic> map) {
    return PartnerPermissions(
      approvedCategories: List<String>.from(map['approvedCategories'] as List),
      onlyApproveMode: map['onlyApproveMode'] as bool,
    );
  }

  Map<String, dynamic> toMap() => {
        'approvedCategories': approvedCategories,
        'onlyApproveMode': onlyApproveMode,
      };
}
```

- [ ] **Step 17: Implement `EVE_MOBILE/app/lib/shared/models/partner_view.dart`**

```dart
/// Mirrors functions/src/types.ts `PartnerView`. This is the CONTAINER
/// contract only — per-category item shapes are finalized by
/// 07-partner-mode-consent.md's recompute function. This plan (05) defines
/// the schema and the read-only/server-write-only security rule; it does not
/// populate this document's contents.
/// Firestore path: users/{uid}/partnerView/current — server-written only.
class PartnerView {
  const PartnerView({
    required this.primaryUserId,
    required this.approvedCategories,
    required this.lastUpdatedAt,
    required this.appointmentReminders,
    required this.pregnancyMilestones,
    required this.supportSuggestions,
    required this.moodReminders,
  });

  final String primaryUserId;
  final List<String> approvedCategories;
  final DateTime lastUpdatedAt;
  final List<dynamic>? appointmentReminders;
  final List<dynamic>? pregnancyMilestones;
  final List<dynamic>? supportSuggestions;
  final List<dynamic>? moodReminders;

  factory PartnerView.fromMap(Map<String, dynamic> map) {
    return PartnerView(
      primaryUserId: map['primaryUserId'] as String,
      approvedCategories: List<String>.from(map['approvedCategories'] as List),
      lastUpdatedAt: _parseTimestamp(map['lastUpdatedAt'])!,
      appointmentReminders: map['appointmentReminders'] as List<dynamic>?,
      pregnancyMilestones: map['pregnancyMilestones'] as List<dynamic>?,
      supportSuggestions: map['supportSuggestions'] as List<dynamic>?,
      moodReminders: map['moodReminders'] as List<dynamic>?,
    );
  }

  Map<String, dynamic> toMap() => {
        'primaryUserId': primaryUserId,
        'approvedCategories': approvedCategories,
        'lastUpdatedAt': lastUpdatedAt,
        'appointmentReminders': appointmentReminders,
        'pregnancyMilestones': pregnancyMilestones,
        'supportSuggestions': supportSuggestions,
        'moodReminders': moodReminders,
      };
}

DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final dynamic converted = (value as dynamic).toDate();
  if (converted is DateTime) return converted;
  throw ArgumentError('Unsupported timestamp value: $value');
}
```

- [ ] **Step 18: Implement `EVE_MOBILE/app/lib/shared/models/chat_message.dart`**

```dart
/// Mirrors functions/src/types.ts `ChatMessage`.
/// Firestore path: users/{uid}/chat/{messageId}
class ChatMessage {
  const ChatMessage({
    required this.senderId, // 'her' | 'partner' | 'system'
    required this.messageText,
    required this.timestamp,
    required this.type, // 'text' | 'system'
  });

  final String senderId;
  final String messageText;
  final DateTime timestamp;
  final String type;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      senderId: map['senderId'] as String,
      messageText: map['messageText'] as String,
      timestamp: _parseTimestamp(map['timestamp'])!,
      type: map['type'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'messageText': messageText,
        'timestamp': timestamp,
        'type': type,
      };
}

DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final dynamic converted = (value as dynamic).toDate();
  if (converted is DateTime) return converted;
  throw ArgumentError('Unsupported timestamp value: $value');
}
```

- [ ] **Step 19: Run the full test file to verify everything passes**

Run: `dart test test/shared/models/firestore_models_test.dart`
Expected: PASS — all groups (`UserProfile`, `LifeStageProfile`, `SymptomLog`, `Preferences`, `PartnerLink`, `PartnerPermissions`, `PartnerView`, `ChatMessage`), 16 tests total, 0 failures.

- [ ] **Step 20: Commit**

```bash
git add EVE_MOBILE/app/pubspec.yaml EVE_MOBILE/app/lib/shared/models EVE_MOBILE/app/test/shared/models EVE_MOBILE/app/pubspec.lock
git commit -m "feat(app): add Dart mirror models for the Firestore schema"
```

---

## Task 3: `firestore.rules` + emulator rules tests

**Files:**
- Create: `EVE_MOBILE/firebase.json`
- Create: `EVE_MOBILE/firestore.indexes.json`
- Create: `EVE_MOBILE/firestore.rules`
- Test: `EVE_MOBILE/functions/test/emulatorSetup.ts`
- Test: `EVE_MOBILE/functions/jest.config.js`
- Test: `EVE_MOBILE/functions/test/rules/firestore.rules.test.ts`

**Interfaces:**
- Consumes: canonical paths from `00-design-spec.md` §10; field names `senderId`/`type` from Task 1's `ChatMessage`.
- Produces: `EVE_MOBILE/firestore.rules` (real rules file, referenced by path from Task 4's tests too), `EVE_MOBILE/firebase.json` emulator config (Firestore on `127.0.0.1:8080`, Auth on `127.0.0.1:9099`) that Task 4 also runs against.

- [ ] **Step 1: Create `EVE_MOBILE/firestore.indexes.json`**

```json
{
  "indexes": [],
  "fieldOverrides": []
}
```

- [ ] **Step 2: Create `EVE_MOBILE/firebase.json`**

```json
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "functions": {
    "source": "functions"
  },
  "emulators": {
    "firestore": {
      "port": 8080
    },
    "auth": {
      "port": 9099
    },
    "functions": {
      "port": 5001
    },
    "ui": {
      "enabled": true
    }
  }
}
```

- [ ] **Step 3: Create a placeholder deny-all `EVE_MOBILE/firestore.rules`**

This intentionally denies everything so the tests written next fail for the right reason before the real rules exist.

```
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

- [ ] **Step 4: Create `EVE_MOBILE/functions/test/emulatorSetup.ts`**

```typescript
process.env.GCLOUD_PROJECT = 'demo-eve-test';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
```

- [ ] **Step 5: Create `EVE_MOBILE/functions/jest.config.js`**

```javascript
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: '.',
  testMatch: ['<rootDir>/test/**/*.test.ts'],
  setupFiles: ['<rootDir>/test/emulatorSetup.ts'],
  testTimeout: 20000,
};
```

- [ ] **Step 6: Write the rules test file — `EVE_MOBILE/functions/test/rules/firestore.rules.test.ts`**

```typescript
import * as fs from 'fs';
import * as path from 'path';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, serverTimestamp } from 'firebase/firestore';

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-eve-test',
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '../../../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

async function seedPartnerLink(primaryUid: string, partnerUid: string) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, `partnerLinks/${partnerUid}`), {
      primaryUserId: primaryUid,
      relationshipType: 'husband',
      linkedAt: serverTimestamp(),
    });
    await setDoc(doc(db, `users/${primaryUid}/partnerView/current`), {
      primaryUserId: primaryUid,
      approvedCategories: ['moodReminders'],
      lastUpdatedAt: serverTimestamp(),
      appointmentReminders: null,
      pregnancyMilestones: null,
      supportSuggestions: null,
      moodReminders: [],
    });
  });
}

test('(a) owner can read and write her own logs', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(
    setDoc(doc(alice, 'users/alice/logs/log1'), {
      date: serverTimestamp(),
      symptoms: ['cramps'],
      mood: 'okay',
      painLevel: 3,
      notes: '',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(getDoc(doc(alice, 'users/alice/logs/log1')));
});

test("(b) a random authenticated user cannot read another user's logs", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users/alice/logs/log1'), { symptoms: ['cramps'] });
  });
  const mallory = testEnv.authenticatedContext('mallory').firestore();
  await assertFails(getDoc(doc(mallory, 'users/alice/logs/log1')));
});

test('(c) a linked partner can read partnerView but not logs or lifeStageProfile', async () => {
  await seedPartnerLink('alice', 'bob');
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/alice/logs/log1'), { symptoms: ['cramps'] });
    await setDoc(doc(db, 'users/alice/lifeStageProfile/current'), { type: 'cycle' });
  });
  const bob = testEnv.authenticatedContext('bob').firestore();
  await assertSucceeds(getDoc(doc(bob, 'users/alice/partnerView/current')));
  await assertFails(getDoc(doc(bob, 'users/alice/logs/log1')));
  await assertFails(getDoc(doc(bob, 'users/alice/lifeStageProfile/current')));
});

test('(d) no client, not even the owner, can write partnerView', async () => {
  const partnerViewPayload = {
    primaryUserId: 'alice',
    approvedCategories: [],
    lastUpdatedAt: serverTimestamp(),
    appointmentReminders: null,
    pregnancyMilestones: null,
    supportSuggestions: null,
    moodReminders: null,
  };

  const alice = testEnv.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(alice, 'users/alice/partnerView/current'), partnerViewPayload));

  await seedPartnerLink('alice', 'bob');
  const bob = testEnv.authenticatedContext('bob').firestore();
  await assertFails(setDoc(doc(bob, 'users/alice/partnerView/current'), partnerViewPayload));
});

test('(e) only a system-authored chat message may have type "system"', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();

  await assertFails(
    setDoc(doc(alice, 'users/alice/chat/msg1'), {
      senderId: 'her',
      messageText: 'spoofed system nudge',
      timestamp: serverTimestamp(),
      type: 'system',
    }),
  );

  await assertSucceeds(
    setDoc(doc(alice, 'users/alice/chat/msg2'), {
      senderId: 'her',
      messageText: 'hello',
      timestamp: serverTimestamp(),
      type: 'text',
    }),
  );

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await assertSucceeds(
      setDoc(doc(context.firestore(), 'users/alice/chat/msg3'), {
        senderId: 'system',
        messageText: 'She logged a difficult day today.',
        timestamp: serverTimestamp(),
        type: 'system',
      }),
    );
  });
});

test('(f) a linked partner can read and write chat, with senderId "partner"', async () => {
  await seedPartnerLink('alice', 'bob');
  const bob = testEnv.authenticatedContext('bob').firestore();

  await assertSucceeds(
    setDoc(doc(bob, 'users/alice/chat/msg4'), {
      senderId: 'partner',
      messageText: 'Thinking of you today.',
      timestamp: serverTimestamp(),
      type: 'text',
    }),
  );
  await assertSucceeds(getDoc(doc(bob, 'users/alice/chat/msg4')));
});
```

- [ ] **Step 7: Install npm deps and run to verify all tests fail against the deny-all placeholder**

Run (from `EVE_MOBILE/`): `cd functions && npm install`
Run (from `EVE_MOBILE/`): `npm run test:emulator --prefix functions -- --testPathPattern=rules`

Actually run directly: `cd EVE_MOBILE/functions && npm run test:emulator`

Expected: the emulator starts, then Jest reports FAIL for tests (a), (c) (read half succeeds is false — actually the whole read is denied), (e) (text message create denied), (f) (denied) — every rule that should `assertSucceeds` instead gets a permission-denied and fails the assertion, because the placeholder rules deny everything. Tests (b) and (d) (which assert failure) PASS even against deny-all, since deny-all also denies those. This confirms the test harness is wired correctly before writing real rules.

- [ ] **Step 8: Replace the placeholder with the real `EVE_MOBILE/firestore.rules`**

```
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(uid) {
      return isSignedIn() && request.auth.uid == uid;
    }

    // A "linked partner" is anyone whose own uid has a reverse-lookup doc at
    // partnerLinks/{their uid} pointing back at this primary user's uid.
    function isLinkedPartner(uid) {
      return isSignedIn()
        && exists(/databases/$(database)/documents/partnerLinks/$(request.auth.uid))
        && get(/databases/$(database)/documents/partnerLinks/$(request.auth.uid)).data.primaryUserId == uid;
    }

    // users/{uid} — root User Profile document. Owner only.
    match /users/{uid} {
      allow read, write: if isOwner(uid);
    }

    // users/{uid}/lifeStageProfile/current — owner only, never shared with a partner.
    match /users/{uid}/lifeStageProfile/{docId} {
      allow read, write: if isOwner(uid);
    }

    // users/{uid}/logs/{logId} — Symptom/Mood Log. Owner only, never shared directly.
    match /users/{uid}/logs/{logId} {
      allow read, write: if isOwner(uid);
    }

    // users/{uid}/preferences/{goals|notifications|aiScope|theme} — owner only.
    match /users/{uid}/preferences/{prefDoc} {
      allow read, write: if isOwner(uid);
    }

    // users/{uid}/partnerLink/current — owner manages her own invite state.
    match /users/{uid}/partnerLink/{docId} {
      allow read, write: if isOwner(uid);
    }

    // users/{uid}/partnerPermissions/current — the consent switchboard. Owner only.
    match /users/{uid}/partnerPermissions/{docId} {
      allow read, write: if isOwner(uid);
    }

    // users/{uid}/partnerView/current — server-generated filtered projection.
    // Owner and linked partner may READ. No client, not even the owner, may write —
    // only a Cloud Function via the Admin SDK, which bypasses these rules entirely.
    match /users/{uid}/partnerView/{docId} {
      allow read: if isOwner(uid) || isLinkedPartner(uid);
      allow write: if false;
    }

    // users/{uid}/chat/{messageId} — shared thread between owner and linked partner.
    // A `type: 'system'` message can only be written by a Cloud Function (Admin SDK
    // bypasses rules) — a client attempting to set type: 'system' is rejected here.
    match /users/{uid}/chat/{messageId} {
      allow read: if isOwner(uid) || isLinkedPartner(uid);

      allow create: if (isOwner(uid) || isLinkedPartner(uid))
                    && request.resource.data.type is string
                    && request.resource.data.type != 'system'
                    && request.resource.data.senderId is string
                    && (isOwner(uid)
                          ? request.resource.data.senderId == 'her'
                          : request.resource.data.senderId == 'partner')
                    && request.resource.data.messageText is string
                    && request.resource.data.messageText.size() > 0;

      allow update, delete: if false; // chat is append-only from clients
    }

    // partnerLinks/{partnerUid} — top-level reverse lookup, server-written only.
    // A partner may read her own reverse-lookup doc to resolve which primary
    // user's partnerView/chat to read.
    match /partnerLinks/{partnerUid} {
      allow read: if isSignedIn() && request.auth.uid == partnerUid;
      allow write: if false;
    }
  }
}
```

- [ ] **Step 9: Run the rules tests again to verify they all pass**

Run (from `EVE_MOBILE/functions/`): `npm run test:emulator`
Expected: emulator starts, Jest reports PASS for all 7 tests in `test/rules/firestore.rules.test.ts` (a, b, c, d, e, f, and the deny-half of e).

- [ ] **Step 10: Commit**

```bash
git add EVE_MOBILE/firebase.json EVE_MOBILE/firestore.indexes.json EVE_MOBILE/firestore.rules EVE_MOBILE/functions/jest.config.js EVE_MOBILE/functions/test/emulatorSetup.ts EVE_MOBILE/functions/test/rules
git commit -m "feat: add firestore.rules with owner/partner/system access control and emulator rules tests"
```

---

## Task 4: `onUserCreate` Cloud Function

**Files:**
- Create: `EVE_MOBILE/functions/src/onUserCreate.ts`
- Create: `EVE_MOBILE/functions/src/index.ts`
- Test: `EVE_MOBILE/functions/test/onUserCreate.test.ts`

**Interfaces:**
- Consumes: `UserProfile`, `LifeStageProfile`, `GoalsPreferences`, `NotificationPreferences`, `AiScopePreferences`, `ThemePreferences`, `PartnerLink`, `PartnerPermissions`, `PartnerView` from Task 1's `functions/src/types.ts`; the Firestore + Auth emulators configured in Task 3's `firebase.json`.
- Produces: `onUserCreate` — a `functions.auth.user().onCreate` v1 trigger, exported from both `onUserCreate.ts` and re-exported from `index.ts`, consumed later by Plan 4 (build roadmap) and Plan 3 (deploy config).

- [ ] **Step 1: Write the failing test — `EVE_MOBILE/functions/test/onUserCreate.test.ts`**

```typescript
import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';

const test = functionsTest({ projectId: 'demo-eve-test' });

import { onUserCreate } from '../src/onUserCreate';

const TEST_UID = 'test-uid-onusercreate';

const DOC_PATHS = [
  `users/${TEST_UID}`,
  `users/${TEST_UID}/lifeStageProfile/current`,
  `users/${TEST_UID}/preferences/goals`,
  `users/${TEST_UID}/preferences/notifications`,
  `users/${TEST_UID}/preferences/aiScope`,
  `users/${TEST_UID}/preferences/theme`,
  `users/${TEST_UID}/partnerLink/current`,
  `users/${TEST_UID}/partnerPermissions/current`,
  `users/${TEST_UID}/partnerView/current`,
];

afterEach(async () => {
  const db = admin.firestore();
  await Promise.all(DOC_PATHS.map((p) => db.doc(p).delete()));
});

afterAll(async () => {
  test.cleanup();
});

describe('onUserCreate', () => {
  it('initializes the full document set for a new user in a single batch', async () => {
    const db = admin.firestore();
    const batchSpy = jest.spyOn(db, 'batch');

    const userRecord = test.auth.exampleUserRecord({ uid: TEST_UID, displayName: 'Priya' });
    const wrapped = test.wrap(onUserCreate);
    await wrapped(userRecord);

    expect(batchSpy).toHaveBeenCalledTimes(1);
    batchSpy.mockRestore();

    const [profile, lifeStage, goals, notifications, aiScope, theme, partnerLink, partnerPermissions, partnerView] =
      await Promise.all(DOC_PATHS.map((p) => db.doc(p).get()));

    expect(profile.exists).toBe(true);
    expect(profile.data()).toMatchObject({
      authId: TEST_UID,
      name: 'Priya',
      age: null,
      lifeStage: null,
    });

    expect(lifeStage.exists).toBe(true);
    expect(lifeStage.data()).toEqual({ type: null });

    expect(goals.exists).toBe(true);
    expect(goals.data()).toMatchObject({
      selectedGoals: [],
      dietType: null,
      foodAllergies: '',
      cuisines: [],
      workoutPreference: [],
    });

    expect(notifications.exists).toBe(true);
    expect(notifications.data()).toEqual({ enabledReminders: [] });

    expect(aiScope.exists).toBe(true);
    expect(aiScope.data()).toEqual({ enabledHelpAreas: [] });

    expect(theme.exists).toBe(true);
    expect(theme.data()).toEqual({ selectedTheme: 'default' });

    expect(partnerLink.exists).toBe(true);
    expect(partnerLink.data()).toMatchObject({
      partnerUserId: null,
      relationshipType: null,
      inviteStatus: 'none',
    });

    expect(partnerPermissions.exists).toBe(true);
    expect(partnerPermissions.data()).toEqual({ approvedCategories: [], onlyApproveMode: false });

    expect(partnerView.exists).toBe(true);
    expect(partnerView.data()).toMatchObject({
      primaryUserId: TEST_UID,
      approvedCategories: [],
      appointmentReminders: null,
      pregnancyMilestones: null,
      supportSuggestions: null,
      moodReminders: null,
    });
  });

  it('defaults name to an empty string when the Auth record has no displayName', async () => {
    const db = admin.firestore();
    const uid = `${TEST_UID}-nodisplay`;
    const userRecord = test.auth.exampleUserRecord({ uid, displayName: undefined });
    const wrapped = test.wrap(onUserCreate);
    await wrapped(userRecord);

    const profile = await db.doc(`users/${uid}`).get();
    expect(profile.data()?.name).toBe('');

    await Promise.all([
      db.doc(`users/${uid}`).delete(),
      db.doc(`users/${uid}/lifeStageProfile/current`).delete(),
      db.doc(`users/${uid}/preferences/goals`).delete(),
      db.doc(`users/${uid}/preferences/notifications`).delete(),
      db.doc(`users/${uid}/preferences/aiScope`).delete(),
      db.doc(`users/${uid}/preferences/theme`).delete(),
      db.doc(`users/${uid}/partnerLink/current`).delete(),
      db.doc(`users/${uid}/partnerPermissions/current`).delete(),
      db.doc(`users/${uid}/partnerView/current`).delete(),
    ]);
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run (from `EVE_MOBILE/functions/`): `npm run test:emulator`
Expected: FAIL — `Cannot find module '../src/onUserCreate'`.

- [ ] **Step 3: Implement `EVE_MOBILE/functions/src/onUserCreate.ts`**

```typescript
import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import type {
  UserProfile,
  GoalsPreferences,
  NotificationPreferences,
  AiScopePreferences,
  ThemePreferences,
  PartnerLink,
  PartnerPermissions,
  PartnerView,
} from './types';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

/**
 * Fires when a new Firebase Auth account is created. Writes every document
 * a user needs — profile, life-stage shell, preferences, partner scaffolding
 * — in a single atomic batch, so the client never observes a
 * partially-initialized user (EVE2_PRD.md §10.3). Onboarding screens (Plan 1)
 * subsequently `update()` these documents field-by-field; they never need to
 * `create()` them, because this function guarantees they already exist.
 *
 * Does NOT populate partnerView with real content — only the empty
 * container shape. Plan 7's recompute function owns writing real content
 * into partnerView once permissions/logs exist.
 */
export const onUserCreate = functions.auth.user().onCreate(async (user) => {
  const db = admin.firestore();
  const uid = user.uid;
  const now = admin.firestore.FieldValue.serverTimestamp();
  const batch = db.batch();

  const userProfile: Omit<UserProfile, 'createdAt' | 'updatedAt'> & {
    createdAt: FirebaseFirestore.FieldValue;
    updatedAt: FirebaseFirestore.FieldValue;
  } = {
    authId: uid,
    name: user.displayName ?? '',
    age: null,
    height: null,
    weight: null,
    country: null,
    lifeStage: null,
    createdAt: now,
    updatedAt: now,
  };
  batch.set(db.doc(`users/${uid}`), userProfile);

  batch.set(db.doc(`users/${uid}/lifeStageProfile/current`), { type: null });

  const goals: GoalsPreferences = {
    selectedGoals: [],
    dietType: null,
    foodAllergies: '',
    cuisines: [],
    workoutPreference: [],
  };
  batch.set(db.doc(`users/${uid}/preferences/goals`), goals);

  const notifications: NotificationPreferences = { enabledReminders: [] };
  batch.set(db.doc(`users/${uid}/preferences/notifications`), notifications);

  const aiScope: AiScopePreferences = { enabledHelpAreas: [] };
  batch.set(db.doc(`users/${uid}/preferences/aiScope`), aiScope);

  const theme: ThemePreferences = { selectedTheme: 'default' };
  batch.set(db.doc(`users/${uid}/preferences/theme`), theme);

  const partnerLink: Omit<PartnerLink, 'invitedAt' | 'linkedAt'> & {
    invitedAt: null;
    linkedAt: null;
  } = {
    partnerUserId: null,
    relationshipType: null,
    inviteStatus: 'none',
    invitedAt: null,
    linkedAt: null,
  };
  batch.set(db.doc(`users/${uid}/partnerLink/current`), partnerLink);

  const partnerPermissions: PartnerPermissions = {
    approvedCategories: [],
    onlyApproveMode: false,
  };
  batch.set(db.doc(`users/${uid}/partnerPermissions/current`), partnerPermissions);

  const partnerView: Omit<PartnerView, 'lastUpdatedAt'> & {
    lastUpdatedAt: FirebaseFirestore.FieldValue;
  } = {
    primaryUserId: uid,
    approvedCategories: [],
    lastUpdatedAt: now,
    appointmentReminders: null,
    pregnancyMilestones: null,
    supportSuggestions: null,
    moodReminders: null,
  };
  batch.set(db.doc(`users/${uid}/partnerView/current`), partnerView);

  await batch.commit();
});
```

- [ ] **Step 4: Create `EVE_MOBILE/functions/src/index.ts`**

```typescript
import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export { onUserCreate } from './onUserCreate';

// Added by later plans — kept here as a map of what belongs where so this
// file doesn't need re-discovering:
// export { onPartnerViewRecompute } from './partnerView';        // 07-partner-mode-consent.md
// export { onChatSystemMessage } from './chatSystemMessages';    // 07-partner-mode-consent.md
// export { aiProxy } from './aiProxy';                            // 03-tech-stack.md
// export { scheduledNotificationDispatch } from './notifications/scheduler'; // 03-tech-stack.md
```

- [ ] **Step 5: Run the tests to verify they pass**

Run (from `EVE_MOBILE/functions/`): `npm run test:emulator`
Expected: emulator starts, Jest reports PASS for both tests in `test/onUserCreate.test.ts` (and Task 3's rules tests still pass — the full suite runs together since `testMatch` covers `test/**/*.test.ts`).

- [ ] **Step 6: Run the full verification sweep**

Run (from `EVE_MOBILE/functions/`): `npm run test:types && npm run test:emulator`
Expected: both exit 0 — no TypeScript errors, all Jest tests (Task 3's 7 rules tests + Task 4's 2 function tests) pass.

- [ ] **Step 7: Commit**

```bash
git add EVE_MOBILE/functions/src/onUserCreate.ts EVE_MOBILE/functions/src/index.ts EVE_MOBILE/functions/test/onUserCreate.test.ts
git commit -m "feat(functions): add onUserCreate trigger that atomically initializes a new user's Firestore documents"
```

---

## Self-Review

**1. Spec coverage.**

| Design-spec §10 path | Covered by |
|---|---|
| `users/{uid}` | Task 1 `UserProfile`, Task 2 Dart mirror, Task 3 rules, Task 4 `onUserCreate` |
| `users/{uid}/lifeStageProfile/current` | Task 1 `LifeStageProfile` union (5 branches per §6/EVE2_PRD §4), Task 2 Dart mirror, Task 3 rules, Task 4 shell init |
| `users/{uid}/logs/{logId}` | Task 1 `SymptomLog`, Task 2 Dart mirror, Task 3 rules test (a)/(b)/(c) |
| `users/{uid}/preferences/goals` | Task 1 `GoalsPreferences`, Task 2, Task 3 rules, Task 4 init |
| `users/{uid}/preferences/notifications` | Task 1 `NotificationPreferences`, Task 2, Task 3 rules, Task 4 init |
| `users/{uid}/preferences/aiScope` | Task 1 `AiScopePreferences`, Task 2, Task 3 rules, Task 4 init |
| `users/{uid}/preferences/theme` | Task 1 `ThemePreferences`, Task 2, Task 3 rules, Task 4 init |
| `users/{uid}/partnerLink/current` | Task 1 `PartnerLink`, Task 2, Task 3 rules, Task 4 init |
| `users/{uid}/partnerPermissions/current` | Task 1 `PartnerPermissions`, Task 2, Task 3 rules, Task 4 init |
| `users/{uid}/partnerView/current` | Task 1 `PartnerView` (container only, per boundary), Task 2, Task 3 rules test (c)/(d), Task 4 shell init |
| `partnerLinks/{partnerUid}` | Task 1 `PartnerLinkReverseLookup`, Task 3 rules + `isLinkedPartner()` |
| `users/{uid}/chat/{messageId}` | Task 1 `ChatMessage`, Task 2, Task 3 rules test (e)/(f) |
| `onUserCreate` (EVE2_PRD §10.3) | Task 4 |
| Firebase Emulator Suite for all tests | Task 3 + Task 4 both run via `firebase emulators:exec` |
| `partnerView` recompute logic | Explicitly excluded — see Global Constraints and inline comments in Task 1/Task 4 pointing to Plan 7 |

**2. Placeholder scan.** No `TBD`/`later`/"add appropriate handling" strings appear in any step; every code block is complete, runnable code with exact file paths. The one deliberately temporary artifact — the deny-all `firestore.rules` in Task 3 Step 3 — is explicitly a TDD scaffold that Step 8 replaces with the real file in the same task, not a leftover placeholder.

**3. Type consistency.** Verified field-for-field: `functions/src/types.ts` (Task 1) → Dart mirrors (Task 2) → rules test payloads (Task 3) → `onUserCreate.ts` writes (Task 4) all use identical field names (`authId`, `partnerUserId`, `approvedCategories`, `senderId`, `messageText`, `enabledReminders`, `enabledHelpAreas`, `selectedTheme`, `inviteStatus`, `onlyApproveMode`, `primaryUserId`) and identical enum string values (`'cycle'|'conceive'|'pregnant'|'postpartum'|'menopause'`, `'her'|'partner'|'system'`, `'text'|'system'`, `'none'|'pending'|'accepted'|'declined'`). No renamed function/method appears across tasks — `fromMap`/`toMap` naming is consistent across all 8 Dart files, `onUserCreate` naming is consistent across `onUserCreate.ts`/`index.ts`/`onUserCreate.test.ts`.
