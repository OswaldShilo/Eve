import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? EveTheme.defaultTheme(),
      home: Scaffold(body: Center(child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ))),
    );

BoxDecoration _decorationOf(WidgetTester tester, Finder within) {
  final container = tester.widgetList<Container>(
    find.descendant(of: within, matching: find.byType(Container)),
  ).firstWhere((c) => c.decoration is BoxDecoration);
  return container.decoration! as BoxDecoration;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('eveOutlined', () {
    test('draws the mock outline + solid, unblurred drop shadow', () {
      final d = eveOutlined(color: Colors.white, shadow: 6);
      final border = d.border! as Border;
      expect(border.top.color, EveColors.outline);
      expect(border.top.width, 3.5);
      expect(d.boxShadow!.single.offset, const Offset(0, 6));
      expect(d.boxShadow!.single.blurRadius, 0);
      expect(d.boxShadow!.single.color, EveColors.outline);
    });

    test('shadow 0 means no shadow', () {
      expect(eveOutlined(color: Colors.white, shadow: 0).boxShadow, isNull);
    });
  });

  group('EveButton', () {
    testWidgets('primary is ruby-filled and fires onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        EveButton(key: const Key('b'), label: 'Next Step', onPressed: () => taps++),
      ));

      expect(_decorationOf(tester, find.byKey(const Key('b'))).color,
          EveColors.rubyMain);
      await tester.tap(find.text('Next Step'));
      expect(taps, 1);
    });

    testWidgets('secondary is white', (tester) async {
      await tester.pumpWidget(_host(EveButton(
        key: const Key('b'),
        label: 'Continue with Google',
        variant: EveButtonVariant.secondary,
        onPressed: () {},
      )));
      expect(_decorationOf(tester, find.byKey(const Key('b'))).color,
          EveColors.cardBg);
    });

    testWidgets('disabled (null onPressed) is dimmed', (tester) async {
      await tester.pumpWidget(_host(
        const EveButton(key: Key('b'), label: 'Next Step', onPressed: null),
      ));
      final opacity = tester.widget<Opacity>(
        find.descendant(of: find.byKey(const Key('b')), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, 0.5);
    });

    testWidgets('busy shows a spinner and ignores taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(EveButton(
        label: 'Finish Setup',
        busy: true,
        onPressed: () => taps++,
      )));

      expect(find.byKey(const Key('eve-button-busy')), findsOneWidget);
      expect(find.text('Finish Setup'), findsNothing);
      await tester.tap(find.byKey(const Key('eve-button-busy')));
      expect(taps, 0);
    });

    testWidgets('pressing moves the face down and shrinks the shadow',
        (tester) async {
      await tester.pumpWidget(_host(
        EveButton(key: const Key('b'), label: 'Next Step', onPressed: () {}),
      ));
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Next Step')));
      await tester.pump();

      expect(_decorationOf(tester, find.byKey(const Key('b'))).boxShadow!.single.offset,
          const Offset(0, 2));
      await gesture.up();
      await tester.pump();
      expect(_decorationOf(tester, find.byKey(const Key('b'))).boxShadow!.single.offset,
          const Offset(0, 6));
    });
  });

  testWidgets('EveBackButton is 38px and calls back', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(EveBackButton(onPressed: () => taps++)));

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    expect(taps, 1);
    final box = tester.getSize(find.ancestor(
      of: find.byIcon(Icons.arrow_back_rounded),
      matching: find.byType(Container),
    ).first);
    expect(box, const Size(38, 38));
  });

  testWidgets('EveProgressBar fills proportionally', (tester) async {
    await tester.pumpWidget(_host(const SizedBox(
      width: 200,
      child: EveProgressBar(percent: 50),
    )));
    await tester.pump(const Duration(milliseconds: 400));

    final fill = tester.widget<FractionallySizedBox>(
      find.byKey(const Key('eve-progress-fill')),
    );
    expect(fill.widthFactor, closeTo(0.5, 0.001));
  });

  testWidgets('EveChip selected fills ruby with white text', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(Row(children: [
      EveChip(key: const Key('on'), label: 'Light', selected: true, onTap: () => taps++),
      const EveChip(key: Key('off'), label: 'Heavy'),
    ])));

    expect(_decorationOf(tester, find.byKey(const Key('on'))).color,
        EveColors.rubyMain);
    expect(tester.widget<Text>(find.text('Light')).style!.color, Colors.white);
    expect(_decorationOf(tester, find.byKey(const Key('off'))).color,
        EveColors.cardBg);
    await tester.tap(find.text('Light'));
    expect(taps, 1);
  });

  testWidgets('EveToggleRow toggles from the row and the switch',
      (tester) async {
    var value = false;
    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setState) => _host(EveToggleRow(
        label: 'Only show what I approve',
        value: value,
        onChanged: (v) => setState(() => value = v),
      )),
    ));

    await tester.tap(find.text('Only show what I approve'));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    await tester.tap(find.byType(EveToggle));
    await tester.pumpAndSettle();
    expect(value, isFalse);
  });

  testWidgets('EveTextField shows its label and reports changes',
      (tester) async {
    String? latest;
    await tester.pumpWidget(_host(EveTextField(
      label: 'Name',
      fieldKey: const Key('name'),
      onChanged: (v) => latest = v,
    )));

    expect(find.text('Name'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('name')), 'Maya');
    expect(latest, 'Maya');
  });

  testWidgets('SpeechBubble renders the text with a tail', (tester) async {
    await tester.pumpWidget(_host(const SpeechBubble(text: 'Hello, I am Eve')));
    expect(find.text('Hello, I am Eve'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('components follow the dark theme card colour', (tester) async {
    await tester.pumpWidget(_host(
      const EveCard(key: Key('c'), child: Text('x')),
      theme: EveTheme.dark(),
    ));
    expect(_decorationOf(tester, find.byKey(const Key('c'))).color,
        EveColors.darkCard);
  });
}
