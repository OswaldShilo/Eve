import 'package:eve_app/app.dart';
import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/features/onboarding/domain/onboarding_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// `pumpAndSettle` never returns while an `EveMascot` is on screen (its idle
/// float repeats forever), so advance a bounded amount of time instead —
/// long enough for go_router's page transition to finish.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('EveApp boots to the real onboarding Welcome screen',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EveApp()));
    await _settle(tester);

    expect(find.text('Begin Setup'), findsOneWidget);
  });

  testWidgets('choosing Dark on the Theme screen applies the dark theme',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EveApp()));
    await _settle(tester);

    final context = tester.element(find.text('Begin Setup'));
    expect(Theme.of(context).scaffoldBackgroundColor, EveColors.bgLight);

    ProviderScope.containerOf(context)
        .read(onboardingStateProvider.notifier)
        .setField('theme', 'Dark');
    await _settle(tester);
    // MaterialApp cross-fades themes with AnimatedTheme; its ticker only
    // starts on the frame after the rebuild, so advance one more frame.
    await tester.pump(const Duration(milliseconds: 300));

    final after = tester.element(find.text('Begin Setup'));
    expect(Theme.of(after).brightness, Brightness.dark);
    expect(Theme.of(after).scaffoldBackgroundColor, EveColors.darkBg);
  });
}
