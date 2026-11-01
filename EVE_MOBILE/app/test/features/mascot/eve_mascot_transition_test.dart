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
  testWidgets('changing emotion animates the mouth control point smoothly, not instantly', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: EveMascot(emotion: EveEmotion.neutral, peelPercent: 0),
    ));
    await tester.pump();
    final startY = _painterOf(tester).mouth.control.dy;
    expect(startY, closeTo(154, 0.01)); // neutral mouth control-y

    await tester.pumpWidget(const MaterialApp(
      home: EveMascot(emotion: EveEmotion.hype, peelPercent: 0),
    ));
    await tester.pump(); // transition ticker starts on this frame (elapsed 0)
    await tester.pump(const Duration(milliseconds: 110)); // mid-transition
    final midY = _painterOf(tester).mouth.control.dy;
    // hype's control-y is 168; mid-transition should be strictly between
    // 154 and 168, never snapping straight to 168 on the first frame.
    expect(midY, greaterThan(154));
    expect(midY, lessThan(168));

    await tester.pump(const Duration(milliseconds: 220));
    final endY = _painterOf(tester).mouth.control.dy;
    expect(endY, closeTo(168, 0.5));
  });

  testWidgets('fertile-glow opacity fades in smoothly when switching to fertile', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: EveMascot(emotion: EveEmotion.neutral, peelPercent: 0),
    ));
    await tester.pump();
    expect(_painterOf(tester).fertileGlowOpacity, 0);

    await tester.pumpWidget(const MaterialApp(
      home: EveMascot(emotion: EveEmotion.fertile, peelPercent: 0),
    ));
    await tester.pump(const Duration(milliseconds: 110)); // halfway through 220ms
    final midOpacity = _painterOf(tester).fertileGlowOpacity;
    expect(midOpacity, greaterThan(0));
    expect(midOpacity, lessThan(0.8));

    await tester.pump(const Duration(milliseconds: 220));
    expect(_painterOf(tester).fertileGlowOpacity, closeTo(0.8, 0.02));
  });
}
