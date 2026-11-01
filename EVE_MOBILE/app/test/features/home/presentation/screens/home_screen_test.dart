import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/features/home/presentation/home_modules.dart';
import 'package:eve_app/features/home/presentation/widgets/bento_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/home/presentation/screens/home_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('HomeScreen renders greeting, phase badge, bento cards and default hero speech', (tester) async {
    // Tall surface so the lazily-built ListView lays out every card.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Welcome back, Maya'), findsOneWidget);
    expect(find.text('Current status overview'), findsOneWidget);
    expect(find.text('Follicular Phase • Day 9'), findsOneWidget);
    expect(find.text('7-Day Check-in Streak Active'), findsOneWidget);
    // `.bento-title` is text-transform: uppercase in the mock.
    expect(find.text('NEXT CYCLE PHASE'), findsOneWidget);
    expect(find.text('in 14 Days'), findsOneWidget);
    expect(find.text('CHECK-IN STREAK'), findsOneWidget);
    expect(find.text('8 Days'), findsOneWidget);
    expect(find.text('DAILY RECOMMENDATION'), findsOneWidget);
    expect(find.text('Boost Collagen & Iron Intake'), findsOneWidget);
  });

  testWidgets('HomeScreen swaps hero speech when an emotion chip is tapped', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.tap(find.byKey(const Key('home-emotion-chip-Support')));
    await tester.pump();

    expect(find.text('Rest and recovery recorded.'), findsOneWidget);
  });

  testWidgets('heroStandardMessage replaces the demo line on the Standard chip', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HomeScreen(heroStandardMessage: 'You have logged 3 check-ins this month.'),
    ));

    expect(find.text('You have logged 3 check-ins this month.'), findsOneWidget);
    expect(find.text('7-Day Check-in Streak Active'), findsNothing);
  });

  testWidgets('HomeScreen bottom nav invokes onNavigateChat and onNavigateLog', (tester) async {
    var chatTapped = false;
    var logTapped = false;

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        onNavigateChat: () => chatTapped = true,
        onNavigateLog: () => logTapped = true,
      ),
    ));

    await tester.tap(find.text('Chat'));
    expect(chatTapped, isTrue);

    await tester.tap(find.text('Log'));
    expect(logTapped, isTrue);
  });

  testWidgets('HomeScreen shows a labelled doctor summary card that invokes onNavigateDoctorSummary',
      (tester) async {
    var tapped = false;

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(onNavigateDoctorSummary: () => tapped = true),
    ));

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-doctor-summary-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('home-doctor-summary-button')));
    await tester.pump();
    expect(find.text('DOCTOR-READY SUMMARY'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-doctor-summary-button')));
    expect(tapped, isTrue);
  });

  testWidgets('placeholder modules say Coming soon instead of showing a value', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(
        bentoCards: moduleCardsFor('pregnant', logsThisMonth: 2, onOpenLog: () {}, onOpenChat: () {}),
      ),
    ));

    expect(find.text('PREGNANCY MILESTONES'), findsOneWidget);
    expect(find.byKey(const Key('bento-placeholder-Pregnancy Milestones')), findsOneWidget);
    expect(find.text('2 this month'), findsOneWidget);
    expect(find.text('Coming soon'), findsNWidgets(2)); // milestones + daily recommendation
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
        home: HomeScreen(
          greetingName: 'Alexandria',
          phaseBadge: 'Perimenopause Tracking Active',
          bentoCards: moduleCardsFor('cycle', logsThisMonth: 12, onOpenLog: () {}, onOpenChat: () {}),
          onNavigateDoctorSummary: () {},
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      // Scroll through the whole dashboard so every card is laid out.
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  group('moduleCardsFor', () {
    test('follows activeModules for each life stage', () {
      List<String> titles(String stage) => moduleCardsFor(stage, logsThisMonth: 0, onOpenChat: () {})
          .map((c) => c.title)
          .toList();

      expect(titles('cycle'), ['Next Cycle Phase', 'Check-ins', 'Daily Recommendation', 'Partner Chat']);
      expect(titles('pregnant'), ['Check-ins', 'Daily Recommendation', 'Pregnancy Milestones', 'Partner Chat']);
      expect(titles('postpartum'), ['Check-ins', 'Daily Recommendation', 'Postpartum Recovery', 'Partner Chat']);
      expect(titles('menopause'), ['Check-ins', 'Daily Recommendation', 'Partner Chat']);
    });

    test('no stage yet means no module cards', () {
      expect(moduleCardsFor(null, logsThisMonth: 0), isEmpty);
    });

    test('only modules without a data source are placeholders', () {
      final cards = moduleCardsFor('cycle', logsThisMonth: 4, onOpenChat: () {});
      final byTitle = {for (final c in cards) c.title: c};
      expect(byTitle['Next Cycle Phase']!.placeholder, isTrue);
      expect(byTitle['Daily Recommendation']!.placeholder, isTrue);
      expect(byTitle['Check-ins']!.placeholder, isFalse);
      expect(byTitle['Check-ins']!.value, '4 this month');
      expect(byTitle['Partner Chat']!.placeholder, isFalse);
    });

    test('BentoCardData defaults keep existing callers unchanged', () {
      const card = BentoCardData(title: 't', value: 'v', description: 'd');
      expect(card.placeholder, isFalse);
      expect(card.onTap, isNull);
    });
  });
}
