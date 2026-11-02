import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_progress.dart';

void main() {
  test('onboardingProgressPercent matches the mock formula, clamped between 10 and 100', () {
    // total = 13 (the default cycle-branch sequence length from Task 25)
    expect(onboardingProgressPercent(currentIndex: 0, totalScreens: 13), 10.0); // round(1/13*100)=8, clamped to 10
    expect(onboardingProgressPercent(currentIndex: 3, totalScreens: 13), 31.0); // round(4/13*100)=31
    expect(onboardingProgressPercent(currentIndex: 4, totalScreens: 13), 38.0); // round(5/13*100)=38
    expect(onboardingProgressPercent(currentIndex: 8, totalScreens: 13), 69.0); // round(9/13*100)=69
    expect(onboardingProgressPercent(currentIndex: 9, totalScreens: 13), 77.0); // round(10/13*100)=77
    expect(onboardingProgressPercent(currentIndex: 12, totalScreens: 13), 100.0); // last screen
  });

  test('onboardingProgressPercent never exceeds 100 even if currentIndex overshoots', () {
    expect(onboardingProgressPercent(currentIndex: 20, totalScreens: 13), 100.0);
  });
}
