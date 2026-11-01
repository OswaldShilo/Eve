import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class PartnerAskScreen extends ConsumerWidget {
  const PartnerAskScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 92,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('Yes, invite my partner', 'true'),
    OptionListItem('No, keep EVE private', 'false'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Decide whether to invite a partner to share updates and schedule reminders.',
      title: 'Would you like to invite your partner?',
      subtitle: 'Partner mode enables shared updates and schedule reminders.',
      primaryLabel: 'Continue',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.single,
        selectedValues: {state.partnerInvite.toString()},
        onToggle: (v) => notifier.setField('partnerInvite', v == 'true'),
      ),
    );
  }
}
