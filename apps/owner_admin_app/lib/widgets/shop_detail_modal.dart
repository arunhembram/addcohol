import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shop_model.dart';
import '../config/translations.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';
import 'category_chip.dart';

class ShopDetailModal extends StatelessWidget {
  final ShopModel shop;

  const ShopDetailModal({super.key, required this.shop});

  static void show(BuildContext context, ShopModel shop) {
    showDialog(
      context: context,
      builder: (ctx) => ShopDetailModal(shop: shop),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<AppLocaleProvider>(context);
    final proof = shop.currentProof;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              shop.shopName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(status: shop.todayUploadState),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${locale.isBengali ? "দোকান কোড" : "Shop Code"}: ${shop.shopCode} • ${shop.zoneName}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Shop Details Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale.isBengali ? 'ক্যাটেগরি' : 'Category',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        CategoryChip(category: shop.category),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale.isBengali ? 'আপলোড মোড' : 'Upload Mode',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          locale.t('mode_${shop.uploadMode}'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Address & GPS
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.address,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                        ),
                        Text(
                          'GPS: ${shop.latitude.toStringAsFixed(5)}, ${shop.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (shop.merchantPhone != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 18, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '${locale.isBengali ? "মার্চেন্ট ফোন" : "Merchant Phone"}: ${shop.merchantPhone}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Proof Photo Section
              Text(
                locale.isBengali ? "আজকের বিজ্ঞাপনের ছবি (প্রুফ)" : "Today's Advertisement Proof",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              if (proof != null && proof.hasImage && proof.imageUrl != null) ...[
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    '${ApiConfig.imageBaseUrl}${proof.imageUrl}',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${locale.isBengali ? "আপলোড করেছেন" : "Uploaded by"}: ${proof.uploaderType == "merchant" ? (locale.isBengali ? "মার্চেন্ট" : "Merchant") : (locale.isBengali ? "মাঠকর্মী" : "Employee")}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    Row(
                      children: [
                        Icon(
                          proof.isDistanceSuspicious
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 14,
                          color: proof.isDistanceSuspicious ? Colors.orange : Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${locale.isBengali ? "দূরত্ব" : "Distance"}: ${proof.distanceMeters.toStringAsFixed(1)}m',
                          style: TextStyle(
                            fontSize: 12,
                            color: proof.isDistanceSuspicious ? Colors.orange : Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (proof.rejectionReason != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.statusRedLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppTheme.statusRed),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${locale.isBengali ? "বাতিলের কারণ" : "Rejection Reason"}: ${proof.rejectionReason}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.statusRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.photo_library_outlined, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        locale.isBengali
                            ? 'আজকের জন্য এখনও কোনো বিজ্ঞাপনের ছবি আপলোড করা হয়নি।'
                            : 'No advertisement photo uploaded yet today.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
