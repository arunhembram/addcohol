import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_data_provider.dart';
import '../config/translations.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../models/upload_model.dart';
import '../widgets/status_badge.dart';

class UploadReviewScreen extends StatefulWidget {
  const UploadReviewScreen({super.key});

  @override
  State<UploadReviewScreen> createState() => _UploadReviewScreenState();
}

class _UploadReviewScreenState extends State<UploadReviewScreen> {
  UploadModel? _selectedUpload;

  void _showRejectDialog(BuildContext context, UploadModel upload) {
    final dataProvider = Provider.of<AdminDataProvider>(context, listen: false);
    final locale = Provider.of<AppLocaleProvider>(context, listen: false);
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          locale.isBengali ? 'বিজ্ঞাপনের প্রুফ বাতিল করুন' : 'Reject Advertisement Proof',
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.statusRed),
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${locale.isBengali ? "দোকান" : "Shop"}: ${upload.shopName} (${upload.shopCode})',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Text(
                locale.isBengali
                    ? 'বাতিলের কারণ লিখুন (বাধ্যতামূলক):'
                    : 'Rejection Reason (Required):',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: locale.isBengali
                      ? 'e.g. পোস্টারটি স্পষ্ট নয়, QR কোডের পাশে পুরো ফ্রেম সহ ছবি তুলুন।'
                      : 'e.g. Poster is blurry or QR code is partially cut off.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(locale.t('btn_cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              await dataProvider.reviewProof(
                uploadId: upload.id,
                status: 'rejected',
                rejectionReason: reasonCtrl.text.trim(),
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                setState(() => _selectedUpload = null);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusRed,
              foregroundColor: Colors.white,
            ),
            child: Text(locale.t('btn_reject')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<AdminDataProvider>(context);
    final locale = Provider.of<AppLocaleProvider>(context);
    final uploads = dataProvider.todayUploads;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locale.t('nav_upload_review'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locale.isBengali
                        ? 'আজকের আপলোডকৃত বিজ্ঞাপনের ছবি পর্যালোচনা, দূরত্ব যাচাই ও অনুমোদন'
                        : 'Review daily proof photos, verify GPS proximity, and approve or reject',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Split View: List on left, Image preview & action on right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Upload Queue
              Expanded(
                flex: 3,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${locale.isBengali ? "আজকের প্রুফ তালিকা" : "Today Uploads"} (${uploads.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        if (uploads.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                locale.isBengali
                                    ? 'আজকে এখনও কোনো বিজ্ঞাপনের ছবি আপলোড করা হয়নি।'
                                    : 'No proof photos uploaded today yet.',
                                style: const TextStyle(color: AppTheme.textSecondary),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: uploads.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 16),
                            itemBuilder: (ctx, i) {
                              final u = uploads[i];
                              final isSelected = _selectedUpload?.id == u.id;

                              return InkWell(
                                onTap: () => setState(() => _selectedUpload = u),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.primary.withOpacity(0.06)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected
                                        ? Border.all(color: AppTheme.primary.withOpacity(0.4))
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: u.imageUrl != null
                                            ? Image.network(
                                                '${ApiConfig.imageBaseUrl}${u.imageUrl}',
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    const Icon(
                                                      Icons.broken_image,
                                                      size: 20,
                                                      color: Colors.grey,
                                                    ),
                                              )
                                            : const Icon(Icons.image_outlined, color: Colors.grey),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              u.shopName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${u.shopCode} • ${u.zoneName} • ${u.uploaderType == "merchant" ? (locale.isBengali ? "মার্চেন্ট" : "Merchant") : (locale.isBengali ? "মাঠকর্মী" : "Employee")}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          StatusBadge(status: u.status),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                u.isDistanceSuspicious
                                                    ? Icons.warning_amber_rounded
                                                    : Icons.check_circle_outline,
                                                size: 12,
                                                color: u.isDistanceSuspicious
                                                    ? Colors.orange
                                                    : Colors.green,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${u.distanceMeters.toStringAsFixed(0)}m',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: u.isDistanceSuspicious
                                                      ? Colors.orange
                                                      : Colors.green,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Right: Selected Proof Details & Action Box
              Expanded(
                flex: 4,
                child: _selectedUpload == null
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(48),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app_outlined,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  locale.isBengali
                                      ? 'বামপাশের তালিকা থেকে যেকোনো একটি প্রুফ নির্বাচন করুন'
                                      : 'Select a proof from the list on the left to review',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedUpload!.shopName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'Code: ${_selectedUpload!.shopCode} • Zone: ${_selectedUpload!.zoneName}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  StatusBadge(status: _selectedUpload!.status, isLarge: true),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Image Viewer
                              Container(
                                height: 320,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _selectedUpload!.imageUrl != null
                                    ? Image.network(
                                        '${ApiConfig.imageBaseUrl}${_selectedUpload!.imageUrl}',
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) => const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 48,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      )
                                    : const Center(
                                        child: Text(
                                          'No image file',
                                          style: TextStyle(color: Colors.white70),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 16),

                              // GPS & Geo Proximity Box
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _selectedUpload!.isDistanceSuspicious
                                      ? AppTheme.statusYellowLight
                                      : AppTheme.statusGreenLight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _selectedUpload!.isDistanceSuspicious
                                        ? AppTheme.statusYellow
                                        : AppTheme.statusGreen,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _selectedUpload!.isDistanceSuspicious
                                          ? Icons.warning_amber_rounded
                                          : Icons.verified_user_outlined,
                                      color: _selectedUpload!.isDistanceSuspicious
                                          ? AppTheme.statusYellow
                                          : AppTheme.statusGreen,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedUpload!.isDistanceSuspicious
                                                ? (locale.isBengali
                                                      ? 'সতর্কতা: ক্যাপচার দূরত্ব দোকান থেকে ১৫০ মিটারের বেশি!'
                                                      : 'Suspicious: GPS distance > 150m from shop location!')
                                                : (locale.isBengali
                                                      ? 'GPS অবস্থান বৈধ: দোকান চত্বরে তোলা হয়েছে।'
                                                      : 'GPS Verified: Captured on shop premises.'),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                              color: _selectedUpload!.isDistanceSuspicious
                                                  ? Colors.amber.shade900
                                                  : Colors.green.shade900,
                                            ),
                                          ),
                                          Text(
                                            '${locale.isBengali ? "দূরত্ব" : "Distance"}: ${_selectedUpload!.distanceMeters.toStringAsFixed(1)}m • Lat/Lon: ${_selectedUpload!.capturedLatitude.toStringAsFixed(5)}, ${_selectedUpload!.capturedLongitude.toStringAsFixed(5)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _selectedUpload!.isDistanceSuspicious
                                                  ? Colors.amber.shade800
                                                  : Colors.green.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        await dataProvider.reviewProof(
                                          uploadId: _selectedUpload!.id,
                                          status: 'verified',
                                        );
                                        setState(() => _selectedUpload = null);
                                      },
                                      icon: const Icon(Icons.check_circle_outline, size: 18),
                                      label: Text(locale.t('btn_verify')),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.statusGreen,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showRejectDialog(context, _selectedUpload!),
                                      icon: const Icon(Icons.cancel_outlined, size: 18),
                                      label: Text(locale.t('btn_reject')),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.statusRed,
                                        side: const BorderSide(color: AppTheme.statusRed),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
