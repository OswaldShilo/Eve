import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Temporary placeholder for every route this app declares. Plan 1
/// (`plans/01-core-workflow.md`) replaces each of these `builder:`
/// callbacks with the real screen widget for that route.
class RouteLabelScreen extends StatelessWidget {
  const RouteLabelScreen({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(label, key: const Key('routeLabel')),
      ),
    );
  }
}

GoRoute _placeholderRoute(String path, String name) {
  return GoRoute(
    path: path,
    name: name,
    builder: (context, state) => RouteLabelScreen(label: name),
  );
}

/// The app-wide route table. Every screen ID from
/// plans/00-design-spec.md §5 (the onboarding sequence) and §7
/// (Home/Chat/Log) has a named route here.
/// `/onboarding/simplified-branch` is intentionally a single shared route
/// for the conceive/postpartum/perimenopause branches; the screen reads
/// `lifeStage` off `onboardingStateProvider` to vary its copy.
final GoRouter appRouter = GoRouter(
  initialLocation: '/onboarding/welcome',
  routes: [
    _placeholderRoute('/onboarding/welcome', 'onboarding-welcome'),
    _placeholderRoute('/onboarding/auth', 'onboarding-auth'),
    _placeholderRoute('/onboarding/profile', 'onboarding-profile'),
    _placeholderRoute('/onboarding/lifestage', 'onboarding-lifestage'),
    _placeholderRoute('/onboarding/cycle-info', 'onboarding-cycle-info'),
    _placeholderRoute(
      '/onboarding/cycle-symptoms',
      'onboarding-cycle-symptoms',
    ),
    _placeholderRoute('/onboarding/cycle-goals', 'onboarding-cycle-goals'),
    _placeholderRoute('/onboarding/pregnant-due', 'onboarding-pregnant-due'),
    _placeholderRoute(
      '/onboarding/pregnant-meds',
      'onboarding-pregnant-meds',
    ),
    _placeholderRoute(
      '/onboarding/pregnant-symptoms',
      'onboarding-pregnant-symptoms',
    ),
    _placeholderRoute(
      '/onboarding/simplified-branch',
      'onboarding-simplified-branch',
    ),
    _placeholderRoute('/onboarding/food', 'onboarding-food'),
    _placeholderRoute('/onboarding/workout', 'onboarding-workout'),
    _placeholderRoute(
      '/onboarding/notifications',
      'onboarding-notifications',
    ),
    _placeholderRoute('/onboarding/ai-scope', 'onboarding-ai-scope'),
    _placeholderRoute('/onboarding/partner-ask', 'onboarding-partner-ask'),
    _placeholderRoute('/onboarding/partner-rel', 'onboarding-partner-rel'),
    _placeholderRoute('/onboarding/partner-perm', 'onboarding-partner-perm'),
    _placeholderRoute('/onboarding/theme', 'onboarding-theme'),
    _placeholderRoute('/onboarding/completion', 'onboarding-completion'),
    _placeholderRoute('/home', 'home'),
    _placeholderRoute('/chat', 'chat'),
    _placeholderRoute('/log', 'log'),
  ],
);
