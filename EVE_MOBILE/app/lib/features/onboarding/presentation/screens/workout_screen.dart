import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 69,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _items = [
    OptionListItem('Walking', 'Walking'),
    OptionListItem('Yoga', 'Yoga'),
    OptionListItem('Gym', 'Gym'),
    OptionListItem('Home workout', 'Home workout'),
    OptionListItem('Dance', 'Dance'),
    OptionListItem('Pilates', 'Pilates'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Select the physical activities you prefer to keep energetic.',
      title: 'Workout Preferences',
      subtitle: 'What activities keep you feeling energetic?',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: OptionList(
        items: _items,
        mode: OptionSelectionMode.multi,
        selectedValues: state.workouts.toSet(),
        onToggle: (v) => notifier.toggleListField('workouts', v),
      ),
    );
  }
}
