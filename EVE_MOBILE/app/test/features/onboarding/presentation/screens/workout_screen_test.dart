import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/workout_screen.dart';

void main() {
  testWidgets('WorkoutScreen renders all six activity options and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: WorkoutScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Workout Preferences'), findsOneWidget);
    for (final label in const ['Walking', 'Yoga', 'Gym', 'Home workout', 'Dance', 'Pilates']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
