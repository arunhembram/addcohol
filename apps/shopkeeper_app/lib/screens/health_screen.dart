import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppHealthScreen extends ConsumerWidget {
  const AppHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final theme = Theme.of(context);
    final healthAsync = ref.watch(appHealthDiagnosticsProvider);

    return AppScaffold(
      title: AppStrings.get('system_health', lang: lang),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(appHealthDiagnosticsProvider);
          await ref.read(appHealthDiagnosticsProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Store Diagnostic Station',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Probing live cloud connection, secure token store, and client parameters.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              healthAsync.when(
                data: (health) => Column(
                  children: [
                    for (final sub in health.subsystems)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppHealthCard(
                          title: sub.name,
                          status: sub.status.label,
                          message: sub.message,
                          latencyMs: sub.latencyMs,
                        ),
                      ),
                  ],
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: AppLoadingIndicator(message: 'Inspecting shop portal health...'),
                ),
                error: (err, st) => AppErrorView(
                  title: 'Diagnostics Error',
                  message: err.toString(),
                  onRetry: () => ref.invalidate(appHealthDiagnosticsProvider),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: AppStrings.get('refresh', lang: lang),
                icon: Icons.refresh_rounded,
                width: double.infinity,
                variant: AppButtonVariant.outlined,
                onPressed: () => ref.invalidate(appHealthDiagnosticsProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
