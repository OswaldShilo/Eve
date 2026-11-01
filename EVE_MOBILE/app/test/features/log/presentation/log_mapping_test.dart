import 'package:eve_app/features/log/presentation/log_mapping.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:eve_app/shared/models/symptom_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calendarDaysFor keeps the given month, one entry per day (latest wins), sorted', () {
    final days = calendarDaysFor([
      // Local times: calendar days are her local days, so UTC fixtures would
      // shift across midnight in timezones far from UTC (e.g. IST).
      SymptomLog(userId: 'u1', date: DateTime(2026, 3, 14, 8), symptoms: const ['Cramps'], mood: 'low'),
      SymptomLog(userId: 'u1', date: DateTime(2026, 3, 2), mood: 'great', notes: 'Felt strong.'),
      SymptomLog(userId: 'u1', date: DateTime(2026, 3, 14, 20), mood: 'okay'),
      SymptomLog(userId: 'u1', date: DateTime(2026, 4, 1), mood: 'good'),
    ], month: DateTime(2026, 3));

    expect(days.map((d) => d.dayNumber), [2, 14]);
    expect(days.first.detail, 'Felt strong.');
    expect(days.first.emotion, EveEmotion.hype);
    expect(days.last.emotion, EveEmotion.neutral);
    expect(days.last.detail, 'No symptoms logged');
  });

  test('emotionForMood', () {
    expect(emotionForMood('difficult'), EveEmotion.caring);
    expect(emotionForMood(null), EveEmotion.neutral);
  });
}
