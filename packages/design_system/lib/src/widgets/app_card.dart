import 'package:flutter/material.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBorder = border ??
        Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        );

    final cardContent = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: AppRadii.radiusMd,
        border: cardBorder,
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, borderRadius: AppRadii.radiusMd, child: cardContent);
    }
    return cardContent;
  }
}
