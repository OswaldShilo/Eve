import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/partner_rel_screen.dart';

void main() {
  testWidgets('PartnerRelScreen renders all three relationship options and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: PartnerRelScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Relationship'), findsOneWidget);
    expect(find.text('Husband'), findsOneWidget);
    expect(find.text('Boyfriend'), findsOneWidget);
    expect(find.text('Partner'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
