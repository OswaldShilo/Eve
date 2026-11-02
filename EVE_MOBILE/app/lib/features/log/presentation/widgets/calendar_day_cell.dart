import 'package:flutter/material.dart';
import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';

class CalendarDayData {
  const CalendarDayData({
    required this.dayNumber,
    this.dotColors = const [],
    this.dateTitle,
    this.detail,
    this.emotion = EveEmotion.neutral,
  });

  final int dayNumber;
  final List<Color> dotColors;
  final String? dateTitle;
  final String? detail;
  final EveEmotion emotion;
}

/// `.calendar-cell`: a square day cell. Days with logs get the soft
/// `.has-data` fill and their coloured `.dot`s; the selected day turns blush
/// with a dark outline and grows slightly (`transform: scale(1.08)`).
class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.data,
    required this.selected,
    required this.onTap,
    this.hasData,
  });

  final CalendarDayData data;
  final bool selected;
  final VoidCallback onTap;

  /// Defaults to "has at least one dot".
  final bool? hasData;

  @override
  Widget build(BuildContext context) {
    final tokens = EveTokens.of(context);
    final withData = hasData ?? data.dotColors.isNotEmpty;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        key: Key('calendar-day-${data.dayNumber}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1.08 : 1,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: selected
                  ? EveColors.rubyBlush
                  : withData
                      ? tokens.soft
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                width: 2,
                color: selected
                    ? EveColors.outline
                    : withData
                        ? const Color(0x262A000E) // rgba(42, 0, 14, 0.15)
                        : Colors.transparent,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${data.dayNumber}',
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(
                            color: selected ? EveColors.outline : tokens.ink,
                          ),
                    ),
                  ),
                ),
                if (data.dotColors.isNotEmpty)
                  Positioned(
                    bottom: 3,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final color in data.dotColors)
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: EveColors.outline, width: 1),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
