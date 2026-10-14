import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Aggregated data models for Master Admin Weekly Bookings View
class MasterBookedWeekSlot {
  final String id;
  final DateTime slotStartDate;
  final DateTime slotEndDate;
  final List<ZoneCampaignGroup> zoneGroups;

  const MasterBookedWeekSlot({
    required this.id,
    required this.slotStartDate,
    required this.slotEndDate,
    required this.zoneGroups,
  });

  int get totalCampaigns => zoneGroups.fold(0, (sum, g) => sum + g.runs.length);
  int get totalZones => zoneGroups.length;

  int get completedCampaigns => zoneGroups.fold(
        0,
        (sum, g) => sum + g.runs.where((r) => r.isCompleted).length,
      );

  int get activeCampaigns => zoneGroups.fold(
        0,
        (sum, g) => sum + g.runs.where((r) => r.isDistributionActive).length,
      );

  int get missingPrintCount => zoneGroups.fold(
        0,
        (sum, g) => sum + g.runs.where((r) => !r.hasPrintoutProof).length,
      );
}

class ZoneCampaignGroup {
  final Zone zone;
  final String adminName;
  final String adminPhone;
  final String adminId;
  final List<CompanyAdDistributionRun> runs;

  const ZoneCampaignGroup({
    required this.zone,
    required this.adminName,
    required this.adminPhone,
    required this.adminId,
    required this.runs,
  });
}

/// Master Admin Weekly Bookings Screen.
///
/// Features:
/// 1. Weekly Slots List:
///    - Only booked slots are listed, ranked chronologically with closer dates first.
///    - Stadium capsule slot cards (Start Date - "View Bookings" Button - End Date).
/// 2. Cards of Booked Zones Window:
///    - Clicking "View Bookings" opens the zone cards for that weekly slot.
///    - Zone Header: Zone Name, Assigned Admin Name, Calling Button (reveals phone popup).
///    - Table matching Normal Admin Screen:
///      - Company Name, Side (Left/Right/Both), Size (A5/A6), Category (Shop/Saloon),
///        Ad Design (Task 1 proof thumbnail), Print Out (Task 2 proof thumbnail),
///        Distribution (Task 3 % & map link), and Live in Remaining Days.
///      - Edit & delete buttons omitted for clean monitoring.
///      - Thumbnails can be clicked to enlarge with InteractiveViewer zoom.
class MasterWeeklyBookingsScreen extends StatefulWidget {
  final String? initialSlotId;

  const MasterWeeklyBookingsScreen({
    super.key,
    this.initialSlotId,
  });

  @override
  State<MasterWeeklyBookingsScreen> createState() => _MasterWeeklyBookingsScreenState();
}

class _MasterWeeklyBookingsScreenState extends State<MasterWeeklyBookingsScreen> {
  static const Color colorNavy = Color(0xFF0F2A43);

  String? _selectedSlotId;
  String _filterCategory = 'ALL'; // 'ALL', 'MISSING_PRINTS', 'LIVE_NOW'

  // Admin phone directory for demo zones
  static const Map<String, ({String name, String phone, String id})> _zoneAdminDirectory = {
    CanonicalZones.kolkataCentralId: (
      name: 'Subhasis Sen',
      phone: '+91 98301 23456',
      id: '10001',
    ),
    CanonicalZones.saltLakeSector5Id: (
      name: 'Subhasis Sen',
      phone: '+91 98301 23456',
      id: '10001',
    ),
    CanonicalZones.howrahIndustrialId: (
      name: 'Priya Mukherjee',
      phone: '+91 98302 34567',
      id: '10002',
    ),
  };

  @override
  void initState() {
    super.initState();
    _selectedSlotId = widget.initialSlotId;
  }

  DateTime _getSlotMonday(DateTime dt) {
    final d = DateTime(dt.year, dt.month, dt.day);
    return d.subtract(Duration(days: d.weekday - 1)); // 1 is Monday
  }

  DateTime _getSlotSunday(DateTime monday) {
    return monday.add(const Duration(days: 6)); // Sunday
  }

  /// Gather and aggregate all booked weekly slots from CanonicalZones.
  /// Each weekly slot groups MULTIPLE ZONES, and each zone contains MULTIPLE COMPANIES.
  List<MasterBookedWeekSlot> _getBookedWeekSlots() {
    final allZones = CanonicalZones.all;

    // Map: slotKey -> Map: zoneId -> List<CompanyAdDistributionRun>
    final Map<String, ({DateTime start, DateTime end, Map<String, List<CompanyAdDistributionRun>> zoneMap})> slotsData = {};

    for (final zone in allZones) {
      final runs = CanonicalZones.getCompanyAdRuns(zone.id);
      for (final run in runs) {
        // Group by 7-day Monday-to-Sunday calendar weekly slot
        final monday = _getSlotMonday(run.slotStartDate);
        final sunday = _getSlotSunday(monday);
        final slotKey = 'week_${monday.year}_${monday.month}_${monday.day}';

        final entry = slotsData.putIfAbsent(
          slotKey,
          () => (
            start: monday,
            end: sunday,
            zoneMap: <String, List<CompanyAdDistributionRun>>{},
          ),
        );

        entry.zoneMap.putIfAbsent(zone.id, () => []).add(run);
      }
    }

    final List<MasterBookedWeekSlot> result = [];

    slotsData.forEach((key, data) {
      final List<ZoneCampaignGroup> zoneGroups = [];

      data.zoneMap.forEach((zoneId, runs) {
        final zone = allZones.firstWhere(
          (z) => z.id == zoneId,
          orElse: () => CanonicalZones.kolkataCentral,
        );

        final adminInfo = _zoneAdminDirectory[zoneId] ??
            (
              name: zone.assignedAdminName ?? 'Zone Admin',
              phone: '+91 98000 00000',
              id: CanonicalZones.getZoneAdminCode(zoneId),
            );

        // Sort runs in zone: nearest date first
        final sortedRuns = List<CompanyAdDistributionRun>.from(runs)
          ..sort((a, b) => a.slotStartDate.compareTo(b.slotStartDate));

        zoneGroups.add(
          ZoneCampaignGroup(
            zone: zone,
            adminName: adminInfo.name,
            adminPhone: adminInfo.phone,
            adminId: adminInfo.id,
            runs: sortedRuns,
          ),
        );
      });

      // Sort zones alphabetically
      zoneGroups.sort((a, b) => a.zone.name.compareTo(b.zone.name));

      result.add(
        MasterBookedWeekSlot(
          id: key,
          slotStartDate: data.start,
          slotEndDate: data.end,
          zoneGroups: zoneGroups,
        ),
      );
    });

    // Rank wise of dates: closer date week slot first!
    result.sort((a, b) => a.slotStartDate.compareTo(b.slotStartDate));

    return result;
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    return '$day $month';
  }

  String _formatFullDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    return '$day $month ${dt.year}';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'N/A';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day $month, $hour:$minute $ampm';
  }

  Widget _buildUrgencyBadge(CompanyAdDistributionRun ad) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(ad.slotStartDate.year, ad.slotStartDate.month, ad.slotStartDate.day);

    String label;
    Color bgColor;
    Color textColor;
    IconData icon;

    if (now.isAfter(ad.slotStartDate) && now.isBefore(ad.slotEndDate.add(const Duration(days: 1)))) {
      label = 'Live Now';
      bgColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF15803D);
      icon = Icons.bolt;
    } else if (start.isAtSameMomentAs(today)) {
      label = 'Starts Today';
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFB91C1C);
      icon = Icons.warning_rounded;
    } else if (start.isAfter(today)) {
      final days = start.difference(today).inDays;
      if (days == 1) {
        label = 'Starts In 1 day';
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFB91C1C);
        icon = Icons.timer_outlined;
      } else if (days <= 3) {
        label = 'Starts In $days days';
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFB45309);
        icon = Icons.schedule_rounded;
      } else {
        label = 'Starts In $days days';
        bgColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF475569);
        icon = Icons.calendar_today_outlined;
      }
    } else {
      label = 'Ended';
      bgColor = const Color(0xFFF1F5F9);
      textColor = const Color(0xFF94A3B8);
      icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.3), width: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideBadge(String sideRaw) {
    final side = sideRaw.toLowerCase();
    Color bg;
    Color fg;
    IconData icon;
    String text;

    if (side == 'left') {
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF1D4ED8);
      icon = Icons.align_horizontal_left_rounded;
      text = 'LEFT';
    } else if (side == 'right') {
      bg = const Color(0xFFFFF7ED);
      fg = const Color(0xFFC2410C);
      icon = Icons.align_horizontal_right_rounded;
      text = 'RIGHT';
    } else {
      bg = const Color(0xFFFAF5FF);
      fg = const Color(0xFF7E22CE);
      icon = Icons.sync_alt_rounded;
      text = 'BOTH';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeBadge(String sizeRaw) {
    final isA5 = sizeRaw.toUpperCase().contains('A5');
    final color = isA5 ? const Color(0xFF0F766E) : const Color(0xFF7C3AED);
    final bg = isA5 ? const Color(0xFFF0FDFA) : const Color(0xFFF5F3FF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Text(
        sizeRaw.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String businessType) {
    final isSaloon = businessType.toLowerCase() == 'saloon';
    final bg = isSaloon ? const Color(0xFFFDF2F8) : const Color(0xFFF0FDF4);
    final fg = isSaloon ? const Color(0xFFBE185D) : const Color(0xFF15803D);
    final icon = isSaloon ? Icons.content_cut_rounded : Icons.storefront_rounded;
    final text = isSaloon ? 'SALOON' : 'SHOP';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  void _showCallingPopup(BuildContext context, ZoneCampaignGroup group) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar & Name
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF3B82F6), width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.shield_rounded, color: Color(0xFF1D4ED8), size: 32),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                group.adminName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colorNavy,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Admin ID: #${group.adminId} • Assigned Officer',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Jurisdiction: ${group.zone.name}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F2A43)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              // Phone number display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_rounded, color: Color(0xFF15803D), size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: SelectableText(
                        group.adminPhone,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: Color(0xFF0F172A),
                        ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF15803D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                      label: const Text('Call Admin Now', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final telUri = Uri.parse('tel:${group.adminPhone.replaceAll(RegExp(r'\s+'), '')}');
                        if (await canLaunchUrl(telUri)) {
                          await launchUrl(telUri);
                        } else {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Calling device interface opened for ${group.adminPhone}')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: group.adminPhone));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Phone number copied: ${group.adminPhone}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF047857),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Message on WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final cleanPhone = group.adminPhone.replaceAll(RegExp(r'\D'), '');
                    final waUri = Uri.parse(
                      'https://wa.me/$cleanPhone?text=Hello%20${Uri.encodeComponent(group.adminName)},%20regarding%20${Uri.encodeComponent(group.zone.name)}%20campaigns...',
                    );
                    if (await canLaunchUrl(waUri)) {
                      await launchUrl(waUri);
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(
    BuildContext context,
    String imageUrl,
    String title,
    DateTime? uploadedAt,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 4),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white24)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (uploadedAt != null)
                                Text(
                                  'Uploaded: ${_formatDateTime(uploadedAt)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Center(
                              child: Text(
                                'Image preview unavailable',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final bookedSlots = _getBookedWeekSlots();

    MasterBookedWeekSlot? currentSlot;
    if (_selectedSlotId != null) {
      currentSlot = bookedSlots.where((s) => s.id == _selectedSlotId).firstOrNull;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: colorNavy),
          onPressed: () {
            if (_selectedSlotId != null) {
              setState(() => _selectedSlotId = null);
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentSlot != null
                  ? 'Bookings: ${_formatDate(currentSlot.slotStartDate)} – ${_formatDate(currentSlot.slotEndDate)}'
                  : 'Weekly Booking Status & Progress',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16.5,
                color: colorNavy,
              ),
            ),
            Text(
              currentSlot != null
                  ? '${currentSlot.totalZones} Zones • ${currentSlot.totalCampaigns} Company Campaigns'
                  : 'Only active & booked campaign slots (Ranked by closer date first)',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: colorNavy),
            tooltip: 'Refresh Bookings',
            onPressed: () => setState(() {}),
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: currentSlot != null
          ? _buildBookedZonesWindow(context, currentSlot)
          : _buildWeeklySlotsListView(context, bookedSlots),
    );
  }

  /// 1. Weekly Slots List View
  /// Lists only booked slots, ranked with closer dates first.
  /// Stadium capsule cards with Start Date on left, "View Bookings" in center, End Date on right.
  Widget _buildWeeklySlotsListView(BuildContext context, List<MasterBookedWeekSlot> slots) {
    if (slots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_rounded, size: 64, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            const Text(
              'No Booked Weekly Slots Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorNavy),
            ),
            const SizedBox(height: 6),
            const Text(
              'When companies book campaign slots in zones, they will appear here.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back to Map Cockpit'),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            // Header summary banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF0284C7), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Campaign Week Slots',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: colorNavy),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Showing ${slots.length} booked weekly cycles. Nearest starting weeks ranked first.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // List of Stadium Capsule Slots
            for (int i = 0; i < slots.length; i++) ...[
              _buildSlotStadiumCapsule(context, slots[i], rank: i + 1),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }

  /// Stadium Capsule for Weekly Slot
  /// Left: Start Date, Center: "View Bookings" Button with stats, Right: End Date
  Widget _buildSlotStadiumCapsule(
    BuildContext context,
    MasterBookedWeekSlot slot, {
    required int rank,
  }) {
    final startDay = slot.slotStartDate.day.toString();
    final startMonth = _formatDate(slot.slotStartDate).split(' ').last.toUpperCase();
    final endDay = slot.slotEndDate.day.toString();
    final endMonth = _formatDate(slot.slotEndDate).split(' ').last.toUpperCase();

    // Check urgency of this slot
    final now = DateTime.now();
    final isLive = now.isAfter(slot.slotStartDate) && now.isBefore(slot.slotEndDate.add(const Duration(days: 1)));
    final daysUntilStart = slot.slotStartDate.difference(DateTime(now.year, now.month, now.day)).inDays;

    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isLive
              ? const Color(0xFF10B981)
              : (daysUntilStart <= 1 ? const Color(0xFFF87171) : const Color(0xFFCBD5E1)),
          width: isLive || daysUntilStart <= 1 ? 1.6 : 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. LEFT SECTION: Start Date
          Expanded(
            flex: 26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      startDay,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: colorNavy,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      startMonth,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. CENTER SECTION: "View Bookings" Button
          Expanded(
            flex: 48,
            child: Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorNavy,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onPressed: () {
                  setState(() {
                    _selectedSlotId = slot.id;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.table_view_rounded, size: 16, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'View Bookings (${slot.totalZones} Zones · ${slot.totalCampaigns} Companies)',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),

          // 3. RIGHT SECTION: End Date
          Expanded(
            flex: 26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      endDay,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: colorNavy,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      endMonth,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                if (isLive)
                  const Tooltip(
                    message: 'Live Now',
                    child: Icon(Icons.bolt, color: Color(0xFF16A34A), size: 18),
                  )
                else if (daysUntilStart <= 1)
                  const Tooltip(
                    message: 'Starts Soon',
                    child: Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                  )
                else
                  const SizedBox(width: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Cards of Booked Zones Window (Opened upon clicking "View Bookings")
  Widget _buildBookedZonesWindow(BuildContext context, MasterBookedWeekSlot slot) {
    return Column(
      children: [
        // Sub-navigation bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 15),
                label: const Text('Back to Weekly Slots'),
                onPressed: () => setState(() => _selectedSlotId = null),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF0284C7)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${_formatFullDate(slot.slotStartDate)}  —  ${_formatFullDate(slot.slotEndDate)}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: colorNavy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Filter chips
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All Companies'),
                    selected: _filterCategory == 'ALL',
                    onSelected: (_) => setState(() => _filterCategory = 'ALL'),
                  ),
                  ChoiceChip(
                    label: Text('Missing Print (${slot.missingPrintCount})'),
                    selected: _filterCategory == 'MISSING_PRINTS',
                    selectedColor: const Color(0xFFFEE2E2),
                    onSelected: (_) => setState(() => _filterCategory = 'MISSING_PRINTS'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Scrollable Zone Cards
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              for (final group in slot.zoneGroups) ...[
                _buildZoneCard(context, slot, group),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Zone Card containing the Admin Contact bar and the Company Tasks Progress Table
  Widget _buildZoneCard(
    BuildContext context,
    MasterBookedWeekSlot slot,
    ZoneCampaignGroup group,
  ) {
    // Filter runs if required
    var runs = group.runs;
    if (_filterCategory == 'MISSING_PRINTS') {
      runs = runs.where((r) => !r.hasPrintoutProof).toList();
    }

    if (runs.isEmpty && _filterCategory != 'ALL') {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ZONE CARD HEADER: Zone Name + Assigned Admin info + Calling Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                // Zone icon & name
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(int.parse(group.zone.colorHex.replaceFirst('#', '0xFF'))),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            group.zone.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: colorNavy,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F2A43).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${runs.length} Companies Booked',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: colorNavy),
                            ),
                          ),
                        ],
                      ),
                      if (group.zone.description != null)
                        Text(
                          group.zone.description!,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                    ],
                  ),
                ),

                // Assigned Admin Contact Box + Calling Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.badge_outlined, size: 15, color: Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin: ${group.adminName}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F2A43),
                            ),
                          ),
                          Text(
                            'ID: #${group.adminId}',
                            style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),

                      // CALLING BUTTON (Reveals Phone Popup)
                      Material(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _showCallingPopup(context, group),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            child: Row(
                              children: [
                                Icon(Icons.phone_in_talk_rounded, color: Color(0xFF15803D), size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Call Admin',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ZONE CARD BODY: Progress Table matching Normal Admin Screen
          // (No edit/delete buttons, only image thumbnail click to zoom, right column: Live in Remaining days)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1000),
              child: DataTable(
                headingRowHeight: 46,
                dataRowMinHeight: 74,
                dataRowMaxHeight: 88,
                horizontalMargin: 16,
                columnSpacing: 18,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                columns: const [
                  DataColumn(label: Text('COMPANY NAME', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5))),
                  DataColumn(label: Text('SIDE\n(BOOKED)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5))),
                  DataColumn(label: Text('SIZE\n(A5 / A6)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5))),
                  DataColumn(label: Text('CATEGORY\n(SHOP/ SALOON)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5))),
                  DataColumn(label: Text('AD DESIGN\n(TASK 1)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5))),
                  DataColumn(label: Text('PRINT OUT\n(TASK 2)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5))),
                  DataColumn(label: Text('DISTRIBUTION\n(TASK 3)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5))),
                  DataColumn(label: Text('LIVE IN REMAINING DAYS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5))),
                ],
                rows: [
                  for (final ad in runs)
                    DataRow(
                      cells: [
                        // 1. COMPANY NAME + shop count
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ad.companyName,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: colorNavy),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Icons.storefront_outlined, size: 12, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${ad.totalTargetCount} shops',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // 2. SIDE (BOOKED)
                        DataCell(Center(child: _buildSideBadge(ad.placementSide))),

                        // 3. SIZE (A5 / A6)
                        DataCell(Center(child: _buildSizeBadge(ad.standSize))),

                        // 4. CATEGORY (SHOP/ SALOON)
                        DataCell(Center(child: _buildCategoryBadge(ad.businessType))),

                        // 5. AD DESIGN (TASK 1) - Only thumbnail + upload date, no edit/delete
                        DataCell(
                          ad.hasAdDesign
                              ? InkWell(
                                  onTap: () => _showFullScreenImage(
                                    context,
                                    ad.adCreativeImageUrl!,
                                    '${ad.companyName} - Ad Design (Task 1)',
                                    ad.adDesignUploadedAt,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Image.network(
                                              ad.adCreativeImageUrl!,
                                              width: 58,
                                              height: 44,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Container(
                                                width: 58,
                                                height: 44,
                                                color: const Color(0xFFE2E8F0),
                                                child: const Icon(Icons.broken_image, size: 16),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            right: 2,
                                            bottom: 2,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.6),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: const Icon(Icons.zoom_in, color: Colors.white, size: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Uploaded: ${_formatDate(ad.adDesignUploadedAt ?? DateTime.now())}',
                                        style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF93C5FD)),
                                  ),
                                  child: const Text(
                                    'Task 1 Pending',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                  ),
                                ),
                        ),

                        // 6. PRINT OUT (TASK 2) - Only thumbnail + upload date, no edit/delete
                        DataCell(
                          ad.hasPrintoutProof
                              ? InkWell(
                                  onTap: () => _showFullScreenImage(
                                    context,
                                    ad.printoutProofImageUrl!,
                                    '${ad.companyName} - Print Out Proof (Task 2)',
                                    ad.printoutProofUploadedAt,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Image.network(
                                              ad.printoutProofImageUrl!,
                                              width: 58,
                                              height: 44,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Container(
                                                width: 58,
                                                height: 44,
                                                color: const Color(0xFFE2E8F0),
                                                child: const Icon(Icons.broken_image, size: 16),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            right: 2,
                                            bottom: 2,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.6),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: const Icon(Icons.zoom_in, color: Colors.white, size: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Uploaded: ${_formatDate(ad.printoutProofUploadedAt ?? DateTime.now())}',
                                        style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  )
                                )
                              : ad.canUploadPrintout
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF6EE7B7)),
                                      ),
                                      child: const Text(
                                        'Task 2 Ready\n(Print Pending)',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '❌ Locked\n(Requires Design)',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                                      ),
                                    ),
                        ),

                        // 7. DISTRIBUTION (TASK 3)
                        DataCell(
                          (ad.isDistributionActive || ad.distributedShopIds.isNotEmpty || ad.isCompleted)
                              ? SizedBox(
                                  width: 165,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${ad.progressPercent}% Complete',
                                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                                          ),
                                          Text(
                                            '${ad.completedOrGoneCount}/${ad.totalTargetCount}',
                                            style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: ad.progressFraction,
                                          minHeight: 5,
                                          backgroundColor: const Color(0xFFE2E8F0),
                                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              context.push('/zones/map?zoneId=${group.zone.id}');
                                            },
                                            child: const Row(
                                              children: [
                                                Icon(Icons.map_outlined, size: 11, color: Color(0xFF0284C7)),
                                                SizedBox(width: 3),
                                                Text(
                                                  'View Map',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF0284C7),
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Transform.scale(
                                            scale: 0.65,
                                            child: Switch(
                                              value: ad.status == 'active',
                                              activeThumbColor: const Color(0xFF0284C7),
                                              onChanged: (val) {
                                                CanonicalZones.toggleCompanyAdRun(group.zone.id, ad.id, val);
                                                setState(() {});
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '❌ Locked\n(Requires Print Proof)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                                  ),
                                ),
                        ),

                        // 8. LIVE IN REMAINING DAYS (User: named Live in Remaining days not date slot)
                        DataCell(
                          Center(
                            child: _buildUrgencyBadge(ad),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
