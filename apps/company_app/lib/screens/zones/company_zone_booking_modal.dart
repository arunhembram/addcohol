import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

/// Modal dialog for Company/Advertiser to book or request an ad campaign in a specific zone.
class CompanyZoneBookingModal extends StatefulWidget {
  final Zone zone;
  final List<CompanyVisibleShop> shops;

  const CompanyZoneBookingModal({
    super.key,
    required this.zone,
    required this.shops,
  });

  static Future<void> show(
    BuildContext context, {
    required Zone zone,
    required List<CompanyVisibleShop> shops,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CompanyZoneBookingModal(
        zone: zone,
        shops: shops,
      ),
    );
  }

  @override
  State<CompanyZoneBookingModal> createState() =>
      _CompanyZoneBookingModalState();
}

class _CompanyZoneBookingModalState extends State<CompanyZoneBookingModal> {
  final _campaignNameController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedDuration = '30 Days';
  final String _targetCategory = 'All';
  bool _isSubmitting = false;

  final List<String> _durationOptions = [
    '7 Days',
    '15 Days',
    '30 Days',
    '60 Days',
    '90 Days',
  ];

  @override
  void dispose() {
    _campaignNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitBooking() async {
    final campaignName = _campaignNameController.text.trim();
    if (campaignName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a Campaign Name to proceed with booking.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).pop();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.verified_rounded, color: AppColors.success, size: 52),
        title: const Text('Zone Booking Request Sent!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your advertising campaign request for "${widget.zone.name}" has been registered successfully.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Campaign: $campaignName', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('• Territory: ${widget.zone.name}'),
                  Text('• Total Screen Units: ${widget.shops.length} Shops'),
                  Text('• Duration: $_selectedDuration'),
                  Text('• Targeting: $_targetCategory Categories'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'The Master Admin and Regional Operations team will review and activate your campaign schedule.',
              style: TextStyle(fontSize: 12, color: AppColors.neutral600),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Compute category counts
    final Map<String, int> categoryCounts = {};
    for (final shop in widget.shops) {
      final cat = shop.category;
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.neutral900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.md,
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.neutral400.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Header Banner
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Book Zone: ${widget.zone.name}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.shops.length} Retail Displays Available for Advertising',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.neutral600,
                        ),
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
            const Divider(height: 24),

            // Category Distribution Pills
            Text(
              'Shops in this Territory',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.neutral700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  label: Text(
                    'All (${widget.shops.length})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                ...categoryCounts.entries.map((e) => Chip(
                      backgroundColor: AppColors.neutral100,
                      label: Text(
                        '${e.key}: ${e.value}',
                        style: const TextStyle(fontSize: 11, color: AppColors.neutral800),
                      ),
                    )),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Form Inputs
            Text(
              'Campaign Details',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.neutral700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _campaignNameController,
              decoration: const InputDecoration(
                labelText: 'Campaign Name *',
                hintText: 'e.g. Durga Puja Festival Special 2026',
                prefixIcon: Icon(Icons.edit_note_rounded),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Duration selector
            Text(
              'Campaign Duration',
              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _durationOptions.map((dur) {
                  final isSel = _selectedDuration == dur;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(dur),
                      selected: isSel,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : AppColors.neutral800,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedDuration = dur);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Additional Notes
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Special Notes / Instructions (Optional)',
                hintText: 'e.g. Prefer grocery and high footfall pharmacy storefronts',
                prefixIcon: Icon(Icons.notes_rounded),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(
                      _isSubmitting ? 'Submitting...' : 'Confirm Booking Request',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isSubmitting ? null : _submitBooking,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
