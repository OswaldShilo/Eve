import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class AiScopeScreen extends ConsumerWidget {
  const AiScopeScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 85,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('All topics', 'Everything'),
    OptionListItem('Answer health questions', 'Answer health questions'),
    OptionListItem('Nutrition guidance', 'Nutrition'),
    OptionListItem('Workout guidance', 'Workout'),
    OptionListItem('Mental wellbeing support', 'Mental wellbeing'),
    OptionListItem('Medication reminders', 'Medication reminders'),
    OptionListItem('Doctor visit preparation', 'Doctor prep'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Select the key areas where you would like assistance from EVE.',
      title: 'What would you like EVE to help with?',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.multi,
        selectedValues: state.aiScope.toSet(),
        onToggle: (v) => notifier.toggleListField('aiScope', v),
      ),
    );
  }
}
