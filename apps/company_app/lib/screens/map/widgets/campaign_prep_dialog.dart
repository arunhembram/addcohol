import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Modal dialog showing upcoming campaign preparation details and target shop count
class CampaignPrepDialog extends StatelessWidget {
  final String zoneName;
  final String dateRange;
  final int targetShopCount;

  const CampaignPrepDialog({
    super.key,
    required this.zoneName,
    this.dateRange = '20 Dec – 26 Dec 2026',
    this.targetShopCount = 50,
  });

  static Future<void> show(
    BuildContext context, {
    required String zoneName,
    String dateRange = '20 Dec – 26 Dec 2026',
    int targetShopCount = 50,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CampaignPrepDialog(
        zoneName: zoneName,
        dateRange: dateRange,
        targetShopCount: targetShopCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: const Color(0xFF334155), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0284C7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.upcoming_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Upcoming Campaign Preparation',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF1E293B)),

                // Details Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.calendar_month_rounded,
                        label: 'Scheduled Dates',
                        value: dateRange,
                        highlightValue: true,
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Assigned Territory',
                        value: zoneName,
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        icon: Icons.storefront_rounded,
                        label: 'Target Shop Count',
                        value: '$targetShopCount Partner Shops',
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        icon: Icons.local_shipping_outlined,
                        label: 'Preparation Status',
                        value: 'Print Materials & Route Allocation in Progress',
                      ),
                    ],
                  ),
                ),

                // Close Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          side: const BorderSide(color: Color(0xFF334155)),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool highlightValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: const Color(0xFF334155), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF38BDF8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: highlightValue ? const Color(0xFF38BDF8) : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
