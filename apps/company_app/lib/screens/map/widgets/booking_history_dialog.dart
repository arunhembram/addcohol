import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Represents daily audit records for a past booked slot
class DailyAuditRecord {
  final String date;
  final int activeCount;
  final int totalTarget;
  final int inactiveCount;
  final double refundAmount;

  const DailyAuditRecord({
    required this.date,
    required this.activeCount,
    required this.totalTarget,
    required this.inactiveCount,
    required this.refundAmount,
  });
}

/// Represents a completed past booking slot in Booking History
class PastBookingSlot {
  final String id;
  final String zoneName;
  final String dateRange;
  final int totalTargetShops;
  final double totalSlotAmount;
  final double totalRefunded;
  final List<DailyAuditRecord> dailyBreakdown;

  const PastBookingSlot({
    required this.id,
    required this.zoneName,
    required this.dateRange,
    required this.totalTargetShops,
    required this.totalSlotAmount,
    required this.totalRefunded,
    required this.dailyBreakdown,
  });
}

/// Dialog presenting past booked campaign slots ("Booking History")
/// with drill-down date-wise active/inactive shop auditing and refund transparency.
class BookingHistoryDialog extends StatelessWidget {
  const BookingHistoryDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const BookingHistoryDialog(),
    );
  }

  static final List<PastBookingSlot> _mockPastSlots = [
    PastBookingSlot(
      id: 'past-slot-jan-2027',
      zoneName: 'Howrah Industrial Area',
      dateRange: '1 Jan 2027 – 7 Jan 2027',
      totalTargetShops: 50,
      totalSlotAmount: 35000.0,
      totalRefunded: 4400.0,
      dailyBreakdown: [
        const DailyAuditRecord(
          date: '1/1/2027',
          activeCount: 40,
          totalTarget: 50,
          inactiveCount: 10,
          refundAmount: 2000.0,
        ),
        const DailyAuditRecord(
          date: '2/1/2027',
          activeCount: 45,
          totalTarget: 50,
          inactiveCount: 5,
          refundAmount: 1000.0,
        ),
        const DailyAuditRecord(
          date: '3/1/2027',
          activeCount: 48,
          totalTarget: 50,
          inactiveCount: 2,
          refundAmount: 400.0,
        ),
        const DailyAuditRecord(
          date: '4/1/2027',
          activeCount: 50,
          totalTarget: 50,
          inactiveCount: 0,
          refundAmount: 0.0,
        ),
        const DailyAuditRecord(
          date: '5/1/2027',
          activeCount: 46,
          totalTarget: 50,
          inactiveCount: 4,
          refundAmount: 800.0,
        ),
        const DailyAuditRecord(
          date: '6/1/2027',
          activeCount: 49,
          totalTarget: 50,
          inactiveCount: 1,
          refundAmount: 200.0,
        ),
        const DailyAuditRecord(
          date: '7/1/2027',
          activeCount: 50,
          totalTarget: 50,
          inactiveCount: 0,
          refundAmount: 0.0,
        ),
      ],
    ),
    PastBookingSlot(
      id: 'past-slot-sep-2026',
      zoneName: 'Kolkata Central Zone',
      dateRange: '15 Sep 2026 – 21 Sep 2026',
      totalTargetShops: 45,
      totalSlotAmount: 31500.0,
      totalRefunded: 1400.0,
      dailyBreakdown: [
        const DailyAuditRecord(
          date: '15/9/2026',
          activeCount: 43,
          totalTarget: 45,
          inactiveCount: 2,
          refundAmount: 400.0,
        ),
        const DailyAuditRecord(
          date: '16/9/2026',
          activeCount: 44,
          totalTarget: 45,
          inactiveCount: 1,
          refundAmount: 200.0,
        ),
        const DailyAuditRecord(
          date: '17/9/2026',
          activeCount: 45,
          totalTarget: 45,
          inactiveCount: 0,
          refundAmount: 0.0,
        ),
        const DailyAuditRecord(
          date: '18/9/2026',
          activeCount: 41,
          totalTarget: 45,
          inactiveCount: 4,
          refundAmount: 800.0,
        ),
        const DailyAuditRecord(
          date: '19/9/2026',
          activeCount: 45,
          totalTarget: 45,
          inactiveCount: 0,
          refundAmount: 0.0,
        ),
        const DailyAuditRecord(
          date: '20/9/2026',
          activeCount: 45,
          totalTarget: 45,
          inactiveCount: 0,
          refundAmount: 0.0,
        ),
        const DailyAuditRecord(
          date: '21/9/2026',
          activeCount: 45,
          totalTarget: 45,
          inactiveCount: 0,
          refundAmount: 0.0,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 620),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A), // Dark Slate
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: const Color(0xFF334155), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.history_edu_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Booking History',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Past completed campaign slots and refund audits',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
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

                // Slots List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _mockPastSlots.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (ctx, index) {
                      final slot = _mockPastSlots[index];
                      return _buildSlotCard(context, slot);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotCard(BuildContext context, PastBookingSlot slot) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: const Color(0xFF334155), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  slot.dateRange,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.analytics_outlined, size: 14),
                label: const Text(
                  'Details',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showSlotDetails(context, slot),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            slot.zoneName,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Target: ${slot.totalTargetShops} Shops / day',
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Refund Processed: ₹${slot.totalRefunded.toInt()}',
                  style: const TextStyle(
                    color: Color(0xFF6EE7B7),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSlotDetails(BuildContext context, PastBookingSlot slot) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: const Color(0xFF334155), width: 1.5),
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${slot.zoneName} • Daily Audit',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                slot.dateRange,
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF1E293B)),

                  // Date-wise audit list
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: slot.dailyBreakdown.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = slot.dailyBreakdown[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: item.inactiveCount > 0
                                  ? const Color(0xFFEAB308).withValues(alpha: 0.3)
                                  : const Color(0xFF10B981).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Date column
                              Container(
                                width: 75,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    item.date,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Active / Inactive counts
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.activeCount} out of ${item.totalTarget} Active',
                                      style: TextStyle(
                                        color: item.activeCount == item.totalTarget
                                            ? const Color(0xFF10B981)
                                            : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.inactiveCount} Inactive',
                                      style: TextStyle(
                                        color: item.inactiveCount > 0
                                            ? const Color(0xFFF87171)
                                            : const Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Refund column
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Refund Amount',
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${item.refundAmount.toInt()}',
                                    style: TextStyle(
                                      color: item.refundAmount > 0
                                          ? const Color(0xFF38BDF8)
                                          : const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Total Refund Footer
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F172A),
                      border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Slot Refund Processed:',
                          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                        ),
                        Text(
                          '₹${slot.totalRefunded.toInt()}',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
