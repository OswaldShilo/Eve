import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:eve_app/features/onboarding/presentation/screens/partner_ask_screen.dart';

void main() {
  testWidgets('PartnerAskScreen renders both options, writes partnerInvite, and Continue invokes onContinue', (tester) async {
    var pressed = false;
    late OnboardingNotifier notifier;

    await tester.pumpWidget(ProviderScope(
      child: Consumer(
        builder: (context, ref, _) {
          notifier = ref.read(onboardingStateProvider.notifier);
          return MaterialApp(
            home: PartnerAskScreen(onContinue: () => pressed = true, onBack: () {}),
          );
        },
      ),
    ));

    expect(find.text('Would you like to invite your partner?'), findsOneWidget);
    expect(find.text('Yes, invite my partner'), findsOneWidget);
    expect(find.text('No, keep EVE private'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.byKey(const Key('option-true')));
    expect(notifier.state.partnerInvite, isTrue);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
