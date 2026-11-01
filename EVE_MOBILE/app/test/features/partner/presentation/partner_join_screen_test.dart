// EVE_MOBILE/app/test/features/partner/presentation/partner_join_screen_test.dart
import 'package:eve_app/features/partner/presentation/partner_join_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('submits the uppercased code and shows a server error', (tester) async {
    String? submitted;
    await tester.pumpWidget(MaterialApp(
      home: PartnerJoinScreen(onSubmit: (code) async {
        submitted = code;
        return 'This invite code is not valid.';
      }),
    ));

    await tester.enterText(find.byType(TextField), 'abc234');
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(submitted, 'ABC234');
    expect(find.text('This invite code is not valid.'), findsOneWidget);
  });
}
