import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

enum AppBadgeVariant { success, warning, error, info, neutral }

class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (variant) {
      case AppBadgeVariant.success:
        bg = AppColors.successContainer;
        fg = AppColors.successGreen;
        break;
      case AppBadgeVariant.warning:
        bg = AppColors.warningContainer;
        fg = AppColors.warningAmber;
        break;
      case AppBadgeVariant.error:
        bg = AppColors.errorContainer;
        fg = AppColors.errorRed;
        break;
      case AppBadgeVariant.info:
        bg = AppColors.primaryContainerTeal;
        fg = AppColors.primaryTeal;
        break;
      case AppBadgeVariant.neutral:
        bg = AppColors.surfaceVariantLight;
        fg = AppColors.secondarySlate;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs + 1),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadii.radiusSm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}
