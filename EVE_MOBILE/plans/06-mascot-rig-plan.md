# EVE Mascot Rig Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the SVG pomegranate mascot rig from `UI/mobile/mockv4.html` as a native Flutter `CustomPainter` + `AnimationController` system — one reusable `EveMascot` widget, not a singleton, that renders 6 emotion states and a 3-stage peel/growth progression with idle float, blink, and smooth state-transition animation.

**Architecture:** Geometry (raw path coordinate data), emotion data (path-variant table + interpolation), and rendering (`CustomPainter`) are three separate files with zero animation knowledge in the painter — the painter is a pure function of already-resolved pose values (mouth/brow paths, eyelid Y, crown scale/rotation, seed opacities, idle float offset). All animation state (idle sine loop, periodic blink, emotion-transition tween, peel-transition tween) lives in the public `EveMascot` widget's private `State`, which owns per-instance `AnimationController`s on its own `vsync` and disposes them on unmount. This keeps the painter trivially testable (construct it with fixed numbers, assert canvas output) and keeps animation orchestration in exactly one place.

**Tech Stack:** Flutter/Dart, `dart:ui`/`package:flutter/material.dart` only (`CustomPainter`, `AnimationController`, `Ticker` via `TickerProviderStateMixin`, `Timer` from `dart:async`) — no new pub packages. `flutter_test` for widget tests and `matchesGoldenFile` for golden-image regression tests.

## Global Constraints

- Canonical file paths (design-spec §9, fixed, do not deviate): `EVE_MOBILE/app/lib/features/mascot/eve_mascot.dart`, `eve_mascot_painter.dart`, `eve_rig_geometry.dart`, `eve_emotion.dart`. Tests mirror under `EVE_MOBILE/app/test/features/mascot/`.
- Public interface is fixed verbatim (design-spec §10) — do not add constructor parameters, rename fields, or invent additional `EveEmotion` values:
  ```dart
  enum EveEmotion { neutral, caring, warm, hype, sassy, fertile }

  class EveMascot extends StatelessWidget {
    const EveMascot({
      required this.emotion,
      this.peelPercent = 100,
      this.size = 120,
    });
    final EveEmotion emotion;
    final double peelPercent; // 0-100, drives crown/seed-row growth stage
    final double size;
  }
  ```
- `EveMascot` must literally be a `StatelessWidget` per the contract above. Because animation requires a `vsync`, `EveMascot.build()` delegates to a private `_EveMascotBody` `StatefulWidget` that owns all `AnimationController`s. This satisfies both the fixed public API and the animation requirement.
- Source viewBox is `viewBox="0 -40 200 260"` (width 200, height 260, y origin shifted -40). All raw coordinates in this plan are copied verbatim from `UI/mobile/mockv4.html` lines 1165-1282 (SVG template) and lines 2218-2275 (`setMascotEmotion`/`setMascotPeel`). Every `M`/`C`/`Q`/`Z` command in the source template is absolute (uppercase) — there are no relative commands to convert.
- SVG → Flutter command mapping used throughout: `M x,y` → `moveTo(x,y)`; `C x1,y1 x2,y2 x,y` → `cubicTo(x1,y1,x2,y2,x,y)`; `Q cx,cy x,y` → `quadraticBezierTo(cx,cy,x,y)`; `Z` → `close()`.
- Peel thresholds are exact and copied from `setMascotPeel` (mockv4.html:2262-2275): `percent < 35` → crown `scale(1)`, no rotation, only seed-row-1 visible. `35 <= percent < 70` → crown `scale(1.08) rotate(-4deg)`, seed-row-2 visible. `percent >= 70` → crown `scale(1.15) rotate(-8deg)`, seed-row-3 visible. Seed-row-1 is always visible regardless of percent.
- Emotion pose values (mouth/brow `d` strings, eyelid resting Y, fertile-glow opacity) are copied exactly from the `setMascotEmotion` function body (mockv4.html:2221-2260) — **not** from the static template defaults, which differ by 1-2px in a few places from the JS-computed "neutral" defaults (flagged as a found source inconsistency in the Self-Review section; JS values are canonical because `setMascotEmotion` runs unconditionally for every configured mascot instance and overwrites the template).
- `EveMascot` is explicitly not a singleton (design-spec §4): many instances exist simultaneously (one per onboarding screen, one each on Home/Chat/Log). Every `AnimationController`/`Timer` created by an instance must be created in that instance's own `State.initState()` and disposed in that instance's own `State.dispose()` — never shared globally.
- Fertile state stays visually subtle per EVE2_PRD §6 — no bounce/scale added to the fertile-glow ellipse beyond the opacity fade already specified; do not invent extra motion for it.
- No emojis in code, comments, or any string literal (EVE2_PRD copy-voice rule applies project-wide).
- This plan assumes `EVE_MOBILE/app/` already exists as an initialized Flutter package (owned by Plan 3/4's setup). If it does not yet exist when this plan is executed, run `flutter create --org com.eve --platforms=android,ios EVE_MOBILE/app` first (one-time, out of this plan's scope) so `EVE_MOBILE/app/lib/` and `EVE_MOBILE/app/test/` exist before Task 1, Step 1.
- Every animation-timing constant this plan introduces beyond what the mock specifies (emotion-transition duration/curve, peel-transition duration/curve, blink close/open duration split) is a deliberate, documented choice — the mock itself snaps these instantly with no CSS transition on the affected elements (only `.peel-transition`-classed pith/crown elements had any transition in the mock, and even that duration is not given in the JS/SVG excerpt this plan was scoped against). Values chosen here are noted inline as "chosen, not literally specified."

---

## Task 1: `EveRigGeometry` — static path/shape data for every non-emotion body part

**Files:**
- Create: `EVE_MOBILE/app/lib/features/mascot/eve_rig_geometry.dart`
- Test: `EVE_MOBILE/app/test/features/mascot/eve_rig_geometry_test.dart`

**Interfaces:**
- Consumes: nothing (leaf data module).
- Produces (used by Task 3 painter and Task 4/6 widget code):
  - `class EveRigColors` — static `Color` constants (exact hex from the mock).
  - `class EveHighlightDot { final Offset center; final double radius; final double opacity; }`
  - `class EveSeedNode { final Path path; final Color fill; final List<EveHighlightDot> highlights; }`
  - `class EveSeedRow { final List<EveSeedNode> nodes; final double restScale; final Offset restTranslate; }`
  - `class EvePeelStage { final double crownScale; final double crownRotationDegrees; final bool seedRow2Visible; final bool seedRow3Visible; factory EvePeelStage.fromPercent(double percent); }`
  - `class EveRigGeometry` — static methods/constants: `bodyOutline()`, `bodyMainShell()`, `bodyUndersideShadow()`, `topPithLiner()`, `topCreamPith()`, `crownBackLeft()`, `crownBackRight()`, `crownFrontLeft()`, `crownFrontRight()`, `crownFrontCenter()`, `seedRow1()`, `seedRow2()`, `seedRow3()`, `armLeft()`, `armRight()`, `armLeftOrigin`, `armRightOrigin`, `crownTransformOrigin`, `fertileGlowRect`, `underEyePatchLeft`, `underEyePatchRight`, `eyeCenterLeft`, `eyeCenterRight`, `eyelidRect(Offset eyeCenter, double translateY)`, `footLeft`, `footRight`, `outlineStrokeWidth3_5`, `crownStrokeWidth`, `pithStrokeWidth`.

- [ ] **Step 1: Create the mascot feature directory and write the failing geometry test (body shell + one crown piece — the two pieces the task requires as a full worked example)**

Create `EVE_MOBILE/app/test/features/mascot/eve_rig_geometry_test.dart`:

```dart
import 'package:eve/features/mascot/eve_rig_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EveRigGeometry body shell', () {
    test('bodyMainShell is a closed path whose fill contains the visual center '
        'and excludes a point clearly outside the pomegranate silhouette', () {
      final path = EveRigGeometry.bodyMainShell();
      // Body shell spans roughly x:20-180, y:44-194 (mockv4.html:1177). Center ~ (100,119).
      expect(path.contains(const Offset(100, 119)), isTrue);
      expect(path.contains(const Offset(0, 0)), isFalse);
      expect(path.contains(const Offset(199, 219)), isFalse);
    });

    test('bodyOutline is larger than bodyMainShell (it is the underlying dark '
        'silhouette drawn first, per mockv4.html:1176-1177)', () {
      final outline = EveRigGeometry.bodyOutline().getBounds();
      final shell = EveRigGeometry.bodyMainShell().getBounds();
      expect(outline.width, greaterThan(shell.width));
      expect(outline.height, greaterThan(shell.height));
    });
  });

  group('EveRigGeometry crown', () {
    test('crownBackLeft contains a point inside its triangular wedge and '
        'excludes the mascot body center (mockv4.html:1229)', () {
      final path = EveRigGeometry.crownBackLeft();
      // Wedge runs roughly between (68,44), (60,26)-ish control, (92,44) tip area.
      expect(path.contains(const Offset(74, 35)), isTrue);
      expect(path.contains(const Offset(100, 119)), isFalse);
    });

    test('all five crown pieces exist and are non-empty paths', () {
      final pieces = [
        EveRigGeometry.crownBackLeft(),
        EveRigGeometry.crownBackRight(),
        EveRigGeometry.crownFrontLeft(),
        EveRigGeometry.crownFrontRight(),
        EveRigGeometry.crownFrontCenter(),
      ];
      for (final p in pieces) {
        expect(p.getBounds().isEmpty, isFalse);
      }
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails (file does not exist yet)**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_rig_geometry_test.dart`
Expected: FAIL — `Error: Not found: 'package:eve/features/mascot/eve_rig_geometry.dart'`

(If the app's package name is not `eve`, use whatever `name:` field `EVE_MOBILE/app/pubspec.yaml` declares — Plan 3 fixes this; substitute consistently in every import in this plan.)

- [ ] **Step 3: Write `eve_rig_geometry.dart` — colors, body shell (worked example), crown (worked example)**

Create `EVE_MOBILE/app/lib/features/mascot/eve_rig_geometry.dart`:

```dart
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_rig_geometry_test.dart`
Expected: PASS — all 4 tests green.

- [ ] **Step 5: Add remaining geometry coverage tests (seed rows, eyes, arms, peel stage) and confirm they pass against the file already written**

Append to `EVE_MOBILE/app/test/features/mascot/eve_rig_geometry_test.dart` (inside `main()`, as new `group`s):

```dart
  group('EveRigGeometry seed rows', () {
    test('row counts match the mock (1 seed row = 3 nodes, rows 2/3 = 2 and 3 nodes)', () {
      expect(EveRigGeometry.seedRow1().nodes.length, 3);
      expect(EveRigGeometry.seedRow2().nodes.length, 2);
      expect(EveRigGeometry.seedRow3().nodes.length, 3);
    });

    test('rows 2 and 3 carry the baked-in rest scale/translate from mockv4.html:1200,1211', () {
      expect(EveRigGeometry.seedRow2().restScale, 0.82);
      expect(EveRigGeometry.seedRow2().restTranslate, const Offset(0, -10));
      expect(EveRigGeometry.seedRow3().restScale, 0.82);
      expect(EveRigGeometry.seedRow3().restTranslate, const Offset(0, -14));
      expect(EveRigGeometry.seedRow1().restScale, 1.0);
    });
  });

  group('EveRigGeometry eyes and eyelids', () {
    test('eyelidRect resolves the correct absolute x for each eye (mockv4.html:1259,1271)', () {
      final left = EveRigGeometry.eyelidRect(EveRigGeometry.eyeCenterLeft, -34);
      final right = EveRigGeometry.eyelidRect(EveRigGeometry.eyeCenterRight, -34);
      expect(left.left, 50);
      expect(right.left, 114);
      expect(left.top, 51); // 85 + (-34)
      expect(left.width, 36);
      expect(left.height, 34);
    });

    test('eyelidRect at translateY=0 sits over the eye socket (closed/blink state)', () {
      final rect = EveRigGeometry.eyelidRect(EveRigGeometry.eyeCenterLeft, 0);
      final socket = EveRigGeometry.eyeSocketRect(EveRigGeometry.eyeCenterLeft);
      expect(rect.overlaps(socket), isTrue);
    });
  });

  group('EvePeelStage.fromPercent', () {
    test('below 35 percent: flat crown, only row 1 implied visible', () {
      final stage = EvePeelStage.fromPercent(10);
      expect(stage.crownScale, 1.0);
      expect(stage.crownRotationDegrees, 0);
      expect(stage.seedRow2Visible, isFalse);
      expect(stage.seedRow3Visible, isFalse);
    });

    test('35 to just under 70: crown scale 1.08, rotate -4, row 2 visible, row 3 not', () {
      final stage = EvePeelStage.fromPercent(35);
      expect(stage.crownScale, 1.08);
      expect(stage.crownRotationDegrees, -4);
      expect(stage.seedRow2Visible, isTrue);
      expect(stage.seedRow3Visible, isFalse);

      final justBelow70 = EvePeelStage.fromPercent(69.999);
      expect(justBelow70.crownScale, 1.08);
    });

    test('70 and above: crown scale 1.15, rotate -8, both rows visible', () {
      final stage = EvePeelStage.fromPercent(70);
      expect(stage.crownScale, 1.15);
      expect(stage.crownRotationDegrees, -8);
      expect(stage.seedRow2Visible, isTrue);
      expect(stage.seedRow3Visible, isTrue);
    });
  });

  group('EveRigGeometry arms', () {
    test('arm origins match mockv4.html transform-origin attributes (1236, 1240)', () {
      expect(EveRigGeometry.armLeftOrigin, const Offset(34, 135));
      expect(EveRigGeometry.armRightOrigin, const Offset(166, 135));
      expect(EveRigGeometry.armLeft().getBounds().isEmpty, isFalse);
      expect(EveRigGeometry.armRight().getBounds().isEmpty, isFalse);
    });
  });
```

- [ ] **Step 6: Run the full geometry test file**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_rig_geometry_test.dart`
Expected: PASS — all tests green (12 tests total).

- [ ] **Step 7: Commit**

```bash
git add EVE_MOBILE/app/lib/features/mascot/eve_rig_geometry.dart EVE_MOBILE/app/test/features/mascot/eve_rig_geometry_test.dart
git commit -m "feat(mascot): port rig geometry (body, crown, seeds, eyes, arms) from SVG template"
```

---

## Task 2: `EveEmotion` enum + emotion pose data table

**Files:**
- Create: `EVE_MOBILE/app/lib/features/mascot/eve_emotion.dart`
- Test: `EVE_MOBILE/app/test/features/mascot/eve_emotion_test.dart`

**Interfaces:**
- Consumes: nothing (leaf data module; independent of `eve_rig_geometry.dart`).
- Produces (used by Task 3 painter and Task 5 widget code):
  - `enum EveEmotion { neutral, caring, warm, hype, sassy, fertile }`
  - `class EveBrowShape { final Offset start, control, end; Path toPath(); static EveBrowShape lerp(a, b, t); }`
  - `class EveMouthShape { final Offset start, control, end; final bool closed; Path toPath(); static EveMouthShape lerp(a, b, t); }`
  - `class EveEmotionPose { final EveMouthShape mouth; final EveBrowShape browLeft, browRight; final double eyelidRestY; final double fertileGlowOpacity; static EveEmotionPose lerp(a, b, t); }`
  - `class EveEmotionTable { static const Map<EveEmotion, EveEmotionPose> poses; }`

- [ ] **Step 1: Write the failing test — data table values ported exactly from `setMascotEmotion`**

Create `EVE_MOBILE/app/test/features/mascot/eve_emotion_test.dart`:

```dart
import 'package:eve/features/mascot/eve_emotion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EveEmotionTable — exact values from setMascotEmotion (mockv4.html:2218-2260)', () {
    test('neutral uses the JS default-branch values, not the template default', () {
      final pose = EveEmotionTable.poses[EveEmotion.neutral]!;
      // Default mouthPath = "M 86,140 Q 100,154 114,140" -> control point y=154.
      expect(pose.mouth.start, const Offset(86, 140));
      expect(pose.mouth.control, const Offset(100, 154));
      expect(pose.mouth.end, const Offset(114, 140));
      expect(pose.mouth.closed, isFalse);
      expect(pose.browLeft.start, const Offset(54, 92));
      expect(pose.browLeft.control, const Offset(68, 88));
      expect(pose.browLeft.end, const Offset(80, 92));
      expect(pose.browRight.control, const Offset(132, 88));
      expect(pose.eyelidRestY, -34);
      expect(pose.fertileGlowOpacity, 0);
    });

    test('caring (covers caring/hug/concerned) matches lines 2227-2231', () {
      final pose = EveEmotionTable.poses[EveEmotion.caring]!;
      expect(pose.mouth.start, const Offset(88, 142));
      expect(pose.mouth.control, const Offset(100, 150));
      expect(pose.mouth.end, const Offset(112, 142));
      expect(pose.browLeft.control, const Offset(68, 94));
      expect(pose.browRight.start, const Offset(120, 91));
      expect(pose.eyelidRestY, -28);
    });

    test('warm (covers warm/happy/positive) is a closed mouth path per lines 2232-2236', () {
      final pose = EveEmotionTable.poses[EveEmotion.warm]!;
      expect(pose.mouth.start, const Offset(84, 138));
      expect(pose.mouth.control, const Offset(100, 162));
      expect(pose.mouth.end, const Offset(116, 138));
      expect(pose.mouth.closed, isTrue);
      expect(pose.eyelidRestY, -34);
    });

    test('hype matches lines 2237-2241', () {
      final pose = EveEmotionTable.poses[EveEmotion.hype]!;
      expect(pose.mouth.control, const Offset(100, 168));
      expect(pose.mouth.closed, isTrue);
      expect(pose.browLeft.control, const Offset(68, 78));
    });

    test('sassy matches lines 2242-2246', () {
      final pose = EveEmotionTable.poses[EveEmotion.sassy]!;
      expect(pose.mouth.control, const Offset(100, 138));
      expect(pose.mouth.closed, isFalse);
      expect(pose.eyelidRestY, -32);
      expect(pose.browRight.start, const Offset(120, 92));
    });

    test('fertile keeps neutral brows/eyelid but a distinct mouth control-y '
        'of 156 (not 154) and 0.8 fertile-glow opacity, per lines 2247-2250', () {
      final pose = EveEmotionTable.poses[EveEmotion.fertile]!;
      expect(pose.mouth.control, const Offset(100, 156));
      expect(pose.browLeft, EveEmotionTable.poses[EveEmotion.neutral]!.browLeft);
      expect(pose.eyelidRestY, -34);
      expect(pose.fertileGlowOpacity, 0.8);
    });

    test('all 6 EveEmotion values have a table entry', () {
      for (final e in EveEmotion.values) {
        expect(EveEmotionTable.poses.containsKey(e), isTrue, reason: '$e missing from table');
      }
    });
  });

  group('shape lerp', () {
    test('EveBrowShape.lerp at t=0 and t=1 returns the endpoints exactly', () {
      const a = EveBrowShape(Offset(0, 0), Offset(1, 1), Offset(2, 2));
      const b = EveBrowShape(Offset(10, 10), Offset(11, 11), Offset(12, 12));
      expect(EveBrowShape.lerp(a, b, 0).start, a.start);
      expect(EveBrowShape.lerp(a, b, 1).start, b.start);
      expect(EveBrowShape.lerp(a, b, 0.5).start, const Offset(5, 5));
    });

    test('EveMouthShape.lerp snaps `closed` at the t=0.5 boundary', () {
      const a = EveMouthShape(Offset(0, 0), Offset(1, 1), Offset(2, 2), closed: false);
      const b = EveMouthShape(Offset(10, 10), Offset(11, 11), Offset(12, 12), closed: true);
      expect(EveMouthShape.lerp(a, b, 0.49).closed, isFalse);
      expect(EveMouthShape.lerp(a, b, 0.5).closed, isTrue);
    });

    test('EveEmotionPose.lerp interpolates fertileGlowOpacity and eyelidRestY', () {
      final a = EveEmotionTable.poses[EveEmotion.neutral]!;
      final b = EveEmotionTable.poses[EveEmotion.fertile]!;
      final mid = EveEmotionPose.lerp(a, b, 0.5);
      expect(mid.fertileGlowOpacity, closeTo(0.4, 0.001));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_emotion_test.dart`
Expected: FAIL — `eve_emotion.dart` not found.

- [ ] **Step 3: Write `eve_emotion.dart`**

Create `EVE_MOBILE/app/lib/features/mascot/eve_emotion.dart`:

```dart
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_emotion_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/mascot/eve_emotion.dart EVE_MOBILE/app/test/features/mascot/eve_emotion_test.dart
git commit -m "feat(mascot): port EveEmotion pose data table from setMascotEmotion"
```

---

## Task 3: `EveMascotPainter` — static single-frame render

**Files:**
- Create: `EVE_MOBILE/app/lib/features/mascot/eve_mascot_painter.dart`
- Test: `EVE_MOBILE/app/test/features/mascot/eve_mascot_painter_test.dart`

**Interfaces:**
- Consumes: `EveRigGeometry`/`EveRigColors`/`EvePeelStage` (Task 1), `EveMouthShape`/`EveBrowShape` (Task 2).
- Produces (used by Task 4-7 widget code and Task 8 golden tests):
  - `class EveMascotPainter extends CustomPainter` with constructor:
    ```dart
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
    ```
    All fields are fully-resolved numeric/shape values — the painter has **no** knowledge of `EveEmotion` or peel percent; it just draws whatever pose it is given. This is what makes it a pure, trivially-testable render target for every later animation task (they compute the interpolated values and pass them in; they never touch this file again).
  - `EveMascotPainter.forState({required EveEmotion emotion, required double peelPercent})` factory — convenience constructor that looks up `EveEmotionTable.poses[emotion]` and `EvePeelStage.fromPercent(peelPercent)` and builds a fully-resolved (non-animated) painter. Used by Task 8's golden tests and by `EveMascot`'s very first frame before any controller has ticked.

- [ ] **Step 1: Write the failing test**

Create `EVE_MOBILE/app/test/features/mascot/eve_mascot_painter_test.dart`:

```dart
import 'dart:ui' as ui;
import 'package:eve/features/mascot/eve_emotion.dart';
import 'package:eve/features/mascot/eve_mascot_painter.dart';
import 'package:eve/features/mascot/eve_rig_geometry.dart';
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_mascot_painter_test.dart`
Expected: FAIL — `eve_mascot_painter.dart` not found.

- [ ] **Step 3: Write `eve_mascot_painter.dart`**

Create `EVE_MOBILE/app/lib/features/mascot/eve_mascot_painter.dart`:

```dart
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
      Paint()..color = EveRigColors.creamPith.withOpacity(0.9),
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
      canvas.drawPath(node.path, Paint()..color = node.fill.withOpacity(opacity));
      canvas.drawPath(
        node.path,
        Paint()
          ..color = EveRigColors.outlineDark.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = EveRigGeometry.seedStrokeWidth,
      );
      for (final dot in node.highlights) {
        canvas.drawCircle(dot.center, dot.radius, Paint()..color = Colors.white.withOpacity(dot.opacity * opacity));
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
      Paint()..color = EveRigColors.fertileGlow.withOpacity(fertileGlowOpacity),
    );
  }

  void _drawUnderEyePatches(Canvas canvas) {
    final paint = Paint()..color = EveRigColors.underEyePatch.withOpacity(0.9);
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_mascot_painter_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 5: Manual demo checkpoint**

Add a temporary scratch screen (or use `flutter run` with a throwaway `main()`) rendering `CustomPaint(size: const Size(200,260), painter: EveMascotPainter.forState(emotion: EveEmotion.neutral, peelPercent: 20))` inside a plain `MaterialApp`/`Scaffold` to visually confirm: a pink pomegranate silhouette with a flat (unscaled) crown, only the top seed row visible, a neutral face, and no fertile glow. Delete the scratch screen after confirming — it is not part of the deliverable.

- [ ] **Step 6: Commit**

```bash
git add EVE_MOBILE/app/lib/features/mascot/eve_mascot_painter.dart EVE_MOBILE/app/test/features/mascot/eve_mascot_painter_test.dart
git commit -m "feat(mascot): static single-frame EveMascotPainter with peel-stage seed visibility"
```

---

## Task 4: Idle physics — per-instance `AnimationController` float + periodic blink

**Files:**
- Create: `EVE_MOBILE/app/lib/features/mascot/eve_mascot.dart`
- Test: `EVE_MOBILE/app/test/features/mascot/eve_mascot_idle_test.dart`

**Interfaces:**
- Consumes: `EveMascotPainter` (Task 3), `EveEmotionTable`/`EveEmotion` (Task 2), `EvePeelStage` (Task 1).
- Produces (extended by Tasks 5-7, consumed by Task 8): `class EveMascot extends StatelessWidget` (public, fixed signature) wrapping `class _EveMascotBody extends StatefulWidget` / `_EveMascotBodyState`.

### Architecture decision: per-instance controllers, not a shared ticker

The mock's `runIdleAnimation` (mockv4.html:2298-2326) drives every mascot instance from one shared `idleTime` variable and one shared `requestAnimationFrame` loop — but that is an artifact of it being a single HTML page with a handful of DOM nodes, not a deliberate design requirement. Nothing in `EVE2_PRD.md` §6 or the design spec asks for cross-instance-synchronized floating/blinking. Given design-spec §4's explicit "not a singleton" note — many `EveMascot` instances are mounted and unmounted independently across 23+ onboarding screens plus Home/Chat/Log — this plan gives **each `EveMascot` instance its own `AnimationController`s on its own `vsync`** (via `TickerProviderStateMixin` in `_EveMascotBodyState`), for three reasons:

1. It is the idiomatic Flutter pattern; a shared global ticker would require a hand-rolled registry to add/remove instances as screens mount and unmount, which is real complexity bought for a purely cosmetic (and unrequired) sync benefit.
2. Per-instance controllers make `dispose()` trivial and impossible to get wrong: each instance owns exactly what it created.
3. A shared ticker persisting across navigation is a leak risk if any instance forgets to unregister; per-instance controllers tied to `State.dispose()` cannot leak past their widget's lifetime.

### Idle float and blink timing, derived from the mock

- `idleTime += 0.03` per animation frame (mockv4.html:2299); assuming the standard 60fps `requestAnimationFrame` cadence (not stated explicitly in the excerpt scoped for this plan — flagged as an assumption), that is a rate of `0.03 * 60 = 1.8` rad/sec. `floatOffset = sin(idleTime) * 2` therefore completes one full sine cycle every `2*pi/1.8 ≈ 3.4907s ≈ 3491ms`. This plan reproduces it with an `AnimationController(duration: Duration(milliseconds: 3491))..repeat()` whose `value` (0→1, repeating) is mapped back to radians via `value * 2 * pi`, giving the identical `sin(...) * 2` waveform.
- Blink trigger `Math.floor(idleTime * 10) % 35 === 0` (mockv4.html:2302) fires roughly every `35 / (0.3 * 60) ≈ 1.944s ≈ 1944ms` (since `idleTime*10` grows by `0.3`/frame at 60fps). This plan reproduces the cadence with `Timer.periodic(const Duration(milliseconds: 1944), ...)`.
- The mock holds the eyelid at fully-closed (`translate(0,0)`) for exactly 150ms via `setTimeout` with an instant snap, no easing (mockv4.html:2302-2305, 2313-2321). This plan uses a 150ms round trip on a dedicated `AnimationController` (75ms close + 75ms reopen) instead of an instant snap-and-hold, for a smoother native feel — a deliberate, flagged enhancement, not a literal port (see Global Constraints).

- [ ] **Step 1: Write the failing test — idle float and blink are driven by real (fake-async) time**

Create `EVE_MOBILE/app/test/features/mascot/eve_mascot_idle_test.dart`:

```dart
import 'dart:math' as math;
import 'package:eve/features/mascot/eve_emotion.dart';
import 'package:eve/features/mascot/eve_mascot.dart';
import 'package:eve/features/mascot/eve_mascot_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EveMascotPainter _painterOf(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
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
    await tester.pump(const Duration(milliseconds: 200));
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_mascot_idle_test.dart`
Expected: FAIL — `eve_mascot.dart` not found.

- [ ] **Step 3: Write `eve_mascot.dart` (idle float + blink only; emotion/peel changes are not yet animated — they will resolve instantly on rebuild until Tasks 5-6 add transition controllers)**

Create `EVE_MOBILE/app/lib/features/mascot/eve_mascot.dart`:

```dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'eve_emotion.dart';
import 'eve_mascot_painter.dart';
import 'eve_rig_geometry.dart';

/// The public mascot widget. See design-spec §10 for the fixed contract.
/// This stays a `StatelessWidget` per that contract; all animation state
/// lives in the private `_EveMascotBody` it delegates to, which owns its
/// own `AnimationController`s on its own `vsync` (see Task 4's
/// architecture-decision note in the plan for why this is per-instance,
/// not shared).
class EveMascot extends StatelessWidget {
  const EveMascot({
    super.key,
    required this.emotion,
    this.peelPercent = 100,
    this.size = 120,
  });

  final EveEmotion emotion;
  final double peelPercent; // 0-100, drives crown/seed-row growth stage
  final double size;

  @override
  Widget build(BuildContext context) {
    return _EveMascotBody(emotion: emotion, peelPercent: peelPercent, size: size);
  }
}

class _EveMascotBody extends StatefulWidget {
  const _EveMascotBody({required this.emotion, required this.peelPercent, required this.size});

  final EveEmotion emotion;
  final double peelPercent;
  final double size;

  @override
  State<_EveMascotBody> createState() => _EveMascotBodyState();
}

class _EveMascotBodyState extends State<_EveMascotBody> with TickerProviderStateMixin {
  static const _idlePeriod = Duration(milliseconds: 3491); // see Task 4 derivation
  static const _blinkInterval = Duration(milliseconds: 1944);
  static const _blinkLegDuration = Duration(milliseconds: 75); // close, then reopen

  late final AnimationController _idleController;
  late final AnimationController _blinkController;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(vsync: this, duration: _idlePeriod)..repeat();
    _blinkController = AnimationController(vsync: this, duration: _blinkLegDuration);
    _blinkTimer = Timer.periodic(_blinkInterval, (_) => _runBlink());
  }

  Future<void> _runBlink() async {
    if (!mounted) return;
    await _blinkController.forward(from: 0);
    if (!mounted) return;
    await _blinkController.reverse();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _idleController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idleController, _blinkController]),
      builder: (context, _) {
        final idleFloatOffset = math.sin(_idleController.value * 2 * math.pi) * 2;
        final pose = EveEmotionTable.poses[widget.emotion]!;
        final stage = EvePeelStage.fromPercent(widget.peelPercent);
        final eyelidY = ui.lerpDouble(pose.eyelidRestY, 0, _blinkController.value)!;

        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: EveMascotPainter(
            mouth: pose.mouth,
            browLeft: pose.browLeft,
            browRight: pose.browRight,
            eyelidY: eyelidY,
            fertileGlowOpacity: pose.fertileGlowOpacity,
            crownScale: stage.crownScale,
            crownRotationDegrees: stage.crownRotationDegrees,
            seedRow2Opacity: stage.seedRow2Visible ? 1 : 0,
            seedRow3Opacity: stage.seedRow3Visible ? 1 : 0,
            idleFloatOffset: idleFloatOffset,
          ),
        );
      },
    );
  }
}
```

Add the `dart:ui` import needed for `lerpDouble` at the top of the file, alongside the existing imports:

```dart
import 'dart:ui' as ui;
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_mascot_idle_test.dart`
Expected: PASS — all 3 tests green.

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/mascot/eve_mascot.dart EVE_MOBILE/app/test/features/mascot/eve_mascot_idle_test.dart
git commit -m "feat(mascot): EveMascot widget with per-instance idle float + blink AnimationControllers"
```

---

## Task 5: Emotion-transition animation (smooth mouth/brow/eyelid/fertile-glow lerp)

**Files:**
- Modify: `EVE_MOBILE/app/lib/features/mascot/eve_mascot.dart`
- Test: `EVE_MOBILE/app/test/features/mascot/eve_mascot_transition_test.dart`

**Interfaces:**
- Consumes: `EveEmotionPose.lerp` (Task 2, already implemented and unit-tested there).
- Produces: `_EveMascotBodyState` now animates emotion changes; no change to `EveMascot`'s own public constructor.

Chosen transition duration/curve (not specified in the mock, which snaps instantly — see Global Constraints): **220ms, `Curves.easeInOut`**. This is a standard microinteraction duration, short enough not to feel laggy when a screen advances but long enough to read as a deliberate expression change rather than a flicker.

- [ ] **Step 1: Write the failing test**

Create `EVE_MOBILE/app/test/features/mascot/eve_mascot_transition_test.dart`:

```dart
import 'package:eve/features/mascot/eve_emotion.dart';
import 'package:eve/features/mascot/eve_mascot.dart';
import 'package:eve/features/mascot/eve_mascot_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EveMascotPainter _painterOf(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
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
    await tester.pump(); // one frame into the 220ms transition
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_mascot_transition_test.dart`
Expected: FAIL — emotion currently snaps instantly (no transition controller yet), so `midY`/`midOpacity` assertions fail.

- [ ] **Step 3: Modify `eve_mascot.dart` to add the emotion-transition controller**

In `EVE_MOBILE/app/lib/features/mascot/eve_mascot.dart`, add a field and constant to `_EveMascotBodyState`:

```dart
  static const _emotionTransitionDuration = Duration(milliseconds: 220); // chosen, not literally specified — see Task 5

  late final AnimationController _emotionTransitionController;
  EveEmotion? _previousEmotion;
```

Update `initState()`:

```dart
  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(vsync: this, duration: _idlePeriod)..repeat();
    _blinkController = AnimationController(vsync: this, duration: _blinkLegDuration);
    _emotionTransitionController = AnimationController(vsync: this, duration: _emotionTransitionDuration)
      ..value = 1.0; // start fully "settled" on the initial emotion, nothing to transition from
    _blinkTimer = Timer.periodic(_blinkInterval, (_) => _runBlink());
  }
```

Add `didUpdateWidget`:

```dart
  @override
  void didUpdateWidget(covariant _EveMascotBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emotion != widget.emotion) {
      _previousEmotion = oldWidget.emotion;
      _emotionTransitionController
        ..value = 0
        ..forward();
    }
  }
```

Update `dispose()`:

```dart
  @override
  void dispose() {
    _blinkTimer?.cancel();
    _idleController.dispose();
    _blinkController.dispose();
    _emotionTransitionController.dispose();
    super.dispose();
  }
```

Update `build()` to merge in the new controller and interpolate the pose:

```dart
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idleController, _blinkController, _emotionTransitionController]),
      builder: (context, _) {
        final idleFloatOffset = math.sin(_idleController.value * 2 * math.pi) * 2;
        final targetPose = EveEmotionTable.poses[widget.emotion]!;
        final t = Curves.easeInOut.transform(_emotionTransitionController.value);
        final pose = (_previousEmotion == null || t >= 1.0)
            ? targetPose
            : EveEmotionPose.lerp(EveEmotionTable.poses[_previousEmotion!]!, targetPose, t);
        final stage = EvePeelStage.fromPercent(widget.peelPercent);
        final eyelidY = ui.lerpDouble(pose.eyelidRestY, 0, _blinkController.value)!;

        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: EveMascotPainter(
            mouth: pose.mouth,
            browLeft: pose.browLeft,
            browRight: pose.browRight,
            eyelidY: eyelidY,
            fertileGlowOpacity: pose.fertileGlowOpacity,
            crownScale: stage.crownScale,
            crownRotationDegrees: stage.crownRotationDegrees,
            seedRow2Opacity: stage.seedRow2Visible ? 1 : 0,
            seedRow3Opacity: stage.seedRow3Visible ? 1 : 0,
            idleFloatOffset: idleFloatOffset,
          ),
        );
      },
    );
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_mascot_transition_test.dart`
Expected: PASS — both tests green.

- [ ] **Step 5: Re-run Task 4's idle test to confirm no regression**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_mascot_idle_test.dart`
Expected: PASS — still green (emotion-transition controller starts at `value = 1.0` and does not affect idle/blink behavior when `emotion` never changes).

- [ ] **Step 6: Commit**

```bash
git add EVE_MOBILE/app/lib/features/mascot/eve_mascot.dart EVE_MOBILE/app/test/features/mascot/eve_mascot_transition_test.dart
git commit -m "feat(mascot): animate emotion changes via 220ms easeInOut pose lerp instead of snapping"
```

---

## Task 6: Peel-percent-driven crown/seed growth animation

**Files:**
- Modify: `EVE_MOBILE/app/lib/features/mascot/eve_mascot.dart`
- Test: `EVE_MOBILE/app/test/features/mascot/eve_mascot_peel_test.dart`

**Interfaces:**
- Consumes: `EvePeelStage.fromPercent` (Task 1).
- Produces: `_EveMascotBodyState` now animates `peelPercent` changes; no change to `EveMascot`'s public constructor.

Chosen transition: **500ms, `Curves.easeOutBack` for crown scale/rotation** (a slight overshoot reads as a small "bloom pop," appropriate to the growth narrative in EVE2_PRD §6, and stays well short of "celebratory"). Seed-row opacity fades in linearly over the same 500ms window using the controller's raw (un-eased) `value`, deliberately not the `easeOutBack`-eased value, because that curve briefly exceeds `1.0` and an opacity greater than 1 would clamp/no-op rather than visually overshoot — there is nothing to gain from applying it there. Neither duration nor curve is specified in the mock (which only toggles `style.opacity` and `setAttribute('transform', ...)` instantly); both are chosen, flagged design decisions.

- [ ] **Step 1: Write the failing test**

Create `EVE_MOBILE/app/test/features/mascot/eve_mascot_peel_test.dart`:

```dart
import 'package:eve/features/mascot/eve_emotion.dart';
import 'package:eve/features/mascot/eve_mascot.dart';
import 'package:eve/features/mascot/eve_mascot_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EveMascotPainter _painterOf(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_mascot_peel_test.dart`
Expected: FAIL — peel changes currently snap instantly.

- [ ] **Step 3: Modify `eve_mascot.dart` to add the peel-transition controller**

Add fields and constant to `_EveMascotBodyState`:

```dart
  static const _peelTransitionDuration = Duration(milliseconds: 500); // chosen, not literally specified — see Task 6

  late final AnimationController _peelTransitionController;
  EvePeelStage? _previousPeelStage;
```

Update `initState()`:

```dart
  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(vsync: this, duration: _idlePeriod)..repeat();
    _blinkController = AnimationController(vsync: this, duration: _blinkLegDuration);
    _emotionTransitionController = AnimationController(vsync: this, duration: _emotionTransitionDuration)
      ..value = 1.0;
    _peelTransitionController = AnimationController(vsync: this, duration: _peelTransitionDuration)
      ..value = 1.0;
    _blinkTimer = Timer.periodic(_blinkInterval, (_) => _runBlink());
  }
```

Update `didUpdateWidget()`:

```dart
  @override
  void didUpdateWidget(covariant _EveMascotBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emotion != widget.emotion) {
      _previousEmotion = oldWidget.emotion;
      _emotionTransitionController
        ..value = 0
        ..forward();
    }
    if (oldWidget.peelPercent != widget.peelPercent) {
      _previousPeelStage = EvePeelStage.fromPercent(oldWidget.peelPercent);
      _peelTransitionController
        ..value = 0
        ..forward();
    }
  }
```

Update `dispose()`:

```dart
  @override
  void dispose() {
    _blinkTimer?.cancel();
    _idleController.dispose();
    _blinkController.dispose();
    _emotionTransitionController.dispose();
    _peelTransitionController.dispose();
    super.dispose();
  }
```

Update `build()`:

```dart
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
        [_idleController, _blinkController, _emotionTransitionController, _peelTransitionController],
      ),
      builder: (context, _) {
        final idleFloatOffset = math.sin(_idleController.value * 2 * math.pi) * 2;

        final targetPose = EveEmotionTable.poses[widget.emotion]!;
        final emotionT = Curves.easeInOut.transform(_emotionTransitionController.value);
        final pose = (_previousEmotion == null || emotionT >= 1.0)
            ? targetPose
            : EveEmotionPose.lerp(EveEmotionTable.poses[_previousEmotion!]!, targetPose, emotionT);
        final eyelidY = ui.lerpDouble(pose.eyelidRestY, 0, _blinkController.value)!;

        final targetStage = EvePeelStage.fromPercent(widget.peelPercent);
        final fromStage = _previousPeelStage ?? targetStage;
        final peelLinearT = _peelTransitionController.value; // 0..1, used for opacity (never overshoots)
        final peelEasedT = Curves.easeOutBack.transform(peelLinearT); // used for scale/rotation (may overshoot)
        final crownScale = ui.lerpDouble(fromStage.crownScale, targetStage.crownScale, peelEasedT)!;
        final crownRotation =
            ui.lerpDouble(fromStage.crownRotationDegrees, targetStage.crownRotationDegrees, peelEasedT)!;
        final seedRow2Opacity = ui.lerpDouble(
          fromStage.seedRow2Visible ? 1.0 : 0.0,
          targetStage.seedRow2Visible ? 1.0 : 0.0,
          peelLinearT,
        )!
            .clamp(0.0, 1.0);
        final seedRow3Opacity = ui.lerpDouble(
          fromStage.seedRow3Visible ? 1.0 : 0.0,
          targetStage.seedRow3Visible ? 1.0 : 0.0,
          peelLinearT,
        )!
            .clamp(0.0, 1.0);

        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: EveMascotPainter(
            mouth: pose.mouth,
            browLeft: pose.browLeft,
            browRight: pose.browRight,
            eyelidY: eyelidY,
            fertileGlowOpacity: pose.fertileGlowOpacity,
            crownScale: crownScale,
            crownRotationDegrees: crownRotation,
            seedRow2Opacity: seedRow2Opacity,
            seedRow3Opacity: seedRow3Opacity,
            idleFloatOffset: idleFloatOffset,
          ),
        );
      },
    );
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_mascot_peel_test.dart`
Expected: PASS — all 3 tests green.

- [ ] **Step 5: Re-run Task 4 and Task 5 tests to confirm no regression**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_mascot_idle_test.dart test/features/mascot/eve_mascot_transition_test.dart`
Expected: PASS — both files still green.

- [ ] **Step 6: Commit**

```bash
git add EVE_MOBILE/app/lib/features/mascot/eve_mascot.dart EVE_MOBILE/app/test/features/mascot/eve_mascot_peel_test.dart
git commit -m "feat(mascot): animate peel-percent crown scale/rotation and seed-row fade-in over 500ms"
```

---

## Task 7: Public `EveMascot` widget — lifecycle correctness across many simultaneous instances

**Files:**
- Modify: `EVE_MOBILE/app/lib/features/mascot/eve_mascot.dart` (doc comments only — see Step 3; no behavioral change)
- Test: `EVE_MOBILE/app/test/features/mascot/eve_mascot_widget_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1-6.
- Produces: confidence that the exact public contract from design-spec §10 holds and that N simultaneously-mounted instances each independently manage and dispose their own controllers with no leaks or cross-talk — the property design-spec §4's "not a singleton" note exists to guarantee.

By this point `eve_mascot.dart` already has the full constructor `EveMascot({required emotion, this.peelPercent = 100, this.size = 120})` from Task 4 — this task does not change the signature, it verifies it and hardens the doc comments before treating the file as done.

- [ ] **Step 1: Write the failing/pending test — many simultaneous instances, independent state, clean disposal**

Create `EVE_MOBILE/app/test/features/mascot/eve_mascot_widget_test.dart`:

```dart
import 'package:eve/features/mascot/eve_emotion.dart';
import 'package:eve/features/mascot/eve_mascot.dart';
import 'package:eve/features/mascot/eve_mascot_painter.dart';
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

    final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
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
        .widgetList<CustomPaint>(find.byType(CustomPaint))
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
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((cp) => cp.painter)
        .whereType<EveMascotPainter>()
        .toList();
    // First instance now settled on hype (control-y 168); second untouched at warm (control-y 162, closed).
    expect(painters[0].mouth.control.dy, closeTo(168, 0.5));
    expect(painters[1].mouth.control.dy, closeTo(162, 0.5));
    expect(painters[1].mouth.closed, isTrue);
  });
}
```

- [ ] **Step 2: Run the test**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_mascot_widget_test.dart`
Expected: PASS already, since Tasks 4-6 built the full widget — this task's job is to confirm that, not to add new behavior. If anything fails, it indicates a lifecycle bug in Task 4-6's implementation (most likely a controller not being isolated per-`State`); fix it in `eve_mascot.dart` before proceeding, re-running until green.

- [ ] **Step 3: Finalize doc comments on the public widget**

In `EVE_MOBILE/app/lib/features/mascot/eve_mascot.dart`, replace the existing short comment above `class EveMascot` with:

```dart
/// The pomegranate mascot ("Eve" / "Pomme"). Renders the shared rig — one
/// body, one crown, one face — at any [size], reflecting [emotion] and how
/// far onboarding has progressed via [peelPercent] (0-100; crown/seed-row
/// growth thresholds at 35 and 70, see `EvePeelStage.fromPercent`).
///
/// Not a singleton: every screen that shows Eve (every onboarding screen
/// plus Home/Chat/Log) creates its own `EveMascot` instance. Each instance
/// owns and disposes its own idle-float, blink, emotion-transition, and
/// peel-transition `AnimationController`s independently — changing one
/// instance's [emotion] or [peelPercent] never affects any other instance.
class EveMascot extends StatelessWidget {
```

- [ ] **Step 4: Run the full mascot test suite**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/`
Expected: PASS — every test file from Tasks 1-7 green.

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/app/lib/features/mascot/eve_mascot.dart EVE_MOBILE/app/test/features/mascot/eve_mascot_widget_test.dart
git commit -m "test(mascot): verify EveMascot lifecycle correctness across many simultaneous instances"
```

---

## Task 8: Golden-image regression tests, one per emotion state

**Files:**
- Create: `EVE_MOBILE/app/test/features/mascot/eve_mascot_golden_test.dart`
- Create (generated by `--update-goldens`, committed as binary): `EVE_MOBILE/app/test/features/mascot/goldens/eve_mascot_neutral.png`, `eve_mascot_caring.png`, `eve_mascot_warm.png`, `eve_mascot_hype.png`, `eve_mascot_sassy.png`, `eve_mascot_fertile.png`

**Interfaces:**
- Consumes: `EveMascotPainter.forState` (Task 3).
- Produces: a `matchesGoldenFile` baseline per emotion state, committed to the repo, that CI/local runs compare future renders against.

Golden tests target the **static painter** (`EveMascotPainter.forState`, via a bare `CustomPaint`), not the full ticking `EveMascot` widget. `EveMascot`'s idle float and blink are driven by wall-clock `Timer`s and a continuously repeating `AnimationController`; pinning a golden image to one arbitrary instant of that motion would make the test flaky against any future timing tweak (Task 4-6 already covers the animation math with deterministic time-based assertions). Golden coverage instead locks in the part that must never silently drift: the exact per-emotion path geometry and colors.

- [ ] **Step 1: Write the golden test file**

Create `EVE_MOBILE/app/test/features/mascot/eve_mascot_golden_test.dart`:

```dart
import 'package:eve/features/mascot/eve_emotion.dart';
import 'package:eve/features/mascot/eve_mascot_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _fixedFrame(EveEmotion emotion) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
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
        find.byType(RepaintBoundary),
        matchesGoldenFile('goldens/eve_mascot_${emotion.name}.png'),
      );
    });
  }
}
```

- [ ] **Step 2: Run once to confirm the test executes (it will fail — no golden files exist yet)**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_mascot_golden_test.dart`
Expected: FAIL — `Could not be compared against non-existent file: ".../goldens/eve_mascot_neutral.png"` (and similarly for the other 5).

- [ ] **Step 3: Generate the golden baselines**

Run: `cd EVE_MOBILE/app && flutter test --update-goldens test/features/mascot/eve_mascot_golden_test.dart`
Expected: exits 0 and creates 6 PNG files under `EVE_MOBILE/app/test/features/mascot/goldens/`.

- [ ] **Step 4: Manually inspect the 6 generated PNGs**

Open each of the 6 files. Confirm by eye: neutral has a closed-but-open-curve mouth and level brows; caring has softer/tilted brows and a smaller mouth curve; warm and hype both show a visibly wider, closed-loop smile (hype's is the most extreme); sassy has one brow raised higher than the other; fertile shows the pink glow ellipse behind a fully-bloomed crown (all 3 seed rows visible, since `peelPercent: 100`) with an otherwise neutral-shaped face. If any image looks wrong (e.g., an eye rendered outside its clip, a seed row missing), the bug is in Task 3's `eve_mascot_painter.dart` or Task 1/2's geometry — fix there, delete the bad PNG, and regenerate (Step 3) before proceeding.

- [ ] **Step 5: Re-run to confirm the goldens now match**

Run: `cd EVE_MOBILE/app && flutter test test/features/mascot/eve_mascot_golden_test.dart`
Expected: PASS — all 6 golden comparisons green.

- [ ] **Step 6: Commit, including the binary golden files**

```bash
git add EVE_MOBILE/app/test/features/mascot/eve_mascot_golden_test.dart EVE_MOBILE/app/test/features/mascot/goldens/
git commit -m "test(mascot): add golden-image regression coverage for all 6 emotion states"
```

---

## Self-Review

**1. Spec coverage.**

- Design-spec §10 exact `EveEmotion`/`EveMascot` contract: implemented verbatim in Task 4/7 (`eve_mascot.dart`); no extra constructor params, no extra enum values.
- Design-spec §9 file paths: `eve_mascot.dart`, `eve_mascot_painter.dart`, `eve_rig_geometry.dart`, `eve_emotion.dart` all created at the exact specified paths (Tasks 1-4).
- Design-spec §4 rig anatomy (body/crown/seed-rows/eyes/brows/mouth/arms): every element listed is ported in Task 1 (geometry) and Task 2 (emotion-varying parts), including under-eye patches, feet, and the fertile-glow ellipse which are mentioned in the raw SVG but not explicitly called out in §4's bullet list — included anyway since they're visible parts of every rendered frame.
- Design-spec §4 peel-stage thresholds (`<35`, `35-70`, `>=70`): Task 1's `EvePeelStage.fromPercent`, unit-tested at both boundaries.
- Design-spec §4 idle animation math (`Math.sin(idleTime) * 2`, periodic blink): Task 4, with the frame-rate assumption and derived millisecond constants documented inline and in Global Constraints.
- Design-spec §4 emotion states (5 named groupings covering the fixed 6-value enum, shared-rig/no-swapped-assets requirement): Task 2's single data table + Task 3's single painter satisfy "shared rig" directly — there is exactly one painter class, never one-per-emotion.
- EVE2_PRD §6 narrative requirements: fertile state kept subtle (opacity-only, no added motion — Global Constraints, Task 6 note); shared rig across states (Task 2/3); mascot never a singleton (Task 4's architecture-decision section, Task 7's multi-instance tests).
- Task list requirement to show body-shell + one crown piece "in full, as a worked example": done in Task 1 Step 3 with inline SVG-command-by-command comments; the rest of the geometry file follows without repeating the comment format but is equally complete (no placeholders).
- Widget tests via `find.byType`/custom finders on rendered painter state: `_painterOf(tester)` helper used throughout Tasks 4-7, reading fields directly off the mounted `CustomPaint.painter`.
- Golden-image test per emotion state: Task 8, all 6 values, fixed `peelPercent: 100`.

**2. Placeholder scan.** No `TODO`/`TBD`/"add appropriate handling" phrasing anywhere in the plan; every step includes literal runnable code and literal `Run:`/`Expected:` command pairs. The one "manual demo checkpoint" (Task 3 Step 5) is intentionally not code-based since it's a visual sanity check, not a deliverable file.

**3. Type/signature consistency.** Traced `EveMascotPainter`'s constructor field names (`mouth`, `browLeft`, `browRight`, `eyelidY`, `fertileGlowOpacity`, `crownScale`, `crownRotationDegrees`, `seedRow2Opacity`, `seedRow3Opacity`, `idleFloatOffset`) from its Task 3 definition through every later call site in Tasks 4-7's `build()` methods — identical names and order used every time. `EveEmotionPose.lerp`/`EveBrowShape.lerp`/`EveMouthShape.lerp` signatures defined once in Task 2 and never redefined, only called, in Task 5. `EvePeelStage.fromPercent` defined once in Task 1, called (never redefined) in Task 3's factory and Task 6's widget code.

**Flagged assumptions / found spec gaps (for the parent build-roadmap and design-spec owners to be aware of):**

1. **Template-vs-JS-default discrepancy in the mock itself.** The static SVG template's baked-in mouth/brow `d` attributes (`Q 100,156`, brow control-y `86`) differ by 1-2px from the values `setMascotEmotion`'s default branch actually assigns for `neutral` (`Q 100,154`, brow control-y `88`). This plan treats the JS function's values as canonical throughout (per this plan's explicit scope: "port the `setMascotEmotion` branches"), since that function runs unconditionally for every mascot the mock configures and overwrites the template regardless.
2. **60fps assumption for idle-loop timing.** The mock's `idleTime += 0.03`/frame and blink-trigger modulo are only meaningful once a frame rate is assumed; this plan assumes the standard 60fps `requestAnimationFrame` cadence (not stated in the JS excerpt itself) to derive the 3491ms float period and 1944ms blink interval. If the real target frame rate differs, these two constants would need recalculating, but the underlying formulas (`sin(controller.value * 2 * pi) * 2` for float, periodic-timer-driven 150ms close/reopen for blink) do not change.
3. **`EveMouthShape.closed` cannot be continuously interpolated** (a path is either closed with an implicit trailing line back to `start`, or it isn't) — Task 2's `EveMouthShape.lerp` snaps this boolean at the `t=0.5` transition midpoint while all 3 control points continue to interpolate continuously and separately. This is the one place in the whole rig where "smooth path interpolation" is a controlled approximation rather than an exact continuous function, and it's called out both where it's implemented (Task 2) and in its test (`snaps 'closed' at the t=0.5 boundary`).
4. **Non-square viewBox vs. single scalar `size`.** The source viewBox is 200x260 (not square), but design-spec §10 fixes `EveMascot.size` as one scalar. This plan fits the artwork into a `size x size` square using the taller dimension (260) as the scale reference and horizontally centers the narrower content — a reasonable, explicit choice (Task 3), but not something either source document specifies, since the HTML mock never needed to solve this (CSS just let the SVG's own aspect ratio dictate its rendered box).
5. **Emotion-transition (220ms/easeInOut) and peel-transition (500ms/easeOutBack) durations and curves are original choices, not ported values** — the mock snaps both instantly with no CSS transition on the affected elements. Called out at first use in Global Constraints and again in Tasks 5 and 6.
6. **Blink is a smooth 75ms-close/75ms-reopen round trip, not the mock's instant-snap-and-150ms-hold.** A deliberate, flagged native-feel improvement (Task 4), still totaling ~150ms end to end.

---

**Plan complete and saved to `EVE_MOBILE/plans/06-mascot-rig-plan.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session using `executing-plans`, batch execution with checkpoints.

**Which approach?**
