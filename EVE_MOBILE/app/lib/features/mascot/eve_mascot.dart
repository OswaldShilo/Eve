import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'eve_emotion.dart';
import 'eve_mascot_painter.dart';
import 'eve_rig_geometry.dart';

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

  static const _emotionTransitionDuration = Duration(milliseconds: 220); // chosen, not literally specified — see Task 5

  late final AnimationController _emotionTransitionController;
  EveEmotion? _previousEmotion;

  static const _peelTransitionDuration = Duration(milliseconds: 500); // chosen, not literally specified — see Task 6

  late final AnimationController _peelTransitionController;
  EvePeelStage? _previousPeelStage;

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
    _emotionTransitionController.dispose();
    _peelTransitionController.dispose();
    super.dispose();
  }

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
}
