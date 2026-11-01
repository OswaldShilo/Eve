import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class PregnantSymptomsScreen extends ConsumerWidget {
  const PregnantSymptomsScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 54,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('Morning sickness', 'Morning sickness'),
    OptionListItem('Swelling', 'Swelling'),
    OptionListItem('Back pain', 'Back pain'),
    OptionListItem('Heartburn', 'Heartburn'),
    OptionListItem('Headache', 'Headache'),
    OptionListItem('None', 'None'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.caring,
      guidanceText: 'Select any pregnancy symptoms you are currently experiencing.',
      title: 'Pregnancy Symptoms',
      subtitle: 'Select symptoms you are currently experiencing.',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.multi,
        selectedValues: state.pregnantSymptoms.toSet(),
        onToggle: (v) => notifier.toggleListField('pregnantSymptoms', v),
      ),
    );
  }
}
