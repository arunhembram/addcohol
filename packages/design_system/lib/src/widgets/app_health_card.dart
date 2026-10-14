import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import 'app_badge.dart';
import 'app_card.dart';

class AppHealthCard extends StatelessWidget {
  final String title;
  final String status;
  final String message;
  final int? latencyMs;
  final IconData icon;

  const AppHealthCard({
    super.key,
    required this.title,
    required this.status,
    required this.message,
    this.latencyMs,
    this.icon = Icons.dns_outlined,
  });

  AppBadgeVariant _resolveBadgeVariant(String statusStr) {
    final lower = statusStr.toLowerCase();
    if (lower.contains('connect') || lower.contains('healthy') || lower.contains('granted')) {
      return AppBadgeVariant.success;
    }
    if (lower.contains('degraded') || lower.contains('warn') || lower.contains('unconfigured')) {
      return AppBadgeVariant.warning;
    }
    if (lower.contains('disconnect') ||
        lower.contains('fail') ||
        lower.contains('denied') ||
        lower.contains('error')) {
      return AppBadgeVariant.error;
    }
    return AppBadgeVariant.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeVariant = _resolveBadgeVariant(status);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha(120),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (latencyMs != null) ...[
                Text(
                  '${latencyMs}ms',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.secondarySlate,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              AppBadge(label: status, variant: badgeVariant),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
