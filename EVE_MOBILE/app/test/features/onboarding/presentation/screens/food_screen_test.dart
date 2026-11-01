import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/food_screen.dart';

void main() {
  testWidgets('FoodScreen renders allergy field, six cuisines and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: FoodScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Food Preferences'), findsOneWidget);
    expect(find.byKey(const Key('food-allergies-field')), findsOneWidget);
    for (final label in const ['Italian', 'Indian', 'Asian', 'Mediterranean', 'Mexican', 'American']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
