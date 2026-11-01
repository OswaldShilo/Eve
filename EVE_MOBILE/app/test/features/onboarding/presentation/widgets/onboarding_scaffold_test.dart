import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

void main() {
  testWidgets(
    'OnboardingScaffold renders title, subtitle, guidance text and forwards taps',
    (tester) async {
      var continuePressed = false;
      var backPressed = false;

      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test subtitle.'), findsOneWidget);
      expect(find.text('Test guidance line.'), findsOneWidget);
      expect(find.text('Screen body content'), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding-primary-button')));
      await tester.tap(find.byKey(const Key('onboarding-back-button')));
      expect(continuePressed, isTrue);
      expect(backPressed, isTrue);
    },
  );

  testWidgets(
    'OnboardingScaffold disables primary button when primaryEnabled is false',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );

      final button = tester.widget<EveButton>(
        find.byKey(const Key('onboarding-primary-button')),
      );
      expect(button.onPressed, isNull);

      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScaffold(
            progressPercent: 10,
            emotion: EveEmotion.neutral,
            guidanceText: 'g',
            title: 't',
            primaryLabel: 'Next',
            primaryEnabled: false,
            onPrimaryPressed: () => pressed = true,
            onBack: () {},
            child: const SizedBox(),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('onboarding-primary-button')));
      expect(pressed, isFalse);
    },
  );

  testWidgets('primaryBusy shows a spinner on the primary button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScaffold(
          progressPercent: 10,
          emotion: EveEmotion.neutral,
          guidanceText: 'g',
          title: 't',
          primaryLabel: 'Finish Setup',
          primaryBusy: true,
          onPrimaryPressed: () {},
          onBack: () {},
          child: const SizedBox(),
        ),
      ),
    );

    expect(find.byKey(const Key('eve-button-busy')), findsOneWidget);
  });

  testWidgets('Android system back calls onBack instead of leaving the app', (tester) async {
    var backPressed = 0;
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScaffold(
        progressPercent: 30,
        emotion: EveEmotion.neutral,
        guidanceText: 'g',
        title: 'About You',
        primaryLabel: 'Next',
        onPrimaryPressed: () {},
        onBack: () => backPressed++,
        child: const SizedBox(),
      ),
    ));

    final handled = await tester.binding.handlePopRoute();
    await tester.pump();

    expect(handled, isTrue, reason: 'the pop must be consumed, not bubble out of the app');
    expect(backPressed, 1);
    expect(find.text('About You'), findsOneWidget);
  });
}
