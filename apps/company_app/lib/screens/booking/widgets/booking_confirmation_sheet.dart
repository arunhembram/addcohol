import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

/// Modal bottom sheet presenting a structured summary of the booking
/// prior to moving forward into the payment / activation workflow.
class BookingConfirmationSheet extends StatefulWidget {
  final Zone zone;
  final String businessType; // 'Shops' or 'Saloons'
  final String adSize; // 'A5' or 'A6'
  final String sideOption; // 'Both Sides' or 'One Side'
  final double pricePerLocation;
  final int totalLocations;
  final double totalAmount;
  final Future<void> Function() onConfirm;

  const BookingConfirmationSheet({
    super.key,
    required this.zone,
    required this.businessType,
    required this.adSize,
    required this.sideOption,
    required this.pricePerLocation,
    required this.totalLocations,
    required this.totalAmount,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required Zone zone,
    required String businessType,
    required String adSize,
    required String sideOption,
    required double pricePerLocation,
    required int totalLocations,
    required double totalAmount,
    required Future<void> Function() onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BookingConfirmationSheet(
        zone: zone,
        businessType: businessType,
        adSize: adSize,
        sideOption: sideOption,
        pricePerLocation: pricePerLocation,
        totalLocations: totalLocations,
        totalAmount: totalAmount,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<BookingConfirmationSheet> createState() =>
      _BookingConfirmationSheetState();
}

class _BookingConfirmationSheetState extends State<BookingConfirmationSheet> {
  bool _isProcessing = false;

  void _handleConfirm() async {
    setState(() => _isProcessing = true);
    try {
      await widget.onConfirm();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.md,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F2A43).withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF0F2A43),
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirm Ad Space Booking',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'বিজ্ঞাপন বুকিং নিশ্চিতকরণ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const Divider(height: 24, color: Color(0xFFE2E8F0)),

          // Summary Details Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildRow(
                  icon: Icons.location_on_outlined,
                  label: 'Selected Zone',
                  value: widget.zone.name,
                  isBold: true,
                ),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildRow(
                  icon: widget.businessType.toLowerCase() == 'saloons'
                      ? Icons.content_cut_outlined
                      : Icons.storefront_outlined,
                  label: 'Business Category',
                  value: widget.businessType,
                ),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildRow(
                  icon: Icons.aspect_ratio_rounded,
                  label: 'Ad Size',
                  value: widget.adSize,
                ),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildRow(
                  icon: Icons.layers_outlined,
                  label: 'Placement',
                  value: widget.sideOption,
                ),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildRow(
                  icon: Icons.sell_outlined,
                  label: 'Price per location',
                  value: '₹${widget.pricePerLocation.toStringAsFixed(0)}',
                ),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildRow(
                  icon: Icons.numbers_rounded,
                  label: 'Selected Locations',
                  value: '${widget.totalLocations} ${widget.businessType}',
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Total Payable Card
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL PAYABLE AMOUNT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF15803D),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '₹${widget.pricePerLocation.toStringAsFixed(0)} × ${widget.totalLocations} locations',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹${widget.totalAmount.toStringAsFixed(0)}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Actions
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F9D8A), // Teal primary action
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                elevation: 0,
              ),
              onPressed: _isProcessing ? null : _handleConfirm,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_outline_rounded, size: 18),
              label: Text(
                _isProcessing
                    ? 'Processing Booking...'
                    : 'Confirm & Proceed to Payment',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Back to Review',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String label,
    required String value,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? const Color(0xFF0F2A43) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
