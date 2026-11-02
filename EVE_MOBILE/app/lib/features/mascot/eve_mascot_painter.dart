import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'eve_emotion.dart';
import 'eve_rig_geometry.dart';

/// Draws one fully-resolved frame of the mascot rig. This painter owns no
/// animation state and no notion of `EveEmotion`/peel-percent thresholds —
/// every value it needs is passed in already interpolated. `EveMascot`'s
/// widget layer (Tasks 4-7) is the only thing that ever constructs this with
/// time-varying values; this file does not change again after this task.
class EveMascotPainter extends CustomPainter {
  const EveMascotPainter({
    required this.mouth,
    required this.browLeft,
    required this.browRight,
    required this.eyelidY,
    required this.fertileGlowOpacity,
    required this.crownScale,
    required this.crownRotationDegrees,
    required this.seedRow2Opacity,
    required this.seedRow3Opacity,
    this.idleFloatOffset = 0,
  });

  /// Convenience factory: resolves a static, non-animated frame directly
  /// from an emotion + peel percent (used for the very first frame and by
  /// golden tests).
  factory EveMascotPainter.forState({required EveEmotion emotion, required double peelPercent}) {
    final pose = EveEmotionTable.poses[emotion]!;
    final stage = EvePeelStage.fromPercent(peelPercent);
    return EveMascotPainter(
      mouth: pose.mouth,
      browLeft: pose.browLeft,
      browRight: pose.browRight,
      eyelidY: pose.eyelidRestY,
      fertileGlowOpacity: pose.fertileGlowOpacity,
      crownScale: stage.crownScale,
      crownRotationDegrees: stage.crownRotationDegrees,
      seedRow2Opacity: stage.seedRow2Visible ? 1 : 0,
      seedRow3Opacity: stage.seedRow3Visible ? 1 : 0,
    );
  }

  final EveMouthShape mouth;
  final EveBrowShape browLeft;
  final EveBrowShape browRight;
  final double eyelidY;
  final double fertileGlowOpacity;
  final double crownScale;
  final double crownRotationDegrees;
  final double seedRow2Opacity;
  final double seedRow3Opacity;
  final double idleFloatOffset;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Idle float is a screen-space pixel shift (the mock applies
    // `translateY(Npx)` to the whole rendered SVG element), independent of
    // the internal viewBox scale below — so it is applied first/outermost.
    canvas.translate(0, idleFloatOffset);

    // Fit-contain the 200x260 viewBox into a square `size x size` box:
    // 260 is the taller dimension, so it determines the scale; the 200-wide
    // content is then horizontally centered. (design decision — the source
    // viewBox is not square, and `EveMascot.size` is a single scalar; see
    // Self-Review.)
    final scale = size.width / 260.0;
    final contentWidth = 200 * scale;
    final dx = (size.width - contentWidth) / 2;
    canvas.translate(dx, 0);
    canvas.scale(scale);
    canvas.translate(0, 40); // shift viewBox y origin (-40) to 0

    _drawBody(canvas);
    _drawPithAndSeeds(canvas);
    _drawCrown(canvas);
    _drawArms(canvas);
    _drawFertileGlow(canvas);
    _drawUnderEyePatches(canvas);
    _drawEye(canvas, EveRigGeometry.eyeCenterLeft);
    _drawEye(canvas, EveRigGeometry.eyeCenterRight);
    _drawBrows(canvas);
    _drawMouth(canvas);
    _drawFeet(canvas);

    canvas.restore();
  }

  void _drawBody(Canvas canvas) {
    canvas.drawPath(EveRigGeometry.bodyOutline(), Paint()..color = EveRigColors.outlineDark);
    canvas.drawPath(EveRigGeometry.bodyMainShell(), Paint()..color = EveRigColors.bodyPink);
    canvas.drawPath(EveRigGeometry.bodyUndersideShadow(), Paint()..color = EveRigColors.bodyShadow);
  }

  void _drawPithAndSeeds(Canvas canvas) {
    final linerPaint = Paint()
      ..color = EveRigColors.pithLiner
      ..style = PaintingStyle.fill;
    final linerStroke = Paint()
      ..color = EveRigColors.outlineDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = EveRigGeometry.pithStrokeWidth;
    canvas.drawPath(EveRigGeometry.topPithLiner(), linerPaint);
    canvas.drawPath(EveRigGeometry.topPithLiner(), linerStroke);

    canvas.drawPath(
      EveRigGeometry.topCreamPith(),
      Paint()..color = EveRigColors.creamPith.withValues(alpha: 0.9),
    );

    _drawSeedRow(canvas, EveRigGeometry.seedRow1(), opacity: 1);
    _drawSeedRow(canvas, EveRigGeometry.seedRow2(), opacity: seedRow2Opacity);
    _drawSeedRow(canvas, EveRigGeometry.seedRow3(), opacity: seedRow3Opacity);
  }

  void _drawSeedRow(Canvas canvas, EveSeedRow row, {required double opacity}) {
    if (opacity <= 0) return;
    canvas.save();
    canvas.translate(row.restTranslate.dx, row.restTranslate.dy);
    canvas.scale(row.restScale);
    for (final node in row.nodes) {
      canvas.drawPath(node.path, Paint()..color = node.fill.withValues(alpha: opacity));
      canvas.drawPath(
        node.path,
        Paint()
          ..color = EveRigColors.outlineDark.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = EveRigGeometry.seedStrokeWidth,
      );
      for (final dot in node.highlights) {
        canvas.drawCircle(dot.center, dot.radius, Paint()..color = Colors.white.withValues(alpha: dot.opacity * opacity));
      }
    }
    canvas.restore();
  }

  void _drawCrown(Canvas canvas) {
    canvas.save();
    canvas.translate(EveRigGeometry.crownTransformOrigin.dx, EveRigGeometry.crownTransformOrigin.dy);
    canvas.scale(crownScale);
    canvas.rotate(crownRotationDegrees * math.pi / 180);
    canvas.translate(-EveRigGeometry.crownTransformOrigin.dx, -EveRigGeometry.crownTransformOrigin.dy);

    final strokePaint = Paint()
      ..color = EveRigColors.outlineDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = EveRigGeometry.crownStrokeWidth
      ..strokeJoin = StrokeJoin.round;

    void drawPiece(Path path, Color fill) {
      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(path, strokePaint);
    }

    drawPiece(EveRigGeometry.crownBackLeft(), EveRigColors.bodyShadow);
    drawPiece(EveRigGeometry.crownBackRight(), EveRigColors.bodyShadow);
    drawPiece(EveRigGeometry.crownFrontLeft(), EveRigColors.bodyPink);
    drawPiece(EveRigGeometry.crownFrontRight(), EveRigColors.bodyPink);
    drawPiece(EveRigGeometry.crownFrontCenter(), EveRigColors.crownFrontCenter);

    canvas.restore();
  }

  void _drawArms(Canvas canvas) {
    final strokePaint = Paint()
      ..color = EveRigColors.outlineDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = EveRigGeometry.armStrokeWidth
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()..color = EveRigColors.armPink;
    canvas.drawPath(EveRigGeometry.armLeft(), fillPaint);
    canvas.drawPath(EveRigGeometry.armLeft(), strokePaint);
    canvas.drawPath(EveRigGeometry.armRight(), fillPaint);
    canvas.drawPath(EveRigGeometry.armRight(), strokePaint);
  }

  void _drawFertileGlow(Canvas canvas) {
    if (fertileGlowOpacity <= 0) return;
    canvas.drawOval(
      EveRigGeometry.fertileGlowOval,
      Paint()..color = EveRigColors.fertileGlow.withValues(alpha: fertileGlowOpacity),
    );
  }

  void _drawUnderEyePatches(Canvas canvas) {
    final paint = Paint()..color = EveRigColors.underEyePatch.withValues(alpha: 0.9);
    canvas.drawOval(EveRigGeometry.underEyePatchLeft, paint);
    canvas.drawOval(EveRigGeometry.underEyePatchRight, paint);
  }

  void _drawEye(Canvas canvas, Offset center) {
    final socket = EveRigGeometry.eyeSocketRect(center);
    canvas.drawOval(socket, Paint()..color = EveRigColors.outlineDark);

    canvas.save();
    canvas.clipPath(Path()..addOval(socket));

    canvas.drawCircle(center, EveRigGeometry.pupilRadius, Paint()..color = EveRigColors.pupilDark);
    canvas.drawCircle(
      center + EveRigGeometry.pupilHighlight1Offset,
      EveRigGeometry.pupilHighlight1Radius,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      center + EveRigGeometry.pupilHighlight2Offset,
      EveRigGeometry.pupilHighlight2Radius,
      Paint()..color = Colors.white,
    );

    canvas.drawRect(
      EveRigGeometry.eyelidRect(center, eyelidY),
      Paint()..color = EveRigColors.bodyPink,
    );

    canvas.restore();
  }

  void _drawBrows(Canvas canvas) {
    final paint = Paint()
      ..color = EveRigColors.outlineDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(browLeft.toPath(), paint);
    canvas.drawPath(browRight.toPath(), paint);
  }

  void _drawMouth(Canvas canvas) {
    final paint = Paint()
      ..color = EveRigColors.outlineDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(mouth.toPath(), paint);
  }

  void _drawFeet(Canvas canvas) {
    final paint = Paint()..color = EveRigColors.outlineDark;
    canvas.drawOval(EveRigGeometry.footLeft, paint);
    canvas.drawOval(EveRigGeometry.footRight, paint);
  }

  @override
  bool shouldRepaint(covariant EveMascotPainter oldDelegate) {
    return mouth.start != oldDelegate.mouth.start ||
        mouth.control != oldDelegate.mouth.control ||
        mouth.end != oldDelegate.mouth.end ||
        mouth.closed != oldDelegate.mouth.closed ||
        browLeft.control != oldDelegate.browLeft.control ||
        browRight.control != oldDelegate.browRight.control ||
        eyelidY != oldDelegate.eyelidY ||
        fertileGlowOpacity != oldDelegate.fertileGlowOpacity ||
        crownScale != oldDelegate.crownScale ||
        crownRotationDegrees != oldDelegate.crownRotationDegrees ||
        seedRow2Opacity != oldDelegate.seedRow2Opacity ||
        seedRow3Opacity != oldDelegate.seedRow3Opacity ||
        idleFloatOffset != oldDelegate.idleFloatOffset;
  }
}
