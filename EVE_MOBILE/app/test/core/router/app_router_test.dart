import 'package:eve_app/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
}
