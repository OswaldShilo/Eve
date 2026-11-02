import 'dart:async';

import 'package:eve_app/features/log/presentation/widgets/quick_log_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('collects mood, symptoms, pain and notes and returns canonical keys', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    QuickLogResult? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: QuickLogSheet(onSave: (result) async => saved = result)),
    ));

    await tester.tap(find.text('Difficult'));
    await tester.tap(find.text('Cramps'));
    await tester.drag(find.byType(Slider), const Offset(400, 0));
    await tester.enterText(find.byType(TextField), 'Long day.');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved!.mood, 'difficult');
    expect(saved!.symptoms, ['Cramps']);
    expect(saved!.painLevel, 10);
    expect(saved!.notes, 'Long day.');
  });

  testWidgets('a failed save keeps the entry, re-enables Save and explains', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QuickLogSheet(onSave: (_) async {
          attempts++;
          throw Exception('offline');
        }),
      ),
    ));

    await tester.tap(find.text('Low'));
    await tester.enterText(find.byType(TextField), 'Keep this note');
    await tester.tap(find.byKey(const Key('quick-log-save')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('quick-log-error')), findsOneWidget);
    expect(find.text('Keep this note'), findsOneWidget);
    expect(find.byKey(const Key('eve-button-busy')), findsNothing);

    await tester.tap(find.byKey(const Key('quick-log-save')));
    await tester.pump();
    expect(attempts, 2);
  });

  testWidgets('Save spins while saving and ignores repeat taps', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final release = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QuickLogSheet(onSave: (_) async {
          calls++;
          await release.future;
        }),
      ),
    ));

    await tester.tap(find.byKey(const Key('quick-log-save')));
    await tester.pump();
    expect(find.byKey(const Key('eve-button-busy')), findsOneWidget);
    await tester.tap(find.byKey(const Key('quick-log-save')));
    release.complete();
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('sits above the keyboard on a 360x640 phone at 1.3x text', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.3),
          viewInsets: const EdgeInsets.only(bottom: 300),
        ),
        child: child!,
      ),
      home: Scaffold(
        resizeToAvoidBottomInset: false, // like a modal sheet: the sheet pads itself
        body: Align(
          alignment: Alignment.bottomCenter,
          child: QuickLogSheet(onSave: (_) async {}),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Scrolling the sheet brings Save into view above the 300px keyboard.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1000));
    await tester.pump();
    final saveBottom = tester.getBottomLeft(find.byKey(const Key('quick-log-save'))).dy;
    expect(saveBottom, lessThanOrEqualTo(640 - 300 + 1));
  });
}
