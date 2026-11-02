import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class CycleSymptomsScreen extends ConsumerWidget {
  const CycleSymptomsScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 46,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('Cramps', 'Cramps'),
    OptionListItem('Acne', 'Acne'),
    OptionListItem('Headache', 'Headache'),
    OptionListItem('Breast tenderness', 'Breast tenderness'),
    OptionListItem('Bloating', 'Bloating'),
    OptionListItem('Mood swings', 'Mood swings'),
    OptionListItem('Back pain', 'Back pain'),
    OptionListItem('Fatigue', 'Fatigue'),
    OptionListItem('Food cravings', 'Food cravings'),
    OptionListItem('Nausea', 'Nausea'),
    OptionListItem('None', 'None'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.caring,
      guidanceText: 'Select any symptoms you regularly experience during your cycle.',
      title: 'Frequent Symptoms',
      subtitle: 'Select any symptoms you usually experience.',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.multi,
        selectedValues: state.cycleSymptoms.toSet(),
        onToggle: (v) => notifier.toggleListField('cycleSymptoms', v),
      ),
    );
  }
}
