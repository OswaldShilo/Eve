import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/pregnant_due_screen.dart';

void main() {
  testWidgets('PregnantDueScreen renders timeline fields and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: PregnantDueScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Pregnancy Timeline'), findsOneWidget);
    expect(find.text('Expected due date'), findsOneWidget);
    expect(find.text('First day of last period'), findsOneWidget);
    expect(find.text("Doctor's estimated week"), findsOneWidget);
    expect(find.byKey(const Key('pregnant-due-date-field')), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('Single'), findsOneWidget);
    expect(find.text('Twins'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
