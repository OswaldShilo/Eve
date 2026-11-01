import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';
import 'package:eve_app/features/mascot/eve_mascot_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EveMascotPainter _painterOf(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(find.descendant(of: find.byType(EveMascot), matching: find.byType(CustomPaint)));
  return customPaint.painter! as EveMascotPainter;
}

void main() {
  testWidgets('raising peelPercent past 35 animates crown scale up over time, not instantly', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: EveMascot(emotion: EveEmotion.neutral, peelPercent: 10),
    ));
    await tester.pump();
    expect(_painterOf(tester).crownScale, closeTo(1.0, 0.001));

    await tester.pumpWidget(const MaterialApp(
      home: EveMascot(emotion: EveEmotion.neutral, peelPercent: 50),
    ));
    await tester.pump(const Duration(milliseconds: 100)); // partway through the 500ms transition
    final midScale = _painterOf(tester).crownScale;
    expect(midScale, greaterThan(1.0));
    // Should not have already snapped fully to the 1.08 target this early.

    await tester.pump(const Duration(milliseconds: 500));
    expect(_painterOf(tester).crownScale, closeTo(1.08, 0.01));
  });

  testWidgets('seed row 2 opacity ramps from 0 to 1 rather than popping in at peelPercent 35', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: EveMascot(emotion: EveEmotion.neutral, peelPercent: 20),
    ));
    await tester.pump();
    expect(_painterOf(tester).seedRow2Opacity, 0);

    await tester.pumpWidget(const MaterialApp(
      home: EveMascot(emotion: EveEmotion.neutral, peelPercent: 40),
    ));
    await tester.pump(const Duration(milliseconds: 250)); // halfway through 500ms
    final midOpacity = _painterOf(tester).seedRow2Opacity;
    expect(midOpacity, greaterThan(0));
    expect(midOpacity, lessThan(1));

    await tester.pump(const Duration(milliseconds: 500));
    expect(_painterOf(tester).seedRow2Opacity, closeTo(1, 0.01));
  });

  testWidgets('seed row opacity never exceeds 1 even though the crown scale curve overshoots', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: EveMascot(emotion: EveEmotion.neutral, peelPercent: 10),
    ));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(
      home: EveMascot(emotion: EveEmotion.neutral, peelPercent: 80),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      expect(_painterOf(tester).seedRow2Opacity, inInclusiveRange(0.0, 1.0));
      expect(_painterOf(tester).seedRow3Opacity, inInclusiveRange(0.0, 1.0));
    }
  });
}
