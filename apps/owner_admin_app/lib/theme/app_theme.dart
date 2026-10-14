import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF0F766E); // Deep Teal
  static const Color primaryDark = Color(0xFF115E59);
  static const Color accent = Color(0xFF0284C7); // Sky Blue
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color border = Color(0xFFE2E8F0); // Slate 200

  // Status Colors (Per requirements: Green = uploaded/verified, Yellow = missing, Red = rejected/issue, Grey = inactive)
  static const Color statusGreen = Color(0xFF16A34A);
  static const Color statusGreenLight = Color(0xFFDCFCE7);
  static const Color statusYellow = Color(0xFFD97706);
  static const Color statusYellowLight = Color(0xFFFEF3C7);
  static const Color statusRed = Color(0xFFDC2626);
  static const Color statusRedLight = Color(0xFFFEE2E2);
  static const Color statusGrey = Color(0xFF6B7280);
  static const Color statusGreyLight = Color(0xFFF3F4F6);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        surface: cardBackground,
      ),
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto', // Supports English and Bengali glyphs seamlessly
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      dividerColor: border,
    );
  }
}
