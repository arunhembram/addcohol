import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../shop_operational_status.dart';

class FullSizePhotoDialog extends StatelessWidget {
  final Shop shop;
  final ShopOperationalStatus status;

  const FullSizePhotoDialog({
    super.key,
    required this.shop,
    required this.status,
  });

  static Future<void> show(
    BuildContext context, {
    required Shop shop,
    required ShopOperationalStatus status,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => FullSizePhotoDialog(shop: shop, status: status),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upload = status.dailyUpload;
    final photoUrl = upload?.photoUrl ?? shop.shopfrontPhotoUrl ?? '';

    return PointerInterceptor(
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.neutral200)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: status.statusColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(status.statusIcon, color: status.statusColor, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop.shopName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.neutral900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (shop.shopCode != null)
                                Text(
                                  'Code: ${shop.shopCode}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: status.statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppRadii.sm),
                                ),
                                child: Text(
                                  '${status.badgeText} • ${status.bengaliBadgeText}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: status.statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.neutral700),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Image display with zoom/pan
              Expanded(
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: photoUrl.isNotEmpty
                      ? InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4.0,
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                      : null,
                                  color: Colors.white,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.broken_image_rounded,
                                      color: Colors.white60,
                                      size: 56,
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    const Text(
                                      'Failed to load photo preview',
                                      style: TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'Path: $photoUrl',
                                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.no_photography_rounded,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 54,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              const Text(
                                'No photo uploaded for today',
                                style: TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                status.badgeText,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                ),
              ),

              // Metadata footer bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.neutral50,
                  border: Border(top: BorderSide(color: AppColors.neutral200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Business Date: ${upload?.businessDate ?? ShopOperationalService.getKolkataBusinessDate()}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.neutral800,
                            ),
                          ),
                          if (upload != null) ...[
                            Text(
                              'Uploaded: ${upload.serverUploadTime.toLocal().toString().substring(0, 16)} • Uploader: ${upload.uploaderId}',
                              style: const TextStyle(fontSize: 10, color: AppColors.neutral600),
                            ),
                          ] else ...[
                            Text(
                              'Shop Coordinates: ${shop.latitude.toStringAsFixed(4)}, ${shop.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 10, color: AppColors.neutral600),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (upload?.isGeofenceVerified == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadii.full),
                          border: Border.all(color: AppColors.success),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 12, color: AppColors.success),
                            SizedBox(width: 4),
                            Text(
                              'GPS Verified',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
