import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/screens/cycle_info_screen.dart';

void main() {
  testWidgets('CycleInfoScreen renders cycle length, period length, flow fields and Next invokes onContinue', (tester) async {
    var pressed = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: CycleInfoScreen(onContinue: () => pressed = true, onBack: () {}),
      ),
    ));

    expect(find.text('Cycle Details'), findsOneWidget);
    expect(find.text('25–28 days'), findsOneWidget);
    expect(find.text('Irregular'), findsOneWidget);
    expect(find.text('Unsure'), findsOneWidget);
    expect(find.byKey(const Key('cycle-info-period-length-field')), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Moderate'), findsOneWidget);
    expect(find.text('Heavy'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-primary-button')));
    expect(pressed, isTrue);
  });
}
