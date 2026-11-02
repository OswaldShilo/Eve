import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/symptom_log.dart';
import '../../mascot/eve_emotion.dart';
import 'widgets/calendar_day_cell.dart';

const _symptomPurple = Color(0xFF9B51E0);

EveEmotion emotionForMood(String? mood) => switch (mood) {
      'great' || 'good' => EveEmotion.hype,
      'low' || 'difficult' => EveEmotion.caring,
      _ => EveEmotion.neutral,
    };

/// One calendar entry per day of [month]; when a day has several logs the
/// latest one is shown.
List<CalendarDayData> calendarDaysFor(List<SymptomLog> logs, {required DateTime month}) {
  final byDay = <int, SymptomLog>{};
  final inMonth = logs.where((log) {
    final local = log.date.toLocal();
    return local.year == month.year && local.month == month.month;
  }).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  for (final log in inMonth) {
    byDay[log.date.toLocal().day] = log;
  }
  final days = byDay.keys.toList()..sort();
  return [
    for (final day in days)
      CalendarDayData(
        dayNumber: day,
        dotColors: byDay[day]!.symptoms.isNotEmpty ? const [_symptomPurple] : const [],
        dateTitle: DateFormat('MMMM d').format(byDay[day]!.date.toLocal()),
        detail: byDay[day]!.notes.isNotEmpty
            ? byDay[day]!.notes
            : (byDay[day]!.symptoms.isEmpty ? 'No symptoms logged' : byDay[day]!.symptoms.join(', ')),
        emotion: emotionForMood(byDay[day]!.mood),
      ),
  ];
}
