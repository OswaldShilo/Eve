import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/welcome_screen.dart';

void main() {
  testWidgets('WelcomeScreen renders brand copy and invokes onContinue on Begin Setup tap', (tester) async {
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      home: WelcomeScreen(onContinue: () => pressed = true),
    ));

    expect(find.text('Welcome to EVE. Let us personalize your health and cycle tracking experience.'), findsOneWidget);
    expect(find.text('EVE'), findsOneWidget);
    expect(find.text('Cycle & Wellness Companion'), findsOneWidget);
    expect(find.text('Begin Setup'), findsOneWidget);

    await tester.tap(find.byKey(const Key('welcome-begin-setup-button')));
    expect(pressed, isTrue);
  });
}
