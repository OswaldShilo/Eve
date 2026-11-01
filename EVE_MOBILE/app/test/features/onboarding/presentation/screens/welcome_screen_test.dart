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

  testWidgets('the partner-join link sits below Begin Setup without overlapping it', (tester) async {
    var begin = 0;
    var join = 0;
    await tester.pumpWidget(MaterialApp(
      home: WelcomeScreen(onContinue: () => begin++, onJoinPartner: () => join++),
    ));

    final button = tester.getRect(find.byKey(const Key('welcome-begin-setup-button')));
    final link = tester.getRect(find.byKey(const Key('welcome-partner-join')));
    expect(link.top, greaterThanOrEqualTo(button.bottom));

    await tester.tap(find.byKey(const Key('welcome-begin-setup-button')));
    await tester.tap(find.byKey(const Key('welcome-partner-join')));
    expect(begin, 1);
    expect(join, 1);
  });

  testWidgets('no partner-join link without a handler', (tester) async {
    await tester.pumpWidget(MaterialApp(home: WelcomeScreen(onContinue: () {})));
    expect(find.byKey(const Key('welcome-partner-join')), findsNothing);
  });
}
