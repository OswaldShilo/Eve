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

  /// `--bg-light`: the screen background in the default theme.
  static const Color bgLight = Color(0xFFFFF8FA);

  /// `--card-bg`: cards, inputs and the bottom nav in the light themes.
  static const Color cardBg = Color(0xFFFFFFFF);

  /// The mock's literal `#2A000E` outline + solid-shadow colour. It stays the
  /// same in every theme (the mock hard-codes it), unlike `--ruby-dark`,
  /// which flips to a light ink colour under `.dark-theme`.
  static const Color outline = Color(0xFF2A000E);

  /// `.survey-progress-bar` track.
  static const Color progressTrack = Color(0xFFFFE0EC);

  /// `.survey-subtitle` / `.bento-desc` muted grey.
  static const Color mutedText = Color(0xFF777777);

  // `body.dark-theme` overrides.
  static const Color darkBg = Color(0xFF1A050D);
  static const Color darkCard = Color(0xFF2A0916);
  static const Color darkSoft = Color(0xFF380C1E);
  static const Color darkInk = Color(0xFFFFF0F4);
}

/// Per-theme values of the mock's CSS variables that Material's
/// `ColorScheme` has no slot for. Read with `EveTokens.of(context)`.
@immutable
class EveTokens extends ThemeExtension<EveTokens> {
  const EveTokens({
    required this.background,
    required this.card,
    required this.soft,
    required this.ink,
    required this.muted,
  });

  /// `--bg-light`
  final Color background;

  /// `--card-bg`
  final Color card;

  /// `--ruby-soft`
  final Color soft;

  /// `--ruby-dark` used as a text colour (flips in dark theme).
  final Color ink;

  /// Muted secondary text.
  final Color muted;

  /// Outline + solid drop-shadow colour; identical in every theme.
  Color get outline => EveColors.outline;

  static const EveTokens light = EveTokens(
    background: EveColors.bgLight,
    card: EveColors.cardBg,
    soft: EveColors.rubySoft,
    ink: EveColors.rubyDark,
    muted: EveColors.mutedText,
  );

  static const EveTokens plain = EveTokens(
    background: Colors.white,
    card: EveColors.cardBg,
    soft: EveColors.rubySoft,
    ink: EveColors.rubyDark,
    muted: EveColors.mutedText,
  );

  static const EveTokens dark = EveTokens(
    background: EveColors.darkBg,
    card: EveColors.darkCard,
    soft: EveColors.darkSoft,
    ink: EveColors.darkInk,
    muted: Color(0xFFC9A3B3),
  );

  static EveTokens of(BuildContext context) =>
      Theme.of(context).extension<EveTokens>() ?? EveTokens.light;

  @override
  EveTokens copyWith({
    Color? background,
    Color? card,
    Color? soft,
    Color? ink,
    Color? muted,
  }) {
    return EveTokens(
      background: background ?? this.background,
      card: card ?? this.card,
      soft: soft ?? this.soft,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
    );
  }

  @override
  EveTokens lerp(ThemeExtension<EveTokens>? other, double t) {
    if (other is! EveTokens) return this;
    return EveTokens(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

/// Central theme factory for EVE. Produces the three `ThemeData` modes
/// offered on the onboarding Theme screen and consumed by `app.dart`:
/// `defaultTheme`, `light`, and `dark`.
class EveTheme {
  EveTheme._();

  /// Sizes follow the mock's rem values at a 16px root
  /// (e.g. `.survey-title` 1.45rem = 23.2px). Fredoka is the display face
  /// (`--font-display`), Quicksand the body face (`--font-body`); the mock
  /// only loads Quicksand at 600–800, so body text is never lighter than w600.
  static TextTheme textTheme(Color ink, Color muted) {
    return TextTheme(
      // `.brand-eve`
      displayLarge: GoogleFonts.fredoka(
        color: ink,
        fontSize: 60.8,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        height: 1,
      ),
      displayMedium: GoogleFonts.fredoka(
        color: ink,
        fontSize: 32,
        fontWeight: FontWeight.w600,
      ),
      displaySmall: GoogleFonts.fredoka(
        color: ink,
        fontSize: 26,
        fontWeight: FontWeight.w600,
      ),
      // `.survey-title`, `.user-greeting`
      headlineMedium: GoogleFonts.fredoka(
        color: ink,
        fontSize: 23.2,
        fontWeight: FontWeight.w600,
        height: 1.22,
      ),
      // `.month-label`
      headlineSmall: GoogleFonts.fredoka(
        color: ink,
        fontSize: 22.4,
        fontWeight: FontWeight.w600,
      ),
      // `.bento-value`
      titleLarge: GoogleFonts.fredoka(
        color: ink,
        fontSize: 21.6,
        fontWeight: FontWeight.w600,
      ),
      // `.btn-primary`, `.partner-name`
      titleMedium: GoogleFonts.fredoka(
        color: ink,
        fontSize: 17.6,
        fontWeight: FontWeight.w700,
      ),
      // `.mascot-guidance-text`, `.log-toast-title`
      titleSmall: GoogleFonts.fredoka(
        color: ink,
        fontSize: 14.4,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
      // `.option-card`
      bodyLarge: GoogleFonts.quicksand(
        color: ink,
        fontSize: 15.4,
        fontWeight: FontWeight.w700,
      ),
      // `.chat-bubble`, `.form-input`
      bodyMedium: GoogleFonts.quicksand(
        color: ink,
        fontSize: 14.4,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      // `.survey-subtitle`, `.bento-desc`
      bodySmall: GoogleFonts.quicksand(
        color: muted,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      // `.form-label`
      labelLarge: GoogleFonts.quicksand(
        color: ink,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
      // `.sub-chip`, `.chip-btn`, `.bento-title`
      labelMedium: GoogleFonts.quicksand(
        color: ink,
        fontSize: 12.8,
        fontWeight: FontWeight.w800,
      ),
      // `.nav-item`, `.legend-item`
      labelSmall: GoogleFonts.quicksand(
        color: ink,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required EveTokens tokens,
  }) {
    final scheme = brightness == Brightness.dark
        ? ColorScheme.dark(
            primary: EveColors.rubyMain,
            onPrimary: Colors.white,
            secondary: EveColors.fertileTeal,
            surface: tokens.card,
            onSurface: tokens.ink,
            error: EveColors.appointmentOrange,
            outline: EveColors.outline,
          )
        : ColorScheme.light(
            primary: EveColors.rubyMain,
            onPrimary: Colors.white,
            secondary: EveColors.fertileTeal,
            surface: tokens.card,
            onSurface: tokens.ink,
            error: EveColors.appointmentOrange,
            outline: EveColors.outline,
          );
    final text = textTheme(tokens.ink, tokens.muted);
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: tokens.background,
      canvasColor: tokens.background,
      colorScheme: scheme,
      textTheme: text,
      primaryTextTheme: text,
      iconTheme: IconThemeData(color: tokens.ink),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: text.titleMedium,
      ),
      extensions: [tokens],
    );
  }

  /// The app's default branded theme ("Default (Ruby Blush)"): ruby palette
  /// on the mock's `--bg-light` background with white cards.
  static ThemeData defaultTheme() =>
      _build(brightness: Brightness.light, tokens: EveTokens.light);

  /// A plain light theme: same ruby accent, neutral white surfaces.
  static ThemeData light() =>
      _build(brightness: Brightness.light, tokens: EveTokens.plain);

  /// The dark theme: the mock's `body.dark-theme` palette (`#1A050D`
  /// background, `#2A0916` cards, light ink), same ruby accent.
  static ThemeData dark() =>
      _build(brightness: Brightness.dark, tokens: EveTokens.dark);

  /// Maps the onboarding Theme screen's choice ('Default' | 'Light' |
  /// 'Dark', or '' before she has chosen) to the ThemeData to apply.
  static ThemeData forChoice(String choice) => switch (choice) {
        'Dark' => dark(),
        'Light' => light(),
        _ => defaultTheme(),
      };
}
