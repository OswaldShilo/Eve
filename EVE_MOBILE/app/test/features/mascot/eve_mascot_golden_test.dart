import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _fixedFrame(EveEmotion emotion) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: const Key('eve-mascot-golden'),
            child: SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: EveMascotPainter.forState(emotion: emotion, peelPercent: 100),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  for (final emotion in EveEmotion.values) {
    testWidgets('golden: ${emotion.name} at peelPercent 100', (tester) async {
      await tester.pumpWidget(_fixedFrame(emotion));
      await tester.pump();
      await expectLater(
        find.byKey(const Key('eve-mascot-golden')),
        matchesGoldenFile('goldens/eve_mascot_${emotion.name}.png'),
      );
    });
  }
}
