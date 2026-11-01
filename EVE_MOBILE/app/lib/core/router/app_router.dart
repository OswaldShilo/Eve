import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:eve_app/core/constants/appwrite_ids.dart';
import 'package:eve_app/core/providers/appwrite_providers.dart';
import 'package:eve_app/core/providers/repository_providers.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/partner_invite_code_dialog.dart';
import 'package:eve_app/core/services/ai_proxy_service.dart';
import 'package:eve_app/core/services/appwrite_service.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_progress.dart';
import 'package:eve_app/features/partner/presentation/partner_join_screen.dart';
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
import 'package:eve_app/features/chat/presentation/chat_mapping.dart';
import 'package:eve_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:eve_app/features/log/presentation/log_mapping.dart';
import 'package:eve_app/features/log/presentation/widgets/quick_log_sheet.dart';
import 'package:eve_app/shared/models/symptom_log.dart';
import 'package:eve_app/features/home/presentation/screens/doctor_summary_screen.dart';
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
      _AuthRoute(onContinue: onContinue, onBack: onBack, progressPercent: progressPercent),
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
    ),
    ..._middleScreenBuilders.keys.map(_onboardingRoute),
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
                onNavigateDoctorSummary: () => context.go('/doctor-summary'),
              ),
              loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
              error: (_, __) => HomeScreen(
                onNavigateChat: () => context.go('/chat'),
                onNavigateLog: () => context.go('/log'),
                onNavigateDoctorSummary: () => context.go('/doctor-summary'),
              ),
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
  ],
);

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
