import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/completion_screen.dart';

void main() {
  testWidgets('CompletionScreen renders celebratory copy and Enter EVE invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      home: CompletionScreen(onContinue: () => pressed = true),
    ));

    expect(find.text('Your EVE profile setup is complete.'), findsOneWidget);
    expect(find.text('All Set!'), findsOneWidget);
    expect(find.text('Tailored specifically for your health journey'), findsOneWidget);
    expect(find.text('Enter EVE'), findsOneWidget);

    await tester.tap(find.byKey(const Key('completion-enter-eve-button')));
    expect(pressed, isTrue);
  });

  testWidgets('CompletionScreen busy shows a spinner and ignores taps', (tester) async {
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      home: CompletionScreen(onContinue: () => pressed = true, busy: true),
    ));

    expect(find.byKey(const Key('eve-button-busy')), findsOneWidget);
    await tester.tap(find.byKey(const Key('completion-enter-eve-button')));
    expect(pressed, isFalse);
  });
}
