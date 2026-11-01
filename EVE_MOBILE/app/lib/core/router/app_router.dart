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
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'startup',
      builder: (context, state) => const _StartupRoute(),
    ),
    GoRoute(
      path: '/onboarding/welcome',
      name: 'onboarding-welcome',
      builder: (context, state) => WelcomeScreen(
        onContinue: () => context.go('/onboarding/auth'),
        onJoinPartner: () => context.go('/partner/join'),
      ),
    ),
    ..._middleScreenBuilders.keys.map(_onboardingRoute),
    GoRoute(
      path: '/onboarding/completion',
      name: 'onboarding-completion',
      builder: (context, state) => const _CompletionRoute(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => Consumer(builder: (context, ref, _) {
        final uid = ref.watch(currentUidProvider);
        if (uid == null) return const RedirectTo('/onboarding/welcome');
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
        if (uid == null) return const RedirectTo('/onboarding/welcome');
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
        if (uid == null) return const RedirectTo('/onboarding/welcome');
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
        if (uid == null) return const RedirectTo('/onboarding/welcome');
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

/// Saves her answers on "Enter EVE" (busy while saving), shows the partner
/// invite code when she invited one, then opens Home. System back returns to
/// the last survey screen.
class _CompletionRoute extends ConsumerStatefulWidget {
  const _CompletionRoute();

  @override
  ConsumerState<_CompletionRoute> createState() => _CompletionRouteState();
}

class _CompletionRouteState extends ConsumerState<_CompletionRoute> {
  bool _saving = false;

  Future<void> _finish() async {
    if (_saving) return;
    final uid = ref.read(currentUidProvider);
    String? inviteCode;
    if (uid != null) {
      setState(() => _saving = true);
      try {
        inviteCode = await ref.read(onboardingRepositoryProvider).saveOnboarding(uid, ref.read(onboardingStateProvider));
        ref.invalidate(homeDashboardProvider(uid));
      } catch (_) {
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('We could not save your answers. Please check your connection and try again.'),
          ));
        }
        return;
      }
    }
    if (!mounted) return;
    if (inviteCode != null) {
      await showDialog<void>(context: context, builder: (_) => PartnerInviteCodeDialog(code: inviteCode!));
    }
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final sequence = onboardingSequence(ref.watch(onboardingStateProvider));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _saving) return;
        context.go(routeForScreen(sequence[sequence.length - 2]));
      },
      child: CompletionScreen(busy: _saving, onContinue: _finish),
    );
  }
}

/// Signs in (Google or anonymous guest) before advancing, and records the
/// uid every repository call is keyed by. The tapped button shows a spinner
/// and further taps are ignored until sign-in finishes.
class _AuthRoute extends ConsumerStatefulWidget {
  const _AuthRoute({required this.onContinue, required this.onBack, required this.progressPercent});

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  @override
  ConsumerState<_AuthRoute> createState() => _AuthRouteState();
}

class _AuthRouteState extends ConsumerState<_AuthRoute> {
  bool? _busyGoogle; // null = idle

  Future<void> _signIn({required bool google}) async {
    if (_busyGoogle != null) return;
    setState(() => _busyGoogle = google);
    final appwrite = ref.read(appwriteServiceProvider);
    try {
      if (await appwrite.currentUserId() == null) {
        google ? await appwrite.signInWithGoogle() : await appwrite.signInAsGuest();
      }
      ref.read(currentUidProvider.notifier).state = await appwrite.currentUserId();
      if (mounted) setState(() => _busyGoogle = null);
      widget.onContinue();
    } catch (_) {
      if (mounted) {
        setState(() => _busyGoogle = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-in did not complete. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AuthScreen(
        progressPercent: widget.progressPercent,
        onBack: widget.onBack,
        guestBusy: _busyGoogle == false,
        googleBusy: _busyGoogle == true,
        onGoogleSignIn: () => _signIn(google: true),
        onContinue: () => _signIn(google: false),
      );
}

/// Where the app opens: signed-out people start onboarding at Welcome; a
/// signed-in woman who finished onboarding goes straight to Home; a linked
/// partner (whose chat thread belongs to someone else) goes to Chat; a
/// signed-in account that never finished onboarding starts again at Welcome
/// (onboarding answers are only kept in memory until Completion saves them).
class _StartupRoute extends ConsumerWidget {
  const _StartupRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return const RedirectTo('/onboarding/welcome');
    final dashboard = ref.watch(homeDashboardProvider(uid));
    return dashboard.when(
      data: (data) {
        if (data.onboardingComplete) return const RedirectTo('/home');
        return ref.watch(chatThreadIdProvider(uid)).when(
              data: (threadId) => RedirectTo(threadId == uid ? '/onboarding/welcome' : '/chat'),
              loading: () => const StartupSplash(),
              error: (_, __) => const RedirectTo('/onboarding/welcome'),
            );
      },
      loading: () => const StartupSplash(),
      // Home shows its own error state with Retry.
      error: (_, __) => const RedirectTo('/home'),
    );
  }
}

/// Shown while the startup gate looks up her session.
class StartupSplash extends StatelessWidget {
  const StartupSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          key: Key('startup-splash'),
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 3.5),
        ),
      ),
    );
  }
}

/// Replaces the current location with [location] right after the first
/// frame (go_router forbids navigating during build). Shows the splash
/// meanwhile.
class RedirectTo extends StatefulWidget {
  const RedirectTo(this.location, {super.key});

  final String location;

  @override
  State<RedirectTo> createState() => _RedirectToState();
}

class _RedirectToState extends State<RedirectTo> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(widget.location);
    });
  }

  @override
  Widget build(BuildContext context) => const StartupSplash();
}
