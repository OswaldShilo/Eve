import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('onboardingStateProvider', () {
    test('starts with an empty OnboardingState', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(onboardingStateProvider);

      expect(state.name, '');
      expect(state.lifeStage, isNull);
      expect(state.cycleSymptoms, isEmpty);
    });

    test('setField writes a scalar field and exposes it via the provider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(onboardingStateProvider.notifier)
          .setField('lifeStage', 'pregnant');

      expect(
        container.read(onboardingStateProvider).lifeStage,
        'pregnant',
      );
    });

    test('setField merges new values without clobbering unrelated ones', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(onboardingStateProvider.notifier);
      notifier.setField('name', 'Asha');
      notifier.setField('age', '29');
      notifier.setField('country', 'India');

      final state = container.read(onboardingStateProvider);
      expect(state.name, 'Asha');
      expect(state.age, '29');
      expect(state.country, 'India');
    });

    test('setField writes bool fields', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(onboardingStateProvider.notifier);
      notifier.setField('partnerInvite', true);
      notifier.setField('onlyApproveMaster', true);

      final state = container.read(onboardingStateProvider);
      expect(state.partnerInvite, isTrue);
      expect(state.onlyApproveMaster, isTrue);
    });

    test('setField throws ArgumentError for an unknown field', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container
            .read(onboardingStateProvider.notifier)
            .setField('lifeStag', 'cycle'),
        throwsArgumentError,
      );
    });

    test(
        'toggleListField adds a value on first toggle and removes it on '
        'second toggle', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(onboardingStateProvider.notifier);
      notifier.toggleListField('cycleSymptoms', 'cramps');
      notifier.toggleListField('cycleSymptoms', 'bloating');

      expect(
        container.read(onboardingStateProvider).cycleSymptoms,
        ['cramps', 'bloating'],
      );

      notifier.toggleListField('cycleSymptoms', 'cramps');

      expect(
        container.read(onboardingStateProvider).cycleSymptoms,
        ['bloating'],
      );
    });

    test('toggleListField throws ArgumentError for an unknown list field', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container
            .read(onboardingStateProvider.notifier)
            .toggleListField('cycleSymptom', 'cramps'),
        throwsArgumentError,
      );
    });

    test('reset restores the initial empty state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(onboardingStateProvider.notifier);
      notifier.setField('name', 'Asha');
      notifier.reset();

      expect(container.read(onboardingStateProvider).name, '');
    });
  });
}
