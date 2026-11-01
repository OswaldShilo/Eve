import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/sub_chip_row.dart';

class PregnantDueScreen extends ConsumerWidget {
  const PregnantDueScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 38,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _methodItems = [
    OptionListItem('Expected due date', 'Expected due date'),
    OptionListItem('First day of last period', 'First day of last period'),
    OptionListItem("Doctor's estimated week", "Doctor's estimated week"),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Enter your timeline details to calculate key pregnancy milestones.',
      title: 'Pregnancy Timeline',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Calculation method'),
          OptionList(
            items: _methodItems,
            mode: OptionSelectionMode.single,
            selectedValues: state.dueMethod.isEmpty ? const {} : {state.dueMethod},
            onToggle: (v) => notifier.setField('dueMethod', v),
          ),
          const SizedBox(height: 8),
          const Text('Target Date'),
          TextFormField(
            key: const Key('pregnant-due-date-field'),
            decoration: const InputDecoration(hintText: 'YYYY-MM-DD'),
            initialValue: state.dueDate,
            onChanged: (v) => notifier.setField('dueDate', v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('High-risk pregnancy?'),
                    SubChipRow(
                      options: const ['No', 'Yes'],
                      selected: state.highRisk,
                      onSelect: (v) => notifier.setField('highRisk', v),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pregnancy Type'),
                    SubChipRow(
                      options: const ['Single', 'Twins'],
                      selected: state.pregnancyType,
                      onSelect: (v) => notifier.setField('pregnancyType', v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
