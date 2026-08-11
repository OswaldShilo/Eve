import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/eve_theme.dart';

/// The MaterialApp/router root. Screens are supplied by the route table
/// in `core/router/app_router.dart`; Plan 1 replaces the placeholder
/// screens currently wired there with the real onboarding/Home/Chat/Log
/// widgets.
class EveApp extends ConsumerWidget {
  const EveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'EVE',
      debugShowCheckedModeBanner: false,
      theme: EveTheme.defaultTheme(),
      darkTheme: EveTheme.dark(),
      routerConfig: appRouter,
    );
  }
}
