import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// EVE's brand color tokens, ported 1:1 from the CSS custom properties in
/// `UI/mobile/mockv4.html`. Do not redefine these elsewhere — import this
/// class instead.
class EveColors {
  EveColors._();

  static const Color rubyMain = Color(0xFFFF2A6D);
  static const Color rubyDark = Color(0xFF2A000E);
  static const Color rubyBlush = Color(0xFFFFA0B8);
  static const Color rubySoft = Color(0xFFFFF0F4);
  static const Color partnerBlue = Color(0xFF3D7BFF);
  static const Color fertileTeal = Color(0xFF2EC4B6);
  static const Color symptomPurple = Color(0xFF9B51E0);
  static const Color appointmentOrange = Color(0xFFFF9F1C);
}

/// Central theme factory for EVE. Produces the three `ThemeData` modes
/// offered on the onboarding Theme screen and consumed by `app.dart`:
/// `defaultTheme`, `light`, and `dark`.
class EveTheme {
  EveTheme._();

  static TextTheme _textTheme(Color bodyColor, Color displayColor) {
    return TextTheme(
      displayLarge: GoogleFonts.fredoka(
        color: displayColor,
        fontSize: 32,
        fontWeight: FontWeight.w600,
      ),
      displayMedium: GoogleFonts.fredoka(
        color: displayColor,
        fontSize: 26,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.fredoka(
        color: displayColor,
        fontSize: 22,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: GoogleFonts.quicksand(color: bodyColor, fontSize: 16),
      bodyMedium: GoogleFonts.quicksand(color: bodyColor, fontSize: 14),
      labelLarge: GoogleFonts.quicksand(
        color: bodyColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// The app's default branded theme: ruby palette on a soft blush
  /// background. Used before the onboarding Theme screen sets an
  /// explicit preference.
  static ThemeData defaultTheme() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: EveColors.rubySoft,
      colorScheme: const ColorScheme.light(
        primary: EveColors.rubyMain,
        secondary: EveColors.fertileTeal,
        surface: EveColors.rubySoft,
        error: EveColors.appointmentOrange,
      ),
      textTheme: _textTheme(EveColors.rubyDark, EveColors.rubyDark),
    );
  }

  /// A plain light theme: same ruby accent, neutral white surfaces.
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: EveColors.rubyMain,
        secondary: EveColors.fertileTeal,
        surface: Colors.white,
        error: EveColors.appointmentOrange,
      ),
      textTheme: _textTheme(EveColors.rubyDark, EveColors.rubyDark),
    );
  }

  /// The dark theme: ruby-dark background, same ruby-main accent, blush
  /// text for contrast.
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: EveColors.rubyDark,
      colorScheme: const ColorScheme.dark(
        primary: EveColors.rubyMain,
        secondary: EveColors.fertileTeal,
        surface: EveColors.rubyDark,
        error: EveColors.appointmentOrange,
      ),
      textTheme: _textTheme(EveColors.rubyBlush, EveColors.rubyBlush),
    );
  }
}
