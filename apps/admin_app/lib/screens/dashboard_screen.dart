import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final targetRole = ref.watch(currentAppRoleProvider);
    final lang = ref.watch(languageProvider);
    final theme = Theme.of(context);
    final healthAsync = ref.watch(appHealthDiagnosticsProvider);

    return AppScaffold(
      title: AppStrings.get('dashboard', lang: lang),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              backgroundColor: theme.colorScheme.primaryContainer.withAlpha(80),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, size: 28, color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.appName,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Row(
                          children: [
                            AppBadge(
                              label: lang == AppLanguage.bn
                                  ? targetRole.bengaliName
                                  : targetRole.displayName,
                              variant: AppBadgeVariant.info,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            AppBadge(
                              label: config.environment.name.toUpperCase(),
                              variant: config.environment.isProd
                                  ? AppBadgeVariant.success
                                  : AppBadgeVariant.warning,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppStrings.get('health_summary', lang: lang),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            healthAsync.when(
              data: (health) => AppCard(
                onTap: () => context.push('/health'),
                child: Row(
                  children: [
                    Icon(
                      health.overallState.isHealthy
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      color: health.overallState.isHealthy
                          ? AppColors.successGreen
                          : AppColors.warningAmber,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang == AppLanguage.bn
                                ? health.overallState.bengaliName
                                : health.overallState.displayName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${health.subsystems.length} subsystems checked • Tap for detailed report',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  ],
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: AppLoadingIndicator(),
              ),
              error: (err, _) => AppCard(child: Text('Error loading health: $err')),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Feature Modules & Diagnostics',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ActionTile(
              icon: Icons.health_and_safety_outlined,
              title: AppStrings.get('system_health', lang: lang),
              subtitle: 'Probe Supabase, Keystore, and active environment',
              onTap: () => context.push('/health'),
            ),
            _ActionTile(
              icon: Icons.map_outlined,
              title: AppStrings.get('map_view', lang: lang),
              subtitle: 'Google Maps sandbox & GPS location coordinates',
              onTap: () => context.push('/map'),
            ),
            _ActionTile(
              icon: Icons.qr_code_scanner_rounded,
              title: AppStrings.get('qr_features', lang: lang),
              subtitle: 'Mobile Scanner & QR Code Generator',
              onTap: () => context.push('/qr'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          ],
        ),
      ),
    );
  }
}
