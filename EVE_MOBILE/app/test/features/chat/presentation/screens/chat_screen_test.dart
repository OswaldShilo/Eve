import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/chat/presentation/screens/chat_screen.dart';

void main() {
  testWidgets('ChatScreen renders header, default thread, quick replies and Log nav invokes callback', (tester) async {
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
}
