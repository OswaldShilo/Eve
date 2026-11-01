import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 10,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Sign in to securely back up your health data, or continue as a guest.',
      title: 'Welcome to EVE',
      subtitle: 'Sign in to back up your health insights securely.',
      primaryLabel: 'Continue as Guest',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Center(
        child: OutlinedButton.icon(
          key: const Key('auth-google-button'),
          onPressed: onContinue,
          icon: const Icon(Icons.g_mobiledata),
          label: const Text('Sign in with Google'),
        ),
      ),
    );
  }
}
