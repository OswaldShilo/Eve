import 'dart:async';

import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/shared/widgets/appwrite_ping_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget host(Future<String> Function() ping) => MaterialApp(
        theme: EveTheme.defaultTheme(),
        home: Scaffold(body: Center(child: AppwritePingButton(ping: ping))),
      );

  testWidgets('a successful ping shows the reply and the project', (tester) async {
    await tester.pumpWidget(host(() async => 'Pong'));
    await tester.tap(find.byKey(const Key('appwrite-ping')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('appwrite-ping-ok')), findsOneWidget);
    expect(find.textContaining('Appwrite connected: Pong'), findsOneWidget);
    expect(find.textContaining('6ae966a5002293c1e5c3'), findsOneWidget);
  });

  testWidgets('a failed ping shows the error', (tester) async {
    await tester.pumpWidget(host(() async => throw Exception('Invalid Origin')));
    await tester.tap(find.byKey(const Key('appwrite-ping')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('appwrite-ping-failed')), findsOneWidget);
    expect(find.textContaining('Invalid Origin'), findsOneWidget);
  });

  testWidgets('shows progress and ignores repeat taps while pinging', (tester) async {
    final release = Completer<String>();
    var calls = 0;
    await tester.pumpWidget(host(() {
      calls++;
      return release.future;
    }));

    await tester.tap(find.byKey(const Key('appwrite-ping')));
    await tester.pump();
    expect(find.text('Pinging…'), findsOneWidget);
    await tester.tap(find.byKey(const Key('appwrite-ping')));
    release.complete('Pong');
    await tester.pump();
    expect(calls, 1);
  });
}
