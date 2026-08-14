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

  test('appRouter declares every screen ID from design-spec §5 and §7', () {
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

  testWidgets('navigating to /onboarding/lifestage renders that placeholder',
      (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
    await tester.pumpAndSettle();

    appRouter.go('/onboarding/lifestage');
    await tester.pumpAndSettle();

    expect(find.text('onboarding-lifestage'), findsOneWidget);
  });
}
