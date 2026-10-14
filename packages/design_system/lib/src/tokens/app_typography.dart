import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const List<String> fontFallbacks = [
    'Hind Siliguri',
    'Noto Sans Bengali',
    'Roboto',
    'sans-serif',
  ];

  static TextTheme createTextTheme(Color baseColor) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.3,
        color: baseColor,
        fontFamilyFallback: fontFallbacks,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: baseColor,
        fontFamilyFallback: fontFallbacks,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: baseColor,
        fontFamilyFallback: fontFallbacks,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: baseColor,
        fontFamilyFallback: fontFallbacks,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: baseColor,
        fontFamilyFallback: fontFallbacks,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: baseColor,
        fontFamilyFallback: fontFallbacks,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: baseColor,
        fontFamilyFallback: fontFallbacks,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: baseColor,
        fontFamilyFallback: fontFallbacks,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: baseColor,
        fontFamilyFallback: fontFallbacks,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: baseColor.withAlpha(200),
        fontFamilyFallback: fontFallbacks,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.3,
        color: baseColor,
        fontFamilyFallback: fontFallbacks,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.25,
        color: baseColor.withAlpha(180),
        fontFamilyFallback: fontFallbacks,
      ),
    );
  }
}
