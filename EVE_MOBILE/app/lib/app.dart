import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/appwrite_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/eve_theme.dart';
import 'features/onboarding/domain/onboarding_state.dart';

/// The MaterialApp/router root. Screens are supplied by the route table
/// in `core/router/app_router.dart`; Plan 1 replaces the placeholder
/// screens currently wired there with the real onboarding/Home/Chat/Log
/// widgets.
class EveApp extends ConsumerWidget {
  const EveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushLifecycleProvider);
    // The Theme screen's choice applies immediately; before she chooses, the
    // product default is Ruby Blush regardless of the phone's dark mode.
    final themeChoice =
        ref.watch(onboardingStateProvider.select((s) => s.theme));

    return MaterialApp.router(
      title: 'EVE',
      debugShowCheckedModeBanner: false,
      theme: EveTheme.forChoice(themeChoice),
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
