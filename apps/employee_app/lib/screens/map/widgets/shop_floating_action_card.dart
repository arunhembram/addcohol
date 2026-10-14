import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../shop_operational_status.dart';

class ShopFloatingActionCard extends StatelessWidget {
  final Shop shop;
  final ShopOperationalStatus status;
  final VoidCallback onClose;
  final VoidCallback onDirections;
  final VoidCallback onDetails;
  final VoidCallback onMakePayment;
  final VoidCallback onCall;
  final VoidCallback onThumbnailTap;
  final bool isDistributionMode;
  final VoidCallback? onMarkDistributed;
  final VoidCallback? onScanQr;
  final VoidCallback? onClosedToday;
  final VoidCallback? onMarkGone;
  final bool isCrossed;
  final bool isClosedToday;
  final bool isWeeklyClosed;
  final double? distanceMeters;

  const ShopFloatingActionCard({
    super.key,
    required this.shop,
    required this.status,
    required this.onClose,
    required this.onDirections,
    required this.onDetails,
    required this.onMakePayment,
    required this.onCall,
    required this.onThumbnailTap,
    this.isDistributionMode = false,
    this.onMarkDistributed,
    this.onScanQr,
    this.onClosedToday,
    this.onMarkGone,
    this.isCrossed = false,
    this.isClosedToday = false,
    this.isWeeklyClosed = false,
    this.distanceMeters,
  });

  bool get _hasPhoneNumber =>
      shop.phoneNumber != null &&
      shop.phoneNumber!.trim().isNotEmpty &&
      shop.phoneNumber!.trim() != 'N/A';

  bool get _hasPhoto =>
      status.dailyUpload != null ||
      (shop.shopfrontPhotoUrl != null && shop.shopfrontPhotoUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final category = ShopCategory.fromString(shop.category);

    return PointerInterceptor(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Section: Thumbnail, Shop Name, Status Badge, Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Square Thumbnail with Status Badge
                  GestureDetector(
                    onTap: _hasPhoto ? onThumbnailTap : null,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: status.statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            border: Border.all(
                              color: status.statusColor,
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _hasPhoto
                              ? Image.network(
                                  status.dailyUpload?.photoUrl ??
                                      shop.shopfrontPhotoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Center(
                                    child: Icon(
                                      category.icon,
                                      color: status.statusColor,
                                      size: 24,
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Icon(
                                    status.statusIcon,
                                    color: status.statusColor,
                                    size: 26,
                                  ),
                                ),
                        ),
                        // Corner Status Badge
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              color: status.statusColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: Icon(
                              status.statusIcon,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Shop name, Code, Status & Hours
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                shop.shopName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.neutral900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),

                        // Shop Code & Status Row
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (shop.shopCode != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.neutral100,
                                  borderRadius: BorderRadius.circular(AppRadii.sm),
                                  border: Border.all(color: AppColors.neutral300),
                                ),
                                child: Text(
                                  shop.shopCode!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: AppColors.neutral800,
                                  ),
                                ),
                              ),

                            // Dynamic Status Pill (Live countdown / Delayed photo / Closed today)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: status.statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppRadii.full),
                                border: Border.all(
                                  color: status.statusColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    status.statusIcon,
                                    size: 11,
                                    color: status.statusColor,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      status.badgeText,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: status.statusColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 3),
                        Text(
                          '${category.displayName} • Hours: ${shop.openingTime ?? "N/A"} - ${shop.closingTime ?? "N/A"}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.neutral600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.neutral600,
                    tooltip: 'Dismiss Card',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),
            const Divider(height: 1, thickness: 0.8),

            // Bottom Section: Action Buttons
            if (shop.isUnderProcess)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: Colors.amber.shade700, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade800, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '⏳ দোকানটি পর্যালোচনায় আছে (Under Process) • অ্যাডমিন Approve করার পর মেটেরিয়াল বিতরণ ও স্লট বুকিং সক্রিয় হবে',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // 1. Direction
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.directions_outlined,
                            labelEn: 'Direction',
                            labelBn: 'দিকনির্দেশনা',
                            color: AppColors.primary,
                            onTap: onDirections,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 2. Call
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.phone_outlined,
                            labelEn: 'Call',
                            labelBn: 'কল করুন',
                            color: _hasPhoneNumber ? const Color(0xFF00897B) : AppColors.neutral400,
                            isEnabled: _hasPhoneNumber,
                            disabledTooltip: 'ফোন নম্বর নিবন্ধিত নেই',
                            onTap: onCall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else if (isDistributionMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isClosedToday || isWeeklyClosed)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE65100).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(color: const Color(0xFFE65100), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_clock_rounded, color: Color(0xFFE65100), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isWeeklyClosed
                                    ? '🔒 দোকান আজ বন্ধ (সাপ্তাহিক ছুটি: ${shop.weeklyClosedDay ?? ""})'
                                    : '🔒 দোকান আজ বন্ধ হিসেবে চিহ্নিত (পরিদর্শিত • কাল আবার তালিকায় আসবে)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE65100),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isCrossed)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD32F2F).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(color: const Color(0xFFD32F2F), width: 1.2),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.cancel_rounded, color: Color(0xFFD32F2F), size: 16),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '❌ অসমাপ্ত বিতরণ (Crossed • আগের দিনের বিতরণ বাকি)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD32F2F),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Distance Proximity Chip
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: distanceMeters == null
                            ? Colors.grey.shade100
                            : (distanceMeters! <= 100
                                ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
                                : AppColors.error.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(AppRadii.full),
                        border: Border.all(
                          color: distanceMeters == null
                              ? Colors.grey.shade400
                              : (distanceMeters! <= 100
                                  ? const Color(0xFF2E7D32)
                                  : AppColors.error),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            distanceMeters == null
                                ? Icons.location_searching_rounded
                                : (distanceMeters! <= 100
                                    ? Icons.verified_user_rounded
                                    : Icons.wrong_location_rounded),
                            size: 14,
                            color: distanceMeters == null
                                ? Colors.grey.shade700
                                : (distanceMeters! <= 100
                                    ? const Color(0xFF2E7D32)
                                    : AppColors.error),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              distanceMeters == null
                                  ? 'GPS অবস্থান যাচাই হচ্ছে...'
                                  : (distanceMeters! <= 100
                                      ? '১০০ মিটারের মধ্যে আছেন (${distanceMeters!.toStringAsFixed(0)}m) • অ্যাকশন সক্রিয়'
                                      : 'দোকান থেকে ${distanceMeters!.toStringAsFixed(0)}m দূরে • ১০০ মিটারে পৌঁছাতে হবে'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: distanceMeters == null
                                    ? Colors.grey.shade800
                                    : (distanceMeters! <= 100
                                        ? const Color(0xFF2E7D32)
                                        : AppColors.error),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Row 1: 4 Quick Actions (Call, Direction, Closed Today, Gone)
                    Row(
                      children: [
                        // 1. Call
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.phone_outlined,
                            labelEn: 'Call',
                            labelBn: 'কল',
                            color: const Color(0xFF00897B),
                            isEnabled: _hasPhoneNumber,
                            disabledTooltip: 'ফোন নম্বর নেই',
                            onTap: onCall,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 2. Direction
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.directions_outlined,
                            labelEn: 'Direction',
                            labelBn: 'দিকনির্দেশনা',
                            color: AppColors.primary,
                            onTap: onDirections,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 2.5 Scan QR (New dedicated scanner button)
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.qr_code_scanner_rounded,
                            labelEn: 'Scan QR',
                            labelBn: 'স্ক্যান QR',
                            color: const Color(0xFF0F2A43),
                            onTap: onScanQr ?? onMarkDistributed ?? () {},
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 3. Closed Today
                        Expanded(
                          child: _ActionButton(
                            icon: (isClosedToday || isWeeklyClosed)
                                ? Icons.lock_clock_rounded
                                : Icons.lock_clock_outlined,
                            labelEn: isWeeklyClosed ? 'Weekly Off' : 'Closed Today',
                            labelBn: isWeeklyClosed
                                ? 'সাপ্তাহিক বন্ধ'
                                : (isClosedToday ? 'আজ বন্ধ (পরিদর্শিত)' : 'আজ বন্ধ'),
                            color: const Color(0xFFE65100),
                            onTap: onClosedToday ?? () {},
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 4. Gone (Permanently Closed)
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.delete_forever_outlined,
                            labelEn: 'Gone',
                            labelBn: 'দোকান নেই',
                            color: const Color(0xFFC62828),
                            onTap: onMarkGone ?? () {},
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Row 2: Done (Large Primary Action)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (distanceMeters != null && distanceMeters! <= 100)
                              ? const Color(0xFF2E7D32)
                              : Colors.grey.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          elevation: 2,
                        ),
                        icon: Icon(
                          (distanceMeters != null && distanceMeters! <= 100)
                              ? Icons.check_circle_rounded
                              : Icons.lock_clock_rounded,
                          size: 20,
                        ),
                        label: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Done',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              (distanceMeters != null && distanceMeters! <= 100)
                                  ? 'বিতরণ সম্পন্ন'
                                  : 'বিতরণ (১০০ মিটারে যান)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        onPressed: onScanQr ?? onMarkDistributed,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    // Action 1: Directions
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.directions_outlined,
                        labelEn: 'Directions',
                        labelBn: 'দিকনির্দেশনা',
                        color: AppColors.primary,
                        onTap: onDirections,
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Action 2: Details
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.info_outline_rounded,
                        labelEn: 'Details',
                        labelBn: 'বিস্তারিত',
                        color: AppColors.neutral800,
                        onTap: onDetails,
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Action 3: Make Payment
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.qr_code_scanner_rounded,
                        labelEn: 'Make Payment',
                        labelBn: 'পেমেন্ট',
                        color: const Color(0xFF0D9488), // Teal
                        onTap: onMakePayment,
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Action 4: Call
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.phone_outlined,
                        labelEn: 'Call',
                        labelBn: 'কল করুন',
                        color: _hasPhoneNumber ? AppColors.success : AppColors.neutral400,
                        isEnabled: _hasPhoneNumber,
                        disabledTooltip: 'No phone number registered for this shop',
                        onTap: onCall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String labelEn;
  final String labelBn;
  final Color color;
  final VoidCallback onTap;
  final bool isEnabled;
  final String? disabledTooltip;

  const _ActionButton({
    required this.icon,
    required this.labelEn,
    required this.labelBn,
    required this.color,
    required this.onTap,
    this.isEnabled = true,
    this.disabledTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: isEnabled ? color.withValues(alpha: 0.08) : AppColors.neutral100,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          constraints: const BoxConstraints(minHeight: 52),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isEnabled ? color : AppColors.neutral400,
              ),
              const SizedBox(height: 3),
              Text(
                labelEn,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isEnabled ? color : AppColors.neutral400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text(
                labelBn,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: isEnabled
                      ? color.withValues(alpha: 0.8)
                      : AppColors.neutral400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    if (!isEnabled && disabledTooltip != null) {
      return Tooltip(
        message: disabledTooltip!,
        child: content,
      );
    }

    return content;
  }
}
