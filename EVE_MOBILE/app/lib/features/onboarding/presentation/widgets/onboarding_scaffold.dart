import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.progressPercent,
    required this.emotion,
    required this.guidanceText,
    required this.title,
    required this.child,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    required this.onBack,
    this.subtitle,
    this.primaryEnabled = true,
  });

  /// 0-100. Drives both the visual progress bar fill and EveMascot.peelPercent unchanged (see Task 26).
  final double progressPercent;
  final EveEmotion emotion;
  final String guidanceText;
  final String title;
  final String? subtitle;
  final Widget child;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onBack;
  final bool primaryEnabled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('onboarding-back-button'),
                  icon: const Text('‹', style: TextStyle(fontSize: 28)),
                  onPressed: onBack,
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      key: const Key('onboarding-progress-bar'),
                      value: progressPercent / 100,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  EveMascot(emotion: emotion, peelPercent: progressPercent, size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(guidanceText, key: const Key('onboarding-guidance-text')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      key: const Key('onboarding-title'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, key: const Key('onboarding-subtitle')),
                    ],
                    const SizedBox(height: 16),
                    child,
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('onboarding-primary-button'),
                  onPressed: primaryEnabled ? onPrimaryPressed : null,
                  child: Text(primaryLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
