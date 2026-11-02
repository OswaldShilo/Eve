import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canContinueFrom', () {
    test('profile needs a name', () {
      expect(canContinueFrom('profile', const OnboardingState()), isFalse);
      expect(
        canContinueFrom('profile', const OnboardingState(name: '   ')),
        isFalse,
      );
      expect(
        canContinueFrom('profile', const OnboardingState(name: 'Maya')),
        isTrue,
      );
    });

    test('profile numbers are optional but must be numeric when given', () {
      expect(
        canContinueFrom(
          'profile',
          const OnboardingState(
            name: 'Maya',
            age: '28',
            height: '165',
            weight: '60.5',
          ),
        ),
        isTrue,
      );
      expect(
        canContinueFrom(
          'profile',
          const OnboardingState(name: 'Maya', age: 'twenty'),
        ),
        isFalse,
      );
      expect(
        canContinueFrom(
          'profile',
          const OnboardingState(name: 'Maya', weight: '-3'),
        ),
        isFalse,
      );
    });

    test('lifestage needs a selection', () {
      expect(canContinueFrom('lifestage', const OnboardingState()), isFalse);
      expect(
        canContinueFrom('lifestage', const OnboardingState(lifeStage: 'cycle')),
        isTrue,
      );
    });

    test('partner-rel needs a relationship', () {
      expect(canContinueFrom('partner-rel', const OnboardingState()), isFalse);
      expect(
        canContinueFrom(
          'partner-rel',
          const OnboardingState(partnerRelation: 'Husband'),
        ),
        isTrue,
      );
    });

    test('other screens are optional', () {
      for (final id in [
        'food',
        'workout',
        'theme',
        'cycle-info',
        'partner-perm',
      ]) {
        expect(
          canContinueFrom(id, const OnboardingState()),
          isTrue,
          reason: id,
        );
      }
    });
  });
}
