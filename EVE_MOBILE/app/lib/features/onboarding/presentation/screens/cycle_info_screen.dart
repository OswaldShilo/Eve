import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/sub_chip_row.dart';

class CycleInfoScreen extends ConsumerWidget {
  const CycleInfoScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 38,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _cycleLengthItems = [
    OptionListItem('25–28 days', '25–28'),
    OptionListItem('21–24 days', '21–24'),
    OptionListItem('29–35 days', '29–35'),
    OptionListItem('Irregular', 'Irregular'),
    OptionListItem('Unsure', 'Unsure'),
  ];

  static const _periodLengths = ['3', '4', '5', '6', '7+', 'Not sure'];
  static const _periodLengthLabels = {
    '3': '3 days', '4': '4 days', '5': '5 days', '6': '6 days',
    '7+': '7+ days', 'Not sure': 'Not sure',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Provide your typical cycle length and flow details.',
      title: 'Cycle Details',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Average cycle length'),
          OptionList(
            items: _cycleLengthItems,
            mode: OptionSelectionMode.single,
            selectedValues: state.cycleLength.isEmpty ? const {} : {state.cycleLength},
            onToggle: (v) => notifier.setField('cycleLength', v),
          ),
          const SizedBox(height: 10),
          const Text('Average period length'),
          DropdownButtonFormField<String>(
            key: const Key('cycle-info-period-length-field'),
            initialValue: state.periodLength.isEmpty ? null : state.periodLength,
            items: _periodLengths
                .map((p) => DropdownMenuItem(value: p, child: Text(_periodLengthLabels[p]!)))
                .toList(),
            onChanged: (v) {
              if (v != null) notifier.setField('periodLength', v);
            },
          ),
          const SizedBox(height: 10),
          const Text('Flow intensity'),
          SubChipRow(
            options: const ['Light', 'Moderate', 'Heavy'],
            selected: state.flow,
            onSelect: (v) => notifier.setField('flow', v),
          ),
        ],
      ),
    );
  }
}
