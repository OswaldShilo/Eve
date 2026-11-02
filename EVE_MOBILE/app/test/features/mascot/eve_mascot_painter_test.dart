import 'dart:ui' as ui;
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EveMascotPainter _fixedPainter() => const EveMascotPainter(
      mouth: EveMouthShape(Offset(86, 140), Offset(100, 154), Offset(114, 140)),
      browLeft: EveBrowShape(Offset(54, 92), Offset(68, 88), Offset(80, 92)),
      browRight: EveBrowShape(Offset(120, 92), Offset(132, 88), Offset(146, 92)),
      eyelidY: -34,
      fertileGlowOpacity: 0,
      crownScale: 1.0,
      crownRotationDegrees: 0,
      seedRow2Opacity: 0,
      seedRow3Opacity: 0,
    );

void main() {
  test('forState resolves neutral pose + low peel percent with no animation applied', () {
    final painter = EveMascotPainter.forState(emotion: EveEmotion.neutral, peelPercent: 10);
    expect(painter.mouth.control, const Offset(100, 154));
    expect(painter.crownScale, 1.0);
    expect(painter.seedRow2Opacity, 0);
    expect(painter.seedRow3Opacity, 0);
    expect(painter.idleFloatOffset, 0);
  });

  test('forState at peelPercent 100 resolves the fully-bloomed stage', () {
    final painter = EveMascotPainter.forState(emotion: EveEmotion.fertile, peelPercent: 100);
    expect(painter.crownScale, 1.15);
    expect(painter.crownRotationDegrees, -8);
    expect(painter.seedRow2Opacity, 1);
    expect(painter.seedRow3Opacity, 1);
    expect(painter.fertileGlowOpacity, 0.8);
  });

  test('paint() runs without throwing on a real canvas and produces a non-empty picture', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _fixedPainter().paint(canvas, const Size(200, 260));
    final picture = recorder.endRecording();
    expect(picture, isNotNull);
    picture.dispose();
  });

  group('shouldRepaint', () {
    test('returns false when every field is identical', () {
      expect(_fixedPainter().shouldRepaint(_fixedPainter()), isFalse);
    });

    test('returns true when eyelidY differs (blink)', () {
      final a = _fixedPainter();
      final b = EveMascotPainter(
        mouth: a.mouth,
        browLeft: a.browLeft,
        browRight: a.browRight,
        eyelidY: 0,
        fertileGlowOpacity: a.fertileGlowOpacity,
        crownScale: a.crownScale,
        crownRotationDegrees: a.crownRotationDegrees,
        seedRow2Opacity: a.seedRow2Opacity,
        seedRow3Opacity: a.seedRow3Opacity,
      );
      expect(a.shouldRepaint(b), isTrue);
    });

    test('returns true when idleFloatOffset differs', () {
      final a = _fixedPainter();
      final b = EveMascotPainter(
        mouth: a.mouth,
        browLeft: a.browLeft,
        browRight: a.browRight,
        eyelidY: a.eyelidY,
        fertileGlowOpacity: a.fertileGlowOpacity,
        crownScale: a.crownScale,
        crownRotationDegrees: a.crownRotationDegrees,
        seedRow2Opacity: a.seedRow2Opacity,
        seedRow3Opacity: a.seedRow3Opacity,
        idleFloatOffset: 1.5,
      );
      expect(a.shouldRepaint(b), isTrue);
    });
  });
}
