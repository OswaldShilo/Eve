import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.progressPercent = 23,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final double progressPercent;

  static const _countries = [
    'India',
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText:
          'Enter your basic profile details so EVE can personalize your tracking.',
      title: 'About You',
      subtitle:
          'Providing basic details helps EVE tailor your health predictions.',
      primaryLabel: 'Next Step',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EveTextField(
            label: 'Name',
            fieldKey: const Key('profile-name-field'),
            initialValue: state.name,
            textInputAction: TextInputAction.next,
            onChanged: (v) => notifier.setField('name', v),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: EveTextField(
                  label: 'Age',
                  fieldKey: const Key('profile-age-field'),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  initialValue: state.age,
                  onChanged: (v) => notifier.setField('age', v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EveTextField(
                  label: 'Height (cm)',
                  fieldKey: const Key('profile-height-field'),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  initialValue: state.height,
                  onChanged: (v) => notifier.setField('height', v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: EveTextField(
                  label: 'Weight (kg)',
                  fieldKey: const Key('profile-weight-field'),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  initialValue: state.weight,
                  onChanged: (v) => notifier.setField('weight', v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EveSelectField<String>(
                  label: 'Country',
                  fieldKey: const Key('profile-country-field'),
                  value: state.country.isEmpty ? null : state.country,
                  items: _countries,
                  itemLabel: (c) => c,
                  onChanged: (v) => notifier.setField('country', v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
