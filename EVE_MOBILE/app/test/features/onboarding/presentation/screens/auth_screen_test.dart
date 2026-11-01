import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/auth_screen.dart';

void main() {
  testWidgets('AuthScreen renders copy and both auth actions invoke onContinue', (tester) async {
    var continueCount = 0;
    var backPressed = false;
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(
        onContinue: () => continueCount++,
        onBack: () => backPressed = true,
      ),
    ));

    expect(find.text('Welcome to EVE'), findsOneWidget);
    expect(find.text('Sign in to back up your health insights securely.'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
    expect(find.text('Sign in to securely back up your health data, or continue as a guest.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth-google-button')));
    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(continueCount, 2);

    await tester.tap(find.byKey(const Key('onboarding-back-button')));
    expect(backPressed, isTrue);
  });

  testWidgets('AuthScreen routes the Google button to onGoogleSignIn when provided', (tester) async {
    var google = 0;
    var guest = 0;
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(onContinue: () => guest++, onBack: () {}, onGoogleSignIn: () => google++),
    ));
    await tester.tap(find.byKey(const Key('auth-google-button')));
    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(google, 1);
    expect(guest, 1);
  });
}
