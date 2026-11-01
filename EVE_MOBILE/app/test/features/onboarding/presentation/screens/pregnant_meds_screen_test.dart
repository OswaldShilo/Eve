import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/pregnant_meds_screen.dart';

void main() {
  testWidgets('PregnantMedsScreen renders medication/allergy fields and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: PregnantMedsScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Medication & Care'), findsOneWidget);
    expect(find.byKey(const Key('pregnant-meds-medications-field')), findsOneWidget);
    expect(find.byKey(const Key('pregnant-meds-allergies-field')), findsOneWidget);
    expect(find.text('Taking Prenatal Vitamins?'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
