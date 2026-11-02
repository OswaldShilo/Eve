// EVE_MOBILE/app/test/features/home/presentation/screens/doctor_summary_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/home/presentation/screens/doctor_summary_screen.dart';

void main() {
  testWidgets('DoctorSummaryScreen generates and displays a summary, then shows the export button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DoctorSummaryScreen(
        logs: const [
          {'date': '2026-03-04', 'symptoms': ['cramps']},
        ],
        generateSummary: (logs) async => 'Overview: mild cramps recorded once.',
      ),
    ));

    expect(find.text('Generate Summary'), findsOneWidget);
    await tester.tap(find.byKey(const Key('generate-summary-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Overview: mild cramps recorded once.'), findsOneWidget);
    expect(find.byKey(const Key('export-pdf-button')), findsOneWidget);
  });

  testWidgets('DoctorSummaryScreen disables the button and explains when there are no logs', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DoctorSummaryScreen(logs: const [], generateSummary: (logs) async => ''),
    ));

    final button = tester.widget<ElevatedButton>(find.byKey(const Key('generate-summary-button')));
    expect(button.onPressed, isNull);
    expect(find.text('No logs to summarize yet'), findsOneWidget);
  });

  testWidgets('DoctorSummaryScreen shows an error message when generation fails', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DoctorSummaryScreen(
        logs: const [
          {'date': '2026-03-04'},
        ],
        generateSummary: (logs) async => throw Exception('network error'),
      ),
    ));

    await tester.tap(find.byKey(const Key('generate-summary-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('summary-error-text')), findsOneWidget);
  });
}
