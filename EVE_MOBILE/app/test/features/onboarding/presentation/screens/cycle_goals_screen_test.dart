import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/cycle_goals_screen.dart';

void main() {
  testWidgets('CycleGoalsScreen renders goals and reveals diet sub-choice on nutrition tap', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: CycleGoalsScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Your Primary Goals'), findsOneWidget);
    expect(find.text('Predict my next period'), findsOneWidget);
    expect(find.text('Understand body trends'), findsOneWidget);
    expect(find.text('Improve fitness'), findsOneWidget);
    expect(find.text('Improve nutrition'), findsOneWidget);
    expect(find.text('Improve mental wellbeing'), findsOneWidget);
    expect(find.text('Vegetarian'), findsNothing);

    await tester.tap(find.byKey(const Key('option-Improve nutrition')));
    await tester.pump();
    expect(find.text('Vegetarian'), findsOneWidget);
    expect(find.text('Non-vegetarian'), findsOneWidget);
    expect(find.text('Vegan'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
