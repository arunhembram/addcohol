import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:design_system/design_system.dart';

void main() {
  group('Design System Tokens & Themes', () {
    test('Light and Dark themes can be instantiated with Material 3', () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
    });

    test('Bengali typography fallback chain is configured', () {
      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.textTheme.displayLarge?.fontFamilyFallback, contains('Noto Sans Bengali'));
    });

    test('Bilingual dictionary returns translations', () {
      expect(AppStrings.get('app_title', lang: AppLanguage.en), 'Shop Ad Platform');
      expect(AppStrings.get('app_title', lang: AppLanguage.bn), 'শপ অ্যাড প্ল্যাটফর্ম');
      expect(AppStrings.get('connected', lang: AppLanguage.bn), 'সংযুক্ত');
      expect(AppStrings.get('retry', lang: AppLanguage.bn), 'আবার চেষ্টা করুন');
    });
  });

  group('Widget Tests', () {
    testWidgets('AppButton renders label and responds to tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppButton(label: 'Click Me', onPressed: () => tapped = true),
          ),
        ),
      );

      expect(find.text('Click Me'), findsOneWidget);
      await tester.tap(find.text('Click Me'));
      expect(tapped, isTrue);
    });

    testWidgets('AppBadge displays correct label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: AppBadge(label: 'Connected', variant: AppBadgeVariant.success),
          ),
        ),
      );

      expect(find.text('Connected'), findsOneWidget);
    });
  });
}
