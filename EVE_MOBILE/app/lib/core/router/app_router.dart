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
