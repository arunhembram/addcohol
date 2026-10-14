import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_strings.dart';
import '../localization/locale_provider.dart';
import '../tokens/app_spacing.dart';

class AppScaffold extends ConsumerWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final List<Widget>? extraActions;
  final bool showLanguageToggle;
  final bool showThemeToggle;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.extraActions,
    this.showLanguageToggle = true,
    this.showThemeToggle = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (showLanguageToggle)
            IconButton(
              tooltip: lang == AppLanguage.en ? 'Switch to বাংলা' : 'Switch to English',
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  lang == AppLanguage.en ? 'বাংলা' : 'EN',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              onPressed: () {
                ref.read(languageProvider.notifier).toggleLanguage();
              },
            ),
          if (showThemeToggle)
            IconButton(
              tooltip: 'Toggle Theme',
              icon: Icon(
                themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              ),
              onPressed: () {
                ref.read(themeModeProvider.notifier).toggleTheme();
              },
            ),
          if (extraActions != null) ...extraActions!,
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
