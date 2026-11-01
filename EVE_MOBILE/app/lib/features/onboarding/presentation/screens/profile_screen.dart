import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';

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

  static const _countries = ['India', 'United States', 'United Kingdom', 'Canada', 'Australia'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingStateProvider);
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText: 'Enter your basic profile details so EVE can personalize your tracking.',
      title: 'About You',
      subtitle: 'Providing basic details helps EVE tailor your health predictions.',
      primaryLabel: 'Next Step',
      onPrimaryPressed: onContinue,
      onBack: onBack,
      child: Column(
        children: [
          TextFormField(
            key: const Key('profile-name-field'),
            decoration: const InputDecoration(labelText: 'Name'),
            initialValue: state.name,
            onChanged: (v) => notifier.setField('name', v),
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('profile-age-field'),
                  decoration: const InputDecoration(labelText: 'Age'),
                  keyboardType: TextInputType.number,
                  initialValue: state.age,
                  onChanged: (v) => notifier.setField('age', v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const Key('profile-height-field'),
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                  keyboardType: TextInputType.number,
                  initialValue: state.height,
                  onChanged: (v) => notifier.setField('height', v),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('profile-weight-field'),
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  keyboardType: TextInputType.number,
                  initialValue: state.weight,
                  onChanged: (v) => notifier.setField('weight', v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const Key('profile-country-field'),
                  decoration: const InputDecoration(labelText: 'Country'),
                  initialValue: state.country.isEmpty ? null : state.country,
                  items: _countries
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) notifier.setField('country', v);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
