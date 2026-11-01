import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/screens/partner_perm_screen.dart';

void main() {
  testWidgets('PartnerPermScreen hides Pregnancy milestones when not pregnant, shows master toggle, Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        onboardingStateProvider.overrideWith((ref) => OnboardingNotifier()..setField('lifeStage', 'cycle')),
      ],
      child: MaterialApp(
        home: PartnerPermScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Partner Sharing Permissions'), findsOneWidget);
    expect(find.text('Appointment reminders'), findsOneWidget);
    expect(find.text('Support suggestions'), findsOneWidget);
    expect(find.text('Mood updates'), findsOneWidget);
    expect(find.text('Pregnancy milestones'), findsNothing);
    expect(find.text('Only what I approve'), findsOneWidget);
    expect(find.text('Requires manual approval before sharing updates'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });

  testWidgets('PartnerPermScreen shows Pregnancy milestones when lifeStage is pregnant', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        onboardingStateProvider.overrideWith((ref) => OnboardingNotifier()..setField('lifeStage', 'pregnant')),
      ],
      child: MaterialApp(
        home: PartnerPermScreen(onContinue: () {}, onBack: () {}),
      ),
    ));

    expect(find.text('Pregnancy milestones'), findsOneWidget);
  });
}
