import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/lifestage_screen.dart';

void main() {
  testWidgets('LifeStageScreen renders all five options and Continue invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: LifeStageScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Which describes your current stage best?'), findsOneWidget);
    expect(find.text('Tracking my cycle'), findsOneWidget);
    expect(find.text('Trying to conceive'), findsOneWidget);
    expect(find.text('Currently pregnant'), findsOneWidget);
    expect(find.text('Postpartum'), findsOneWidget);
    expect(find.text('Perimenopause / Menopause'), findsOneWidget);

    await tester.tap(find.byKey(const Key('option-pregnant')));
    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
