import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/log/presentation/screens/log_screen.dart';
import 'package:eve_app/features/log/presentation/widgets/calendar_day_cell.dart';
import 'package:eve_app/features/mascot/eve_emotion.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

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

  testWidgets('shows the whole month with weekday headers and leading blanks', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // March 2026 starts on a Sunday; February 2026 on a Sunday too, April on a Wednesday.
    await tester.pumpWidget(MaterialApp(home: LogScreen(month: DateTime(2026, 4))));

    for (var day = 1; day <= 30; day++) {
      expect(find.byKey(Key('calendar-day-$day')), findsOneWidget, reason: 'day $day');
    }
    expect(find.byKey(const Key('calendar-day-31')), findsNothing);
    expect(find.text('S'), findsNWidgets(2));
    expect(find.text('W'), findsOneWidget);

    // April 1 2026 is a Wednesday: it sits in the 4th column, under 'W'.
    final w = tester.getCenter(find.text('W')).dx;
    final first = tester.getCenter(find.byKey(const Key('calendar-day-1'))).dx;
    expect((first - w).abs(), lessThan(2));
  });

  testWidgets('month arrows call back; a day tap moves the toast', (tester) async {
    var prev = 0;
    var next = 0;
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: LogScreen(
        month: DateTime(2026, 3),
        days: const [
          CalendarDayData(dayNumber: 16, dateTitle: 'March 16', detail: 'Fertile Window Begins'),
        ],
        onPreviousMonth: () => prev++,
        onNextMonth: () => next++,
      ),
    ));

    await tester.tap(find.byKey(const Key('log-prev-month')));
    await tester.tap(find.byKey(const Key('log-next-month')));
    expect((prev, next), (1, 1));

    await tester.tap(find.byKey(const Key('calendar-day-16')));
    await tester.pump();
    expect(find.text('Fertile Window Begins'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-day-17')));
    await tester.pump();
    expect(find.text('March 17'), findsOneWidget);
    expect(find.text('No logs recorded.'), findsOneWidget);
  });

  testWidgets('today is selected by default in the current month', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();

    await tester.pumpWidget(MaterialApp(home: LogScreen(month: now)));

    final cell = tester.widget<CalendarDayCell>(find.ancestor(
      of: find.byKey(Key('calendar-day-${now.day}')),
      matching: find.byType(CalendarDayCell),
    ));
    expect(cell.selected, isTrue);
  });

  testWidgets('an empty month explains how to add an entry', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: LogScreen(month: DateTime(2026, 2))));
    expect(find.text('No logs this month yet. Tap + to add how you feel.'), findsOneWidget);
  });

  testWidgets('the legend is one outlined card with all four categories', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: EveTheme.defaultTheme(), home: LogScreen(month: DateTime(2026, 3))));

    final legend = find.byKey(const Key('log-legend'));
    expect(legend, findsOneWidget);
    for (final label in ['Period', 'Fertile Window', 'Symptom', 'Appointment']) {
      expect(find.descendant(of: legend, matching: find.text(label)), findsOneWidget);
    }
  });

  testWidgets('the + button opens a new entry', (tester) async {
    var opened = 0;
    await tester.pumpWidget(MaterialApp(home: LogScreen(onNewEntry: () => opened++)));
    await tester.tap(find.byKey(const Key('log-fab-new-entry')));
    expect(opened, 1);
  });

  for (final scale in [1.0, 1.3, 1.5]) {
    testWidgets('no overflow at 360x640 with text x$scale', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: EveTheme.defaultTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: LogScreen(
          month: DateTime(2026, 5), // 6 calendar rows
          days: const [
            CalendarDayData(
              dayNumber: 30,
              dotColors: [EveColors.rubyMain, EveColors.symptomPurple, EveColors.fertileTeal],
              dateTitle: 'May 30',
              detail: 'Cramps, Headache, Bloating, Fatigue, Back pain and a long note about the day',
            ),
          ],
          initialSelectedDay: 30,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      // The + button sits beside the selected-day toast, never on top of it,
      // and both stay on screen above the bottom nav.
      final fab = tester.getRect(find.byKey(const Key('log-fab-new-entry')));
      final toast = tester.getRect(find.byKey(const Key('log-day-toast')));
      expect(fab.overlaps(toast), isFalse);
      expect(fab.bottom, lessThanOrEqualTo(640));
      expect(toast.bottom, lessThanOrEqualTo(640));

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
