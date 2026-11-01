import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

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
      guidanceText:
          'Select which health updates your partner is permitted to view.',
      title: 'Partner Sharing Permissions',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OptionList(
            items: items,
            mode: OptionSelectionMode.multi,
            selectedValues: state.partnerPermissions.toSet(),
            onToggle: (v) => notifier.toggleListField('partnerPermissions', v),
          ),
          const SizedBox(height: 6),
          EveCard(
            color: EveTokens.of(context).soft,
            radius: 20,
            shadow: 5,
            onTap: () => notifier.setField(
              'onlyApproveMaster',
              !state.onlyApproveMaster,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Only what I approve',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Requires manual approval before sharing updates',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                EveToggle(
                  key: const Key('only-approve-toggle'),
                  value: state.onlyApproveMaster,
                  semanticLabel: 'Only what I approve',
                  onChanged: (v) => notifier.setField('onlyApproveMaster', v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
