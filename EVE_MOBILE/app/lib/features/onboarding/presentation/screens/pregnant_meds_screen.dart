import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/sub_chip_row.dart';

class PregnantMedsScreen extends ConsumerWidget {
  const PregnantMedsScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 46,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.caring,
      guidanceText: 'Record your current medications and care routines for personalized safety.',
      title: 'Medication & Care',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Current Medications'),
          TextFormField(
            key: const Key('pregnant-meds-medications-field'),
            decoration: const InputDecoration(hintText: 'e.g. Levothyroxine'),
            initialValue: state.medications,
            onChanged: (v) => notifier.setField('medications', v),
          ),
          const SizedBox(height: 10),
          const Text('Allergies'),
          TextFormField(
            key: const Key('pregnant-meds-allergies-field'),
            decoration: const InputDecoration(hintText: 'e.g. Penicillin, Latex'),
            initialValue: state.allergies,
            onChanged: (v) => notifier.setField('allergies', v),
          ),
          const SizedBox(height: 10),
          const Text('Taking Prenatal Vitamins?'),
          SubChipRow(
            options: const ['Yes', 'No'],
            selected: state.prenatalVitamins,
            onSelect: (v) => notifier.setField('prenatalVitamins', v),
          ),
        ],
      ),
    );
  }
}
