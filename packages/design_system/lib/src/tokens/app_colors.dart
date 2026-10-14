import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Brand Hues (Teal / Modern Emerald)
  static const Color primaryTeal = Color(0xFF006874);
  static const Color primaryContainerTeal = Color(0xFF9EEFFD);
  static const Color onPrimaryTeal = Colors.white;

  // Secondary Accents (Slate / Dark Cyan)
  static const Color secondarySlate = Color(0xFF4A6267);
  static const Color secondaryContainer = Color(0xFFCDE7EC);

  // Status & Semantic Colors
  static const Color successGreen = Color(0xFF00875A);
  static const Color successContainer = Color(0xFFD4EDDA);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color errorRed = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);

  // Semantic Aliases
  static const Color primary = primaryTeal;
  static const Color primaryContainer = primaryContainerTeal;
  static const Color secondary = secondarySlate;
  static const Color success = successGreen;
  static const Color warning = warningAmber;
  static const Color error = errorRed;
  static const Color info = Color(0xFF0284C7);

  // Neutral Palette
  static const Color neutral50 = Color(0xFFF9FAFB);
  static const Color neutral100 = Color(0xFFF3F4F6);
  static const Color neutral200 = Color(0xFFE5E7EB);
  static const Color neutral300 = Color(0xFFD1D5DB);
  static const Color neutral400 = Color(0xFF9CA3AF);
  static const Color neutral500 = Color(0xFF6B7280);
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral700 = Color(0xFF374151);
  static const Color neutral800 = Color(0xFF1F2937);
  static const Color neutral900 = Color(0xFF111827);

  // Neutral Tones - Light

  static const Color surfaceLight = Color(0xFFFBFDFD);
  static const Color surfaceVariantLight = Color(0xFFDBE4E6);
  static const Color backgroundLight = Color(0xFFF8FAFB);
  static const Color outlineLight = Color(0xFF6F797A);

  // Neutral Tones - Dark
  static const Color surfaceDark = Color(0xFF191C1D);
  static const Color surfaceVariantDark = Color(0xFF3F484A);
  static const Color backgroundDark = Color(0xFF111415);
  static const Color outlineDark = Color(0xFF899294);

  // Material 3 Color Schemes
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primaryTeal,
    onPrimary: Colors.white,
    primaryContainer: primaryContainerTeal,
    onPrimaryContainer: Color(0xFF001F24),
    secondary: secondarySlate,
    onSecondary: Colors.white,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: Color(0xFF051F23),
    tertiary: Color(0xFF525E7D),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFDAE2FF),
    onTertiaryContainer: Color(0xFF0E1A37),
    error: errorRed,
    onError: Colors.white,
    errorContainer: errorContainer,
    onErrorContainer: Color(0xFF410002),
    surface: surfaceLight,
    onSurface: Color(0xFF191C1D),
    surfaceContainerHighest: surfaceVariantLight,
    onSurfaceVariant: Color(0xFF3F484A),
    outline: outlineLight,
    outlineVariant: Color(0xFFBFC8CA),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFF2E3132),
    onInverseSurface: Color(0xFFEFF1F1),
    inversePrimary: Color(0xFF82D3E0),
  );

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF82D3E0),
    onPrimary: Color(0xFF00363D),
    primaryContainer: Color(0xFF004E58),
    onPrimaryContainer: Color(0xFF9EEFFD),
    secondary: Color(0xFFB1CBD0),
    onSecondary: Color(0xFF1C3438),
    secondaryContainer: Color(0xFF334B4F),
    onSecondaryContainer: Color(0xFFCDE7EC),
    tertiary: Color(0xFFBAC6EA),
    onTertiary: Color(0xFF24304D),
    tertiaryContainer: Color(0xFF3B4664),
    onTertiaryContainer: Color(0xFFDAE2FF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: surfaceDark,
    onSurface: Color(0xFFE1E3E3),
    surfaceContainerHighest: surfaceVariantDark,
    onSurfaceVariant: Color(0xFFBFC8CA),
    outline: outlineDark,
    outlineVariant: Color(0xFF3F484A),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFE1E3E3),
    onInverseSurface: Color(0xFF191C1D),
    inversePrimary: primaryTeal,
  );
}
