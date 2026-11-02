import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.onGoogleSignIn,
    this.progressPercent = 10,
    this.guestBusy = false,
    this.googleBusy = false,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final VoidCallback? onGoogleSignIn;
  final double progressPercent;

  /// A guest / Google sign-in is in flight: show a spinner on that button
  /// and ignore further taps on both.
  final bool guestBusy;
  final bool googleBusy;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      progressPercent: progressPercent,
      emotion: EveEmotion.neutral,
      guidanceText:
          'Sign in to securely back up your health data, or continue as a guest.',
      title: 'Welcome to EVE',
      subtitle: 'Sign in to back up your health insights securely.',
      primaryLabel: 'Continue as Guest',
      onPrimaryPressed: googleBusy ? () {} : onContinue,
      onBack: onBack,
      primaryBusy: guestBusy,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: EveButton(
          key: const Key('auth-google-button'),
          variant: EveButtonVariant.secondary,
          label: 'Sign in with Google',
          leading: const _GoogleMark(),
          busy: googleBusy,
          onPressed: guestBusy ? () {} : (onGoogleSignIn ?? onContinue),
        ),
      ),
    );
  }
}

/// The four-colour "G" mark from the mock's `.google-icon-svg`, drawn as
/// arcs so no image asset is needed.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const deg = math.pi / 180;
    canvas.drawArc(
      rect,
      -40 * deg,
      85 * deg,
      false,
      p(const Color(0xFF4285F4)),
    );
    canvas.drawArc(rect, 45 * deg, 90 * deg, false, p(const Color(0xFF34A853)));
    canvas.drawArc(
      rect,
      135 * deg,
      80 * deg,
      false,
      p(const Color(0xFFFBBC05)),
    );
    canvas.drawArc(
      rect,
      215 * deg,
      100 * deg,
      false,
      p(const Color(0xFFEA4335)),
    );
    canvas.drawLine(
      Offset(size.width / 2, size.height / 2),
      Offset(size.width - stroke / 2, size.height / 2),
      p(const Color(0xFF4285F4)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
