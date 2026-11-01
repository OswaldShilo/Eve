import 'package:flutter/material.dart';
import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

/// The shared survey-screen frame from mockv4: `.survey-header` (back button
/// + outlined progress bar), `.mascot-guidance-card` (mini mascot box +
/// guidance line), a scrolling `.onboarding-screen-content` area, and the
/// `.btn-primary` pinned at the bottom.
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
    this.primaryBusy = false,
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

  /// Shows a spinner on the primary button and ignores taps while true.
  final bool primaryBusy;

  @override
  Widget build(BuildContext context) {
    final tokens = EveTokens.of(context);
    final text = Theme.of(context).textTheme;
    // On small phones the soft keyboard leaves too little room for the
    // guidance card, the form and the pinned button together; tuck the
    // card away while typing so the focused field stays visible.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  EveBackButton(
                    key: const Key('onboarding-back-button'),
                    onPressed: onBack,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      // Centre the bar on the button face (the button
                      // reserves 4px below itself for its shadow).
                      padding: const EdgeInsets.only(bottom: 4),
                      child: EveProgressBar(
                        key: const Key('onboarding-progress-bar'),
                        percent: progressPercent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!keyboardOpen)
                EveCard(
                  color: tokens.soft,
                  radius: 20,
                  shadow: 4,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: eveOutlined(
                          color: tokens.soft,
                          radius: 18,
                          shadow: 4,
                        ),
                        alignment: Alignment.center,
                        child: EveMascot(
                          emotion: emotion,
                          peelPercent: progressPercent,
                          size: 44,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          guidanceText,
                          key: const Key('onboarding-guidance-text'),
                          style: text.titleSmall!.copyWith(color: tokens.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        key: const Key('onboarding-title'),
                        style: text.headlineMedium,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle!,
                          key: const Key('onboarding-subtitle'),
                          style: text.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 14),
                      child,
                    ],
                  ),
                ),
              ),
              EveButton(
                key: const Key('onboarding-primary-button'),
                label: primaryLabel,
                busy: primaryBusy,
                onPressed: primaryEnabled ? onPrimaryPressed : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
