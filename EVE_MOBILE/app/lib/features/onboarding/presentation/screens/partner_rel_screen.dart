import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_validation.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class PartnerRelScreen extends ConsumerWidget {
  const PartnerRelScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 92,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('Husband', 'Husband'),
    OptionListItem('Boyfriend', 'Boyfriend'),
    OptionListItem('Partner', 'Partner'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: "Specify your partner's relationship for tailored communications.",
      title: 'Relationship',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      primaryEnabled: canContinueFrom('partner-rel', state),
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.single,
        selectedValues: state.partnerRelation.isEmpty ? const {} : {state.partnerRelation},
        onToggle: (v) => notifier.setField('partnerRelation', v),
      ),
    );
  }
}
