import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/log/presentation/screens/log_screen.dart';
import 'package:eve_app/features/log/presentation/widgets/calendar_day_cell.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';

void main() {
  testWidgets('LogScreen renders month header, legend, day cells and toast, Home nav invokes callback', (tester) async {
    var homeTapped = false;

    await tester.pumpWidget(MaterialApp(
      home: LogScreen(
        monthLabel: 'March 2026',
        days: const [
          CalendarDayData(dayNumber: 14, dotColors: [Color(0xFF9B51E0), Color(0xFFFFA0B8)]),
          CalendarDayData(
            dayNumber: 16,
            dotColors: [Color(0xFF2EC4B6)],
            dateTitle: 'March 16',
            detail: 'Fertile Window Begins',
            emotion: EveEmotion.fertile,
          ),
        ],
        selectedDayIndex: 0,
        onNavigateHome: () => homeTapped = true,
      ),
    ));

    expect(find.text('March 2026'), findsOneWidget);
    expect(find.text('Period'), findsOneWidget);
    expect(find.text('Fertile Window'), findsOneWidget);
    expect(find.text('Symptom'), findsOneWidget);
    expect(find.text('Appointment'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.byKey(const Key('log-fab-new-entry')), findsOneWidget);

    await tester.tap(find.text('Home'));
    expect(homeTapped, isTrue);
  });
}
