import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/sub_chip_row.dart';

class CycleGoalsScreen extends ConsumerWidget {
  const CycleGoalsScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 54,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _fixedItems = [
    OptionListItem('Predict my next period', 'Predict my next period'),
    OptionListItem('Understand body trends', 'Understand body trends'),
    OptionListItem('Improve fitness', 'Improve fitness'),
  ];
  static const _wellbeingItem =
      OptionListItem('Improve mental wellbeing', 'Improve mental wellbeing');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);
    final nutritionSelected = state.cycleGoals.contains('Improve nutrition');

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Select your primary goals for cycle tracking with EVE.',
      title: 'Your Primary Goals',
      subtitle: 'Select how EVE can assist with your cycle health.',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OptionList(
            items: _fixedItems,
            mode: OptionSelectionMode.multi,
            selectedValues: state.cycleGoals.toSet(),
            onToggle: (v) => notifier.toggleListField('cycleGoals', v),
          ),
          OptionList(
            items: const [OptionListItem('Improve nutrition', 'Improve nutrition')],
            mode: OptionSelectionMode.multi,
            selectedValues: state.cycleGoals.toSet(),
            onToggle: (v) => notifier.toggleListField('cycleGoals', v),
          ),
          if (nutritionSelected) ...[
            const SizedBox(height: 8),
            SubChipRow(
              options: const ['Vegetarian', 'Non-vegetarian', 'Vegan'],
              selected: state.nutritionDiet,
              onSelect: (v) => notifier.setField('nutritionDiet', v),
            ),
            const SizedBox(height: 8),
          ],
          OptionList(
            items: const [_wellbeingItem],
            mode: OptionSelectionMode.multi,
            selectedValues: state.cycleGoals.toSet(),
            onToggle: (v) => notifier.toggleListField('cycleGoals', v),
          ),
        ],
      ),
    );
  }
}
