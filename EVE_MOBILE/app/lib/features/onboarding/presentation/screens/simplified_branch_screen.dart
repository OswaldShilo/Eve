import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class _StageContent {
  const _StageContent(this.title, this.symptoms, this.goals);
  final String title;
  final List<String> symptoms;
  final List<String> goals;
}

const _stageContentByLifeStage = {
  'conceive': _StageContent(
    'Trying to Conceive Details',
    ['Ovulation tracking', 'Basal body temperature', 'Cervical mucus tracking', 'Light spotting'],
    ['Identify fertile window', 'Cycle regularity insights', 'Preconception health'],
  ),
  'postpartum': _StageContent(
    'Postpartum Care Details',
    ['Postpartum fatigue', 'Mood changes', 'Night sweats', 'Hormonal hair changes'],
    ['Recovery tracking', 'Nursing & rest logging', 'Mental wellness support'],
  ),
  'menopause': _StageContent(
    'Menopause & Perimenopause Details',
    ['Hot flashes', 'Night sweats', 'Sleep disruption', 'Mood fluctuations', 'Brain fog'],
    ['Symptom intensity logging', 'Bone & cardiovascular health', 'Sleep quality management'],
  ),
};

class SimplifiedBranchScreen extends ConsumerWidget {
  const SimplifiedBranchScreen({
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
    final content = _stageContentByLifeStage[state.lifeStage] ??
        const _StageContent('Stage Details', [], []);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.caring,
      guidanceText: 'Select your primary symptoms and focus areas for this stage.',
      title: content.title,
      subtitle: 'Select your symptoms and goals for this stage.',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Symptoms & Focus'),
          OptionList(
            items: content.symptoms.map((s) => OptionListItem(s, s)).toList(),
            mode: OptionSelectionMode.multi,
            selectedValues: state.simplifiedSymptoms.toSet(),
            onToggle: (v) => notifier.toggleListField('simplifiedSymptoms', v),
          ),
          const SizedBox(height: 10),
          const Text('Goals'),
          OptionList(
            items: content.goals.map((g) => OptionListItem(g, g)).toList(),
            mode: OptionSelectionMode.multi,
            selectedValues: state.simplifiedGoals.toSet(),
            onToggle: (v) => notifier.toggleListField('simplifiedGoals', v),
          ),
        ],
      ),
    );
  }
}
