import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

void main() {
  testWidgets('OptionList renders all item labels and reports taps', (tester) async {
    String? toggled;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OptionList(
          items: const [
            OptionListItem('Cramps', 'Cramps'),
            OptionListItem('Acne', 'Acne'),
          ],
          mode: OptionSelectionMode.multi,
          selectedValues: const {'Cramps'},
          onToggle: (v) => toggled = v,
        ),
      ),
    ));

    expect(find.text('Cramps'), findsOneWidget);
    expect(find.text('Acne'), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);

    await tester.tap(find.byKey(const Key('option-Acne')));
    expect(toggled, 'Acne');
  });

  testWidgets('OptionList in single mode renders radio icons', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OptionList(
          items: const [OptionListItem('Light', 'Light')],
          mode: OptionSelectionMode.single,
          selectedValues: const {'Light'},
          onToggle: (_) {},
        ),
      ),
    ));

    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
  });
}
