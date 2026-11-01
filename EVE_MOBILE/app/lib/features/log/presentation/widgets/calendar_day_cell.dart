import 'package:flutter/material.dart';
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

class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({super.key, required this.data, required this.selected, required this.onTap});

  final CalendarDayData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('calendar-day-${data.dayNumber}'),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: selected ? Border.all(color: const Color(0xFFFF2A6D), width: 2) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${data.dayNumber}'),
            if (data.dotColors.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final color in data.dotColors)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
