import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_validation.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class LifeStageScreen extends ConsumerWidget {
  const LifeStageScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 30,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('Tracking my cycle', 'cycle'),
    OptionListItem('Trying to conceive', 'conceive'),
    OptionListItem('Currently pregnant', 'pregnant'),
    OptionListItem('Postpartum', 'postpartum'),
    OptionListItem('Perimenopause / Menopause', 'menopause'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Select your current stage to customize your tracking experience.',
      title: 'Which describes your current stage best?',
      subtitle: 'Select your primary stage to customize your experience.',
      primaryLabel: 'Continue',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      primaryEnabled: canContinueFrom('lifestage', state),
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.single,
        selectedValues: state.lifeStage == null ? const {} : {state.lifeStage!},
        onToggle: (v) => notifier.setField('lifeStage', v),
      ),
    );
  }
}
