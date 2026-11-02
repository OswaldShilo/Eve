import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/theme_screen.dart';

void main() {
  testWidgets('ThemeScreen renders all three theme options and Finish Setup invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: ThemeScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Choose Theme'), findsOneWidget);
    expect(find.text('Default (Ruby Blush)'), findsOneWidget);
    expect(find.text('Light Theme'), findsOneWidget);
    expect(find.text('Dark Theme'), findsOneWidget);
    expect(find.text('Finish Setup'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
