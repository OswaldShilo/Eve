import 'package:flutter/material.dart';

import '../../core/theme/eve_theme.dart';

/// The mock's signature "sticker" treatment: a thick `#2A000E` outline plus
/// a solid, unblurred drop shadow straight down (`box-shadow: 0 Npx 0
/// #2A000E`). Every outlined surface in mockv4 is this decoration with a
/// different radius / border width / shadow depth.
BoxDecoration eveOutlined({
  required Color color,
  double radius = 20,
  double borderWidth = 3.5,
  double shadow = 6,
  BoxShape shape = BoxShape.rectangle,
}) {
  return BoxDecoration(
    color: color,
    shape: shape,
    borderRadius: shape == BoxShape.circle
        ? null
        : BorderRadius.circular(radius),
    border: Border.all(color: EveColors.outline, width: borderWidth),
    boxShadow: shadow <= 0
        ? null
        : [
            BoxShadow(
              color: EveColors.outline,
              offset: Offset(0, shadow),
              blurRadius: 0,
            ),
          ],
  );
}

/// Shared press behaviour for the mock's buttons: on press the surface moves
/// down by [travel] and its solid shadow shrinks by the same amount
/// (`.btn-primary:active { transform: translateY(4px); box-shadow: 0 2px }`).
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.builder,
    required this.onTap,
    required this.shadow,
    required this.travel,
    this.semanticLabel,
  });

  final Widget Function(double shadow) builder;
  final VoidCallback? onTap;
  final double shadow;
  final double travel;
  final String? semanticLabel;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final travel = _down ? widget.travel : 0.0;
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: Padding(
          // Reserve the shadow's full depth so layout never jumps on press.
          padding: EdgeInsets.only(bottom: widget.shadow),
          child: Transform.translate(
            offset: Offset(0, travel),
            child: widget.builder(widget.shadow - travel),
          ),
        ),
      ),
    );
  }
}

enum EveButtonVariant {
  /// `.btn-primary`: ruby fill, white Fredoka label.
  primary,

  /// `.btn-google-auth`: white fill, dark label.
  secondary,
}

/// `.btn-primary` / `.btn-google-auth`. Disabled when [onPressed] is null;
/// shows a spinner and ignores taps while [busy].
class EveButton extends StatelessWidget {
  const EveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = EveButtonVariant.primary,
    this.busy = false,
    this.leading,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final EveButtonVariant variant;
  final bool busy;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final primary = variant == EveButtonVariant.primary;
    final enabled = onPressed != null && !busy;
    final fg = primary ? Colors.white : EveColors.outline;
    final style = Theme.of(context).textTheme.titleMedium!.copyWith(color: fg);
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: _Pressable(
        onTap: enabled ? onPressed : null,
        shadow: 6,
        travel: 4,
        builder: (shadow) => Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: eveOutlined(
            color: primary ? EveColors.rubyMain : EveColors.cardBg,
            radius: 20,
            shadow: shadow,
          ),
          alignment: Alignment.center,
          child: busy
              ? SizedBox(
                  key: const Key('eve-button-busy'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 3, color: fg),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 12),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: style,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// `.btn-back`: 38px outlined square with a left arrow.
class EveBackButton extends StatelessWidget {
  const EveBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = EveTokens.of(context);
    return _Pressable(
      onTap: onPressed,
      shadow: 4,
      travel: 2,
      semanticLabel: 'Back',
      builder: (shadow) => Container(
        width: 38,
        height: 38,
        decoration: eveOutlined(
          color: tokens.card,
          radius: 14,
          borderWidth: 3,
          shadow: shadow,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.arrow_back_rounded, size: 20, color: tokens.ink),
      ),
    );
  }
}

/// `.nav-arrow-btn`: 36px outlined square used for month navigation.
class EveIconSquareButton extends StatelessWidget {
  const EveIconSquareButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = EveTokens.of(context);
    return _Pressable(
      onTap: onPressed,
      shadow: 4,
      travel: 2,
      semanticLabel: semanticLabel,
      builder: (shadow) => Container(
        width: 36,
        height: 36,
        decoration: eveOutlined(
          color: tokens.card,
          radius: 14,
          borderWidth: 3,
          shadow: shadow,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: tokens.ink),
      ),
    );
  }
}

/// `.survey-progress-bar`: 16px outlined track with a ruby fill.
class EveProgressBar extends StatelessWidget {
  const EveProgressBar({super.key, required this.percent});

  /// 0–100.
  final double percent;

  @override
  Widget build(BuildContext context) {
    final fraction = (percent / 100).clamp(0.0, 1.0);
    return Semantics(
      label: 'Progress',
      value: '${(fraction * 100).round()}%',
      child: Container(
        height: 16,
        decoration: eveOutlined(
          color: EveColors.progressTrack,
          radius: 12,
          shadow: 0,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fraction),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              builder: (context, value, _) => FractionallySizedBox(
                key: const Key('eve-progress-fill'),
                widthFactor: value,
                heightFactor: 1,
                child: const ColoredBox(color: EveColors.rubyMain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A generic outlined card (`.bento-card`, `.home-hero-card`,
/// `.legend-row`, `.calendar-grid`, `.mascot-guidance-card` …). Tappable
/// when [onTap] is set.
class EveCard extends StatelessWidget {
  const EveCard({
    super.key,
    required this.child,
    this.color,
    this.radius = 22,
    this.shadow = 6,
    this.borderWidth = 3.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.onTap,
  });

  final Widget child;

  /// Defaults to the theme's `--card-bg`.
  final Color? color;
  final double radius;
  final double shadow;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? EveTokens.of(context).card;
    Widget box(double s) => Container(
      padding: padding,
      decoration: eveOutlined(
        color: bg,
        radius: radius,
        borderWidth: borderWidth,
        shadow: s,
      ),
      child: child,
    );
    if (onTap == null) {
      return Padding(
        padding: EdgeInsets.only(bottom: shadow),
        child: box(shadow),
      );
    }
    return _Pressable(onTap: onTap, shadow: shadow, travel: 3, builder: box);
  }
}

/// `.form-input` with a `.form-label` above it.
class EveTextField extends StatelessWidget {
  const EveTextField({
    super.key,
    this.label,
    this.controller,
    this.initialValue,
    this.hintText,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.fieldKey,
    this.errorText,
  }) : assert(controller == null || initialValue == null);

  final String? label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;

  /// Key placed on the inner [TextFormField] so tests can `enterText`.
  final Key? fieldKey;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final tokens = EveTokens.of(context);
    final text = Theme.of(context).textTheme;
    final field = Container(
      decoration: eveOutlined(color: tokens.card, radius: 18, shadow: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        initialValue: initialValue,
        onChanged: onChanged,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        maxLines: maxLines,
        style: text.bodyMedium!.copyWith(color: tokens.ink),
        cursorColor: EveColors.rubyMain,
        scrollPadding: const EdgeInsets.only(bottom: 120),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: text.bodyMedium!.copyWith(color: tokens.muted),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: text.labelLarge!.copyWith(color: tokens.ink)),
          const SizedBox(height: 6),
        ],
        Padding(padding: const EdgeInsets.only(bottom: 4), child: field),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: text.labelMedium!.copyWith(color: EveColors.rubyMain),
          ),
        ],
      ],
    );
  }
}

enum EveChipSize {
  /// `.sub-chip`: 2.5px border, 12px radius, 3px shadow.
  small,

  /// `.chip-btn`: 3px border, 20px radius, 4px shadow (quick replies).
  regular,
}

/// `.sub-chip` / `.chip-btn` / `.btn-emotion-chip`: selected chips fill
/// ruby with white text.
class EveChip extends StatelessWidget {
  const EveChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.size = EveChipSize.small,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final EveChipSize size;

  @override
  Widget build(BuildContext context) {
    final tokens = EveTokens.of(context);
    final small = size == EveChipSize.small;
    final shadow = small ? 3.0 : 4.0;
    return Semantics(
      selected: selected,
      child: _Pressable(
        onTap: onTap,
        shadow: shadow,
        travel: 2,
        builder: (s) => Container(
          padding: small
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: eveOutlined(
            color: selected ? EveColors.rubyMain : tokens.card,
            radius: small ? 12 : 20,
            borderWidth: small ? 2.5 : 3,
            shadow: s,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: selected ? Colors.white : tokens.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// `.toggle-switch`: 50×28 outlined pill with a sliding knob.
class EveToggle extends StatelessWidget {
  const EveToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: semanticLabel,
      enabled: onChanged != null,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 50,
          height: 28,
          decoration: BoxDecoration(
            color: value ? EveColors.rubyMain : const Color(0xFFDDDDDD),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: EveColors.outline, width: 3),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(2),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: EveColors.outline, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.toggle-row`: a soft outlined row with a label and an [EveToggle].
class EveToggleRow extends StatelessWidget {
  const EveToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = EveTokens.of(context);
    return EveCard(
      color: tokens.soft,
      radius: 20,
      shadow: 5,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          const SizedBox(width: 12),
          EveToggle(value: value, onChanged: onChanged, semanticLabel: label),
        ],
      ),
    );
  }
}

/// `.speech-bubble`: outlined white bubble with a downward tail. [compact]
/// renders the Home variant (`.home-speech-bubble`: soft fill, no tail).
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.text,
    this.compact = false,
    this.maxWidth = 290,
  });

  final String text;
  final bool compact;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (compact) {
      final tokens = EveTokens.of(context);
      return EveCard(
        color: tokens.soft,
        radius: 16,
        borderWidth: 3,
        shadow: 4,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: textTheme.titleSmall!.copyWith(color: tokens.ink),
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: eveOutlined(color: Colors.white, radius: 20, shadow: 6),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium!.copyWith(
                color: EveColors.outline,
                fontWeight: FontWeight.w600,
                fontSize: 16.3,
              ),
            ),
          ),
          // The mock's `::after` tail sits under the shadow; nudge it up so it
          // reads as attached to the bubble.
          Transform.translate(
            offset: const Offset(0, -1),
            child: CustomPaint(
              size: const Size(18, 10),
              painter: _TailPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = EveColors.outline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// `.mascot-shadow`: the soft ellipse under a standing mascot.
class MascotGroundShadow extends StatelessWidget {
  const MascotGroundShadow({super.key, this.width = 130, this.height = 18});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        color: Color(0x242A000E), // rgba(42, 0, 14, 0.14)
        borderRadius: BorderRadius.all(Radius.elliptical(130, 18)),
      ),
    );
  }
}

/// `.form-select` with an optional `.form-label`: an outlined dropdown.
class EveSelectField<T> extends StatelessWidget {
  const EveSelectField({
    super.key,
    required this.items,
    required this.itemLabel,
    required this.value,
    required this.onChanged,
    this.label,
    this.hintText,
    this.fieldKey,
  });

  final List<T> items;
  final String Function(T) itemLabel;
  final T? value;
  final ValueChanged<T> onChanged;
  final String? label;
  final String? hintText;

  /// Key placed on the inner [DropdownButtonFormField].
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final tokens = EveTokens.of(context);
    final text = Theme.of(context).textTheme;
    final style = text.bodyMedium!.copyWith(color: tokens.ink);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: text.labelLarge!.copyWith(color: tokens.ink)),
          const SizedBox(height: 6),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Container(
            decoration: eveOutlined(color: tokens.card, radius: 18, shadow: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<T>(
              key: fieldKey,
              initialValue: value,
              isExpanded: true,
              style: style,
              dropdownColor: tokens.card,
              borderRadius: BorderRadius.circular(18),
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: tokens.ink),
              hint: hintText == null
                  ? null
                  : Text(hintText!, style: style.copyWith(color: tokens.muted)),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              items: items
                  .map(
                    (v) => DropdownMenuItem<T>(
                      value: v,
                      child: Text(
                        itemLabel(v),
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// `.form-label`: the bold label above a group of inputs or chips.
class EveFormLabel extends StatelessWidget {
  const EveFormLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge!.copyWith(color: EveTokens.of(context).ink),
      ),
    );
  }
}
