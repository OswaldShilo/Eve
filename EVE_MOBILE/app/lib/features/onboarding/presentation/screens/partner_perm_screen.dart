import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class PartnerPermScreen extends ConsumerWidget {
  const PartnerPermScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 96,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    final items = [
      const OptionListItem('Appointment reminders', 'Appointment reminders'),
      if (state.lifeStage == 'pregnant')
        const OptionListItem('Pregnancy milestones', 'Pregnancy milestones'),
      const OptionListItem('Support suggestions', 'Support suggestions'),
      const OptionListItem('Mood updates', 'Mood updates'),
    ];

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.caring,
      guidanceText: 'Select which health updates your partner is permitted to view.',
      title: 'Partner Sharing Permissions',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OptionList(
            items: items,
            mode: OptionSelectionMode.multi,
            selectedValues: state.partnerPermissions.toSet(),
            onToggle: (v) => notifier.toggleListField('partnerPermissions', v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Only what I approve', style: TextStyle(fontWeight: FontWeight.w800)),
                    Text('Requires manual approval before sharing updates'),
                  ],
                ),
              ),
              Switch(
                key: const Key('only-approve-toggle'),
                value: state.onlyApproveMaster,
                onChanged: (v) => notifier.setField('onlyApproveMaster', v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
