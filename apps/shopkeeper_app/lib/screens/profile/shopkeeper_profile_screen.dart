import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/shopkeeper_state_providers.dart';

class ShopkeeperProfileScreen extends ConsumerWidget {
  const ShopkeeperProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(currentBoundShopProvider);
    final category = ShopCategory.fromString(shop.category);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Profile & Support'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Shop Identity Header Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Icon(category.icon, size: 36, color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    shop.shopName,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${category.displayName} • ${shop.address}',
                    style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: BorderRadius.circular(AppRadii.full),
                      border: Border.all(color: AppColors.neutral300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'SHOP CODE: ${shop.shopCode ?? "10000001"}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Operating Hours Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 20, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Operating Hours & Schedule',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _InfoRow(label: 'Opening Time', value: shop.openingTime ?? '09:00 AM'),
                  _InfoRow(label: 'Closing Time', value: shop.closingTime ?? '09:00 PM'),
                  _InfoRow(label: 'Weekly Closed Day', value: shop.weeklyClosedDay ?? 'Sunday'),
                  _InfoRow(label: 'Ad Screens Installed', value: '${shop.activeScreensCount} screen(s) active'),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Owner Details Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_pin, size: 20, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Registered Shopkeeper',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _InfoRow(label: 'Owner Name', value: shop.ownerName ?? 'Tarun Banerjee'),
                  _InfoRow(label: 'Registered Phone', value: shop.phoneNumber ?? '+91 98765 00001'),
                  _InfoRow(label: 'Assigned Territory Zone', value: shop.zoneName ?? 'Kolkata Central Zone'),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Support Contact Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.support_agent_rounded, size: 20, color: AppColors.secondary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Dedicated Support Contact',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _InfoRow(label: 'Field Officer Contact', value: '+91 98300 22201 (Rahul Das)'),
                  _InfoRow(label: 'Helpdesk Hotline', value: '1800-889-SHOP (Toll-Free)'),
                  _InfoRow(label: 'Partner Support Email', value: 'support@shopadplatform.in'),
                  _InfoRow(label: 'Support Hours', value: 'Mon - Sat: 9:00 AM - 7:00 PM IST'),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Sign Out / Unbind Button
            AppButton(
              label: 'Sign Out & Unbind Device',
              variant: AppButtonVariant.danger,
              icon: Icons.logout,
              onPressed: () {
                ref.read(shopkeeperAuthProvider.notifier).logout();
                context.go('/login');
              },
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
