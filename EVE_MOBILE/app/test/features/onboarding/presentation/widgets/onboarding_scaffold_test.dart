import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';

void main() {
  testWidgets('OnboardingScaffold renders title, subtitle, guidance text and forwards taps', (tester) async {
    var continuePressed = false;
    var backPressed = false;

    await tester.pumpWidget(MaterialApp(
      home: OnboardingScaffold(
        progressPercent: 42,
        emotion: EveEmotion.caring,
        guidanceText: 'Test guidance line.',
        title: 'Test Title',
        subtitle: 'Test subtitle.',
        primaryLabel: 'Next',
        onPrimaryPressed: () => continuePressed = true,
        onBack: () => backPressed = true,
        child: const Text('Screen body content'),
      ),
    ));

    expect(find.text('Test Title'), findsOneWidget);
    expect(find.text('Test subtitle.'), findsOneWidget);
    expect(find.text('Test guidance line.'), findsOneWidget);
    expect(find.text('Screen body content'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    await tester.tap(find.byKey(const Key('onboarding-back-button')));
    expect(continuePressed, isTrue);
    expect(backPressed, isTrue);
  });

  testWidgets('OnboardingScaffold disables primary button when primaryEnabled is false', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScaffold(
        progressPercent: 10,
        emotion: EveEmotion.neutral,
        guidanceText: 'g',
        title: 't',
        primaryLabel: 'Next',
        primaryEnabled: false,
        onPrimaryPressed: () {},
        onBack: () {},
        child: const SizedBox(),
      ),
    ));

    final button = tester.widget<ElevatedButton>(find.byKey(const Key('onboarding-primary-button')));
    expect(button.onPressed, isNull);
  });
}
