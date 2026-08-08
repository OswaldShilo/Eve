# EVE Mobile — Core Workflow Screen Graph Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build every screen in EVE's onboarding flow (20 screens: welcome → auth → profile → lifestage → branch → common → partner (conditional) → theme → completion) plus the structural shell of Home, Chat, and Log as real Flutter widgets, matching `UI/mobile/mockv4.html` copy and interaction logic exactly.

**Architecture:** Each onboarding screen is a `ConsumerWidget` reading/writing the shared `onboardingStateProvider` (owned by Plan 2, consumed here by assumed interface — see Global Constraints), wrapped in a shared `OnboardingScaffold` chrome widget (back button, progress bar, mini `EveMascot` + guidance line, primary CTA). Screens never navigate directly — they call `onContinue`/`onBack` callbacks supplied by the caller, so the actual `go_router` wiring (Plan 2) stays decoupled and each screen is independently widget-testable. Home/Chat/Log are built as pure presentation shells driven entirely by constructor params (placeholder data), with real data wiring deferred to Plan 4's build roadmap.

**Tech Stack:** Flutter (Dart), `flutter_riverpod` for state consumption, `flutter_test` for widget tests. No `go_router` dependency inside screen widgets themselves (see Architecture).

## Global Constraints

- Copy voice is formal and warm — no emojis anywhere in any widget, string, or test description (EVE2_PRD §6, design-spec §2).
- All on-screen copy (titles, subtitles, option labels, guidance lines, button labels) must be copied verbatim from `UI/mobile/mockv4.html` — never paraphrased or invented. Every string used below was extracted directly from that file.
- `EveEmotion` is a fixed 6-value enum: `neutral, caring, warm, hype, sassy, fertile` (design-spec §10). Never introduce additional emotion names. The mock's raw `hug`/`concerned` map to `caring`; the mock's raw `happy`/`positive` map to `warm`.
- Mascot peel growth thresholds (owned/implemented by Plan 6, but the percent value Plan 1 computes and passes through is fixed): `< 35%` flat crown/seed-row-1 only, `35–70%` crown scale 1.08 + rotate -4°/seed-row-2, `≥ 70%` crown scale 1.15 + rotate -8°/seed-row-3.
- Canonical folder structure (design-spec §9) is mandatory — every file path below matches it exactly.
- Firestore writes/repositories are **not** implemented in this plan — where a screen needs to persist data (only the Completion screen does), it calls an assumed repository method and nothing more.
- Diagnosis claims are never made in copy; not applicable to this plan's screens directly, but no screen may add clinical-sounding copy beyond what's specified.

### Assumed cross-plan interfaces (Plan 1 requires these; Plans 2/6 own the implementations)

These exact signatures are not fully fixed by design-spec §10 (which only fixes names/shape, not every method), so this plan states the concrete contract it needs. Flagged explicitly in the final report as an assumption Plan 2 must satisfy.

```dart
// package:eve_app/features/mascot/eve_emotion.dart  (Plan 6 owns)
enum EveEmotion { neutral, caring, warm, hype, sassy, fertile }

// package:eve_app/features/mascot/eve_mascot.dart  (Plan 6 owns)
class EveMascot extends StatelessWidget {
  const EveMascot({super.key, required this.emotion, this.peelPercent = 100, this.size = 120});
  final EveEmotion emotion;
  final double peelPercent;
  final double size;
}

// package:eve_app/features/onboarding/domain/onboarding_state.dart  (Plan 2 owns)
class OnboardingState {
  const OnboardingState({
    this.name = '', this.age = '', this.height = '', this.weight = '', this.country = '',
    this.lifeStage, // null | 'cycle' | 'conceive' | 'pregnant' | 'postpartum' | 'menopause'
    this.cycleLength = '', this.periodLength = '', this.flow = '',
    this.cycleSymptoms = const [], this.cycleGoals = const [], this.nutritionDiet = '',
    this.dueDate = '', this.dueMethod = '', this.highRisk = '', this.pregnancyType = '',
    this.medications = '', this.allergies = '', this.prenatalVitamins = '',
    this.pregnantSymptoms = const [], this.foodAllergies = '', this.cuisines = const [],
    this.workouts = const [], this.notifications = const [], this.aiScope = const [],
    this.partnerInvite = false, this.partnerRelation = '', this.partnerPermissions = const [],
    this.onlyApproveMaster = false, this.theme = '',
    this.simplifiedSymptoms = const [], this.simplifiedGoals = const [],
  });
  final String name, age, height, weight, country;
  final String? lifeStage;
  final String cycleLength, periodLength, flow;
  final List<String> cycleSymptoms, cycleGoals;
  final String nutritionDiet;
  final String dueDate, dueMethod, highRisk, pregnancyType, medications, allergies, prenatalVitamins;
  final List<String> pregnantSymptoms;
  final String foodAllergies;
  final List<String> cuisines, workouts, notifications, aiScope;
  final bool partnerInvite;
  final String partnerRelation;
  final List<String> partnerPermissions;
  final bool onlyApproveMaster;
  final String theme;
  final List<String> simplifiedSymptoms, simplifiedGoals;
}

// package:eve_app/features/onboarding/domain/onboarding_state.dart  (Plan 2 owns)
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());
  void setField(String field, Object? value);        // single-select / text-input write (mirrors mock's surveyState[key] = val)
  void toggleListField(String field, String value);   // multi-select toggle (mirrors mock's toggleMultiSelect)
}

final onboardingStateProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) => OnboardingNotifier());
```

Screens are written as `ConsumerWidget`s that call `ref.watch(onboardingStateProvider)` to read and `ref.read(onboardingStateProvider.notifier).setField(...)`/`.toggleListField(...)` to write. Package name is assumed to be `eve_app` (Plan 3 confirms/pins in `pubspec.yaml`); all imports below use `package:eve_app/...`.

---

## Screens at a glance

| # | Screen | File | Emotion | Guidance line |
|---|---|---|---|---|
| 2 | Welcome | `welcome_screen.dart` | neutral (inferred) | — (speech bubble, see task) |
| 3 | Auth | `auth_screen.dart` | neutral | Sign in to securely back up your health data, or continue as a guest. |
| 4 | Profile | `profile_screen.dart` | neutral | Enter your basic profile details so EVE can personalize your tracking. |
| 5 | Life-Stage | `lifestage_screen.dart` | neutral | Select your current stage to customize your tracking experience. |
| 6 | Cycle Info | `cycle_info_screen.dart` | neutral | Provide your typical cycle length and flow details. |
| 7 | Cycle Symptoms | `cycle_symptoms_screen.dart` | **caring** | Select any symptoms you regularly experience during your cycle. |
| 8 | Cycle Goals | `cycle_goals_screen.dart` | neutral | Select your primary goals for cycle tracking with EVE. |
| 9 | Pregnant Due | `pregnant_due_screen.dart` | neutral | Enter your timeline details to calculate key pregnancy milestones. |
| 10 | Pregnant Meds | `pregnant_meds_screen.dart` | **caring** | Record your current medications and care routines for personalized safety. |
| 11 | Pregnant Symptoms | `pregnant_symptoms_screen.dart` | **caring** | Select any pregnancy symptoms you are currently experiencing. |
| 12 | Simplified Branch | `simplified_branch_screen.dart` | **caring** | Select your primary symptoms and focus areas for this stage. |
| 13 | Food | `food_screen.dart` | neutral | Indicate your dietary preferences and any food allergies. |
| 14 | Workout | `workout_screen.dart` | neutral | Select the physical activities you prefer to keep energetic. |
| 15 | Notifications | `notifications_screen.dart` | neutral | Choose which reminders and updates you would like to receive. |
| 16 | AI Scope | `ai_scope_screen.dart` | neutral | Select the key areas where you would like assistance from EVE. |
| 17 | Partner Ask | `partner_ask_screen.dart` | neutral | Decide whether to invite a partner to share updates and schedule reminders. |
| 18 | Partner Relationship | `partner_rel_screen.dart` | neutral | Specify your partner's relationship for tailored communications. |
| 19 | Partner Permissions | `partner_perm_screen.dart` | **caring** | Select which health updates your partner is permitted to view. |
| 20 | Theme | `theme_screen.dart` | **warm** | Select your preferred color scheme for the application interface. |
| 21 | Completion | `completion_screen.dart` | **hype** (inferred) | — (speech bubble, see task) |
| 22 | Home | `home_screen.dart` | varies (chip-driven) | — |
| 23 | Chat | `chat_screen.dart` | neutral (system bubble) | — |
| 24 | Log | `log_screen.dart` | varies (per-day) | — |

Emotion source: `surveyMascotConfigs` in `mockv4.html` lines ~2147–2166. Welcome/Completion emotions are not in that map (see Task 2 and Task 21 for the reasoning).

---

## Task 1: Shared Onboarding Widgets (Scaffold, Option List, Sub-Chip Row)

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/widgets/onboarding_scaffold.dart`
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/widgets/option_list.dart`
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/widgets/sub_chip_row.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/widgets/onboarding_scaffold_test.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/widgets/option_list_test.dart`

**Interfaces:**
- Consumes: `EveMascot`, `EveEmotion` from `package:eve_app/features/mascot/eve_mascot.dart` and `.../eve_emotion.dart` (assumed, Plan 6).
- Produces: `OnboardingScaffold` (used by every screen task 3–20; welcome/completion in tasks 2 and 21 use their own bookend layout, not this scaffold), `OptionList` + `OptionListItem` + `OptionSelectionMode`, `SubChipRow` — used by tasks 5–20.

- [ ] **Step 1: Write the failing scaffold test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/widgets/onboarding_scaffold_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';

void main() {
  testWidgets('OnboardingScaffold renders title, subtitle, guidance text and forwards taps', (tester) async {
    var continuePressed = false;
    var backPressed = false;

    await tester.pumpWidget(MaterialApp(
      home: OnboardingScaffold(
        progressPercent: 42,
        emotion: EveEmotion.caring,
        guidanceText: 'Test guidance line.',
        title: 'Test Title',
        subtitle: 'Test subtitle.',
        primaryLabel: 'Next',
        onPrimaryPressed: () => continuePressed = true,
        onBack: () => backPressed = true,
        child: const Text('Screen body content'),
      ),
    ));

    expect(find.text('Test Title'), findsOneWidget);
    expect(find.text('Test subtitle.'), findsOneWidget);
    expect(find.text('Test guidance line.'), findsOneWidget);
    expect(find.text('Screen body content'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    await tester.tap(find.byKey(const Key('onboarding-back-button')));
    expect(continuePressed, isTrue);
    expect(backPressed, isTrue);
  });

  testWidgets('OnboardingScaffold disables primary button when primaryEnabled is false', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScaffold(
        progressPercent: 10,
        emotion: EveEmotion.neutral,
        guidanceText: 'g',
        title: 't',
        primaryLabel: 'Next',
        primaryEnabled: false,
        onPrimaryPressed: () {},
        onBack: () {},
        child: const SizedBox(),
      ),
    ));

    final button = tester.widget<ElevatedButton>(find.byKey(const Key('onboarding-primary-button')));
    expect(button.onPressed, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/widgets/onboarding_scaffold_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart'`

- [ ] **Step 3: Implement OnboardingScaffold**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/widgets/onboarding_scaffold.dart
import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.progressPercent,
    required this.emotion,
    required this.guidanceText,
    required this.title,
    required this.child,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    required this.onBack,
    this.subtitle,
    this.primaryEnabled = true,
  });

  /// 0-100. Drives both the visual progress bar fill and EveMascot.peelPercent unchanged (see Task 26).
  final double progressPercent;
  final EveEmotion emotion;
  final String guidanceText;
  final String title;
  final String? subtitle;
  final Widget child;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onBack;
  final bool primaryEnabled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('onboarding-back-button'),
                  icon: const Text('‹', style: TextStyle(fontSize: 28)),
                  onPressed: onBack,
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      key: const Key('onboarding-progress-bar'),
                      value: progressPercent / 100,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  EveMascot(emotion: emotion, peelPercent: progressPercent, size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(guidanceText, key: const Key('onboarding-guidance-text')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      key: const Key('onboarding-title'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, key: const Key('onboarding-subtitle')),
                    ],
                    const SizedBox(height: 16),
                    child,
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('onboarding-primary-button'),
                  onPressed: primaryEnabled ? onPrimaryPressed : null,
                  child: Text(primaryLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/widgets/onboarding_scaffold_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Write the failing OptionList test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/widgets/option_list_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

void main() {
  testWidgets('OptionList renders all item labels and reports taps', (tester) async {
    String? toggled;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OptionList(
          items: const [
            OptionListItem('Cramps', 'Cramps'),
            OptionListItem('Acne', 'Acne'),
          ],
          mode: OptionSelectionMode.multi,
          selectedValues: const {'Cramps'},
          onToggle: (v) => toggled = v,
        ),
      ),
    ));

    expect(find.text('Cramps'), findsOneWidget);
    expect(find.text('Acne'), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);

    await tester.tap(find.byKey(const Key('option-Acne')));
    expect(toggled, 'Acne');
  });

  testWidgets('OptionList in single mode renders radio icons', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OptionList(
          items: const [OptionListItem('Light', 'Light')],
          mode: OptionSelectionMode.single,
          selectedValues: const {'Light'},
          onToggle: (_) {},
        ),
      ),
    ));

    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/widgets/option_list_test.dart`
Expected: FAIL — `option_list.dart` doesn't exist

- [ ] **Step 7: Implement OptionList and SubChipRow**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/widgets/option_list.dart
import 'package:flutter/material.dart';

enum OptionSelectionMode { single, multi }

class OptionListItem {
  const OptionListItem(this.label, this.value);
  final String label;
  final String value;
}

class OptionList extends StatelessWidget {
  const OptionList({
    super.key,
    required this.items,
    required this.mode,
    required this.selectedValues,
    required this.onToggle,
  });

  final List<OptionListItem> items;
  final OptionSelectionMode mode;
  final Set<String> selectedValues;
  final void Function(String value) onToggle;

  static const _ruby = Color(0xFFFF2A6D);
  static const _rubySoft = Color(0xFFFFF0F4);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        final selected = selectedValues.contains(item.value);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            key: Key('option-${item.value}'),
            onTap: () => onToggle(item.value),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: selected ? _ruby : const Color(0xFFE5E5E5)),
                borderRadius: BorderRadius.circular(12),
                color: selected ? _rubySoft : Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.label),
                  Icon(
                    mode == OptionSelectionMode.single
                        ? (selected ? Icons.radio_button_checked : Icons.radio_button_unchecked)
                        : (selected ? Icons.check_box : Icons.check_box_outline_blank),
                    color: selected ? _ruby : const Color(0xFF999999),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
```

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/widgets/sub_chip_row.dart
import 'package:flutter/material.dart';

class SubChipRow extends StatelessWidget {
  const SubChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<String> options;
  final String selected;
  final void Function(String value) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return ChoiceChip(
          key: Key('chip-$opt'),
          label: Text(opt),
          selected: isSelected,
          onSelected: (_) => onSelect(opt),
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/features/onboarding/presentation/widgets/`
Expected: PASS (4 tests total)

- [ ] **Step 9: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/widgets/ EVE_MOBILE/app/test/features/onboarding/presentation/widgets/
git commit -m "feat(onboarding): add shared scaffold, option list, and sub-chip row widgets"
```

---

## Task 2: Welcome Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/welcome_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/welcome_screen_test.dart`

**Interfaces:**
- Consumes: `EveMascot`, `EveEmotion` (assumed, Plan 6).
- Produces: `WelcomeScreen` — the app's entry screen, mounted at `/onboarding/welcome` by Plan 2's router.

This is a bookend screen (mock `screen-welcome`), not wrapped in `OnboardingScaffold` — it has no back button, no progress bar, and its own layout (speech bubble, large mascot stage, brand footer, single CTA). It has no `mascot-guidance-card`/mascot-guidance-text entry in `surveyMascotConfigs`, and the mock never calls `setMascotEmotion` for the `welcome` mascot instance before first paint, which leaves it on `setMascotEmotion`'s hardcoded default path values — visually identical to the `neutral` state. `EveEmotion.neutral` is therefore used here (inferred, not from an explicit mock config entry — flagged in the final report).

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/welcome_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/welcome_screen.dart';

void main() {
  testWidgets('WelcomeScreen renders brand copy and invokes onContinue on Begin Setup tap', (tester) async {
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      home: WelcomeScreen(onContinue: () => pressed = true),
    ));

    expect(find.text('Welcome to EVE. Let us personalize your health and cycle tracking experience.'), findsOneWidget);
    expect(find.text('EVE'), findsOneWidget);
    expect(find.text('Cycle & Wellness Companion'), findsOneWidget);
    expect(find.text('Begin Setup'), findsOneWidget);

    await tester.tap(find.byKey(const Key('welcome-begin-setup-button')));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/welcome_screen_test.dart`
Expected: FAIL — `welcome_screen.dart` doesn't exist

- [ ] **Step 3: Implement WelcomeScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Welcome to EVE. Let us personalize your health and cycle tracking experience.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const EveMascot(emotion: EveEmotion.neutral, size: 180),
              Column(
                children: const [
                  Text('EVE', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  Text('Cycle & Wellness Companion', style: TextStyle(color: Color(0xFF666666))),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('welcome-begin-setup-button'),
                  onPressed: onContinue,
                  child: const Text('Begin Setup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/welcome_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/welcome_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/welcome_screen_test.dart
git commit -m "feat(onboarding): add welcome screen"
```

---

## Task 3: Auth Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/auth_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/auth_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold` (Task 1).
- Produces: `AuthScreen`, mounted at `/onboarding/auth`.

Mock `screen-auth` has two forward actions: "Sign in with Google" (calls `handleGoogleAuth()`, which in the mock just calls `nextOnboardingStep()` — real Google Sign-In wiring is out of this plan's scope, owned by Plan 2/3's auth service) and "Continue as Guest" (the `btn-primary`, also calls `nextOnboardingStep()`). Both are exposed as the same `onContinue` callback here since this plan only owns navigation callback wiring, not the auth SDK call itself.

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/auth_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/auth_screen.dart';

void main() {
  testWidgets('AuthScreen renders copy and both auth actions invoke onContinue', (tester) async {
    var continueCount = 0;
    var backPressed = false;
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(
        onContinue: () => continueCount++,
        onBack: () => backPressed = true,
      ),
    ));

    expect(find.text('Welcome to EVE'), findsOneWidget);
    expect(find.text('Sign in to back up your health insights securely.'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
    expect(find.text('Sign in to securely back up your health data, or continue as a guest.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth-google-button')));
    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(continueCount, 2);

    await tester.tap(find.byKey(const Key('onboarding-back-button')));
    expect(backPressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/auth_screen_test.dart`
Expected: FAIL — `auth_screen.dart` doesn't exist

- [ ] **Step 3: Implement AuthScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 10,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Sign in to securely back up your health data, or continue as a guest.',
      title: 'Welcome to EVE',
      subtitle: 'Sign in to back up your health insights securely.',
      primaryLabel: 'Continue as Guest',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Center(
        child: OutlinedButton.icon(
          key: const Key('auth-google-button'),
          onPressed: onContinue,
          icon: const Icon(Icons.g_mobiledata),
          label: const Text('Sign in with Google'),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/auth_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/auth_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/auth_screen_test.dart
git commit -m "feat(onboarding): add auth screen"
```

---

## Task 4: Profile Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/profile_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/profile_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold` (Task 1); `onboardingStateProvider`, `OnboardingState`, `OnboardingNotifier.setField` (assumed, Plan 2).
- Produces: `ProfileScreen`, mounted at `/onboarding/profile`.

Fields (mock `screen-profile`, form-group order): Name (text, pre-filled from auth in the real product — left blank by default here since no auth wiring exists in this plan), Age (number), Height in cm (number), Weight in kg (number), Country (select: India, United States, United Kingdom, Canada, Australia).

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/profile_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/profile_screen.dart';

void main() {
  testWidgets('ProfileScreen renders all five fields and Next Step invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: ProfileScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('About You'), findsOneWidget);
    expect(find.text('Enter your basic profile details so EVE can personalize your tracking.'), findsOneWidget);
    expect(find.byKey(const Key('profile-name-field')), findsOneWidget);
    expect(find.byKey(const Key('profile-age-field')), findsOneWidget);
    expect(find.byKey(const Key('profile-height-field')), findsOneWidget);
    expect(find.byKey(const Key('profile-weight-field')), findsOneWidget);
    expect(find.byKey(const Key('profile-country-field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/profile_screen_test.dart`
Expected: FAIL — `profile_screen.dart` doesn't exist

- [ ] **Step 3: Implement ProfileScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 23,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _countries = ['India', 'United States', 'United Kingdom', 'Canada', 'Australia'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Enter your basic profile details so EVE can personalize your tracking.',
      title: 'About You',
      subtitle: 'Providing basic details helps EVE tailor your health predictions.',
      primaryLabel: 'Next Step',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        children: [
          TextFormField(
            key: const Key('profile-name-field'),
            decoration: const InputDecoration(labelText: 'Name'),
            initialValue: state.name,
            onChanged: (v) => notifier.setField('name', v),
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('profile-age-field'),
                  decoration: const InputDecoration(labelText: 'Age'),
                  keyboardType: TextInputType.number,
                  initialValue: state.age,
                  onChanged: (v) => notifier.setField('age', v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const Key('profile-height-field'),
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                  keyboardType: TextInputType.number,
                  initialValue: state.height,
                  onChanged: (v) => notifier.setField('height', v),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('profile-weight-field'),
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  keyboardType: TextInputType.number,
                  initialValue: state.weight,
                  onChanged: (v) => notifier.setField('weight', v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const Key('profile-country-field'),
                  decoration: const InputDecoration(labelText: 'Country'),
                  initialValue: state.country.isEmpty ? null : state.country,
                  items: _countries
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) notifier.setField('country', v);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/profile_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/profile_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/profile_screen_test.dart
git commit -m "feat(onboarding): add profile screen"
```

---

## Task 5: Life-Stage Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/lifestage_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/lifestage_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold`, `OptionList`, `OptionListItem`, `OptionSelectionMode` (Task 1); `onboardingStateProvider`, `OnboardingNotifier.setField` (assumed).
- Produces: `LifeStageScreen`, mounted at `/onboarding/lifestage`. This is the core branch point Task 25 reads `state.lifeStage` from.

Options (mock `screen-lifestage`, single-select via `selectLifeStage`), values map directly to `OnboardingState.lifeStage`: "Tracking my cycle" → `cycle`, "Trying to conceive" → `conceive`, "Currently pregnant" → `pregnant`, "Postpartum" → `postpartum`, "Perimenopause / Menopause" → `menopause`.

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/lifestage_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/lifestage_screen.dart';

void main() {
  testWidgets('LifeStageScreen renders all five options and Continue invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: LifeStageScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Which describes your current stage best?'), findsOneWidget);
    expect(find.text('Tracking my cycle'), findsOneWidget);
    expect(find.text('Trying to conceive'), findsOneWidget);
    expect(find.text('Currently pregnant'), findsOneWidget);
    expect(find.text('Postpartum'), findsOneWidget);
    expect(find.text('Perimenopause / Menopause'), findsOneWidget);

    await tester.tap(find.byKey(const Key('option-pregnant')));
    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/lifestage_screen_test.dart`
Expected: FAIL — `lifestage_screen.dart` doesn't exist

- [ ] **Step 3: Implement LifeStageScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/lifestage_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class LifeStageScreen extends ConsumerWidget {
  const LifeStageScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 30,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('Tracking my cycle', 'cycle'),
    OptionListItem('Trying to conceive', 'conceive'),
    OptionListItem('Currently pregnant', 'pregnant'),
    OptionListItem('Postpartum', 'postpartum'),
    OptionListItem('Perimenopause / Menopause', 'menopause'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Select your current stage to customize your tracking experience.',
      title: 'Which describes your current stage best?',
      subtitle: 'Select your primary stage to customize your experience.',
      primaryLabel: 'Continue',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.single,
        selectedValues: state.lifeStage == null ? const {} : {state.lifeStage!},
        onToggle: (v) => notifier.setField('lifeStage', v),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/lifestage_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/lifestage_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/lifestage_screen_test.dart
git commit -m "feat(onboarding): add life-stage branch selector screen"
```

---

## Task 6: Cycle Info Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/cycle_info_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/cycle_info_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold`, `OptionList`, `SubChipRow` (Task 1); `onboardingStateProvider` (assumed).
- Produces: `CycleInfoScreen`, mounted at `/onboarding/cycle-info` (only reachable when `lifeStage == 'cycle'`, per Task 25).

Fields (mock `screen-cycle-info`): Average cycle length — single-select option cards: "25–28 days" (value `25–28`), "21–24 days" (`21–24`), "29–35 days" (`29–35`), "Irregular", "Unsure". Average period length — dropdown: 3 days, 4 days, 5 days, 6 days, 7+ days, Not sure. Flow intensity — sub-chip row: Light, Moderate, Heavy.

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/cycle_info_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/cycle_info_screen.dart';

void main() {
  testWidgets('CycleInfoScreen renders cycle length, period length, flow fields and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: CycleInfoScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Cycle Details'), findsOneWidget);
    expect(find.text('25–28 days'), findsOneWidget);
    expect(find.text('Irregular'), findsOneWidget);
    expect(find.text('Unsure'), findsOneWidget);
    expect(find.byKey(const Key('cycle-info-period-length-field')), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Moderate'), findsOneWidget);
    expect(find.text('Heavy'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/cycle_info_screen_test.dart`
Expected: FAIL — `cycle_info_screen.dart` doesn't exist

- [ ] **Step 3: Implement CycleInfoScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/cycle_info_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/sub_chip_row.dart';

class CycleInfoScreen extends ConsumerWidget {
  const CycleInfoScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 38,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _cycleLengthItems = [
    OptionListItem('25–28 days', '25–28'),
    OptionListItem('21–24 days', '21–24'),
    OptionListItem('29–35 days', '29–35'),
    OptionListItem('Irregular', 'Irregular'),
    OptionListItem('Unsure', 'Unsure'),
  ];

  static const _periodLengths = ['3', '4', '5', '6', '7+', 'Not sure'];
  static const _periodLengthLabels = {
    '3': '3 days', '4': '4 days', '5': '5 days', '6': '6 days',
    '7+': '7+ days', 'Not sure': 'Not sure',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Provide your typical cycle length and flow details.',
      title: 'Cycle Details',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Average cycle length'),
          OptionList(
            items: _cycleLengthItems,
            mode: OptionSelectionMode.single,
            selectedValues: state.cycleLength.isEmpty ? const {} : {state.cycleLength},
            onToggle: (v) => notifier.setField('cycleLength', v),
          ),
          const SizedBox(height: 10),
          const Text('Average period length'),
          DropdownButtonFormField<String>(
            key: const Key('cycle-info-period-length-field'),
            initialValue: state.periodLength.isEmpty ? null : state.periodLength,
            items: _periodLengths
                .map((p) => DropdownMenuItem(value: p, child: Text(_periodLengthLabels[p]!)))
                .toList(),
            onChanged: (v) {
              if (v != null) notifier.setField('periodLength', v);
            },
          ),
          const SizedBox(height: 10),
          const Text('Flow intensity'),
          SubChipRow(
            options: const ['Light', 'Moderate', 'Heavy'],
            selected: state.flow,
            onSelect: (v) => notifier.setField('flow', v),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/cycle_info_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/cycle_info_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/cycle_info_screen_test.dart
git commit -m "feat(onboarding): add cycle info screen"
```

---

## Task 7: Cycle Symptoms Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/cycle_symptoms_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/cycle_symptoms_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold`, `OptionList` (Task 1); `onboardingStateProvider`, `OnboardingNotifier.toggleListField` (assumed).
- Produces: `CycleSymptomsScreen`, mounted at `/onboarding/cycle-symptoms`.

Emotion is **`EveEmotion.caring`** per `surveyMascotConfigs['screen-cycle-symptoms']`. Options (mock `screen-cycle-symptoms`, multi-select, 11 options): Cramps, Acne, Headache, Breast tenderness, Bloating, Mood swings, Back pain, Fatigue, Food cravings, Nausea, None.

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/cycle_symptoms_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/cycle_symptoms_screen.dart';

void main() {
  testWidgets('CycleSymptomsScreen renders all 11 symptom options and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: CycleSymptomsScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Frequent Symptoms'), findsOneWidget);
    for (final label in const [
      'Cramps', 'Acne', 'Headache', 'Breast tenderness', 'Bloating', 'Mood swings',
      'Back pain', 'Fatigue', 'Food cravings', 'Nausea', 'None',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/cycle_symptoms_screen_test.dart`
Expected: FAIL — `cycle_symptoms_screen.dart` doesn't exist

- [ ] **Step 3: Implement CycleSymptomsScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/cycle_symptoms_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class CycleSymptomsScreen extends ConsumerWidget {
  const CycleSymptomsScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 46,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('Cramps', 'Cramps'),
    OptionListItem('Acne', 'Acne'),
    OptionListItem('Headache', 'Headache'),
    OptionListItem('Breast tenderness', 'Breast tenderness'),
    OptionListItem('Bloating', 'Bloating'),
    OptionListItem('Mood swings', 'Mood swings'),
    OptionListItem('Back pain', 'Back pain'),
    OptionListItem('Fatigue', 'Fatigue'),
    OptionListItem('Food cravings', 'Food cravings'),
    OptionListItem('Nausea', 'Nausea'),
    OptionListItem('None', 'None'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.caring,
      guidanceText: 'Select any symptoms you regularly experience during your cycle.',
      title: 'Frequent Symptoms',
      subtitle: 'Select any symptoms you usually experience.',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.multi,
        selectedValues: state.cycleSymptoms.toSet(),
        onToggle: (v) => notifier.toggleListField('cycleSymptoms', v),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/cycle_symptoms_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/cycle_symptoms_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/cycle_symptoms_screen_test.dart
git commit -m "feat(onboarding): add cycle symptoms screen"
```

---

## Task 8: Cycle Goals Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/cycle_goals_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/cycle_goals_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold`, `SubChipRow` (Task 1); `onboardingStateProvider` (assumed).
- Produces: `CycleGoalsScreen`, mounted at `/onboarding/cycle-goals`.

Options (mock `screen-cycle-goals`, multi-select into `cycleGoals`): "Predict my next period", "Understand body trends", "Improve fitness", "Improve nutrition" (reveals a diet sub-choice: Vegetarian/Non-vegetarian/Vegan, written to `nutritionDiet`), "Improve mental wellbeing". **Deviation from the mock's literal JS, noted in the final report:** the mock's `toggleNutritionGoal()` toggles the card's visual `selected` state and reveals the sub-choice row, but never actually pushes `'Improve nutrition'` into `surveyState.cycleGoals` — an apparent oversight, since every other goal option does get recorded. This plan does record it, so the Firestore-facing `cycleGoals` list is complete.

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/cycle_goals_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/cycle_goals_screen.dart';

void main() {
  testWidgets('CycleGoalsScreen renders goals and reveals diet sub-choice on nutrition tap', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: CycleGoalsScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Your Primary Goals'), findsOneWidget);
    expect(find.text('Predict my next period'), findsOneWidget);
    expect(find.text('Understand body trends'), findsOneWidget);
    expect(find.text('Improve fitness'), findsOneWidget);
    expect(find.text('Improve nutrition'), findsOneWidget);
    expect(find.text('Improve mental wellbeing'), findsOneWidget);
    expect(find.text('Vegetarian'), findsNothing);

    await tester.tap(find.byKey(const Key('option-Improve nutrition')));
    await tester.pump();
    expect(find.text('Vegetarian'), findsOneWidget);
    expect(find.text('Non-vegetarian'), findsOneWidget);
    expect(find.text('Vegan'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/cycle_goals_screen_test.dart`
Expected: FAIL — `cycle_goals_screen.dart` doesn't exist

- [ ] **Step 3: Implement CycleGoalsScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/cycle_goals_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/sub_chip_row.dart';

class CycleGoalsScreen extends ConsumerWidget {
  const CycleGoalsScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 54,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _fixedItems = [
    OptionListItem('Predict my next period', 'Predict my next period'),
    OptionListItem('Understand body trends', 'Understand body trends'),
    OptionListItem('Improve fitness', 'Improve fitness'),
  ];
  static const _wellbeingItem =
      OptionListItem('Improve mental wellbeing', 'Improve mental wellbeing');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);
    final nutritionSelected = state.cycleGoals.contains('Improve nutrition');

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Select your primary goals for cycle tracking with EVE.',
      title: 'Your Primary Goals',
      subtitle: 'Select how EVE can assist with your cycle health.',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OptionList(
            items: _fixedItems,
            mode: OptionSelectionMode.multi,
            selectedValues: state.cycleGoals.toSet(),
            onToggle: (v) => notifier.toggleListField('cycleGoals', v),
          ),
          OptionList(
            items: const [OptionListItem('Improve nutrition', 'Improve nutrition')],
            mode: OptionSelectionMode.multi,
            selectedValues: state.cycleGoals.toSet(),
            onToggle: (v) => notifier.toggleListField('cycleGoals', v),
          ),
          if (nutritionSelected) ...[
            const SizedBox(height: 8),
            SubChipRow(
              options: const ['Vegetarian', 'Non-vegetarian', 'Vegan'],
              selected: state.nutritionDiet,
              onSelect: (v) => notifier.setField('nutritionDiet', v),
            ),
            const SizedBox(height: 8),
          ],
          OptionList(
            items: [_wellbeingItem],
            mode: OptionSelectionMode.multi,
            selectedValues: state.cycleGoals.toSet(),
            onToggle: (v) => notifier.toggleListField('cycleGoals', v),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/cycle_goals_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/cycle_goals_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/cycle_goals_screen_test.dart
git commit -m "feat(onboarding): add cycle goals screen"
```

---

## Task 9: Pregnant Due-Date Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/pregnant_due_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/pregnant_due_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold`, `OptionList`, `SubChipRow` (Task 1); `onboardingStateProvider` (assumed).
- Produces: `PregnantDueScreen`, mounted at `/onboarding/pregnant-due` (only reachable when `lifeStage == 'pregnant'`).

Fields (mock `screen-pregnant-due`): Calculation method — single-select: "Expected due date", "First day of last period", "Doctor's estimated week" (writes `dueMethod`). Target Date — date input (writes `dueDate`, ISO `yyyy-MM-dd`). High-risk pregnancy? — sub-chip row: No/Yes (writes `highRisk`). Pregnancy Type — sub-chip row: Single/Twins (writes `pregnancyType`).

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/pregnant_due_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/pregnant_due_screen.dart';

void main() {
  testWidgets('PregnantDueScreen renders timeline fields and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: PregnantDueScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Pregnancy Timeline'), findsOneWidget);
    expect(find.text('Expected due date'), findsOneWidget);
    expect(find.text('First day of last period'), findsOneWidget);
    expect(find.text("Doctor's estimated week"), findsOneWidget);
    expect(find.byKey(const Key('pregnant-due-date-field')), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('Single'), findsOneWidget);
    expect(find.text('Twins'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/pregnant_due_screen_test.dart`
Expected: FAIL — `pregnant_due_screen.dart` doesn't exist

- [ ] **Step 3: Implement PregnantDueScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/pregnant_due_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/sub_chip_row.dart';

class PregnantDueScreen extends ConsumerWidget {
  const PregnantDueScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 38,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _methodItems = [
    OptionListItem('Expected due date', 'Expected due date'),
    OptionListItem('First day of last period', 'First day of last period'),
    OptionListItem("Doctor's estimated week", "Doctor's estimated week"),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Enter your timeline details to calculate key pregnancy milestones.',
      title: 'Pregnancy Timeline',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Calculation method'),
          OptionList(
            items: _methodItems,
            mode: OptionSelectionMode.single,
            selectedValues: state.dueMethod.isEmpty ? const {} : {state.dueMethod},
            onToggle: (v) => notifier.setField('dueMethod', v),
          ),
          const SizedBox(height: 8),
          const Text('Target Date'),
          TextFormField(
            key: const Key('pregnant-due-date-field'),
            decoration: const InputDecoration(hintText: 'YYYY-MM-DD'),
            initialValue: state.dueDate,
            onChanged: (v) => notifier.setField('dueDate', v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('High-risk pregnancy?'),
                    SubChipRow(
                      options: const ['No', 'Yes'],
                      selected: state.highRisk,
                      onSelect: (v) => notifier.setField('highRisk', v),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pregnancy Type'),
                    SubChipRow(
                      options: const ['Single', 'Twins'],
                      selected: state.pregnancyType,
                      onSelect: (v) => notifier.setField('pregnancyType', v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/pregnant_due_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/pregnant_due_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/pregnant_due_screen_test.dart
git commit -m "feat(onboarding): add pregnancy due-date screen"
```

---

## Task 10: Pregnant Medication & Care Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/pregnant_meds_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/pregnant_meds_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold`, `SubChipRow` (Task 1); `onboardingStateProvider` (assumed).
- Produces: `PregnantMedsScreen`, mounted at `/onboarding/pregnant-meds`.

Emotion is **`EveEmotion.caring`** per `surveyMascotConfigs['screen-pregnant-meds']` (medical/clinical screen — never celebratory per EVE2_PRD §6). Fields (mock `screen-pregnant-meds`): Current Medications (text, placeholder "e.g. Levothyroxine", writes `medications`). Allergies (text, placeholder "e.g. Penicillin, Latex", writes `allergies`). Taking Prenatal Vitamins? — sub-chip row: Yes/No (writes `prenatalVitamins`).

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/pregnant_meds_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/pregnant_meds_screen.dart';

void main() {
  testWidgets('PregnantMedsScreen renders medication/allergy fields and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: PregnantMedsScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Medication & Care'), findsOneWidget);
    expect(find.byKey(const Key('pregnant-meds-medications-field')), findsOneWidget);
    expect(find.byKey(const Key('pregnant-meds-allergies-field')), findsOneWidget);
    expect(find.text('Taking Prenatal Vitamins?'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/pregnant_meds_screen_test.dart`
Expected: FAIL — `pregnant_meds_screen.dart` doesn't exist

- [ ] **Step 3: Implement PregnantMedsScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/pregnant_meds_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/sub_chip_row.dart';

class PregnantMedsScreen extends ConsumerWidget {
  const PregnantMedsScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 46,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.caring,
      guidanceText: 'Record your current medications and care routines for personalized safety.',
      title: 'Medication & Care',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Current Medications'),
          TextFormField(
            key: const Key('pregnant-meds-medications-field'),
            decoration: const InputDecoration(hintText: 'e.g. Levothyroxine'),
            initialValue: state.medications,
            onChanged: (v) => notifier.setField('medications', v),
          ),
          const SizedBox(height: 10),
          const Text('Allergies'),
          TextFormField(
            key: const Key('pregnant-meds-allergies-field'),
            decoration: const InputDecoration(hintText: 'e.g. Penicillin, Latex'),
            initialValue: state.allergies,
            onChanged: (v) => notifier.setField('allergies', v),
          ),
          const SizedBox(height: 10),
          const Text('Taking Prenatal Vitamins?'),
          SubChipRow(
            options: const ['Yes', 'No'],
            selected: state.prenatalVitamins,
            onSelect: (v) => notifier.setField('prenatalVitamins', v),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/pregnant_meds_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/pregnant_meds_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/pregnant_meds_screen_test.dart
git commit -m "feat(onboarding): add pregnancy medication and care screen"
```

---

## Task 11: Pregnant Symptoms Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/pregnant_symptoms_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/pregnant_symptoms_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold`, `OptionList` (Task 1); `onboardingStateProvider` (assumed).
- Produces: `PregnantSymptomsScreen`, mounted at `/onboarding/pregnant-symptoms`.

Emotion is **`EveEmotion.caring`**. Options (mock `screen-pregnant-symptoms`, multi-select into `pregnantSymptoms`): Morning sickness, Swelling, Back pain, Heartburn, Headache, None.

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/pregnant_symptoms_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/pregnant_symptoms_screen.dart';

void main() {
  testWidgets('PregnantSymptomsScreen renders all six symptom options and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: PregnantSymptomsScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Pregnancy Symptoms'), findsOneWidget);
    for (final label in const [
      'Morning sickness', 'Swelling', 'Back pain', 'Heartburn', 'Headache', 'None',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/pregnant_symptoms_screen_test.dart`
Expected: FAIL — `pregnant_symptoms_screen.dart` doesn't exist

- [ ] **Step 3: Implement PregnantSymptomsScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/pregnant_symptoms_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class PregnantSymptomsScreen extends ConsumerWidget {
  const PregnantSymptomsScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 54,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('Morning sickness', 'Morning sickness'),
    OptionListItem('Swelling', 'Swelling'),
    OptionListItem('Back pain', 'Back pain'),
    OptionListItem('Heartburn', 'Heartburn'),
    OptionListItem('Headache', 'Headache'),
    OptionListItem('None', 'None'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.caring,
      guidanceText: 'Select any pregnancy symptoms you are currently experiencing.',
      title: 'Pregnancy Symptoms',
      subtitle: 'Select symptoms you are currently experiencing.',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.multi,
        selectedValues: state.pregnantSymptoms.toSet(),
        onToggle: (v) => notifier.toggleListField('pregnantSymptoms', v),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/pregnant_symptoms_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/pregnant_symptoms_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/pregnant_symptoms_screen_test.dart
git commit -m "feat(onboarding): add pregnancy symptoms screen"
```

---

## Task 12: Simplified Branch Screen (Conceive / Postpartum / Menopause)

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/simplified_branch_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/simplified_branch_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold`, `OptionList` (Task 1); `onboardingStateProvider` (assumed).
- Produces: `SimplifiedBranchScreen`, mounted at `/onboarding/simplified-branch` (reachable when `lifeStage` is `conceive`, `postpartum`, or `menopause` — per design-spec §2's locked "2 full + 3 collapsed" branch-depth decision, this single screen is genuinely reused for all three, driven purely by `state.lifeStage`, not three near-duplicate screens).

This screen reproduces the mock's `renderSimplifiedBranch()` (lines ~2504–2547 of `mockv4.html`), which swaps title/options based on `surveyState.lifeStage`. Title and option sets, copied verbatim:

- `conceive` → title "Trying to Conceive Details"; symptoms: Ovulation tracking, Basal body temperature, Cervical mucus tracking, Light spotting; goals: Identify fertile window, Cycle regularity insights, Preconception health.
- `postpartum` → title "Postpartum Care Details"; symptoms: Postpartum fatigue, Mood changes, Night sweats, Hormonal hair changes; goals: Recovery tracking, Nursing & rest logging, Mental wellness support.
- `menopause` → title "Menopause & Perimenopause Details"; symptoms: Hot flashes, Night sweats, Sleep disruption, Mood fluctuations, Brain fog; goals: Symptom intensity logging, Bone & cardiovascular health, Sleep quality management.

Symptoms write to `simplifiedSymptoms[]`, goals write to `simplifiedGoals[]` (both multi-select). Emotion is **`EveEmotion.caring`** per `surveyMascotConfigs['screen-simplified-branch']`.

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/simplified_branch_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/screens/simplified_branch_screen.dart';

void main() {
  testWidgets('SimplifiedBranchScreen renders conceive title/options and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        onboardingStateProvider.overrideWith((ref) => OnboardingNotifier()..setField('lifeStage', 'conceive')),
      ],
      child: MaterialApp(
        home: SimplifiedBranchScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Trying to Conceive Details'), findsOneWidget);
    expect(find.text('Ovulation tracking'), findsOneWidget);
    expect(find.text('Basal body temperature'), findsOneWidget);
    expect(find.text('Cervical mucus tracking'), findsOneWidget);
    expect(find.text('Light spotting'), findsOneWidget);
    expect(find.text('Identify fertile window'), findsOneWidget);
    expect(find.text('Cycle regularity insights'), findsOneWidget);
    expect(find.text('Preconception health'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });

  testWidgets('SimplifiedBranchScreen renders menopause title/options when lifeStage is menopause', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        onboardingStateProvider.overrideWith((ref) => OnboardingNotifier()..setField('lifeStage', 'menopause')),
      ],
      child: MaterialApp(
        home: SimplifiedBranchScreen(onContinue: () {}, onBack: () {}),
      ),
    ));

    expect(find.text('Menopause & Perimenopause Details'), findsOneWidget);
    expect(find.text('Hot flashes'), findsOneWidget);
    expect(find.text('Brain fog'), findsOneWidget);
    expect(find.text('Bone & cardiovascular health'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/simplified_branch_screen_test.dart`
Expected: FAIL — `simplified_branch_screen.dart` doesn't exist

- [ ] **Step 3: Implement SimplifiedBranchScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/simplified_branch_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class _StageContent {
  const _StageContent(this.title, this.symptoms, this.goals);
  final String title;
  final List<String> symptoms;
  final List<String> goals;
}

const _stageContentByLifeStage = {
  'conceive': _StageContent(
    'Trying to Conceive Details',
    ['Ovulation tracking', 'Basal body temperature', 'Cervical mucus tracking', 'Light spotting'],
    ['Identify fertile window', 'Cycle regularity insights', 'Preconception health'],
  ),
  'postpartum': _StageContent(
    'Postpartum Care Details',
    ['Postpartum fatigue', 'Mood changes', 'Night sweats', 'Hormonal hair changes'],
    ['Recovery tracking', 'Nursing & rest logging', 'Mental wellness support'],
  ),
  'menopause': _StageContent(
    'Menopause & Perimenopause Details',
    ['Hot flashes', 'Night sweats', 'Sleep disruption', 'Mood fluctuations', 'Brain fog'],
    ['Symptom intensity logging', 'Bone & cardiovascular health', 'Sleep quality management'],
  ),
};

class SimplifiedBranchScreen extends ConsumerWidget {
  const SimplifiedBranchScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 46,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);
    final content = _stageContentByLifeStage[state.lifeStage] ??
        const _StageContent('Stage Details', [], []);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.caring,
      guidanceText: 'Select your primary symptoms and focus areas for this stage.',
      title: content.title,
      subtitle: 'Select your symptoms and goals for this stage.',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Symptoms & Focus'),
          OptionList(
            items: content.symptoms.map((s) => OptionListItem(s, s)).toList(),
            mode: OptionSelectionMode.multi,
            selectedValues: state.simplifiedSymptoms.toSet(),
            onToggle: (v) => notifier.toggleListField('simplifiedSymptoms', v),
          ),
          const SizedBox(height: 10),
          const Text('Goals'),
          OptionList(
            items: content.goals.map((g) => OptionListItem(g, g)).toList(),
            mode: OptionSelectionMode.multi,
            selectedValues: state.simplifiedGoals.toSet(),
            onToggle: (v) => notifier.toggleListField('simplifiedGoals', v),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/simplified_branch_screen_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/simplified_branch_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/simplified_branch_screen_test.dart
git commit -m "feat(onboarding): add generic simplified-branch screen for conceive/postpartum/menopause"
```

---

## Task 13: Food Preferences Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/food_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/food_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold`, `OptionList` (Task 1); `onboardingStateProvider` (assumed).
- Produces: `FoodScreen`, mounted at `/onboarding/food` (common screen, all life stages).

Fields (mock `screen-food`): Food Allergies / Dietary Restrictions (text, placeholder "e.g. Peanuts, Gluten, Dairy", writes `foodAllergies`). Preferred Cuisines — multi-select into `cuisines[]`: Italian, Indian, Asian, Mediterranean, Mexican, American.

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/food_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/food_screen.dart';

void main() {
  testWidgets('FoodScreen renders allergy field, six cuisines and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: FoodScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Food Preferences'), findsOneWidget);
    expect(find.byKey(const Key('food-allergies-field')), findsOneWidget);
    for (final label in const ['Italian', 'Indian', 'Asian', 'Mediterranean', 'Mexican', 'American']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/food_screen_test.dart`
Expected: FAIL — `food_screen.dart` doesn't exist

- [ ] **Step 3: Implement FoodScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/food_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class FoodScreen extends ConsumerWidget {
  const FoodScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 62,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _cuisines = [
    OptionListItem('Italian', 'Italian'),
    OptionListItem('Indian', 'Indian'),
    OptionListItem('Asian', 'Asian'),
    OptionListItem('Mediterranean', 'Mediterranean'),
    OptionListItem('Mexican', 'Mexican'),
    OptionListItem('American', 'American'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Indicate your dietary preferences and any food allergies.',
      title: 'Food Preferences',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Food Allergies / Dietary Restrictions'),
          TextFormField(
            key: const Key('food-allergies-field'),
            decoration: const InputDecoration(hintText: 'e.g. Peanuts, Gluten, Dairy'),
            initialValue: state.foodAllergies,
            onChanged: (v) => notifier.setField('foodAllergies', v),
          ),
          const SizedBox(height: 6),
          const Text('Preferred Cuisines'),
          OptionList(
            items: _cuisines,
            mode: OptionSelectionMode.multi,
            selectedValues: state.cuisines.toSet(),
            onToggle: (v) => notifier.toggleListField('cuisines', v),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/food_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/food_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/food_screen_test.dart
git commit -m "feat(onboarding): add food preferences screen"
```

---

## Task 14: Workout Preferences Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/workout_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/workout_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold`, `OptionList` (Task 1); `onboardingStateProvider` (assumed).
- Produces: `WorkoutScreen`, mounted at `/onboarding/workout` (common screen).

Options (mock `screen-workout`, multi-select into `workouts[]`): Walking, Yoga, Gym, Home workout, Dance, Pilates.

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/workout_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/workout_screen.dart';

void main() {
  testWidgets('WorkoutScreen renders all six activity options and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: WorkoutScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Workout Preferences'), findsOneWidget);
    for (final label in const ['Walking', 'Yoga', 'Gym', 'Home workout', 'Dance', 'Pilates']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/workout_screen_test.dart`
Expected: FAIL — `workout_screen.dart` doesn't exist

- [ ] **Step 3: Implement WorkoutScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/workout_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 69,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('Walking', 'Walking'),
    OptionListItem('Yoga', 'Yoga'),
    OptionListItem('Gym', 'Gym'),
    OptionListItem('Home workout', 'Home workout'),
    OptionListItem('Dance', 'Dance'),
    OptionListItem('Pilates', 'Pilates'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Select the physical activities you prefer to keep energetic.',
      title: 'Workout Preferences',
      subtitle: 'What activities keep you feeling energetic?',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.multi,
        selectedValues: state.workouts.toSet(),
        onToggle: (v) => notifier.toggleListField('workouts', v),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/workout_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/workout_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/workout_screen_test.dart
git commit -m "feat(onboarding): add workout preferences screen"
```

---

## Task 15: Notification Preferences Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/notifications_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/notifications_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold`, `OptionList` (Task 1); `onboardingStateProvider` (assumed).
- Produces: `NotificationsScreen`, mounted at `/onboarding/notifications` (common screen).

Options (mock `screen-notifications`, multi-select into `notifications[]`, 9 options): Morning reminder, Medication reminder, Workout reminder, Water intake reminder, Sleep schedule reminder, Cycle tracking reminder, Appointment reminder, Mood check-in reminder, Daily health insights.

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/notifications_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/notifications_screen.dart';

void main() {
  testWidgets('NotificationsScreen renders all nine reminder options and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: NotificationsScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Notification Preferences'), findsOneWidget);
    for (final label in const [
      'Morning reminder', 'Medication reminder', 'Workout reminder', 'Water intake reminder',
      'Sleep schedule reminder', 'Cycle tracking reminder', 'Appointment reminder',
      'Mood check-in reminder', 'Daily health insights',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/notifications_screen_test.dart`
Expected: FAIL — `notifications_screen.dart` doesn't exist

- [ ] **Step 3: Implement NotificationsScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 77,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('Morning reminder', 'Morning reminder'),
    OptionListItem('Medication reminder', 'Medication reminder'),
    OptionListItem('Workout reminder', 'Workout reminder'),
    OptionListItem('Water intake reminder', 'Water intake reminder'),
    OptionListItem('Sleep schedule reminder', 'Sleep schedule reminder'),
    OptionListItem('Cycle tracking reminder', 'Cycle tracking reminder'),
    OptionListItem('Appointment reminder', 'Appointment reminder'),
    OptionListItem('Mood check-in reminder', 'Mood check-in reminder'),
    OptionListItem('Daily health insights', 'Daily health insights'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Choose which reminders and updates you would like to receive.',
      title: 'Notification Preferences',
      subtitle: 'Choose what reminders EVE should send you.',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.multi,
        selectedValues: state.notifications.toSet(),
        onToggle: (v) => notifier.toggleListField('notifications', v),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/notifications_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/notifications_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/notifications_screen_test.dart
git commit -m "feat(onboarding): add notification preferences screen"
```

---

## Task 16: AI Assistant Scope Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/ai_scope_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/ai_scope_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold`, `OptionList` (Task 1); `onboardingStateProvider` (assumed).
- Produces: `AiScopeScreen`, mounted at `/onboarding/ai-scope` (common screen).

Options (mock `screen-ai-scope`, multi-select into `aiScope[]`; the option's stored **value** differs from its display **label** for several items): "All topics" (value `Everything`), "Answer health questions" (value `Answer health questions`), "Nutrition guidance" (value `Nutrition`), "Workout guidance" (value `Workout`), "Mental wellbeing support" (value `Mental wellbeing`), "Medication reminders" (value `Medication reminders`), "Doctor visit preparation" (value `Doctor prep`).

**Spec-vs-mock discrepancy, flagged in the final report:** EVE2_PRD §4 states selecting "everything" auto-selects the rest, but the mock's actual `toggleAIScopeOption()` (line 2471) just calls the same generic `toggleMultiSelect()` as every other option — there is no auto-select-all behavior actually implemented. This task follows the mock's real, coded behavior (plain toggle) rather than the PRD's prose, per this plan's instruction to treat the mock as authoritative for interaction logic.

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/ai_scope_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/ai_scope_screen.dart';

void main() {
  testWidgets('AiScopeScreen renders all seven options and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: AiScopeScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('What would you like EVE to help with?'), findsOneWidget);
    for (final label in const [
      'All topics', 'Answer health questions', 'Nutrition guidance', 'Workout guidance',
      'Mental wellbeing support', 'Medication reminders', 'Doctor visit preparation',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/ai_scope_screen_test.dart`
Expected: FAIL — `ai_scope_screen.dart` doesn't exist

- [ ] **Step 3: Implement AiScopeScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/ai_scope_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class AiScopeScreen extends ConsumerWidget {
  const AiScopeScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 85,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('All topics', 'Everything'),
    OptionListItem('Answer health questions', 'Answer health questions'),
    OptionListItem('Nutrition guidance', 'Nutrition'),
    OptionListItem('Workout guidance', 'Workout'),
    OptionListItem('Mental wellbeing support', 'Mental wellbeing'),
    OptionListItem('Medication reminders', 'Medication reminders'),
    OptionListItem('Doctor visit preparation', 'Doctor prep'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Select the key areas where you would like assistance from EVE.',
      title: 'What would you like EVE to help with?',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.multi,
        selectedValues: state.aiScope.toSet(),
        onToggle: (v) => notifier.toggleListField('aiScope', v),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/ai_scope_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/ai_scope_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/ai_scope_screen_test.dart
git commit -m "feat(onboarding): add AI assistant scope screen"
```

---

## Task 17: Partner Invite Ask Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/partner_ask_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/partner_ask_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold`, `OptionList` (Task 1); `onboardingStateProvider` (assumed).
- Produces: `PartnerAskScreen`, mounted at `/onboarding/partner-ask` (common screen). `state.partnerInvite` (written here) is what Task 25's branching function reads to decide whether `partner-rel`/`partner-perm` are included in the sequence.

Options (mock `screen-partner-ask`, single-select, boolean-valued): "Yes, invite my partner" (`true`), "No, keep EVE private" (`false`). Button label is "Continue" (not "Next", per mock).

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/partner_ask_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/screens/partner_ask_screen.dart';

void main() {
  testWidgets('PartnerAskScreen renders both options, writes partnerInvite, and Continue invokes onContinue', (tester) async {
    var pressed = false;
    late OnboardingNotifier notifier;

    await tester.pumpWidget(ProviderScope(
      child: Consumer(
        builder: (context, ref, _) {
          notifier = ref.read(onboardingStateProvider.notifier);
          return MaterialApp(
            home: PartnerAskScreen(onContinue: () => pressed = true, onBack: () {}),
          );
        },
      ),
    ));

    expect(find.text('Would you like to invite your partner?'), findsOneWidget);
    expect(find.text('Yes, invite my partner'), findsOneWidget);
    expect(find.text('No, keep EVE private'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.byKey(const Key('option-true')));
    expect(notifier.state.partnerInvite, isTrue);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/partner_ask_screen_test.dart`
Expected: FAIL — `partner_ask_screen.dart` doesn't exist

- [ ] **Step 3: Implement PartnerAskScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/partner_ask_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class PartnerAskScreen extends ConsumerWidget {
  const PartnerAskScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 92,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('Yes, invite my partner', 'true'),
    OptionListItem('No, keep EVE private', 'false'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Decide whether to invite a partner to share updates and schedule reminders.',
      title: 'Would you like to invite your partner?',
      subtitle: 'Partner mode enables shared updates and schedule reminders.',
      primaryLabel: 'Continue',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.single,
        selectedValues: {state.partnerInvite.toString()},
        onToggle: (v) => notifier.setField('partnerInvite', v == 'true'),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/partner_ask_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/partner_ask_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/partner_ask_screen_test.dart
git commit -m "feat(onboarding): add partner invite ask screen"
```

---

## Task 18: Partner Relationship Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/partner_rel_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/partner_rel_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold`, `OptionList` (Task 1); `onboardingStateProvider` (assumed).
- Produces: `PartnerRelScreen`, mounted at `/onboarding/partner-rel` (only reachable when `state.partnerInvite == true`, per Task 25).

Options (mock `screen-partner-rel`, single-select, writes `partnerRelation`): Husband, Boyfriend, Partner.

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/partner_rel_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/partner_rel_screen.dart';

void main() {
  testWidgets('PartnerRelScreen renders all three relationship options and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: PartnerRelScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Relationship'), findsOneWidget);
    expect(find.text('Husband'), findsOneWidget);
    expect(find.text('Boyfriend'), findsOneWidget);
    expect(find.text('Partner'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/partner_rel_screen_test.dart`
Expected: FAIL — `partner_rel_screen.dart` doesn't exist

- [ ] **Step 3: Implement PartnerRelScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/partner_rel_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class PartnerRelScreen extends ConsumerWidget {
  const PartnerRelScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 92,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('Husband', 'Husband'),
    OptionListItem('Boyfriend', 'Boyfriend'),
    OptionListItem('Partner', 'Partner'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: "Specify your partner's relationship for tailored communications.",
      title: 'Relationship',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.single,
        selectedValues: state.partnerRelation.isEmpty ? const {} : {state.partnerRelation},
        onToggle: (v) => notifier.setField('partnerRelation', v),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/partner_rel_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/partner_rel_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/partner_rel_screen_test.dart
git commit -m "feat(onboarding): add partner relationship screen"
```

---

## Task 19: Partner Permissions Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/partner_perm_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/partner_perm_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold`, `OptionList` (Task 1); `onboardingStateProvider` (assumed).
- Produces: `PartnerPermScreen`, mounted at `/onboarding/partner-perm` (only reachable when `state.partnerInvite == true`).

Emotion is **`EveEmotion.caring`** per `surveyMascotConfigs['screen-partner-perm']` — EVE2_PRD §4 calls this "the single most consequential screen in the survey" and §6 flags it as "the single highest-stakes moment in the whole flow." Options (mock `screen-partner-perm`, multi-select into `partnerPermissions[]`): Appointment reminders, **Pregnancy milestones** (conditional — see below), Support suggestions, Mood updates. Plus a master toggle "Only what I approve" (writes `onlyApproveMaster`, subtitle copy: "Requires manual approval before sharing updates").

**Mock bug fixed here, flagged in the final report:** in `mockv4.html`, the "Pregnancy milestones" option card is hardcoded `style="display: none"` (line 1848) and no script ever un-hides it — despite EVE2_PRD §4 explicitly stating it should show "only if she's pregnant." This task implements the PRD's stated intent correctly: the option is included in the list only when `state.lifeStage == 'pregnant'`.

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/partner_perm_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/screens/partner_perm_screen.dart';

void main() {
  testWidgets('PartnerPermScreen hides Pregnancy milestones when not pregnant, shows master toggle, Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        onboardingStateProvider.overrideWith((ref) => OnboardingNotifier()..setField('lifeStage', 'cycle')),
      ],
      child: MaterialApp(
        home: PartnerPermScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Partner Sharing Permissions'), findsOneWidget);
    expect(find.text('Appointment reminders'), findsOneWidget);
    expect(find.text('Support suggestions'), findsOneWidget);
    expect(find.text('Mood updates'), findsOneWidget);
    expect(find.text('Pregnancy milestones'), findsNothing);
    expect(find.text('Only what I approve'), findsOneWidget);
    expect(find.text('Requires manual approval before sharing updates'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });

  testWidgets('PartnerPermScreen shows Pregnancy milestones when lifeStage is pregnant', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        onboardingStateProvider.overrideWith((ref) => OnboardingNotifier()..setField('lifeStage', 'pregnant')),
      ],
      child: MaterialApp(
        home: PartnerPermScreen(onContinue: () {}, onBack: () {}),
      ),
    ));

    expect(find.text('Pregnancy milestones'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/partner_perm_screen_test.dart`
Expected: FAIL — `partner_perm_screen.dart` doesn't exist

- [ ] **Step 3: Implement PartnerPermScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/partner_perm_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class PartnerPermScreen extends ConsumerWidget {
  const PartnerPermScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 96,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    final items = [
      const OptionListItem('Appointment reminders', 'Appointment reminders'),
      if (state.lifeStage == 'pregnant')
        const OptionListItem('Pregnancy milestones', 'Pregnancy milestones'),
      const OptionListItem('Support suggestions', 'Support suggestions'),
      const OptionListItem('Mood updates', 'Mood updates'),
    ];

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.caring,
      guidanceText: 'Select which health updates your partner is permitted to view.',
      title: 'Partner Sharing Permissions',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OptionList(
            items: items,
            mode: OptionSelectionMode.multi,
            selectedValues: state.partnerPermissions.toSet(),
            onToggle: (v) => notifier.toggleListField('partnerPermissions', v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Only what I approve', style: TextStyle(fontWeight: FontWeight.w800)),
                    Text('Requires manual approval before sharing updates'),
                  ],
                ),
              ),
              Switch(
                key: const Key('only-approve-toggle'),
                value: state.onlyApproveMaster,
                onChanged: (v) => notifier.setField('onlyApproveMaster', v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/partner_perm_screen_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/partner_perm_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/partner_perm_screen_test.dart
git commit -m "feat(onboarding): add partner permissions screen with pregnancy-conditional option"
```

---

## Task 20: Theme Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/theme_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/theme_screen_test.dart`

**Interfaces:**
- Consumes: `OnboardingScaffold`, `OptionList` (Task 1); `onboardingStateProvider` (assumed).
- Produces: `ThemeScreen`, mounted at `/onboarding/theme`.

Emotion is **`EveEmotion.warm`** per `surveyMascotConfigs['screen-theme']` — the only screen besides Completion with a positive-register emotion. Options (mock `screen-theme`, single-select, writes `theme`): "Default (Ruby Blush)" (value `Default`), "Light Theme" (value `Light`), "Dark Theme" (value `Dark`). Button label is "Finish Setup" (not "Next").

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/theme_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/theme_screen.dart';

void main() {
  testWidgets('ThemeScreen renders all three theme options and Finish Setup invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: ThemeScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Choose Theme'), findsOneWidget);
    expect(find.text('Default (Ruby Blush)'), findsOneWidget);
    expect(find.text('Light Theme'), findsOneWidget);
    expect(find.text('Dark Theme'), findsOneWidget);
    expect(find.text('Finish Setup'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/theme_screen_test.dart`
Expected: FAIL — `theme_screen.dart` doesn't exist

- [ ] **Step 3: Implement ThemeScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/theme_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 100,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('Default (Ruby Blush)', 'Default'),
    OptionListItem('Light Theme', 'Light'),
    OptionListItem('Dark Theme', 'Dark'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.warm,
      guidanceText: 'Select your preferred color scheme for the application interface.',
      title: 'Choose Theme',
      primaryLabel: 'Finish Setup',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.single,
        selectedValues: state.theme.isEmpty ? const {} : {state.theme},
        onToggle: (v) => notifier.setField('theme', v),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/theme_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/theme_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/theme_screen_test.dart
git commit -m "feat(onboarding): add theme screen"
```

---

## Task 21: Completion Screen

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/presentation/screens/completion_screen.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/presentation/screens/completion_screen_test.dart`

**Interfaces:**
- Consumes: `EveMascot`, `EveEmotion` (assumed, Plan 6). Not wrapped in `OnboardingScaffold` — bookend layout like Welcome (Task 2): no back button, no progress bar.
- Produces: `CompletionScreen`, mounted at `/onboarding/completion`. Its `onContinue` is the terminal action of onboarding — Plan 2's router sends it to `/home` (this is `finishOnboardingToHome()` in the mock), not to the next item in the branching sequence (see Task 25).

Copy (mock `screen-completion`): speech bubble "Your EVE profile setup is complete.", brand footer "All Set!" / "Tailored specifically for your health journey", button "Enter EVE". **Emotion inference, flagged in the final report:** `screen-completion` has no entry in `surveyMascotConfigs` (same gap as Welcome), but EVE2_PRD §4 explicitly narrates this screen as showing "the mascot in its most positive, high-energy state" — the canonical 6-value `EveEmotion` set's closest match for "most positive, high-energy" is `hype`, so this task uses `EveEmotion.hype` here (unlike Welcome, which has no such narrative cue and stays `neutral`).

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/presentation/screens/completion_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/completion_screen.dart';

void main() {
  testWidgets('CompletionScreen renders celebratory copy and Enter EVE invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      home: CompletionScreen(onContinue: () => pressed = true),
    ));

    expect(find.text('Your EVE profile setup is complete.'), findsOneWidget);
    expect(find.text('All Set!'), findsOneWidget);
    expect(find.text('Tailored specifically for your health journey'), findsOneWidget);
    expect(find.text('Enter EVE'), findsOneWidget);

    await tester.tap(find.byKey(const Key('completion-enter-eve-button')));
    expect(pressed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/presentation/screens/completion_screen_test.dart`
Expected: FAIL — `completion_screen.dart` doesn't exist

- [ ] **Step 3: Implement CompletionScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/presentation/screens/completion_screen.dart
import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';

class CompletionScreen extends StatelessWidget {
  const CompletionScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Your EVE profile setup is complete.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const EveMascot(emotion: EveEmotion.hype, size: 180),
              Column(
                children: const [
                  Text('All Set!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  Text('Tailored specifically for your health journey', style: TextStyle(color: Color(0xFF666666))),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('completion-enter-eve-button'),
                  onPressed: onContinue,
                  child: const Text('Enter EVE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/presentation/screens/completion_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/presentation/screens/completion_screen.dart EVE_MOBILE/app/test/features/onboarding/presentation/screens/completion_screen_test.dart
git commit -m "feat(onboarding): add completion screen"
```

---

## Task 22: Home Screen (Structure Only)

**Files:**
- Create: `EVE_MOBILE/app/lib/shared/widgets/eve_bottom_nav.dart`
- Create: `EVE_MOBILE/app/lib/features/home/presentation/widgets/bento_card.dart`
- Create: `EVE_MOBILE/app/lib/features/home/presentation/screens/home_screen.dart`
- Test: `EVE_MOBILE/app/test/features/home/presentation/screens/home_screen_test.dart`

**Interfaces:**
- Consumes: `EveMascot`, `EveEmotion` (assumed, Plan 6).
- Produces: `EveBottomNav` (reused by Task 23 Chat and Task 24 Log), `BentoCardData` + `BentoCard`, `HomeScreen`.

Per this plan's scope boundary, `HomeScreen` takes **all** displayed content as constructor params with mock-accurate defaults — it does not call `activeModules()` or read Firestore; Plan 4's build roadmap wires real per-user data into these same params later. The emotion-toggle chips are, per design-spec §7, "a demo affordance — in real product these become auto-driven by check-in content, not manually clicked" — implemented here as local widget state that swaps the hero speech bubble text and mascot emotion, matching mock `triggerHomeEmotion()`. Raw mock emotion keys translate to the canonical set: `hype`→`hype`, `hug`→`caring`, `sassy`→`sassy`, `fertile`→`fertile`.

Copy (mock `screen-home`): greeting "Welcome back, {name}" (default "Welcome back, Maya"), subtext "Current status overview", phase badge "Follicular Phase • Day 9". Hero speech default "7-Day Check-in Streak Active" with hero mascot defaulting to `EveEmotion.hype` (the "Standard" chip carries the mock's `active` CSS class on load — i.e. it is the pre-selected chip — even though the mock's init script has a separate, apparent bug where it never actually calls `setMascotEmotion` for the home rig until a chip is clicked; this task treats the visually-active default state as authoritative, not the bug). Chips: "Standard" → `hype` / "7-Day Check-in Streak Active"; "Support" → `caring` / "Rest and recovery recorded."; "Focus" → `sassy` / "Late luteal phase: Prioritize restful activities and nutrition."; "Vitality" → `fertile` / "Fertile Window: Estimated peak vitality." Bento cards: "Next Cycle Phase" / "in 14 Days" / "Regular cycle rhythm"; "Check-in Streak" / "8 Days" / "Daily logging habit" (streak is a static, read-only display per design-spec §7 note — the earning mechanic is out of V0 scope); full-width "Daily Recommendation" / "Boost Collagen & Iron Intake" / "Pomegranates and leafy greens are recommended for your current phase."

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/home/presentation/screens/home_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/home/presentation/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen renders greeting, phase badge, bento cards and default hero speech', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Welcome back, Maya'), findsOneWidget);
    expect(find.text('Current status overview'), findsOneWidget);
    expect(find.text('Follicular Phase • Day 9'), findsOneWidget);
    expect(find.text('7-Day Check-in Streak Active'), findsOneWidget);
    expect(find.text('Next Cycle Phase'), findsOneWidget);
    expect(find.text('in 14 Days'), findsOneWidget);
    expect(find.text('Check-in Streak'), findsOneWidget);
    expect(find.text('8 Days'), findsOneWidget);
    expect(find.text('Daily Recommendation'), findsOneWidget);
    expect(find.text('Boost Collagen & Iron Intake'), findsOneWidget);
  });

  testWidgets('HomeScreen swaps hero speech when an emotion chip is tapped', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.tap(find.byKey(const Key('home-emotion-chip-Support')));
    await tester.pump();

    expect(find.text('Rest and recovery recorded.'), findsOneWidget);
  });

  testWidgets('HomeScreen bottom nav invokes onNavigateChat and onNavigateLog', (tester) async {
    var chatTapped = false;
    var logTapped = false;

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        onNavigateChat: () => chatTapped = true,
        onNavigateLog: () => logTapped = true,
      ),
    ));

    await tester.tap(find.byKey(const Key('bottom-nav-chat')));
    expect(chatTapped, isTrue);

    await tester.tap(find.byKey(const Key('bottom-nav-log')));
    expect(logTapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home/presentation/screens/home_screen_test.dart`
Expected: FAIL — `home_screen.dart` doesn't exist

- [ ] **Step 3: Implement EveBottomNav**

```dart
// EVE_MOBILE/app/lib/shared/widgets/eve_bottom_nav.dart
import 'package:flutter/material.dart';

enum EveNavTab { home, chat, log }

class EveBottomNav extends StatelessWidget {
  const EveBottomNav({
    super.key,
    required this.currentTab,
    required this.onHomeTap,
    required this.onChatTap,
    required this.onLogTap,
  });

  final EveNavTab currentTab;
  final VoidCallback onHomeTap;
  final VoidCallback onChatTap;
  final VoidCallback onLogTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentTab.index,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Log'),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            onHomeTap();
            break;
          case 1:
            onChatTap();
            break;
          case 2:
            onLogTap();
            break;
        }
      },
    );
  }
}
```

- [ ] **Step 4: Implement BentoCard**

```dart
// EVE_MOBILE/app/lib/features/home/presentation/widgets/bento_card.dart
import 'package:flutter/material.dart';

class BentoCardData {
  const BentoCardData({required this.title, required this.value, required this.description, this.fullWidth = false});
  final String title;
  final String value;
  final String description;
  final bool fullWidth;
}

class BentoCard extends StatelessWidget {
  const BentoCard({super.key, required this.data, this.onTap});

  final BentoCardData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('bento-card-${data.title}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 6),
            Text(data.value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 4),
            Text(data.description, style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Implement HomeScreen**

```dart
// EVE_MOBILE/app/lib/features/home/presentation/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';
import 'package:eve_app/features/home/presentation/widgets/bento_card.dart';
import 'package:eve_app/shared/widgets/eve_bottom_nav.dart';

class _HeroChip {
  const _HeroChip(this.label, this.emotion, this.message);
  final String label;
  final EveEmotion emotion;
  final String message;
}

const _heroChips = [
  _HeroChip('Standard', EveEmotion.hype, '7-Day Check-in Streak Active'),
  _HeroChip('Support', EveEmotion.caring, 'Rest and recovery recorded.'),
  _HeroChip('Focus', EveEmotion.sassy, 'Late luteal phase: Prioritize restful activities and nutrition.'),
  _HeroChip('Vitality', EveEmotion.fertile, 'Fertile Window: Estimated peak vitality.'),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.greetingName = 'Maya',
    this.phaseBadge = 'Follicular Phase • Day 9',
    this.bentoCards = const [
      BentoCardData(title: 'Next Cycle Phase', value: 'in 14 Days', description: 'Regular cycle rhythm'),
      BentoCardData(title: 'Check-in Streak', value: '8 Days', description: 'Daily logging habit'),
      BentoCardData(
        title: 'Daily Recommendation',
        value: 'Boost Collagen & Iron Intake',
        description: 'Pomegranates and leafy greens are recommended for your current phase.',
        fullWidth: true,
      ),
    ],
    this.onNavigateHome,
    this.onNavigateChat,
    this.onNavigateLog,
  });

  final String greetingName;
  final String phaseBadge;
  final List<BentoCardData> bentoCards;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateChat;
  final VoidCallback? onNavigateLog;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeChipIndex = 0;

  @override
  Widget build(BuildContext context) {
    final activeChip = _heroChips[_activeChipIndex];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                Chip(label: Text(widget.phaseBadge)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(activeChip.message, key: const Key('home-hero-speech'), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  EveMascot(emotion: activeChip.emotion, size: 120),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _heroChips.asMap().entries.map((entry) {
                      final chip = entry.value;
                      return ChoiceChip(
                        key: Key('home-emotion-chip-${chip.label}'),
                        label: Text(chip.label),
                        selected: entry.key == _activeChipIndex,
                        onSelected: (_) => setState(() => _activeChipIndex = entry.key),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                for (final card in widget.bentoCards.where((c) => !c.fullWidth)) BentoCard(data: card),
              ],
            ),
            const SizedBox(height: 12),
            for (final card in widget.bentoCards.where((c) => c.fullWidth)) BentoCard(data: card),
          ],
        ),
      ),
      bottomNavigationBar: EveBottomNav(
        currentTab: EveNavTab.home,
        onHomeTap: () {
          if (widget.onNavigateHome != null) widget.onNavigateHome!();
        },
        onChatTap: () {
          if (widget.onNavigateChat != null) widget.onNavigateChat!();
        },
        onLogTap: () {
          if (widget.onNavigateLog != null) widget.onNavigateLog!();
        },
      ),
    );
  }
}
```

Note: `EveBottomNav`'s `onChatTap`/`onLogTap` are wired to `BottomNavigationBar`, whose items don't carry the `bottom-nav-chat`/`bottom-nav-log` keys used in the test above — `BottomNavigationBarItem` doesn't accept a `key` in a way `find.byKey` can target reliably in all Flutter versions. Use `find.text('Chat')`/`find.text('Log')` instead in Step 1's test, or wrap each item's icon+label in a keyed `InkResponse`. Revise Step 1's test to tap by label text before running:

```dart
    await tester.tap(find.text('Chat'));
    expect(chatTapped, isTrue);

    await tester.tap(find.text('Log'));
    expect(logTapped, isTrue);
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/home/presentation/screens/home_screen_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 7: Commit**

```bash
git add EVE_MOBILE/app/lib/shared/widgets/eve_bottom_nav.dart EVE_MOBILE/app/lib/features/home/ EVE_MOBILE/app/test/features/home/
git commit -m "feat(home): add home dashboard screen structure with bento grid and hero mascot"
```

---

## Task 23: Chat Screen (Structure Only)

**Files:**
- Create: `EVE_MOBILE/app/lib/features/chat/presentation/widgets/chat_bubble.dart`
- Create: `EVE_MOBILE/app/lib/features/chat/presentation/screens/chat_screen.dart`
- Test: `EVE_MOBILE/app/test/features/chat/presentation/screens/chat_screen_test.dart`

**Interfaces:**
- Consumes: `EveMascot`, `EveEmotion` (assumed, Plan 6); `EveBottomNav`, `EveNavTab` (Task 22).
- Produces: `ChatMessageData`, `ChatSender` enum, `ChatBubble`, `ChatScreen`.

Per scope, `ChatScreen` renders a fixed placeholder thread passed via constructor (real message sync is out of this plan). Copy (mock `screen-chat`): header avatar "R", partner name "Ryan", status "Partner • Active today". Thread messages, in order: wife — "I have completed my daily health check-in."; partner — "Great to hear. How are you feeling today?"; wife — "I am feeling slightly low on energy and experiencing mild cramps."; **eve-system** (rendered distinctly, with a mini `EveMascot` avatar per design-spec §7) — "Eve: Maya recorded low energy and mild cramps today. Consider offering support."; partner — "I am bringing dinner home and preparing a warm compress for you."; wife — "Thank you, I appreciate it." Quick-reply chips: "Sending support", "You are doing great", "Do you need anything?". Text input placeholder "Type a message...".

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/chat/presentation/screens/chat_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/chat/presentation/screens/chat_screen.dart';

void main() {
  testWidgets('ChatScreen renders header, default thread, quick replies and Log nav invokes callback', (tester) async {
    var logTapped = false;

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(onNavigateLog: () => logTapped = true),
    ));

    expect(find.text('Ryan'), findsOneWidget);
    expect(find.text('Partner • Active today'), findsOneWidget);
    expect(find.text('I have completed my daily health check-in.'), findsOneWidget);
    expect(find.text('Eve: Maya recorded low energy and mild cramps today. Consider offering support.'), findsOneWidget);
    expect(find.text('Sending support'), findsOneWidget);
    expect(find.text('You are doing great'), findsOneWidget);
    expect(find.text('Do you need anything?'), findsOneWidget);
    expect(find.byKey(const Key('chat-input-field')), findsOneWidget);

    await tester.tap(find.text('Log'));
    expect(logTapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/chat/presentation/screens/chat_screen_test.dart`
Expected: FAIL — `chat_screen.dart` doesn't exist

- [ ] **Step 3: Implement ChatBubble**

```dart
// EVE_MOBILE/app/lib/features/chat/presentation/widgets/chat_bubble.dart
import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';

enum ChatSender { wife, partner, eveSystem }

class ChatMessageData {
  const ChatMessageData({required this.sender, required this.text});
  final ChatSender sender;
  final String text;
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessageData message;

  @override
  Widget build(BuildContext context) {
    if (message.sender == ChatSender.eveSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const EveMascot(emotion: EveEmotion.caring, size: 32),
            const SizedBox(width: 8),
            Expanded(child: Text(message.text)),
          ],
        ),
      );
    }

    final isWife = message.sender == ChatSender.wife;
    return Align(
      alignment: isWife ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isWife ? const Color(0xFFFF2A6D) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: isWife ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement ChatScreen**

```dart
// EVE_MOBILE/app/lib/features/chat/presentation/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:eve_app/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:eve_app/shared/widgets/eve_bottom_nav.dart';

const _defaultThread = [
  ChatMessageData(sender: ChatSender.wife, text: 'I have completed my daily health check-in.'),
  ChatMessageData(sender: ChatSender.partner, text: 'Great to hear. How are you feeling today?'),
  ChatMessageData(sender: ChatSender.wife, text: 'I am feeling slightly low on energy and experiencing mild cramps.'),
  ChatMessageData(
    sender: ChatSender.eveSystem,
    text: 'Eve: Maya recorded low energy and mild cramps today. Consider offering support.',
  ),
  ChatMessageData(sender: ChatSender.partner, text: 'I am bringing dinner home and preparing a warm compress for you.'),
  ChatMessageData(sender: ChatSender.wife, text: 'Thank you, I appreciate it.'),
];

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    this.partnerName = 'Ryan',
    this.partnerStatus = 'Partner • Active today',
    this.thread = _defaultThread,
    this.onSendMessage,
    this.onNavigateHome,
    this.onNavigateChat,
    this.onNavigateLog,
  });

  final String partnerName;
  final String partnerStatus;
  final List<ChatMessageData> thread;
  final void Function(String text)? onSendMessage;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateChat;
  final VoidCallback? onNavigateLog;

  static const _quickReplies = ['Sending support', 'You are doing great', 'Do you need anything?'];

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(child: Text(partnerName.substring(0, 1))),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(partnerName, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(partnerStatus, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [for (final m in thread) ChatBubble(message: m)],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final reply in _quickReplies)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(reply),
                      onPressed: () => onSendMessage?.call(reply),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('chat-input-field'),
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'Type a message...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      onSendMessage?.call(controller.text.trim());
                      controller.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: EveBottomNav(
        currentTab: EveNavTab.chat,
        onHomeTap: () => onNavigateHome?.call(),
        onChatTap: () => onNavigateChat?.call(),
        onLogTap: () => onNavigateLog?.call(),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/chat/presentation/screens/chat_screen_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add EVE_MOBILE/app/lib/features/chat/ EVE_MOBILE/app/test/features/chat/
git commit -m "feat(chat): add chat screen structure with three bubble types and quick replies"
```

---

## Task 24: Log Calendar Screen (Structure Only)

**Files:**
- Create: `EVE_MOBILE/app/lib/features/log/presentation/widgets/calendar_day_cell.dart`
- Create: `EVE_MOBILE/app/lib/features/log/presentation/screens/log_screen.dart`
- Test: `EVE_MOBILE/app/test/features/log/presentation/screens/log_screen_test.dart`

**Interfaces:**
- Consumes: `EveMascot`, `EveEmotion` (assumed, Plan 6); `EveBottomNav`, `EveNavTab` (Task 22).
- Produces: `CalendarDayData`, `CalendarDayCell`, `LogEntryType` enum, `LogScreen`.

Per scope, `LogScreen` renders a fixed placeholder month passed via constructor (real calendar data binding is out of this plan). Copy (mock `screen-log`): month header "March 2026" with `‹`/`›` nav arrows. Legend, exact colors from `mockv4.html` CSS custom properties (lines 15–22): Period = `#FF2A6D` (`--ruby-main`), Fertile Window = `#2EC4B6` (`--fertile-teal`), Symptom = `#9B51E0` (`--symptom-purple`), Appointment = `#FF9F1C` (`--appointment-orange`). Calendar grid: 7-column day-of-week header (S M T W T F S) then day cells, each optionally carrying 1+ colored dots (`has-data` days support multiple dots, e.g. March 14 carries both a symptom-purple and a ruby-blush dot in the mock). Tapping a day updates a mascot-toast detail panel showing the date title + description + a mascot rendered in the emotion passed alongside that day's data (mock `selectDate(cell, dateStr, infoStr, emotionKey)`). FAB "+" for new entry (tap callback only, no form in this plan).

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/log/presentation/screens/log_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/log/presentation/screens/log_screen.dart';
import 'package:eve_app/features/log/presentation/widgets/calendar_day_cell.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';

void main() {
  testWidgets('LogScreen renders month header, legend, day cells and toast, Home nav invokes callback', (tester) async {
    var homeTapped = false;

    await tester.pumpWidget(MaterialApp(
      home: LogScreen(
        monthLabel: 'March 2026',
        days: const [
          CalendarDayData(dayNumber: 14, dotColors: [Color(0xFF9B51E0), Color(0xFFFFA0B8)]),
          CalendarDayData(
            dayNumber: 16,
            dotColors: [Color(0xFF2EC4B6)],
            dateTitle: 'March 16',
            detail: 'Fertile Window Begins',
            emotion: EveEmotion.fertile,
          ),
        ],
        selectedDayIndex: 0,
        onNavigateHome: () => homeTapped = true,
      ),
    ));

    expect(find.text('March 2026'), findsOneWidget);
    expect(find.text('Period'), findsOneWidget);
    expect(find.text('Fertile Window'), findsOneWidget);
    expect(find.text('Symptom'), findsOneWidget);
    expect(find.text('Appointment'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.byKey(const Key('log-fab-new-entry')), findsOneWidget);

    await tester.tap(find.text('Home'));
    expect(homeTapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/log/presentation/screens/log_screen_test.dart`
Expected: FAIL — `log_screen.dart` doesn't exist

- [ ] **Step 3: Implement CalendarDayCell**

```dart
// EVE_MOBILE/app/lib/features/log/presentation/widgets/calendar_day_cell.dart
import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';

class CalendarDayData {
  const CalendarDayData({
    required this.dayNumber,
    this.dotColors = const [],
    this.dateTitle,
    this.detail,
    this.emotion = EveEmotion.neutral,
  });

  final int dayNumber;
  final List<Color> dotColors;
  final String? dateTitle;
  final String? detail;
  final EveEmotion emotion;
}

class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({super.key, required this.data, required this.selected, required this.onTap});

  final CalendarDayData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('calendar-day-${data.dayNumber}'),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: selected ? Border.all(color: const Color(0xFFFF2A6D), width: 2) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${data.dayNumber}'),
            if (data.dotColors.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final color in data.dotColors)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement LogScreen**

```dart
// EVE_MOBILE/app/lib/features/log/presentation/screens/log_screen.dart
import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';
import 'package:eve_app/features/log/presentation/widgets/calendar_day_cell.dart';
import 'package:eve_app/shared/widgets/eve_bottom_nav.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({
    super.key,
    this.monthLabel = 'March 2026',
    this.days = const [],
    this.selectedDayIndex = 0,
    this.onNavigateHome,
    this.onNavigateChat,
    this.onNavigateLog,
    this.onNewEntry,
  });

  final String monthLabel;
  final List<CalendarDayData> days;
  final int selectedDayIndex;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateChat;
  final VoidCallback? onNavigateLog;
  final VoidCallback? onNewEntry;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  late int _selectedIndex = widget.selectedDayIndex;

  static const _legend = [
    ('Period', Color(0xFFFF2A6D)),
    ('Fertile Window', Color(0xFF2EC4B6)),
    ('Symptom', Color(0xFF9B51E0)),
    ('Appointment', Color(0xFFFF9F1C)),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedDay = widget.days.isEmpty ? null : widget.days[_selectedIndex];

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.monthLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    Row(children: const [Icon(Icons.chevron_left), Icon(Icons.chevron_right)]),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final entry in _legend)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: entry.$2, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text(entry.$1, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < widget.days.length; i++)
                      CalendarDayCell(
                        data: widget.days[i],
                        selected: i == _selectedIndex,
                        onTap: () => setState(() => _selectedIndex = i),
                      ),
                  ],
                ),
                if (selectedDay != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        EveMascot(emotion: selectedDay.emotion, size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(selectedDay.dateTitle ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text(selectedDay.detail ?? 'No logs recorded.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                key: const Key('log-fab-new-entry'),
                onPressed: () => widget.onNewEntry?.call(),
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: EveBottomNav(
        currentTab: EveNavTab.log,
        onHomeTap: () => widget.onNavigateHome?.call(),
        onChatTap: () => widget.onNavigateChat?.call(),
        onLogTap: () => widget.onNavigateLog?.call(),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/log/presentation/screens/log_screen_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add EVE_MOBILE/app/lib/features/log/ EVE_MOBILE/app/test/features/log/
git commit -m "feat(log): add log calendar screen structure with legend, grid and detail toast"
```

---

## Task 25 (Integration): Onboarding Sequence Branching Logic

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/domain/onboarding_sequence.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/domain/onboarding_sequence_test.dart`

**Interfaces:**
- Consumes: `OnboardingState` (assumed, Plan 2).
- Produces: `onboardingSequence(OnboardingState state) -> List<String>` and `routeForScreen(String screenId) -> String` — Plan 2's `app_router.dart` calls these to resolve "what screen comes after this one" instead of hardcoding a linear route list, and to build the `List<Module>`-driving `lifeStage` read that also determines Home's module set (Plan 2's `activeModules()`, not built here).

This is the Flutter equivalent of the mock's `buildOnboardingSequence()` (`mockv4.html` lines 2328–2349), reproduced screen-for-screen. Note the mock's `basePrefix` is `['screen-auth', 'screen-profile', 'screen-lifestage']` — **it does not include `screen-welcome`**, because welcome is entered via `startOnboardingFlow()` before the indexed sequence begins and carries no progress bar. This task's `onboardingSequence()` matches that: `welcome` and `completion`'s post-tap destination (`home`) are handled outside the returned list, not inside it.

Router responsibility this task documents (implemented by Plan 2, not here): given `state` and the current screen's id, compute `final seq = onboardingSequence(state); final i = seq.indexOf(currentScreenId); final next = i < seq.length - 1 ? seq[i + 1] : 'home';` — this mirrors the mock's `nextOnboardingStep()` guard (`if (currentOnboardingIndex < onboardingSequence.length - 1)`) and its special-case: when `currentScreenId == 'completion'` (the last sequence element), the "Enter EVE" tap goes to `/home`, matching `finishOnboardingToHome()`. `prevOnboardingStep()`'s "go to welcome if at index 0" rule maps the same way: `i == 0 ? 'welcome' : seq[i - 1]`.

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/domain/onboarding_sequence_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_sequence.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';

void main() {
  test('onboardingSequence builds the cycle branch with no partner invite', () {
    const state = OnboardingState(lifeStage: 'cycle', partnerInvite: false);
    expect(onboardingSequence(state), [
      'auth', 'profile', 'lifestage',
      'cycle-info', 'cycle-symptoms', 'cycle-goals',
      'food', 'workout', 'notifications', 'ai-scope', 'partner-ask',
      'theme', 'completion',
    ]);
  });

  test('onboardingSequence builds the pregnant branch with partner invite screens included', () {
    const state = OnboardingState(lifeStage: 'pregnant', partnerInvite: true);
    expect(onboardingSequence(state), [
      'auth', 'profile', 'lifestage',
      'pregnant-due', 'pregnant-meds', 'pregnant-symptoms',
      'food', 'workout', 'notifications', 'ai-scope', 'partner-ask',
      'partner-rel', 'partner-perm',
      'theme', 'completion',
    ]);
  });

  test('onboardingSequence collapses conceive/postpartum/menopause into simplified-branch', () {
    for (final stage in ['conceive', 'postpartum', 'menopause']) {
      final state = OnboardingState(lifeStage: stage);
      expect(onboardingSequence(state).contains('simplified-branch'), isTrue,
          reason: '$stage should route through simplified-branch');
      expect(onboardingSequence(state).contains('cycle-info'), isFalse);
      expect(onboardingSequence(state).contains('pregnant-due'), isFalse);
    }
  });

  test('routeForScreen maps a screen id to its /onboarding/ path', () {
    expect(routeForScreen('cycle-info'), '/onboarding/cycle-info');
    expect(routeForScreen('welcome'), '/onboarding/welcome');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/domain/onboarding_sequence_test.dart`
Expected: FAIL — `onboarding_sequence.dart` doesn't exist

- [ ] **Step 3: Implement onboardingSequence and routeForScreen**

```dart
// EVE_MOBILE/app/lib/features/onboarding/domain/onboarding_sequence.dart
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';

const _basePrefix = ['auth', 'profile', 'lifestage'];

List<String> onboardingSequence(OnboardingState state) {
  final List<String> branchScreens;
  switch (state.lifeStage) {
    case 'cycle':
      branchScreens = ['cycle-info', 'cycle-symptoms', 'cycle-goals'];
      break;
    case 'pregnant':
      branchScreens = ['pregnant-due', 'pregnant-meds', 'pregnant-symptoms'];
      break;
    default:
      branchScreens = ['simplified-branch'];
  }

  final commonScreens = <String>['food', 'workout', 'notifications', 'ai-scope', 'partner-ask'];
  if (state.partnerInvite) {
    commonScreens.addAll(['partner-rel', 'partner-perm']);
  }
  commonScreens.addAll(['theme', 'completion']);

  return [..._basePrefix, ...branchScreens, ...commonScreens];
}

String routeForScreen(String screenId) => '/onboarding/$screenId';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/domain/onboarding_sequence_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/domain/onboarding_sequence.dart EVE_MOBILE/app/test/features/onboarding/domain/onboarding_sequence_test.dart
git commit -m "feat(onboarding): add branching sequence logic mirroring mock's buildOnboardingSequence"
```

---

## Task 26 (Integration): Progress Percent → Mascot Peel Percent Wiring

**Files:**
- Create: `EVE_MOBILE/app/lib/features/onboarding/domain/onboarding_progress.dart`
- Test: `EVE_MOBILE/app/test/features/onboarding/domain/onboarding_progress_test.dart`

**Interfaces:**
- Consumes: nothing beyond core Dart.
- Produces: `onboardingProgressPercent({required int currentIndex, required int totalScreens}) -> double`, the single number that flows into both `OnboardingScaffold.progressPercent` (Task 1 — drives the visible progress bar) and, unchanged, into `EveMascot.peelPercent` (Plan 6) on every screen built in Tasks 3–20.

This closes the loop the design spec asks for explicitly: the mock computes one percent value per screen (`updateSurveyProgress()`, `mockv4.html` lines 2351–2365: `pct = Math.min(100, Math.max(10, Math.round(((curr + 1) / total) * 100)))`) and feeds that same number to both the progress bar fill and `setMascotPeel(rig, pct)`. Plan 1 does not reimplement the `<35`/`35–70`/`≥70` crown/seed-row branching itself — that threshold logic lives inside Plan 6's `EveMascot` — Plan 1's only job is guaranteeing the same 0–100 value reaches both places unmodified. Concretely, each screen task above (3–20) receives its `progressPercent` constructor value from this function, called by Plan 2's router as `onboardingProgressPercent(currentIndex: seq.indexOf(screenId), totalScreens: seq.length)` where `seq = onboardingSequence(state)` (Task 25) — the hardcoded default values used as fallback constructor defaults in Tasks 3–20 (e.g. `profile_screen.dart`'s `progressPercent = 23`) are pre-computed illustrative approximations for the default 13-screen cycle-branch sequence, and are always overridden by the router in real navigation.

- [ ] **Step 1: Write the failing test**

```dart
// EVE_MOBILE/app/test/features/onboarding/domain/onboarding_progress_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_progress.dart';

void main() {
  test('onboardingProgressPercent matches the mock formula, clamped between 10 and 100', () {
    // total = 13 (the default cycle-branch sequence length from Task 25)
    expect(onboardingProgressPercent(currentIndex: 0, totalScreens: 13), 10.0); // round(1/13*100)=8, clamped to 10
    expect(onboardingProgressPercent(currentIndex: 3, totalScreens: 13), 31.0); // round(4/13*100)=31
    expect(onboardingProgressPercent(currentIndex: 4, totalScreens: 13), 38.0); // round(5/13*100)=38
    expect(onboardingProgressPercent(currentIndex: 8, totalScreens: 13), 69.0); // round(9/13*100)=69
    expect(onboardingProgressPercent(currentIndex: 9, totalScreens: 13), 77.0); // round(10/13*100)=77
    expect(onboardingProgressPercent(currentIndex: 12, totalScreens: 13), 100.0); // last screen
  });

  test('onboardingProgressPercent never exceeds 100 even if currentIndex overshoots', () {
    expect(onboardingProgressPercent(currentIndex: 20, totalScreens: 13), 100.0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/onboarding/domain/onboarding_progress_test.dart`
Expected: FAIL — `onboarding_progress.dart` doesn't exist

- [ ] **Step 3: Implement onboardingProgressPercent**

```dart
// EVE_MOBILE/app/lib/features/onboarding/domain/onboarding_progress.dart
double onboardingProgressPercent({required int currentIndex, required int totalScreens}) {
  final raw = ((currentIndex + 1) / totalScreens * 100).round();
  return raw.clamp(10, 100).toDouble();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/onboarding/domain/onboarding_progress_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Wire it into OnboardingScaffold's mascot (verification, no new production code)**

Confirm (already true from Task 1's implementation) that `OnboardingScaffold` passes its `progressPercent` param straight into `EveMascot(peelPercent: progressPercent, ...)` with no intermediate transform — re-read `EVE_MOBILE/app/lib/features/onboarding/presentation/widgets/onboarding_scaffold.dart` and confirm the line `EveMascot(emotion: emotion, peelPercent: progressPercent, size: 64)` is present exactly as written in Task 1 Step 3. This is the final link: `onboardingProgressPercent()` (this task) → `progressPercent` constructor arg on each Task 3–20 screen → `OnboardingScaffold.progressPercent` → `EveMascot.peelPercent`, at which point Plan 6's threshold logic (`<35`/`35–70`/`≥70`) takes over.

- [ ] **Step 6: Commit**

```bash
git add EVE_MOBILE/app/lib/features/onboarding/domain/onboarding_progress.dart EVE_MOBILE/app/test/features/onboarding/domain/onboarding_progress_test.dart
git commit -m "feat(onboarding): add progress-to-peel-percent formula matching mock's updateSurveyProgress"
```

---

## Self-Review

**Spec coverage.**
- All 20 onboarding screens from design-spec §5 have a dedicated task (Tasks 2–21), each mapped to its exact route id from the branch/common-screen lists. ✅
- All fields from design-spec §6's `surveyState` field list are written by some screen: `name/age/height/weight/country` (Task 4), `lifeStage` (Task 5), `cycleLength/periodLength/flow` (Task 6), `cycleSymptoms` (Task 7), `cycleGoals/nutritionDiet` (Task 8), `dueDate/dueMethod/highRisk/pregnancyType` (Task 9), `medications/allergies/prenatalVitamins` (Task 10), `pregnantSymptoms` (Task 11), `simplifiedSymptoms/simplifiedGoals` (Task 12), `foodAllergies/cuisines` (Task 13), `workouts` (Task 14), `notifications` (Task 15), `aiScope` (Task 16), `partnerInvite` (Task 17), `partnerRelation` (Task 18), `partnerPermissions/onlyApproveMaster` (Task 19), `theme` (Task 20). ✅
- Per-screen mascot emotion reproduces `surveyMascotConfigs` exactly: `caring` on cycle-symptoms, pregnant-meds, pregnant-symptoms, simplified-branch, partner-perm; `warm` on theme; `neutral` everywhere else in that map — no screen was left defaulted to neutral without checking the mock first. ✅ (Welcome/Completion emotions are explicitly flagged as inferences since they're absent from `surveyMascotConfigs`.)
- Guidance copy lines are verbatim from `mockv4.html` on every task. ✅
- Home/Chat/Log built as structure-only, constructor-driven shells per the scope boundary, with real data wiring explicitly deferred to Plan 4. ✅
- Branching logic (Task 25) and peel-percent wiring (Task 26) included as the final two integration tasks, per instruction. ✅
- Widget test present on every task verifying key fields render and that the forward-navigation control invokes its callback. ✅

**Placeholder scan.** No "TBD"/"similar to Task N"/unimplemented-handler patterns found; every step that changes code shows the full code, not a diff description. The one caveat is Task 22 Step 5's note about `BottomNavigationBarItem` keys — resolved concretely in the same step with the exact test revision, not left open.

**Type consistency.** `OnboardingNotifier.setField`/`toggleListField` names and `OnboardingState` field names are used identically across all 20 onboarding screen tasks and Task 25. `EveMascot`/`EveEmotion` constructor usage matches the Global Constraints block in every task. `EveBottomNav`/`EveNavTab` introduced in Task 22 are reused with identical names in Tasks 23 and 24. `BentoCardData`, `ChatMessageData`/`ChatSender`, `CalendarDayData` each defined once and consumed only where produced.

---

## Assumptions and spec gaps to flag

1. **`OnboardingNotifier` method surface is assumed, not spec-fixed.** Design-spec §10 fixes the provider's *name* (`onboardingStateProvider`) and that it holds a model equivalent to `surveyState`, but not its mutation API. This plan assumes a two-method generic surface (`setField(String, Object?)`, `toggleListField(String, String)`) mirroring the mock's own generic `surveyState[key] = val` / `toggleMultiSelect` pattern. Plan 2 must implement exactly this surface (or this plan's 20 screen files need matching edits).
2. **Package name assumed as `eve_app`.** Not fixed anywhere in the design spec (no `pubspec.yaml` exists yet); Plan 3 should confirm or this plan's imports need a rename pass.
3. **Welcome and Completion mascot emotions are inferred, not spec-fixed.** Neither screen has an entry in `surveyMascotConfigs`. Welcome is treated as `neutral` (the mock's unset default). Completion is treated as `hype`, based on EVE2_PRD §4's "most positive, high-energy state" narrative — the closest canonical `EveEmotion` match.
4. **AI Scope "select everything auto-selects the rest" (EVE2_PRD §4) is not actually implemented in the mock's JS** (`toggleAIScopeOption` is a plain toggle, mockv4.html line 2471). This plan follows the mock's real coded behavior over the PRD's prose, per the instruction that the mock is authoritative for interaction logic. Flagging in case product intent was actually the PRD's version.
5. **Partner Permissions "Pregnancy milestones" conditional visibility is a mock bug, fixed in this plan.** The mock hardcodes `display:none` on that option with no script ever un-hiding it. This plan implements the PRD's stated intent (`EVE2_PRD §4`: shown only if pregnant) instead of literally reproducing the mock's dead code.
6. **Cycle Goals "Improve nutrition" is written into `cycleGoals[]` in this plan; the mock's `toggleNutritionGoal()` never actually does this** (it only toggles a CSS class and reveals the diet sub-choice). Treated as a mock oversight since every other goal option is recorded and Firestore's Goals & Preferences collection (design-spec §10) expects a complete list.
7. **Home screen's initial hero emotion/speech is inferred as `hype`/"7-Day Check-in Streak Active".** The mock's home mascot rig is never explicitly initialized via `setMascotEmotion` before first paint (unlike every onboarding screen, which is initialized from `surveyMascotConfigs`), even though the "Standard" chip carries the `active` CSS class on load. This plan treats the visually-active chip as authoritative rather than reproducing the apparent initialization gap.
8. **Progress-percent default values baked into each screen's constructor (e.g. `progressPercent = 23` on `ProfileScreen`) are illustrative pre-computed fallbacks for the default 13-screen cycle-branch sequence**, not a substitute for Task 26's router wiring — Plan 2's router must always pass the real computed value for the user's actual branch/partner-invite combination, since e.g. the pregnant branch and partner-invite-on sequences have different lengths and thus different per-screen percentages.

