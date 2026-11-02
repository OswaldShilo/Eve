import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

/// The 6 mascot emotion states. Fixed set — see design-spec §10. `caring`
/// covers the mock's `caring`/`hug`/`concerned` grouping; `warm` covers
/// `warm`/`happy`/`positive`.
enum EveEmotion { neutral, caring, warm, hype, sassy, fertile }

/// A single quadratic-bezier stroked brow: `M start Q control end`.
@immutable
class EveBrowShape {
  const EveBrowShape(this.start, this.control, this.end);

  final Offset start;
  final Offset control;
  final Offset end;

  Path toPath() => Path()
    ..moveTo(start.dx, start.dy)
    ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

  static EveBrowShape lerp(EveBrowShape a, EveBrowShape b, double t) => EveBrowShape(
        Offset.lerp(a.start, b.start, t)!,
        Offset.lerp(a.control, b.control, t)!,
        Offset.lerp(a.end, b.end, t)!,
      );
}

/// A single quadratic-bezier mouth: `M start Q control end [Z]`. `closed`
/// mirrors the mock's trailing `Z` on the warm/hype variants (an implicit
/// straight line back to `start`, forming a filled-looking smile crescent
/// even though the path itself is stroked with fill="none").
@immutable
class EveMouthShape {
  const EveMouthShape(this.start, this.control, this.end, {this.closed = false});

  final Offset start;
  final Offset control;
  final Offset end;
  final bool closed;

  Path toPath() {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    if (closed) path.close();
    return path;
  }

  /// Interpolates the 3 control points continuously. `closed` cannot be
  /// interpolated (a path is either closed or not), so it snaps to the
  /// target's value at the halfway point — an approximation flagged in the
  /// plan's Self-Review section.
  static EveMouthShape lerp(EveMouthShape a, EveMouthShape b, double t) => EveMouthShape(
        Offset.lerp(a.start, b.start, t)!,
        Offset.lerp(a.control, b.control, t)!,
        Offset.lerp(a.end, b.end, t)!,
        closed: t < 0.5 ? a.closed : b.closed,
      );
}

/// The full set of emotion-dependent pose values ported from
/// `setMascotEmotion` (mockv4.html:2218-2260).
@immutable
class EveEmotionPose {
  const EveEmotionPose({
    required this.mouth,
    required this.browLeft,
    required this.browRight,
    required this.eyelidRestY,
    required this.fertileGlowOpacity,
  });

  final EveMouthShape mouth;
  final EveBrowShape browLeft;
  final EveBrowShape browRight;
  final double eyelidRestY;
  final double fertileGlowOpacity;

  static EveEmotionPose lerp(EveEmotionPose a, EveEmotionPose b, double t) => EveEmotionPose(
        mouth: EveMouthShape.lerp(a.mouth, b.mouth, t),
        browLeft: EveBrowShape.lerp(a.browLeft, b.browLeft, t),
        browRight: EveBrowShape.lerp(a.browRight, b.browRight, t),
        eyelidRestY: lerpDouble(a.eyelidRestY, b.eyelidRestY, t)!,
        fertileGlowOpacity: lerpDouble(a.fertileGlowOpacity, b.fertileGlowOpacity, t)!,
      );
}

/// Ported exactly from `setMascotEmotion` (mockv4.html:2218-2260). Do not
/// re-derive these coordinates from the static SVG template defaults — the
/// template's baked-in `d` attributes are overwritten unconditionally by
/// this function for every configured mascot instance, so the JS values
/// here are the single source of truth.
class EveEmotionTable {
  EveEmotionTable._();

  static const _neutralBrowLeft = EveBrowShape(Offset(54, 92), Offset(68, 88), Offset(80, 92));
  static const _neutralBrowRight = EveBrowShape(Offset(120, 92), Offset(132, 88), Offset(146, 92));

  static const Map<EveEmotion, EveEmotionPose> poses = {
    EveEmotion.neutral: EveEmotionPose(
      mouth: EveMouthShape(Offset(86, 140), Offset(100, 154), Offset(114, 140)),
      browLeft: _neutralBrowLeft,
      browRight: _neutralBrowRight,
      eyelidRestY: -34,
      fertileGlowOpacity: 0,
    ),
    EveEmotion.caring: EveEmotionPose(
      mouth: EveMouthShape(Offset(88, 142), Offset(100, 150), Offset(112, 142)),
      browLeft: EveBrowShape(Offset(54, 88), Offset(68, 94), Offset(80, 91)),
      browRight: EveBrowShape(Offset(120, 91), Offset(132, 94), Offset(146, 88)),
      eyelidRestY: -28,
      fertileGlowOpacity: 0,
    ),
    EveEmotion.warm: EveEmotionPose(
      mouth: EveMouthShape(Offset(84, 138), Offset(100, 162), Offset(116, 138), closed: true),
      browLeft: EveBrowShape(Offset(54, 88), Offset(68, 82), Offset(80, 88)),
      browRight: EveBrowShape(Offset(120, 88), Offset(132, 82), Offset(146, 88)),
      eyelidRestY: -34,
      fertileGlowOpacity: 0,
    ),
    EveEmotion.hype: EveEmotionPose(
      mouth: EveMouthShape(Offset(82, 136), Offset(100, 168), Offset(118, 136), closed: true),
      browLeft: EveBrowShape(Offset(54, 84), Offset(68, 78), Offset(80, 84)),
      browRight: EveBrowShape(Offset(120, 84), Offset(132, 78), Offset(146, 84)),
      eyelidRestY: -34,
      fertileGlowOpacity: 0,
    ),
    EveEmotion.sassy: EveEmotionPose(
      mouth: EveMouthShape(Offset(88, 144), Offset(100, 138), Offset(112, 142)),
      browLeft: EveBrowShape(Offset(54, 86), Offset(68, 80), Offset(80, 88)),
      browRight: EveBrowShape(Offset(120, 92), Offset(132, 94), Offset(146, 90)),
      eyelidRestY: -32,
      fertileGlowOpacity: 0,
    ),
    EveEmotion.fertile: EveEmotionPose(
      // Note: fertile's mouth control-point y is 156, distinct from
      // neutral's 154 by 2px — copied exactly from mockv4.html:2248-2249,
      // not a typo. Brows and eyelid fall through to the same declared
      // defaults neutral uses (the fertile branch never reassigns them).
      mouth: EveMouthShape(Offset(86, 140), Offset(100, 156), Offset(114, 140)),
      browLeft: _neutralBrowLeft,
      browRight: _neutralBrowRight,
      eyelidRestY: -34,
      fertileGlowOpacity: 0.8,
    ),
  };
}
