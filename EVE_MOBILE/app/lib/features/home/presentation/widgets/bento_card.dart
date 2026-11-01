import 'package:flutter/material.dart';
import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

class BentoCardData {
  const BentoCardData({
    required this.title,
    required this.value,
    required this.description,
    this.fullWidth = false,
    this.placeholder = false,
    this.onTap,
  });
  final String title;
  final String value;
  final String description;
  final bool fullWidth;

  /// The module has no real data source yet: the card says so (a
  /// "Coming soon" tag, muted value) instead of showing invented numbers.
  final bool placeholder;
  final VoidCallback? onTap;
}

/// `.bento-card`: outlined card with an uppercase ruby `.bento-title`, a
/// Fredoka `.bento-value` and a muted `.bento-desc`. Grows with its text, so
/// large font sizes never overflow it.
class BentoCard extends StatelessWidget {
  const BentoCard({super.key, required this.data, this.onTap});

  final BentoCardData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = EveTokens.of(context);
    final text = Theme.of(context).textTheme;
    return EveCard(
      key: Key('bento-card-${data.title}'),
      radius: 22,
      shadow: 6,
      onTap: onTap ?? data.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title.toUpperCase(),
            style: text.labelMedium!.copyWith(
              color: EveColors.rubyMain,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          if (data.placeholder) ...[
            Container(
              key: Key('bento-placeholder-${data.title}'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.soft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: EveColors.outline, width: 2),
              ),
              child: Text(
                'Coming soon',
                style: text.labelSmall!.copyWith(color: tokens.ink),
              ),
            ),
            const SizedBox(height: 6),
          ] else ...[
            Text(
              data.value,
              style: text.titleLarge!.copyWith(color: tokens.ink),
            ),
            const SizedBox(height: 6),
          ],
          Text(data.description, style: text.bodySmall),
        ],
      ),
    );
  }
}
