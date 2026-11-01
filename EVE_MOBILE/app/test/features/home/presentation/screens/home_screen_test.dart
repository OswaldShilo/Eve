import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/home/presentation/screens/home_screen.dart';

void main() {
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
    expect(find.text('Next Cycle Phase'), findsOneWidget);
    expect(find.text('in 14 Days'), findsOneWidget);
    expect(find.text('Check-in Streak'), findsOneWidget);
    expect(find.text('8 Days'), findsOneWidget);
    expect(find.text('Daily Recommendation'), findsOneWidget);
    expect(find.text('Boost Collagen & Iron Intake'), findsOneWidget);
  });

  testWidgets('HomeScreen swaps hero speech when an emotion chip is tapped', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    await tester.tap(find.byKey(const Key('home-emotion-chip-Support')));
    await tester.pump();

    expect(find.text('Rest and recovery recorded.'), findsOneWidget);
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
}
