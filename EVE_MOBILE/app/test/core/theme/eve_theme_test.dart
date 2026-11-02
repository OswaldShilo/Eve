import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    // Prevent google_fonts from attempting a network fetch during tests;
    // fall back to the bundled/system font instead.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('EveColors', () {
    test('matches the locked brand hex values', () {
      expect(EveColors.rubyMain, const Color(0xFFFF2A6D));
      expect(EveColors.rubyDark, const Color(0xFF2A000E));
      expect(EveColors.rubyBlush, const Color(0xFFFFA0B8));
      expect(EveColors.rubySoft, const Color(0xFFFFF0F4));
      expect(EveColors.partnerBlue, const Color(0xFF3D7BFF));
      expect(EveColors.fertileTeal, const Color(0xFF2EC4B6));
      expect(EveColors.symptomPurple, const Color(0xFF9B51E0));
      expect(EveColors.appointmentOrange, const Color(0xFFFF9F1C));
    });
  });

  group('EveTheme', () {
    Future<ThemeData> resolve(ThemeData theme, WidgetTester tester) async {
      late ThemeData resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              resolved = Theme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return resolved;
    }

    testWidgets(
        'defaultTheme is light, ruby-branded, on the mock --bg-light background',
        (tester) async {
      final theme = await resolve(EveTheme.defaultTheme(), tester);

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, EveColors.rubyMain);
      // mockv4 `--bg-light` is #FFF8FA; cards are white (`--card-bg`).
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFFF8FA));
      expect(theme.extension<EveTokens>()!.card, Colors.white);
      expect(theme.extension<EveTokens>()!.soft, EveColors.rubySoft);
    });

    testWidgets('light is a plain light theme on a white background',
        (tester) async {
      final theme = await resolve(EveTheme.light(), tester);

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, EveColors.rubyMain);
      expect(theme.scaffoldBackgroundColor, Colors.white);
    });

    testWidgets('dark uses the mock body.dark-theme palette, same accent',
        (tester) async {
      final theme = await resolve(EveTheme.dark(), tester);
      final tokens = theme.extension<EveTokens>()!;

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, EveColors.rubyMain);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF1A050D));
      expect(tokens.card, const Color(0xFF2A0916));
      expect(tokens.soft, const Color(0xFF380C1E));
      expect(tokens.ink, const Color(0xFFFFF0F4));
      // Outline stays the literal #2A000E in every theme, as in the mock.
      expect(tokens.outline, const Color(0xFF2A000E));
    });

    test('forChoice maps the Theme screen values', () {
      expect(EveTheme.forChoice('Dark').brightness, Brightness.dark);
      expect(EveTheme.forChoice('Light').scaffoldBackgroundColor, Colors.white);
      expect(EveTheme.forChoice('Default').scaffoldBackgroundColor,
          EveColors.bgLight);
      expect(EveTheme.forChoice('').scaffoldBackgroundColor, EveColors.bgLight);
    });

    test('text theme uses Fredoka for display/headline/title and Quicksand '
        'for body/label, with no unset slots', () {
      final t = EveTheme.defaultTheme().textTheme;
      for (final s in [
        t.displayLarge,
        t.headlineMedium,
        t.headlineSmall,
        t.titleLarge,
        t.titleMedium,
        t.titleSmall,
      ]) {
        expect(s!.fontFamily, contains('Fredoka'));
      }
      for (final s in [
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall,
        t.labelLarge,
        t.labelMedium,
        t.labelSmall,
      ]) {
        expect(s!.fontFamily, contains('Quicksand'));
        expect(s.fontWeight!.value, greaterThanOrEqualTo(600));
      }
      // `.survey-title` 1.45rem
      expect(t.headlineMedium!.fontSize, closeTo(23.2, 0.01));
    });
  });
}
