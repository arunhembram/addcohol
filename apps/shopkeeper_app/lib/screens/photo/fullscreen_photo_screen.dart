import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/shopkeeper_state_providers.dart';

class FullscreenPhotoScreen extends ConsumerWidget {
  const FullscreenPhotoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(currentBoundShopProvider);
    final todayUploadAsync = ref.watch(todayUploadProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${shop.shopName} - Today\'s Ad Photo',
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: todayUploadAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (err, _) => Center(
          child: Text('Error loading photo: $err', style: const TextStyle(color: Colors.white)),
        ),
        data: (upload) {
          if (upload == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_outlined, size: 64, color: AppColors.neutral500),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'No Photo Uploaded Today',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Take a photo of your storefront today to keep your ad screen running active.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.neutral400, fontSize: 13),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: "Capture Today's Photo",
                      icon: Icons.camera_alt,
                      onPressed: () => context.go('/upload'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1:1 Aspect Ratio Square Photo with Shop Code Watermark Overlay
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480, maxHeight: 480),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Base Photo
                          Container(
                            color: Colors.grey.shade900,
                            child: Image.network(
                              upload.photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, st) => Container(
                                color: Colors.grey.shade800,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image, size: 48, color: Colors.white54),
                              ),
                            ),
                          ),

                          // Top-Left Watermark: Shop Code Badge
                          Positioned(
                            top: AppSpacing.md,
                            left: AppSpacing.md,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(AppRadii.sm),
                                border: Border.all(color: Colors.amber, width: 2),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black54, blurRadius: 6),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified, size: 16, color: Colors.amber),
                                  const SizedBox(width: 6),
                                  Text(
                                    'CODE: ${upload.shopCode ?? shop.shopCode ?? "10000001"}',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Top-Right Verified Badge
                          Positioned(
                            top: AppSpacing.md,
                            right: AppSpacing.md,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(AppRadii.full),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on, size: 12, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text(
                                    'GEOFENCE VERIFIED',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Bottom Gradient Overlay with Shop Name, Business Date & Timestamp
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.95),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    shop.shopName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Date: ${upload.businessDate} • Captured: ${upload.captureTime.toLocal().toString().substring(11, 19)}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    'GPS: ${upload.latitude.toStringAsFixed(4)}, ${upload.longitude.toStringAsFixed(4)} (Within ${upload.geofenceDistanceMeters.toStringAsFixed(0)}m of shop)',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Scheduled Deletion Notice
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_delete_outlined, color: Colors.amber, size: 24),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Midnight Server Auto-Purge Policy',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'The private server image will be automatically purged at midnight IST. Local image is retained on your phone and tamper-evident audit logs remain in the system.',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: AppButton(
                      label: 'Return to Dashboard',
                      variant: AppButtonVariant.outlined,
                      onPressed: () => context.go('/'),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
