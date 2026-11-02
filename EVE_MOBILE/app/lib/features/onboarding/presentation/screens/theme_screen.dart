import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 100,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('Default (Ruby Blush)', 'Default'),
    OptionListItem('Light Theme', 'Light'),
    OptionListItem('Dark Theme', 'Dark'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.warm,
      guidanceText: 'Select your preferred color scheme for the application interface.',
      title: 'Choose Theme',
      primaryLabel: 'Finish Setup',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.single,
        selectedValues: state.theme.isEmpty ? const {} : {state.theme},
        onToggle: (v) => notifier.setField('theme', v),
      ),
    );
  }
}
