import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/pregnant_symptoms_screen.dart';

void main() {
  testWidgets('PregnantSymptomsScreen renders all six symptom options and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: PregnantSymptomsScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Pregnancy Symptoms'), findsOneWidget);
    for (final label in const [
      'Morning sickness', 'Swelling', 'Back pain', 'Heartburn', 'Headache', 'None',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
