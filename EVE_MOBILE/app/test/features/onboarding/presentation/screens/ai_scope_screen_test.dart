import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/ai_scope_screen.dart';

void main() {
  testWidgets('AiScopeScreen renders all seven options and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: AiScopeScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('What would you like EVE to help with?'), findsOneWidget);
    for (final label in const [
      'All topics', 'Answer health questions', 'Nutrition guidance', 'Workout guidance',
      'Mental wellbeing support', 'Medication reminders', 'Doctor visit preparation',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
