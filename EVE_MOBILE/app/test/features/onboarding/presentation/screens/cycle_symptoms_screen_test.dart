import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/cycle_symptoms_screen.dart';

void main() {
  testWidgets('CycleSymptomsScreen renders all 11 symptom options and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: CycleSymptomsScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Frequent Symptoms'), findsOneWidget);
    for (final label in const [
      'Cramps', 'Acne', 'Headache', 'Breast tenderness', 'Bloating', 'Mood swings',
      'Back pain', 'Fatigue', 'Food cravings', 'Nausea', 'None',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
