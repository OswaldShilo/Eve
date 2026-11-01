import 'package:flutter/material.dart';

import '../../core/theme/eve_theme.dart';
import '../../features/mascot/eve_emotion.dart';
import '../../features/mascot/eve_mascot.dart';
import 'eve_components.dart';

/// A centred loading / empty / error state with Eve, used wherever a
/// screen's data is not ready: a spinner while [loading], otherwise a
/// title, a message and an optional action (e.g. Retry).
class EveStatusView extends StatelessWidget {
  const EveStatusView({
    super.key,
    this.title,
    this.message,
    this.emotion = EveEmotion.caring,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  /// The loading variant: Eve with a spinner and an optional [message].
  const EveStatusView.loading({super.key, this.message})
    : title = null,
      emotion = EveEmotion.neutral,
      actionLabel = null,
      onAction = null,
      loading = true;

  final String? title;
  final String? message;
  final EveEmotion emotion;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tokens = EveTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(child: EveMascot(emotion: emotion, size: 96)),
            const SizedBox(height: 16),
            if (loading)
              const SizedBox(
                key: Key('eve-status-loading'),
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  color: EveColors.rubyMain,
                ),
              ),
            if (title != null)
              Text(
                title!,
                textAlign: TextAlign.center,
                style: text.titleMedium!.copyWith(color: tokens.ink),
              ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: text.bodyMedium!.copyWith(color: tokens.muted),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: EveButton(
                  key: const Key('eve-status-action'),
                  label: actionLabel!,
                  onPressed: onAction,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
