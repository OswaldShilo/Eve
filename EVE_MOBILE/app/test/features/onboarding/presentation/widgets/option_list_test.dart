import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/features/onboarding/presentation/widgets/option_list.dart';

Color? _fill(WidgetTester tester, String key) =>
    (tester.widget<Container>(find.byKey(Key(key))).decoration!
            as BoxDecoration)
        .color;

void main() {
  testWidgets('OptionList renders all item labels and reports taps', (
    tester,
  ) async {
    String? toggled;
    await tester.pumpWidget(
      MaterialApp(
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
      ),
    );

    expect(find.text('Cramps'), findsOneWidget);
    expect(find.text('Acne'), findsOneWidget);
    // Selected `.check-box-icon` fills #2A000E with a white tick; unselected
    // stays white and empty.
    expect(_fill(tester, 'check-Cramps'), EveColors.outline);
    expect(_fill(tester, 'check-Acne'), Colors.white);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('option-Acne')));
    expect(toggled, 'Acne');
  });

  testWidgets('OptionList in single mode renders radio icons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OptionList(
            items: const [OptionListItem('Light', 'Light')],
            mode: OptionSelectionMode.single,
            selectedValues: const {'Light'},
            onToggle: (_) {},
          ),
        ),
      ),
    );

    expect(_fill(tester, 'radio-Light'), EveColors.outline);
  });

  testWidgets(
    'long labels wrap instead of overflowing at 360px with 1.5x text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: EveTheme.defaultTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: OptionList(
                  items: const [
                    OptionListItem(
                      'Perimenopause / Menopause support and symptom guidance',
                      'm',
                    ),
                  ],
                  mode: OptionSelectionMode.single,
                  selectedValues: const {'m'},
                  onToggle: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );
}
