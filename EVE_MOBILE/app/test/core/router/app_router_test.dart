import 'dart:async';

import 'package:eve_app/core/providers/appwrite_providers.dart';
import 'package:eve_app/core/providers/repository_providers.dart';
import 'package:eve_app/core/router/app_router.dart';
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

  testWidgets('navigating to /home renders the real Home screen', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: appRouter)));
    await _settle(tester);

    appRouter.go('/home');
    await _settle(tester);

    expect(find.text('Welcome back, Maya'), findsOneWidget);
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

  testWidgets('Home shows the signed-in user name from the repository', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWith((ref) => 'u1'),
        homeRepositoryProvider.overrideWithValue(FakeHomeRepository(const HomeDashboardDataFixture().data)),
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
