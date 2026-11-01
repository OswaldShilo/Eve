import 'package:eve_app/core/theme/eve_theme.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void _noop() {}

/// Every onboarding screen, built standalone.
final Map<String, Widget Function()> _screens = {
  'welcome': () => const WelcomeScreen(onContinue: _noop, onJoinPartner: _noop),
  'auth': () => const AuthScreen(onContinue: _noop, onBack: _noop),
  'profile': () => const ProfileScreen(onContinue: _noop, onBack: _noop),
  'lifestage': () => const LifeStageScreen(onContinue: _noop, onBack: _noop),
  'cycle-info': () => const CycleInfoScreen(onContinue: _noop, onBack: _noop),
  'cycle-symptoms': () =>
      const CycleSymptomsScreen(onContinue: _noop, onBack: _noop),
  'cycle-goals': () => const CycleGoalsScreen(onContinue: _noop, onBack: _noop),
  'pregnant-due': () =>
      const PregnantDueScreen(onContinue: _noop, onBack: _noop),
  'pregnant-meds': () =>
      const PregnantMedsScreen(onContinue: _noop, onBack: _noop),
  'pregnant-symptoms': () =>
      const PregnantSymptomsScreen(onContinue: _noop, onBack: _noop),
  'simplified': () =>
      const SimplifiedBranchScreen(onContinue: _noop, onBack: _noop),
  'food': () => const FoodScreen(onContinue: _noop, onBack: _noop),
  'workout': () => const WorkoutScreen(onContinue: _noop, onBack: _noop),
  'notifications': () =>
      const NotificationsScreen(onContinue: _noop, onBack: _noop),
  'ai-scope': () => const AiScopeScreen(onContinue: _noop, onBack: _noop),
  'partner-ask': () => const PartnerAskScreen(onContinue: _noop, onBack: _noop),
  'partner-rel': () => const PartnerRelScreen(onContinue: _noop, onBack: _noop),
  'partner-perm': () =>
      const PartnerPermScreen(onContinue: _noop, onBack: _noop),
  'theme': () => const ThemeScreen(onContinue: _noop, onBack: _noop),
  'completion': () => const CompletionScreen(onContinue: _noop),
};

Future<void> _pumpAt(
  WidgetTester tester,
  Widget screen, {
  required double textScale,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: EveTheme.defaultTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            viewInsets: viewInsets,
          ),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  // Bounded settle: the mascot's idle float never stops.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final scale in [1.0, 1.3, 1.5]) {
    for (final entry in _screens.entries) {
      testWidgets('${entry.key} has no overflow at 360x640, text x$scale', (
        tester,
      ) async {
        await _pumpAt(tester, entry.value(), textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }

  // A 300px soft keyboard on a 640px phone: text-field screens must still
  // lay out (the scroll area shrinks; the primary button stays reachable).
  for (final key in ['profile', 'food', 'pregnant-meds', 'pregnant-due']) {
    testWidgets('$key lays out with the keyboard open', (tester) async {
      await _pumpAt(
        tester,
        _screens[key]!(),
        textScale: 1.3,
        viewInsets: const EdgeInsets.only(bottom: 300),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('onboarding-primary-button')),
        findsOneWidget,
      );
      // The guidance card is tucked away while the keyboard is up.
      expect(find.byKey(const Key('onboarding-guidance-text')), findsNothing);
      final buttonBottom = tester
          .getBottomLeft(find.byKey(const Key('onboarding-primary-button')))
          .dy;
      expect(buttonBottom, lessThanOrEqualTo(640 - 300 + 1));
    });
  }
}
