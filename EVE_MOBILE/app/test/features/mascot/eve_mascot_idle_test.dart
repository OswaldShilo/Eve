import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';
import 'package:eve_app/features/mascot/eve_mascot_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EveMascotPainter _painterOf(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(EveMascot), matching: find.byType(CustomPaint)),
  );
  return customPaint.painter! as EveMascotPainter;
}

void main() {
  testWidgets('idle float offset follows sin(t * 2*pi / 3491ms) * 2', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: EveMascot(emotion: EveEmotion.neutral, peelPercent: 0),
    ));
    await tester.pump(); // first frame, t=0
    expect(_painterOf(tester).idleFloatOffset, closeTo(0, 0.05));

    // Quarter period -> sin(pi/2)*2 = 2 (peak).
    await tester.pump(const Duration(milliseconds: 873)); // ~3491/4
    expect(_painterOf(tester).idleFloatOffset, closeTo(2, 0.3));
  });

  testWidgets('eyelid closes to Y=0 during a blink window and reopens after', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: EveMascot(emotion: EveEmotion.neutral, peelPercent: 0),
    ));
    await tester.pump();
    expect(_painterOf(tester).eyelidY, closeTo(-34, 0.01)); // resting, neutral pose

    // First blink trigger fires at ~1944ms; pump into the middle of the
    // 75ms closing leg.
    await tester.pump(const Duration(milliseconds: 1944));
    await tester.pump(const Duration(milliseconds: 37));
    expect(_painterOf(tester).eyelidY, greaterThan(-34));
    expect(_painterOf(tester).eyelidY, lessThan(0));

    // Well past the full 150ms round trip, eyelid should be back at rest.
    // Pumped as separate frames: the reopen leg's ticker only starts on the
    // frame after the closing leg completes.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_painterOf(tester).eyelidY, closeTo(-34, 0.01));
  });

  testWidgets('disposing the widget cancels the idle controller and blink timer cleanly', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: EveMascot(emotion: EveEmotion.neutral, peelPercent: 0),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(seconds: 3)); // long enough to cross a blink boundary if leaked
    expect(tester.takeException(), isNull);
  });
}
