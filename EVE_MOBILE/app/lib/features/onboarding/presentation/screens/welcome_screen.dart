import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/brand_bookend.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onContinue,
    this.onJoinPartner,
  });

  final VoidCallback onContinue;

  /// "Joining a partner?" link shown under Begin Setup when set.
  final VoidCallback? onJoinPartner;

  @override
  Widget build(BuildContext context) {
    return BrandBookend(
      speech:
          'Welcome to EVE. Let us personalize your health and cycle tracking experience.',
      emotion: EveEmotion.neutral,
      title: 'EVE',
      subtitle: 'Cycle & Wellness Companion',
      button: EveButton(
        key: const Key('welcome-begin-setup-button'),
        label: 'Begin Setup',
        onPressed: onContinue,
      ),
      footer: onJoinPartner == null
          ? null
          : TextButton(
              key: const Key('welcome-partner-join'),
              onPressed: onJoinPartner,
              child: const Text('Joining a partner? Enter an invite code'),
            ),
    );
  }
}
