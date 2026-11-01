import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';
import 'package:eve_app/features/mascot/eve_mascot_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EveMascot honors the default peelPercent=100 and size=120', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: EveMascot(emotion: EveEmotion.neutral),
    ));
    await tester.pump();
    final mascot = tester.widget<EveMascot>(find.byType(EveMascot));
    expect(mascot.peelPercent, 100);
    expect(mascot.size, 120);

    final customPaint = tester.widget<CustomPaint>(find.descendant(of: find.byType(EveMascot), matching: find.byType(CustomPaint)));
    expect(customPaint.size, const Size(120, 120));
  });

  testWidgets('5 simultaneous EveMascot instances with different emotions render independently', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            EveMascot(emotion: EveEmotion.neutral, size: 40),
            EveMascot(emotion: EveEmotion.caring, size: 40),
            EveMascot(emotion: EveEmotion.warm, size: 40),
            EveMascot(emotion: EveEmotion.hype, size: 40),
            EveMascot(emotion: EveEmotion.fertile, peelPercent: 80, size: 40),
          ],
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(EveMascot), findsNWidgets(5));

    final painters = tester
        .widgetList<CustomPaint>(find.descendant(of: find.byType(EveMascot), matching: find.byType(CustomPaint)))
        .map((cp) => cp.painter)
        .whereType<EveMascotPainter>()
        .toList();
    expect(painters.length, 5);
    // The fertile instance is the only one with non-zero glow opacity.
    final fertileCount = painters.where((p) => p.fertileGlowOpacity > 0).length;
    expect(fertileCount, 1);
  });

  testWidgets('mounting and unmounting many instances repeatedly does not throw or leak controllers', (tester) async {
    for (var cycle = 0; cycle < 3; cycle++) {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              EveMascot(emotion: EveEmotion.neutral, size: 30),
              EveMascot(emotion: EveEmotion.sassy, size: 30),
              EveMascot(emotion: EveEmotion.hype, size: 30),
            ],
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('changing one instance\'s emotion does not affect a sibling instance', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            EveMascot(key: key, emotion: EveEmotion.neutral, size: 30),
            const EveMascot(emotion: EveEmotion.warm, size: 30),
          ],
        ),
      ),
    ));
    await tester.pump();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            EveMascot(key: key, emotion: EveEmotion.hype, size: 30),
            const EveMascot(emotion: EveEmotion.warm, size: 30),
          ],
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 220));

    final painters = tester
        .widgetList<CustomPaint>(find.descendant(of: find.byType(EveMascot), matching: find.byType(CustomPaint)))
        .map((cp) => cp.painter)
        .whereType<EveMascotPainter>()
        .toList();
    // First instance now settled on hype (control-y 168); second untouched at warm (control-y 162, closed).
    expect(painters[0].mouth.control.dy, closeTo(168, 0.5));
    expect(painters[1].mouth.control.dy, closeTo(162, 0.5));
    expect(painters[1].mouth.closed, isTrue);
  });
}
