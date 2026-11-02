import 'package:flutter/material.dart';
import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/features/mascot/eve_mascot.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

/// The Welcome / Completion layout from mockv4 (`#screen-welcome`,
/// `#screen-completion`): a tailed `.speech-bubble`, Eve standing on a
/// `.mascot-shadow` in the 230px `.mascot-stage-welcome`, the
/// `.brand-footer` (big Fredoka title with a blush drop shadow over an
/// uppercase ruby subtitle) and a `.btn-primary`.
///
/// Eve bounces in once when the screen opens (PRD §4 "bounce/scale
/// entrance"). The column is centred on the screen and scrolls when it does
/// not fit (small phones, large text). It deliberately avoids
/// IntrinsicHeight + spaceBetween: intrinsic sizing measures the speech
/// bubble's text at full width (ConstrainedBox does not clamp intrinsic
/// width), under-reports its height and overflows.
class BrandBookend extends StatelessWidget {
  const BrandBookend({
    super.key,
    required this.speech,
    required this.emotion,
    required this.title,
    required this.subtitle,
    required this.button,
    this.footer,
  });

  final String speech;
  final EveEmotion emotion;
  final String title;
  final String subtitle;
  final Widget button;

  /// Optional widget under the button (e.g. the partner-join link).
  final Widget? footer;

  static const _entrance = Duration(milliseconds: 750);

  @override
  Widget build(BuildContext context) {
    final tokens = EveTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // `.mascot-stage-welcome` is 230px on the mock's 844px frame;
            // shrink it on short phones so Begin Setup stays above the fold.
            final stage = (constraints.maxHeight * 0.3).clamp(150.0, 230.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 40).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        builder: (context, t, child) => Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - t)),
                            child: child,
                          ),
                        ),
                        child: SpeechBubble(text: speech),
                      ),
                      const SizedBox(height: 16),
                      TweenAnimationBuilder<double>(
                        key: const Key('bookend-mascot-entrance'),
                        tween: Tween(begin: 0.55, end: 1),
                        duration: _entrance,
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) => Transform.scale(
                          scale: scale,
                          alignment: Alignment.bottomCenter,
                          child: child,
                        ),
                        child: SizedBox(
                          width: stage,
                          height: stage,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                bottom: 8,
                                child: MascotGroundShadow(
                                  width: stage * 0.56,
                                  height: 18,
                                ),
                              ),
                              Positioned(
                                bottom: 16,
                                child: EveMascot(
                                  emotion: emotion,
                                  size: stage * 0.82,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              title,
                              key: const Key('bookend-title'),
                              textAlign: TextAlign.center,
                              style: text.displayLarge!.copyWith(
                                color: tokens.ink,
                                shadows: const [
                                  Shadow(
                                    color: EveColors.rubyBlush,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle.toUpperCase(),
                            key: const Key('bookend-subtitle'),
                            textAlign: TextAlign.center,
                            style: text.labelLarge!.copyWith(
                              color: EveColors.rubyMain,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [button, if (footer != null) footer!],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
