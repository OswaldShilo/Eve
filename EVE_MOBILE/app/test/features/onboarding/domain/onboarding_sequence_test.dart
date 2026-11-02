import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_sequence.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';

void main() {
  test('onboardingSequence builds the cycle branch with no partner invite', () {
    const state = OnboardingState(lifeStage: 'cycle', partnerInvite: false);
    expect(onboardingSequence(state), [
      'auth', 'profile', 'lifestage',
      'cycle-info', 'cycle-symptoms', 'cycle-goals',
      'food', 'workout', 'notifications', 'ai-scope', 'partner-ask',
      'theme', 'completion',
    ]);
  });

  test('onboardingSequence builds the pregnant branch with partner invite screens included', () {
    const state = OnboardingState(lifeStage: 'pregnant', partnerInvite: true);
    expect(onboardingSequence(state), [
      'auth', 'profile', 'lifestage',
      'pregnant-due', 'pregnant-meds', 'pregnant-symptoms',
      'food', 'workout', 'notifications', 'ai-scope', 'partner-ask',
      'partner-rel', 'partner-perm',
      'theme', 'completion',
    ]);
  });

  test('onboardingSequence collapses conceive/postpartum/menopause into simplified-branch', () {
    for (final stage in ['conceive', 'postpartum', 'menopause']) {
      final state = OnboardingState(lifeStage: stage);
      expect(onboardingSequence(state).contains('simplified-branch'), isTrue,
          reason: '$stage should route through simplified-branch');
      expect(onboardingSequence(state).contains('cycle-info'), isFalse);
      expect(onboardingSequence(state).contains('pregnant-due'), isFalse);
    }
  });

  test('routeForScreen maps a screen id to its /onboarding/ path', () {
    expect(routeForScreen('cycle-info'), '/onboarding/cycle-info');
    expect(routeForScreen('welcome'), '/onboarding/welcome');
  });
}
