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

    testWidgets('defaultTheme is light, ruby-branded, on a soft background',
        (tester) async {
      final theme = await resolve(EveTheme.defaultTheme(), tester);

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, EveColors.rubyMain);
      expect(theme.scaffoldBackgroundColor, EveColors.rubySoft);
    });

    testWidgets('light is a plain light theme on a white background',
        (tester) async {
      final theme = await resolve(EveTheme.light(), tester);

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, EveColors.rubyMain);
      expect(theme.scaffoldBackgroundColor, Colors.white);
    });

    testWidgets('dark uses ruby-dark as the background with the same accent',
        (tester) async {
      final theme = await resolve(EveTheme.dark(), tester);

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, EveColors.rubyMain);
      expect(theme.scaffoldBackgroundColor, EveColors.rubyDark);
    });
  });
}
