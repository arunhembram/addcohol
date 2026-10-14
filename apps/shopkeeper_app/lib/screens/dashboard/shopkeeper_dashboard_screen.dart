import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/shopkeeper_state_providers.dart';

class ShopkeeperDashboardScreen extends ConsumerWidget {
  const ShopkeeperDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(currentBoundShopProvider);
    final todayUploadAsync = ref.watch(todayUploadProvider);
    final category = ShopCategory.fromString(shop.category);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.storefront, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                shop.shopName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Shop Profile & Support',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            tooltip: 'Sign Out / Unbind',
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(shopkeeperAuthProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Shop Identity Banner with Square Thumbnail / Category Icon
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  // Square thumbnail in place of normal shop icon if today's photo exists
                  todayUploadAsync.maybeWhen(
                    data: (upload) {
                      if (upload != null && upload.photoUrl.isNotEmpty) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: AppColors.neutral200,
                              border: Border.all(color: AppColors.success, width: 2),
                            ),
                            child: Image.network(
                              upload.photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, st) => Container(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image, color: AppColors.primary),
                              ),
                            ),
                          ),
                        );
                      }
                      return _buildDefaultCategoryAvatar(category);
                    },
                    orElse: () => _buildDefaultCategoryAvatar(category),
                  ),

                  const SizedBox(width: AppSpacing.md),

                  // Shop info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.shopName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${category.displayName} • ${shop.address}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.neutral600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            AppBadge(
                              label: 'Code: ${shop.shopCode ?? "10000001"}',
                              variant: AppBadgeVariant.success,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            AppBadge(
                              label: 'Active Ad Partner',
                              variant: AppBadgeVariant.info,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Today's Upload Status Card
            todayUploadAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text('Error checking today\'s upload status: $err'),
              ),
              data: (upload) {
                final isUploaded = upload != null;

                if (isUploaded) {
                  return AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, size: 16, color: Colors.white),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Today's Photo Uploaded & Verified",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  Text(
                                    'Captured at ${upload.captureTime.toLocal().toString().substring(11, 16)} • Geofence Verified',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.neutral600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppBadge(
                              label: 'Verified',
                              variant: AppBadgeVariant.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.neutral100,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 16, color: AppColors.neutral700),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Private server image expires at midnight (IST). Audit record is safely retained.',
                                  style: TextStyle(fontSize: 11, color: AppColors.neutral700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: "View Fullscreen Photo with Shop Code",
                          icon: Icons.fullscreen,
                          variant: AppButtonVariant.primary,
                          onPressed: () => context.push('/view-photo'),
                        ),
                      ],
                    ),
                  );
                } else {
                  return AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.priority_high,
                                size: 16,
                                color: AppColors.warning,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Today's Photo Pending",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                  Text(
                                    'Daily photo capture keeps your shop active for advertisers',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.neutral600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppBadge(
                              label: 'Action Required',
                              variant: AppBadgeVariant.warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'Upload rules: Camera capture only (gallery disabled). Foreground GPS geofence validation is enforced.',
                          style: TextStyle(fontSize: 12, color: AppColors.neutral700),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: "Capture Today's Shop Photo",
                          icon: Icons.camera_alt,
                          onPressed: () => context.push('/upload'),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            // Quick Navigation Hub
            Text(
              'Shop Management',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),

            Row(
              children: [
                Expanded(
                  child: _NavCard(
                    icon: Icons.camera_alt_outlined,
                    title: 'Upload Photo',
                    subtitle: 'Daily camera capture',
                    color: AppColors.primary,
                    onTap: () => context.push('/upload'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _NavCard(
                    icon: Icons.image_outlined,
                    title: 'View Today Photo',
                    subtitle: 'Watermarked view',
                    color: AppColors.secondary,
                    onTap: () => context.push('/view-photo'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // Accept Payment Card (Field Payment Acknowledgement)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              backgroundColor: AppColors.primary.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: const Icon(Icons.qr_code_2, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Accept Payment',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Generate fresh dynamic QR to acknowledge payment',
                          style: TextStyle(fontSize: 11, color: AppColors.neutral700),
                        ),
                      ],
                    ),
                  ),
                  AppButton(
                    label: 'Accept',
                    onPressed: () => context.push('/accept-payment'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Row(
              children: [
                Expanded(
                  child: _NavCard(
                    icon: Icons.payment_outlined,
                    title: 'Ad Payments',
                    subtitle: 'Payouts & rent',
                    color: AppColors.success,
                    onTap: () => context.push('/payments'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _NavCard(
                    icon: Icons.info_outline,
                    title: 'Shop Profile',
                    subtitle: 'Hours & support',
                    color: AppColors.neutral800,
                    onTap: () => context.push('/profile'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultCategoryAvatar(ShopCategory category) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Icon(
        category.icon,
        size: 32,
        color: AppColors.primary,
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
            ),
          ],
        ),
      ),
    );
  }
}
