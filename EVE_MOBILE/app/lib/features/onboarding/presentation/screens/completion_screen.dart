import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/brand_bookend.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

class CompletionScreen extends StatelessWidget {
  const CompletionScreen({
    super.key,
    required this.onContinue,
    this.busy = false,
  });

  final VoidCallback onContinue;

  /// Her answers are being saved: spinner on the button, taps ignored.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return BrandBookend(
      speech: 'Your EVE profile setup is complete.',
      emotion: EveEmotion.hype,
      title: 'All Set!',
      subtitle: 'Tailored specifically for your health journey',
      button: EveButton(
        key: const Key('completion-enter-eve-button'),
        label: 'Enter EVE',
        busy: busy,
        onPressed: onContinue,
      ),
    );
  }
}
