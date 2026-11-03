import 'dart:async';

import 'package:appwrite/appwrite.dart';

import 'package:eve_app/core/providers/appwrite_providers.dart';
import 'package:eve_app/core/providers/repository_providers.dart';
import 'package:eve_app/core/router/app_router.dart';
import 'package:eve_app/features/chat/data/chat_repository.dart';
import 'package:eve_app/features/home/data/home_repository.dart';
import 'package:eve_app/features/onboarding/data/onboarding_repository.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_repositories.dart';

/// `pumpAndSettle` never returns while an `EveMascot` is on screen (its idle
/// float repeats forever), so advance a bounded amount of time instead —
/// long enough for go_router's page transition to finish.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

const _expectedRoutePaths = <String>{
  '/',
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
  '/partner/join',
  '/doctor-summary',
};

void main() {
  setUp(() {
    appRouter.go('/onboarding/welcome');
  });

  test('appRouter declares every screen ID from design-spec §5 and §7', () {
    final paths = appRouter.configuration.routes
        .whereType<GoRoute>()
        .map((route) => route.path)
        .toSet();

    expect(paths, equals(_expectedRoutePaths));
  });

  testWidgets('initial location renders the real Welcome screen', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: appRouter)));
    await _settle(tester);

    expect(find.text('Begin Setup'), findsOneWidget);
  });

  testWidgets('signed out, /home redirects to Welcome instead of showing demo data', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: appRouter)));
    await _settle(tester);

    appRouter.go('/home');
    await _settle(tester);
    await _settle(tester);

    expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/onboarding/welcome');
    expect(find.text('Welcome back, Maya'), findsNothing);
  });

  for (final path in ['/chat', '/log', '/doctor-summary']) {
    testWidgets('signed out, $path redirects to Welcome', (tester) async {
      await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: appRouter)));
      appRouter.go(path);
      await _settle(tester);
      await _settle(tester);

      expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/onboarding/welcome');
    });
  }

  group('startup gate (/)', () {
    Future<String> openAt(
      WidgetTester tester, {
      String? uid,
      HomeDashboardData? dashboard,
      ChatRepository? chat,
    }) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUidProvider.overrideWith((ref) => uid),
          if (dashboard != null) homeRepositoryProvider.overrideWithValue(FakeHomeRepository(dashboard)),
          logRepositoryProvider.overrideWithValue(FakeLogRepository()),
          if (chat != null) chatRepositoryProvider.overrideWithValue(chat),
        ],
        child: MaterialApp.router(routerConfig: appRouter),
      ));
      appRouter.go('/');
      await _settle(tester);
      await _settle(tester);
      return appRouter.routerDelegate.currentConfiguration.uri.path;
    }

    testWidgets('signed out opens Welcome', (tester) async {
      expect(await openAt(tester), '/onboarding/welcome');
    });

    testWidgets('a returning, onboarded user opens Home', (tester) async {
      final path = await openAt(tester, uid: 'u1', dashboard: const HomeDashboardDataFixture().data);
      expect(path, '/home');
      expect(find.text('Welcome back, Priya'), findsOneWidget);
    });

    testWidgets('a signed-in account that never finished onboarding opens Welcome', (tester) async {
      final path = await openAt(
        tester,
        uid: 'u1',
        dashboard: const HomeDashboardData(greetingName: 'there', phaseBadge: 'Welcome to EVE'),
        chat: FakeChatRepository(),
      );
      expect(path, '/onboarding/welcome');
    });

    testWidgets('a linked partner opens the shared Chat', (tester) async {
      final path = await openAt(
        tester,
        uid: 'partner1',
        dashboard: const HomeDashboardData(greetingName: 'there', phaseBadge: 'Welcome to EVE'),
        chat: _PartnerChatRepository(),
      );
      expect(path, '/chat');
    });

    testWidgets('shows a splash while the session is looked up', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUidProvider.overrideWith((ref) => 'u1'),
          homeRepositoryProvider.overrideWithValue(_NeverHomeRepository()),
        ],
        child: MaterialApp.router(routerConfig: appRouter),
      ));
      appRouter.go('/');
      await _settle(tester);
      expect(find.byKey(const Key('startup-splash')), findsOneWidget);
      expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/');
    });
  });

  testWidgets('completing the Life-Stage screen advances into the cycle branch', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: appRouter)));
    await _settle(tester);

    appRouter.go('/onboarding/lifestage');
    await _settle(tester);
    await tester.tap(find.text('Tracking my cycle'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    await _settle(tester);

    expect(find.text('Cycle Details'), findsOneWidget);
  });

  testWidgets('Completion saves onboarding through the repository and goes Home', (tester) async {
    final repo = FakeOnboardingRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        onboardingRepositoryProvider.overrideWithValue(repo),
        homeRepositoryProvider.overrideWithValue(FakeHomeRepository(const HomeDashboardDataFixture().data)),
        // Home also reads her logs for the check-in count.
        logRepositoryProvider.overrideWithValue(FakeLogRepository()),
        currentUidProvider.overrideWith((ref) => 'u1'),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ));
    appRouter.go('/onboarding/completion');
    await _settle(tester);

    await tester.tap(find.text('Enter EVE'));
    await _settle(tester);

    expect(repo.saved.single.$1, 'u1');
    expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/home');
  });

  testWidgets('Completion save failure shows the server-not-set-up error, stays put, and a retry goes Home',
      (tester) async {
    final repo = _FailingOnceOnboardingRepository(
      AppwriteException("Database with the requested ID 'eve' could not be found.", 404, 'database_not_found'),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        onboardingRepositoryProvider.overrideWithValue(repo),
        homeRepositoryProvider.overrideWithValue(FakeHomeRepository(const HomeDashboardDataFixture().data)),
        logRepositoryProvider.overrideWithValue(FakeLogRepository()),
        currentUidProvider.overrideWith((ref) => 'u1'),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ));
    appRouter.go('/onboarding/completion');
    await _settle(tester);

    await tester.tap(find.text('Enter EVE'));
    await _settle(tester);

    expect(find.byKey(const Key('completion-save-error')), findsOneWidget);
    expect(find.textContaining('server is not set up'), findsOneWidget);
    expect(find.textContaining('[404 database_not_found]'), findsOneWidget); // tests run in debug mode
    expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/onboarding/completion');
    expect(find.byKey(const Key('eve-button-busy')), findsNothing);

    // The snack bar overlaps the button in the 800x600 test view; on a phone it times out after 4 s.
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).hideCurrentSnackBar();
    await _settle(tester);
    await tester.tap(find.text('Enter EVE'));
    await _settle(tester);

    expect(repo.calls, 2);
    expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/home');
  });

  testWidgets('Completion network failure keeps the connection message', (tester) async {
    final repo = _FailingOnceOnboardingRepository(Exception('offline'));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        onboardingRepositoryProvider.overrideWithValue(repo),
        currentUidProvider.overrideWith((ref) => 'u1'),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ));
    appRouter.go('/onboarding/completion');
    await _settle(tester);

    await tester.tap(find.text('Enter EVE'));
    await _settle(tester);

    expect(find.textContaining('Please check your connection and try again.'), findsOneWidget);
    expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/onboarding/completion');
  });

  testWidgets('Home shows the signed-in user name from the repository', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWith((ref) => 'u1'),
        homeRepositoryProvider.overrideWithValue(FakeHomeRepository(const HomeDashboardDataFixture().data)),
        // Home also reads her logs for the check-in count.
        logRepositoryProvider.overrideWithValue(FakeLogRepository()),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ));
    appRouter.go('/home');
    await _settle(tester);
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
    await _settle(tester);
    await chat.sendMessage('u1', 'Hello from the test');
    await _settle(tester);
    expect(find.text('Hello from the test'), findsOneWidget);
  });

  testWidgets('Welcome links partners to the join screen', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: appRouter)));
    appRouter.go('/onboarding/welcome');
    await _settle(tester);
    await tester.ensureVisible(find.byKey(const Key('welcome-partner-join')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('welcome-partner-join')));
    await _settle(tester);
    expect(find.text('Join your partner'), findsOneWidget);
  });

  testWidgets('Doctor summary is disabled with an explanation when she has no logs', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWith((ref) => 'u1'),
        logRepositoryProvider.overrideWithValue(FakeLogRepository()),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ));
    appRouter.go('/doctor-summary');
    await _settle(tester);
    expect(find.text('No logs to summarize yet'), findsOneWidget);
  });

  testWidgets('Android back on a survey screen returns to the previous screen', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: appRouter)));
    appRouter.go('/onboarding/profile');
    await _settle(tester);

    final handled = await tester.binding.handlePopRoute();
    await _settle(tester);

    expect(handled, isTrue);
    expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/onboarding/auth');
  });

  testWidgets('Android back on Completion returns to the Theme screen', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: appRouter)));
    appRouter.go('/onboarding/completion');
    await _settle(tester);

    await tester.binding.handlePopRoute();
    await _settle(tester);

    expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/onboarding/theme');
  });

  testWidgets('Enter EVE shows a spinner while saving and saves only once on double tap', (tester) async {
    final repo = _SlowOnboardingRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        onboardingRepositoryProvider.overrideWithValue(repo),
        homeRepositoryProvider.overrideWithValue(FakeHomeRepository(const HomeDashboardDataFixture().data)),
        // Home also reads her logs for the check-in count.
        logRepositoryProvider.overrideWithValue(FakeLogRepository()),
        currentUidProvider.overrideWith((ref) => 'u1'),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ));
    appRouter.go('/onboarding/completion');
    await _settle(tester);

    await tester.tap(find.text('Enter EVE'));
    await tester.pump();
    expect(find.byKey(const Key('eve-button-busy')), findsOneWidget);
    await tester.tap(find.byKey(const Key('completion-enter-eve-button')));
    await tester.pump();

    repo.release.complete();
    await _settle(tester);

    expect(repo.calls, 1);
    expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/home');
  });

  testWidgets('Home shows an error with Retry instead of demo data, and Retry reloads', (tester) async {
    final home = _FlakyHomeRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWith((ref) => 'u1'),
        homeRepositoryProvider.overrideWithValue(home),
        logRepositoryProvider.overrideWithValue(FakeLogRepository()),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ));
    appRouter.go('/home');
    await _settle(tester);

    expect(find.byKey(const Key('home-error')), findsOneWidget);
    expect(find.text('Welcome back, Maya'), findsNothing);

    home.fail = false;
    await tester.tap(find.byKey(const Key('eve-status-action')));
    await _settle(tester);

    expect(find.text('Welcome back, Priya'), findsOneWidget);
    expect(home.calls, 2);
  });

  testWidgets('Home renders the modules for her life stage', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWith((ref) => 'u1'),
        homeRepositoryProvider.overrideWithValue(FakeHomeRepository(
          const HomeDashboardData(greetingName: 'Priya', phaseBadge: 'Pregnancy Tracking Active', lifeStage: 'pregnant'),
        )),
        logRepositoryProvider.overrideWithValue(FakeLogRepository()),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ));
    appRouter.go('/home');
    await _settle(tester);

    await tester.scrollUntilVisible(
      find.text('PREGNANCY MILESTONES'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('PREGNANCY MILESTONES'));
    await tester.pump();
    expect(find.text('PREGNANCY MILESTONES'), findsOneWidget);
    expect(find.text('NEXT CYCLE PHASE'), findsNothing);
    expect(find.text('Log your first check-in from the Log tab.'), findsOneWidget);
  });

  testWidgets('Chat shows an error with Retry when the thread cannot be found', (tester) async {
    final chat = _FlakyThreadChatRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWith((ref) => 'u1'),
        chatRepositoryProvider.overrideWithValue(chat),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ));
    appRouter.go('/chat');
    await _settle(tester);

    expect(find.byKey(const Key('chat-error')), findsOneWidget);
    expect(find.text('Ryan'), findsNothing);

    chat.fail = false;
    await tester.tap(find.byKey(const Key('eve-status-action')));
    await _settle(tester);
    await _settle(tester);
    expect(find.byKey(const Key('chat-empty')), findsOneWidget);
  });

  testWidgets('Chat never shows the demo partner name on live data', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWith((ref) => 'u1'),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
      ],
      child: MaterialApp.router(routerConfig: appRouter),
    ));
    appRouter.go('/chat');
    // Thread lookup, then the message stream, each resolve on a later frame.
    await _settle(tester);
    await _settle(tester);

    expect(find.text('Ryan'), findsNothing);
    expect(find.text('Your partner'), findsOneWidget);
  });
}

class _FailingOnceOnboardingRepository implements OnboardingRepository {
  _FailingOnceOnboardingRepository(this.error);

  final Object error;
  int calls = 0;

  @override
  Future<String?> saveOnboarding(String uid, OnboardingState state) async {
    calls++;
    if (calls == 1) throw error;
    return null;
  }
}

class _SlowOnboardingRepository implements OnboardingRepository {
  final release = Completer<void>();
  int calls = 0;

  @override
  Future<String?> saveOnboarding(String uid, OnboardingState state) async {
    calls++;
    await release.future;
    return null;
  }

}

/// The signed-in user is a partner: her thread belongs to the primary user.
class _PartnerChatRepository extends FakeChatRepository {
  @override
  Future<String> threadIdFor(String uid) async => 'primary-user';
}

class _NeverHomeRepository implements HomeRepository {
  @override
  Future<HomeDashboardData> loadDashboard(String uid) => Completer<HomeDashboardData>().future;
}

class _FlakyHomeRepository implements HomeRepository {
  bool fail = true;
  int calls = 0;

  @override
  Future<HomeDashboardData> loadDashboard(String uid) async {
    calls++;
    if (fail) throw Exception('offline');
    return const HomeDashboardDataFixture().data;
  }
}

class _FlakyThreadChatRepository extends FakeChatRepository {
  bool fail = true;

  @override
  Future<String> threadIdFor(String uid) async {
    if (fail) throw Exception('offline');
    return uid;
  }
}
