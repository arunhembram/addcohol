import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../shop_operational_status.dart';
import 'full_size_photo_dialog.dart';

class ShopDetailsModal extends StatelessWidget {
  final Shop shop;
  final ShopOperationalStatus status;
  final VoidCallback? onConvertFollowupToAgreed;

  const ShopDetailsModal({
    super.key,
    required this.shop,
    required this.status,
    this.onConvertFollowupToAgreed,
  });

  static Future<void> show(
    BuildContext context, {
    required Shop shop,
    required ShopOperationalStatus status,
    VoidCallback? onConvertFollowupToAgreed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PointerInterceptor(
        child: ShopDetailsModal(
          shop: shop,
          status: status,
          onConvertFollowupToAgreed: onConvertFollowupToAgreed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = ShopCategory.fromString(shop.category);
    final upload = status.dailyUpload;
    final hasPhoto = upload != null || (shop.shopfrontPhotoUrl != null && shop.shopfrontPhotoUrl!.isNotEmpty);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.neutral300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(category.icon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.shopName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neutral900,
                        ),
                      ),
                      Text(
                        'Assignment Profile & Registration Data',
                        style: TextStyle(fontSize: 11, color: AppColors.neutral600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status & Photo Section
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: status.statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: status.statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        // Square Thumbnail
                        GestureDetector(
                          onTap: hasPhoto
                              ? () => FullSizePhotoDialog.show(context, shop: shop, status: status)
                              : null,
                          child: Stack(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.neutral200,
                                  borderRadius: BorderRadius.circular(AppRadii.sm),
                                  border: Border.all(color: status.statusColor, width: 2),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: hasPhoto
                                    ? Image.network(
                                        upload?.photoUrl ?? shop.shopfrontPhotoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Center(
                                          child: Icon(Icons.broken_image, size: 20, color: AppColors.neutral500),
                                        ),
                                      )
                                    : Center(
                                        child: Icon(status.statusIcon, size: 24, color: status.statusColor),
                                      ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: status.statusColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  child: Icon(status.statusIcon, size: 10, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${status.badgeText} (${status.bengaliBadgeText})',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: status.statusColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hasPhoto
                                    ? 'Tap thumbnail to view full-size photo'
                                    : 'Asia/Kolkata business date: ${ShopOperationalService.getKolkataBusinessDate()}',
                                style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
                              ),
                            ],
                          ),
                        ),
                        if (hasPhoto)
                          IconButton(
                            icon: const Icon(Icons.fullscreen, color: AppColors.primary),
                            tooltip: 'View Full Photo',
                            onPressed: () => FullSizePhotoDialog.show(context, shop: shop, status: status),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Registration details grid
                  _buildSectionHeader('Shop Assignment & Identification'),
                  _buildDetailRow('Shop Code (8-Digit)', shop.shopCode ?? 'Not Assigned', isCode: true),
                  _buildDetailRow('Display Reference', shop.displayReference ?? 'N/A'),
                  _buildDetailRow('Agreement Status', shop.isAgreed ? 'Agreed & Active' : 'Follow-up Scheduled',
                      valueColor: shop.isAgreed ? AppColors.success : AppColors.warning),
                  _buildDetailRow('Category', '${category.displayName} (${shop.category})'),
                  _buildDetailRow('Active Screens', '${shop.activeScreensCount} screen(s)'),
                  _buildDetailRow('Monthly Partner Rent', '₹${shop.monthlyRent.toStringAsFixed(0)} / month'),

                  const SizedBox(height: AppSpacing.md),
                  _buildSectionHeader('Owner & Contact Information'),
                  _buildDetailRow('Owner Name', shop.ownerName ?? 'N/A'),
                  _buildDetailRow('Phone Number', shop.phoneNumber ?? 'Not provided', isPhone: true),

                  const SizedBox(height: AppSpacing.md),
                  _buildSectionHeader('Location & Jurisdiction'),
                  _buildDetailRow('Assigned Zone', shop.zoneName ?? 'N/A'),
                  _buildDetailRow('Zone ID', shop.zoneId ?? 'N/A'),
                  _buildDetailRow('Full Address', shop.address),
                  if (shop.landmark != null && shop.landmark!.isNotEmpty)
                    _buildDetailRow('Landmark', shop.landmark!),
                  _buildDetailRow(
                    'GPS Coordinates',
                    '${shop.latitude.toStringAsFixed(6)}, ${shop.longitude.toStringAsFixed(6)}',
                  ),

                  const SizedBox(height: AppSpacing.md),
                  _buildSectionHeader('Operating Timing (Asia/Kolkata)'),
                  _buildDetailRow('Opening Time', shop.openingTime ?? 'Not set'),
                  _buildDetailRow('Closing Time', shop.closingTime ?? 'Not set'),
                  _buildDetailRow('Weekly Closed Day', shop.weeklyClosedDay ?? 'None'),

                  if (shop.isFollowup) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildSectionHeader('Follow-up Information'),
                    _buildDetailRow('Follow-up Reason', shop.followupReason ?? 'N/A'),
                    if (shop.nextFollowupDate != null)
                      _buildDetailRow(
                        'Scheduled Date',
                        shop.nextFollowupDate!.toLocal().toString().substring(0, 16),
                      ),
                    if (onConvertFollowupToAgreed != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        label: 'Convert Follow-up to Agreed Shop',
                        icon: Icons.check_circle_outline,
                        onPressed: onConvertFollowupToAgreed,
                      ),
                    ],
                  ],

                  const SizedBox(height: AppSpacing.md),
                  _buildSectionHeader('Audit Timestamp'),
                  _buildDetailRow('Registered On', shop.createdAt.toLocal().toString().substring(0, 16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isCode = false, bool isPhone = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.neutral600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCode ? FontWeight.bold : FontWeight.w600,
                letterSpacing: isCode ? 1.5 : 0.0,
                color: valueColor ?? (isCode ? AppColors.primary : AppColors.neutral900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
