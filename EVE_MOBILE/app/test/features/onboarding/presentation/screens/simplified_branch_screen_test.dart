import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/screens/simplified_branch_screen.dart';

void main() {
  testWidgets('SimplifiedBranchScreen renders conceive title/options and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        onboardingStateProvider.overrideWith((ref) => OnboardingNotifier()..setField('lifeStage', 'conceive')),
      ],
      child: MaterialApp(
        home: SimplifiedBranchScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Trying to Conceive Details'), findsOneWidget);
    expect(find.text('Ovulation tracking'), findsOneWidget);
    expect(find.text('Basal body temperature'), findsOneWidget);
    expect(find.text('Cervical mucus tracking'), findsOneWidget);
    expect(find.text('Light spotting'), findsOneWidget);
    expect(find.text('Identify fertile window'), findsOneWidget);
    expect(find.text('Cycle regularity insights'), findsOneWidget);
    expect(find.text('Preconception health'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });

  testWidgets('SimplifiedBranchScreen renders menopause title/options when lifeStage is menopause', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        onboardingStateProvider.overrideWith((ref) => OnboardingNotifier()..setField('lifeStage', 'menopause')),
      ],
      child: MaterialApp(
        home: SimplifiedBranchScreen(onContinue: () {}, onBack: () {}),
      ),
    ));

    expect(find.text('Menopause & Perimenopause Details'), findsOneWidget);
    expect(find.text('Hot flashes'), findsOneWidget);
    expect(find.text('Brain fog'), findsOneWidget);
    expect(find.text('Bone & cardiovascular health'), findsOneWidget);
  });
}
