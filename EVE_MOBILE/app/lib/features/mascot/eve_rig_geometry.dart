import 'package:flutter/material.dart';

/// Exact colors from `mockv4.html`'s `#mascot-svg-template` (lines 1165-1282).
class EveRigColors {
  EveRigColors._();

  static const outlineDark = Color(0xFF2A000E);
  static const bodyPink = Color(0xFFFF2A6D);
  static const bodyShadow = Color(0xFFC80042);
  static const pithLiner = Color(0xFF3D0013);
  static const creamPith = Color(0xFFFFF2F5);
  static const crownFrontCenter = Color(0xFFFF5E8E);
  static const armPink = Color(0xFFE6195E);
  static const fertileGlow = Color(0xFFFFA0B8);
  static const underEyePatch = Color(0xFFFFA0B8);
  static const pupilDark = Color(0xFF150007);
  static const seedRow1A = Color(0xFFD9004C);
  static const seedRow1B = Color(0xFFFF2A6D);
  static const seedRow1C = Color(0xFFB8003A);
  static const seedRow2A = Color(0xFFFF175A);
  static const seedRow2B = Color(0xFFE6004C);
  static const seedRow3A = Color(0xFFFF2A6D);
  static const seedRow3B = Color(0xFFFF5E8E);
  static const seedRow3C = Color(0xFFD9004C);
}

/// A small filled circle rendered on top of a seed node (the "shine" highlight).
class EveHighlightDot {
  const EveHighlightDot(this.center, this.radius, {this.opacity = 1.0});
  final Offset center;
  final double radius;
  final double opacity;
}

/// One pomegranate seed: a filled path outlined in `EveRigColors.outlineDark`
/// plus 1-2 white highlight dots.
class EveSeedNode {
  const EveSeedNode(this.path, this.fill, this.highlights);
  final Path path;
  final Color fill;
  final List<EveHighlightDot> highlights;
}

/// A row of seed nodes. Rows 2 and 3 carry a permanent rest scale/translate
/// baked into the mock's inline style (mockv4.html:1200, 1211) — only
/// *opacity* is toggled by peel percent; the row is always drawn slightly
/// smaller and shifted up when visible.
class EveSeedRow {
  const EveSeedRow(this.nodes, {this.restScale = 1.0, this.restTranslate = Offset.zero});
  final List<EveSeedNode> nodes;
  final double restScale;
  final Offset restTranslate;
}

/// Resolved crown/seed growth stage for a given peel percent. Ported exactly
/// from `setMascotPeel` (mockv4.html:2262-2275).
class EvePeelStage {
  const EvePeelStage({
    required this.crownScale,
    required this.crownRotationDegrees,
    required this.seedRow2Visible,
    required this.seedRow3Visible,
  });

  final double crownScale;
  final double crownRotationDegrees;
  final bool seedRow2Visible;
  final bool seedRow3Visible;

  factory EvePeelStage.fromPercent(double percent) {
    final seedRow2Visible = percent >= 35;
    final seedRow3Visible = percent >= 70;
    if (percent < 35) {
      return EvePeelStage(
        crownScale: 1.0,
        crownRotationDegrees: 0,
        seedRow2Visible: seedRow2Visible,
        seedRow3Visible: seedRow3Visible,
      );
    }
    if (percent < 70) {
      return EvePeelStage(
        crownScale: 1.08,
        crownRotationDegrees: -4,
        seedRow2Visible: seedRow2Visible,
        seedRow3Visible: seedRow3Visible,
      );
    }
    return EvePeelStage(
      crownScale: 1.15,
      crownRotationDegrees: -8,
      seedRow2Visible: seedRow2Visible,
      seedRow3Visible: seedRow3Visible,
    );
  }
}

/// Raw path/shape geometry for every rig part that does NOT vary by emotion
/// (body, crown, seeds, eye sockets/pupils, arms, fertile glow, feet).
/// Emotion-varying parts (mouth, brows, eyelid resting Y) live in
/// `eve_emotion.dart`.
class EveRigGeometry {
  EveRigGeometry._();

  // ---- Stroke widths (from the SVG template's stroke-width attributes) ----
  static const double outlineStrokeWidth = 3.5; // body wasn't stroked; crown/arms use 3.5
  static const double crownStrokeWidth = 3.5;
  static const double pithStrokeWidth = 2.5;
  static const double armStrokeWidth = 3.5;
  static const double seedStrokeWidth = 2.0;

  // ---- Body (mockv4.html:1176-1178) ----
  // WORKED EXAMPLE: `M 100,42 C 154,42 184,76 184,126 C 184,174 150,198 100,198
  //                   C 50,198 16,174 16,126 C 16,76 46,42 100,42 Z`
  // M 100,42            -> moveTo(100, 42)
  // C 154,42 184,76 184,126 -> cubicTo(154, 42, 184, 76, 184, 126)
  // C 184,174 150,198 100,198 -> cubicTo(184, 174, 150, 198, 100, 198)
  // C 50,198 16,174 16,126  -> cubicTo(50, 198, 16, 174, 16, 126)
  // C 16,76 46,42 100,42    -> cubicTo(16, 76, 46, 42, 100, 42)
  // Z                    -> close()
  static Path bodyOutline() => Path()
    ..moveTo(100, 42)
    ..cubicTo(154, 42, 184, 76, 184, 126)
    ..cubicTo(184, 174, 150, 198, 100, 198)
    ..cubicTo(50, 198, 16, 174, 16, 126)
    ..cubicTo(16, 76, 46, 42, 100, 42)
    ..close();

  static Path bodyMainShell() => Path()
    ..moveTo(100, 44)
    ..cubicTo(152, 44, 180, 78, 180, 124)
    ..cubicTo(180, 170, 148, 194, 100, 194)
    ..cubicTo(52, 194, 20, 170, 20, 124)
    ..cubicTo(20, 78, 48, 44, 100, 44)
    ..close();

  static Path bodyUndersideShadow() => Path()
    ..moveTo(32, 145)
    ..cubicTo(42, 175, 68, 194, 100, 194)
    ..cubicTo(132, 194, 158, 175, 168, 145)
    ..cubicTo(150, 168, 126, 182, 100, 182)
    ..cubicTo(74, 182, 50, 168, 32, 145)
    ..close();

  // ---- Top peel reservoir (mockv4.html:1181-1182) ----
  static Path topPithLiner() => Path()
    ..moveTo(68, 44)
    ..quadraticBezierTo(100, 48, 132, 44)
    ..quadraticBezierTo(100, 52, 68, 44)
    ..close();

  static Path topCreamPith() => Path()
    ..moveTo(70, 44)
    ..quadraticBezierTo(100, 50, 130, 44)
    ..quadraticBezierTo(100, 56, 70, 44)
    ..close();

  // ---- Crown, 5 pieces (mockv4.html:1229-1233) ----
  static const Offset crownTransformOrigin = Offset(100, 42);

  // WORKED EXAMPLE: `M 68,44 Q 60,26 74,32 Q 88,38 92,44 Z`
  // M 68,44        -> moveTo(68, 44)
  // Q 60,26 74,32  -> quadraticBezierTo(60, 26, 74, 32)
  // Q 88,38 92,44  -> quadraticBezierTo(88, 38, 92, 44)
  // Z              -> close()
  static Path crownBackLeft() => Path()
    ..moveTo(68, 44)
    ..quadraticBezierTo(60, 26, 74, 32)
    ..quadraticBezierTo(88, 38, 92, 44)
    ..close();

  static Path crownBackRight() => Path()
    ..moveTo(132, 44)
    ..quadraticBezierTo(140, 26, 126, 32)
    ..quadraticBezierTo(112, 38, 108, 44)
    ..close();

  static Path crownFrontLeft() => Path()
    ..moveTo(60, 48)
    ..quadraticBezierTo(48, 30, 68, 36)
    ..quadraticBezierTo(80, 40, 84, 52)
    ..close();

  static Path crownFrontRight() => Path()
    ..moveTo(140, 48)
    ..quadraticBezierTo(152, 30, 132, 36)
    ..quadraticBezierTo(120, 40, 116, 52)
    ..close();

  static Path crownFrontCenter() => Path()
    ..moveTo(82, 54)
    ..quadraticBezierTo(100, 62, 118, 54)
    ..quadraticBezierTo(100, 46, 82, 54)
    ..close();

  // ---- Seed rows (mockv4.html:1185-1224) ----
  static EveSeedRow seedRow1() => EveSeedRow([
        EveSeedNode(
          Path()
            ..moveTo(80, 36)
            ..cubicTo(74, 26, 84, 18, 89, 25)
            ..cubicTo(93, 31, 87, 40, 80, 36)
            ..close(),
          EveRigColors.seedRow1A,
          const [EveHighlightDot(Offset(84, 24), 1.8, opacity: 0.8)],
        ),
        EveSeedNode(
          Path()
            ..moveTo(100, 30)
            ..cubicTo(92, 16, 108, 12, 112, 23)
            ..cubicTo(114, 30, 106, 36, 100, 30)
            ..close(),
          EveRigColors.seedRow1B,
          const [EveHighlightDot(Offset(102, 19), 2.0)],
        ),
        EveSeedNode(
          Path()
            ..moveTo(120, 36)
            ..cubicTo(113, 40, 107, 31, 111, 25)
            ..cubicTo(116, 18, 126, 27, 120, 36)
            ..close(),
          EveRigColors.seedRow1C,
          const [EveHighlightDot(Offset(116, 24), 1.8, opacity: 0.8)],
        ),
      ]);

  static EveSeedRow seedRow2() => EveSeedRow(
        [
          EveSeedNode(
            Path()
              ..moveTo(88, 42)
              ..cubicTo(82, 34, 94, 30, 97, 38)
              ..cubicTo(99, 44, 92, 48, 88, 42)
              ..close(),
            EveRigColors.seedRow2A,
            const [EveHighlightDot(Offset(91, 37), 1.5)],
          ),
          EveSeedNode(
            Path()
              ..moveTo(112, 42)
              ..cubicTo(108, 48, 101, 44, 103, 38)
              ..cubicTo(106, 30, 118, 34, 112, 42)
              ..close(),
            EveRigColors.seedRow2B,
            const [EveHighlightDot(Offset(109, 37), 1.5)],
          ),
        ],
        restScale: 0.82,
        restTranslate: const Offset(0, -10),
      );

  static EveSeedRow seedRow3() => EveSeedRow(
        [
          EveSeedNode(
            Path()
              ..moveTo(76, 52)
              ..cubicTo(68, 44, 80, 38, 85, 46)
              ..cubicTo(88, 52, 82, 58, 76, 52)
              ..close(),
            EveRigColors.seedRow3A,
            const [EveHighlightDot(Offset(80, 46), 1.8)],
          ),
          EveSeedNode(
            Path()
              ..moveTo(100, 52)
              ..cubicTo(92, 42, 108, 38, 110, 48)
              ..cubicTo(112, 54, 104, 58, 100, 52)
              ..close(),
            EveRigColors.seedRow3B,
            const [EveHighlightDot(Offset(102, 46), 1.8)],
          ),
          EveSeedNode(
            Path()
              ..moveTo(124, 52)
              ..cubicTo(118, 58, 112, 52, 115, 46)
              ..cubicTo(120, 38, 132, 44, 124, 52)
              ..close(),
            EveRigColors.seedRow3C,
            const [EveHighlightDot(Offset(120, 46), 1.8)],
          ),
        ],
        restScale: 0.82,
        restTranslate: const Offset(0, -14),
      );

  // ---- Arms (mockv4.html:1237, 1241) ----
  static const Offset armLeftOrigin = Offset(34, 135);
  static const Offset armRightOrigin = Offset(166, 135);

  static Path armLeft() => Path()
    ..moveTo(34, 135)
    ..quadraticBezierTo(14, 145, 24, 162)
    ..quadraticBezierTo(34, 166, 40, 148)
    ..close();

  static Path armRight() => Path()
    ..moveTo(166, 135)
    ..quadraticBezierTo(186, 145, 176, 162)
    ..quadraticBezierTo(166, 166, 160, 148)
    ..close();

  // ---- Fertile glow (mockv4.html:1244) ----
  static const Rect fertileGlowRect = Rect.fromLTWH(62, 26, 76, 18); // center(100,35) rx38 ry18 -> fromCenter
  static Rect get fertileGlowOval => Rect.fromCenter(center: const Offset(100, 35), width: 76, height: 36);

  // ---- Under-eye patches (mockv4.html:1247-1248) ----
  static Rect get underEyePatchLeft => Rect.fromCenter(center: const Offset(68, 130), width: 25, height: 11);
  static Rect get underEyePatchRight => Rect.fromCenter(center: const Offset(132, 130), width: 25, height: 11);

  // ---- Eyes (mockv4.html:1168-1173, 1251-1273) ----
  static const Offset eyeCenterLeft = Offset(68, 115);
  static const Offset eyeCenterRight = Offset(132, 115);
  static Rect eyeSocketRect(Offset center) => Rect.fromCenter(center: center, width: 26, height: 34);

  /// Pupil geometry is identical for both eyes, expressed relative to the
  /// eye center (mockv4.html:1254-1257, 1266-1269).
  static const double pupilRadius = 11.0;
  static const Offset pupilHighlight1Offset = Offset(-3, -4);
  static const double pupilHighlight1Radius = 5.0;
  static const Offset pupilHighlight2Offset = Offset(4, 5);
  static const double pupilHighlight2Radius = 2.5;

  /// The eyelid is a 36x34 rect whose SVG `x` sits 18px left of the eye
  /// center (`x=50` for the left eye at cx=68, `x=114` for the right eye at
  /// cx=132 — mockv4.html:1259, 1271) and whose `y` base is 85, shifted by
  /// `translateY`. `translateY` is negative when open (moved up out of the
  /// eye) and 0 when fully closed/blinking.
  static Rect eyelidRect(Offset eyeCenter, double translateY) =>
      Rect.fromLTWH(eyeCenter.dx - 18, 85 + translateY, 36, 34);

  // ---- Feet (mockv4.html:1279-1280) ----
  static Rect get footLeft => Rect.fromCenter(center: const Offset(76, 195), width: 24, height: 10);
  static Rect get footRight => Rect.fromCenter(center: const Offset(124, 195), width: 24, height: 10);
}
