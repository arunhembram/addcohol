import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

class CompanyShopDetailModal extends StatelessWidget {
  final CompanyVisibleShop shop;
  final bool canViewDailyProof;

  const CompanyShopDetailModal({
    super.key,
    required this.shop,
    required this.canViewDailyProof,
  });

  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'chicken':
        return Icons.restaurant_rounded;
      case 'fast food':
        return Icons.fastfood_rounded;
      case 'grocery':
        return Icons.local_grocery_store_rounded;
      case 'saloon':
        return Icons.content_cut_rounded;
      case 'pharmacy':
        return Icons.local_pharmacy_rounded;
      case 'tea stall':
        return Icons.coffee_rounded;
      case 'bakery':
        return Icons.cake_rounded;
      case 'clothing':
        return Icons.checkroom_rounded;
      default:
        return Icons.storefront_rounded;
    }
  }

  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'chicken':
        return Colors.orange;
      case 'fast food':
        return Colors.deepOrange;
      case 'grocery':
        return Colors.green;
      case 'saloon':
        return Colors.purple;
      case 'pharmacy':
        return Colors.teal;
      case 'tea stall':
        return Colors.brown;
      case 'bakery':
        return Colors.pink;
      case 'clothing':
        return Colors.indigo;
      default:
        return Colors.blueGrey;
    }
  }

  static void show(BuildContext context, {
    required CompanyVisibleShop shop,
    required bool canViewDailyProof,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (ctx) => CompanyShopDetailModal(
        shop: shop,
        canViewDailyProof: canViewDailyProof,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catIcon = getCategoryIcon(shop.category);
    final catColor = getCategoryColor(shop.category);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Category & Shop Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: catColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(catIcon, color: catColor, size: 36),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.shopName,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          AppBadge(
                            label: shop.category,
                            variant: AppBadgeVariant.neutral,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.neutral100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.neutral300),
                            ),
                            child: Text(
                              'Code: ${shop.shopCode}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Basic Information Only Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.neutral50,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    icon: Icons.map_outlined,
                    label: 'Assigned Zone',
                    value: shop.zoneName,
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Display Location',
                    value: shop.address,
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    icon: Icons.tv_rounded,
                    label: 'Installed Screens',
                    value: '${shop.screenCount} Screen${shop.screenCount > 1 ? 's' : ''}',
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    icon: Icons.check_circle_outline,
                    label: 'Advertising Status',
                    value: 'Agreed & Active',
                    statusBadge: AppBadge(
                      label: 'Agreed & Active',
                      variant: AppBadgeVariant.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Daily Photo Proof Section (Respects can_view_daily_proof feature flag)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: canViewDailyProof
                    ? (shop.hasTodayProof == true
                        ? AppColors.success.withAlpha(15)
                        : AppColors.warning.withAlpha(15))
                    : AppColors.neutral100,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(
                  color: canViewDailyProof
                      ? (shop.hasTodayProof == true
                          ? AppColors.success.withAlpha(60)
                          : AppColors.warning.withAlpha(60))
                      : AppColors.neutral300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    canViewDailyProof
                        ? (shop.hasTodayProof == true
                            ? Icons.verified_rounded
                            : Icons.schedule_rounded)
                        : Icons.lock_outline_rounded,
                    size: 24,
                    color: canViewDailyProof
                        ? (shop.hasTodayProof == true
                            ? AppColors.success
                            : AppColors.warning)
                        : AppColors.neutral500,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          canViewDailyProof
                              ? (shop.hasTodayProof == true
                                  ? 'Today\'s Proof Verified'
                                  : 'Today\'s Proof Pending')
                              : 'Daily Proof Status (Hidden)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: canViewDailyProof
                                ? (shop.hasTodayProof == true
                                    ? AppColors.success
                                    : AppColors.warning)
                                : AppColors.neutral700,
                          ),
                        ),
                        Text(
                          canViewDailyProof
                              ? (shop.hasTodayProof == true
                                  ? 'Field advertisement displayed and verified for current business day.'
                                  : 'Shopkeeper has not yet uploaded today\'s photo.')
                              : 'Requires Master Admin authorization flag (can_view_daily_proof).',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.neutral600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Privacy Assurance Note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.privacy_tip_outlined, size: 14, color: AppColors.neutral500),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Company View: Sensitive employee & identity records are excluded by RLS.',
                      style: TextStyle(fontSize: 10, color: AppColors.neutral600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            AppButton(
              label: 'Close Details',
              variant: AppButtonVariant.secondary,
              width: double.infinity,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? statusBadge,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.neutral500),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.neutral600),
        ),
        const Spacer(),
        if (statusBadge != null)
          statusBadge
        else
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}
