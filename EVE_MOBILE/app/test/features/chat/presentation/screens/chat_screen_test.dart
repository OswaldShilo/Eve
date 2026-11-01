import 'dart:async';

import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:google_fonts/google_fonts.dart';

Color? _bubbleColor(WidgetTester tester, String key) =>
    (tester.widget<Container>(find.byKey(Key(key)).first).decoration! as BoxDecoration).color;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('ChatScreen renders header, default thread, quick replies and Log nav invokes callback', (tester) async {
    // Tall surface: the thread is anchored to the newest message, so a short
    // one would scroll the oldest bubble out of view.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var logTapped = false;

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(onNavigateLog: () => logTapped = true),
    ));

    expect(find.text('Ryan'), findsOneWidget);
    expect(find.text('Partner • Active today'), findsOneWidget);
    expect(find.text('I have completed my daily health check-in.'), findsOneWidget);
    expect(find.text('Eve: Maya recorded low energy and mild cramps today. Consider offering support.'), findsOneWidget);
    expect(find.text('Sending support'), findsOneWidget);
    expect(find.text('You are doing great'), findsOneWidget);
    expect(find.text('Do you need anything?'), findsOneWidget);
    expect(find.byKey(const Key('chat-input-field')), findsOneWidget);

    await tester.tap(find.text('Log'));
    expect(logTapped, isTrue);
  });

  testWidgets('bubbles use the mock colours: ruby for her, partner blue for him', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));

    expect(_bubbleColor(tester, 'chat-bubble-her'), EveColors.rubyMain);
    expect(_bubbleColor(tester, 'chat-bubble-partner'), EveColors.partnerBlue);
  });

  testWidgets('the newest message is visible without scrolling', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    expect(find.text('Thank you, I appreciate it.').hitTestable(), findsOneWidget);
  });

  testWidgets('typed text survives a rebuild with a new live thread', (tester) async {
    Widget screen(List<ChatMessageData> thread) => MaterialApp(
          home: ChatScreen(thread: thread, onSendMessage: (_) async {}),
        );
    await tester.pumpWidget(screen(const [ChatMessageData(sender: ChatSender.partner, text: 'Hi')]));
    await tester.enterText(find.byKey(const Key('chat-input-field')), 'Half-typed reply');

    await tester.pumpWidget(screen(const [
      ChatMessageData(sender: ChatSender.partner, text: 'Hi'),
      ChatMessageData(sender: ChatSender.partner, text: 'A new message arrived'),
    ]));

    expect(find.text('A new message arrived'), findsOneWidget);
    expect(find.text('Half-typed reply'), findsOneWidget);
  });

  testWidgets('a successful send clears the input; the button spins while sending', (tester) async {
    final sent = <String>[];
    final release = Completer<void>();
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        thread: const [],
        onSendMessage: (text) async {
          sent.add(text);
          await release.future;
        },
      ),
    ));

    await tester.enterText(find.byKey(const Key('chat-input-field')), '  On my way  ');
    await tester.tap(find.byKey(const Key('chat-send-button')));
    await tester.pump();
    expect(find.byKey(const Key('chat-sending')), findsOneWidget);

    // A second tap while sending is ignored.
    await tester.tap(find.byKey(const Key('chat-send-button')));
    release.complete();
    await tester.pump();

    expect(sent, ['On my way']);
    expect(find.text('On my way'), findsNothing);
    expect(find.byKey(const Key('chat-sending')), findsNothing);
  });

  testWidgets('a failed send keeps the text and explains', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        thread: const [],
        onSendMessage: (_) async => throw Exception('offline'),
      ),
    ));

    await tester.enterText(find.byKey(const Key('chat-input-field')), 'Please keep me');
    await tester.tap(find.byKey(const Key('chat-send-button')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Please keep me'), findsOneWidget);
    expect(find.text('Your message was not sent. Please try again.'), findsOneWidget);
  });

  testWidgets('quick replies send immediately', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(thread: const [], onSendMessage: (t) async => sent.add(t)),
    ));

    await tester.tap(find.text('Sending support'));
    await tester.pump();
    expect(sent, ['Sending support']);
  });

  testWidgets('an empty thread shows the waiting-for-partner state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChatScreen(thread: [])));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('chat-empty')), findsOneWidget);
    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('the viewer\'s own messages sit on the right', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ChatScreen(thread: [
        // Partner's view: his message is "mine", hers is not.
        ChatMessageData(sender: ChatSender.partner, text: 'mine', mine: true),
        ChatMessageData(sender: ChatSender.wife, text: 'hers', mine: false),
      ]),
    ));

    final width = tester.getSize(find.byType(MaterialApp)).width;
    expect(tester.getCenter(find.text('mine')).dx, greaterThan(width / 2));
    expect(tester.getCenter(find.text('hers')).dx, lessThan(width / 2));
  });

  for (final scale in [1.0, 1.3, 1.5]) {
    testWidgets('no overflow at 360x640 with text x$scale, keyboard closed and open', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final inset in [0.0, 280.0]) {
        await tester.pumpWidget(MaterialApp(
          theme: EveTheme.defaultTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: inset),
            ),
            child: child!,
          ),
          home: const ChatScreen(),
        ));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: 'inset $inset');
        expect(find.byKey(const Key('chat-input-field')).hitTestable(), findsOneWidget);
      }
    });
  }
}
