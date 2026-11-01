import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

class FoodScreen extends ConsumerWidget {
  const FoodScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 62,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _cuisines = [
    OptionListItem('Italian', 'Italian'),
    OptionListItem('Indian', 'Indian'),
    OptionListItem('Asian', 'Asian'),
    OptionListItem('Mediterranean', 'Mediterranean'),
    OptionListItem('Mexican', 'Mexican'),
    OptionListItem('American', 'American'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Indicate your dietary preferences and any food allergies.',
      title: 'Food Preferences',
      primaryLabel: 'Next',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EveTextField(
            label: 'Food Allergies / Dietary Restrictions',
            fieldKey: const Key('food-allergies-field'),
            hintText: 'e.g. Peanuts, Gluten, Dairy',
            initialValue: state.foodAllergies,
            onChanged: (v) => notifier.setField('foodAllergies', v),
          ),
          const SizedBox(height: 20),
          const EveFormLabel('Preferred Cuisines'),
          OptionList(
            items: _cuisines,
            mode: OptionSelectionMode.multi,
            selectedValues: state.cuisines.toSet(),
            onToggle: (v) => notifier.toggleListField('cuisines', v),
          ),
        ],
      ),
    );
  }
}
