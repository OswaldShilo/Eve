import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
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

  testWidgets('Target Date opens a date picker and stores YYYY-MM-DD', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: PregnantDueScreen(onContinue: () {}, onBack: () {}),
      ),
    ));

    expect(find.text('Select a date'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pregnant-due-date-field')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final stored = container.read(onboardingStateProvider).dueDate;
    expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(stored), isTrue, reason: stored);
    expect(find.text('Select a date'), findsNothing);
  });
}
