import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
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
