import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/profile_screen.dart';

void main() {
  testWidgets('ProfileScreen renders all five fields and Next Step invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: ProfileScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('About You'), findsOneWidget);
    expect(find.text('Enter your basic profile details so EVE can personalize your tracking.'), findsOneWidget);
    expect(find.byKey(const Key('profile-name-field')), findsOneWidget);
    expect(find.byKey(const Key('profile-age-field')), findsOneWidget);
    expect(find.byKey(const Key('profile-height-field')), findsOneWidget);
    expect(find.byKey(const Key('profile-weight-field')), findsOneWidget);
    expect(find.byKey(const Key('profile-country-field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
