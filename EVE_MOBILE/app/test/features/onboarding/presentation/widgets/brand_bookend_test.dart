import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/brand_bookend.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Widget _bookend() => MaterialApp(
  theme: EveTheme.defaultTheme(),
  home: BrandBookend(
    speech: 'Welcome to EVE.',
    emotion: EveEmotion.neutral,
    title: 'EVE',
    subtitle: 'Cycle & Wellness Companion',
    button: EveButton(label: 'Begin Setup', onPressed: () {}),
  ),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'renders the speech bubble, mascot on its ground shadow and the brand footer',
    (tester) async {
      await tester.pumpWidget(_bookend());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SpeechBubble), findsOneWidget);
      expect(find.byType(EveMascot), findsOneWidget);
      expect(find.byType(MascotGroundShadow), findsOneWidget);
      expect(find.text('EVE'), findsOneWidget);
      expect(find.text('CYCLE & WELLNESS COMPANION'), findsOneWidget);

      final title = tester.widget<Text>(find.byKey(const Key('bookend-title')));
      expect(title.style!.shadows!.single.color, EveColors.rubyBlush);
      expect(title.style!.fontSize, closeTo(60.8, 0.01));
      final sub = tester.widget<Text>(
        find.byKey(const Key('bookend-subtitle')),
      );
      expect(sub.style!.color, EveColors.rubyMain);
    },
  );

  testWidgets('Eve bounces in from a smaller scale and settles at full size', (
    tester,
  ) async {
    await tester.pumpWidget(_bookend());

    // Transform.scale only scales x/y (z stays 1), so read the x scale.
    double scaleNow() => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byKey(const Key('bookend-mascot-entrance')),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .storage[0];

    // The animation ticker starts on the frame after the first build.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(scaleNow(), lessThan(0.9));

    await tester.pump(const Duration(seconds: 1));
    expect(scaleNow(), closeTo(1, 0.001));
  });

  testWidgets('scrolls instead of overflowing on a short screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_bookend());
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pump();
    expect(find.text('Begin Setup').hitTestable(), findsOneWidget);
  });
}
