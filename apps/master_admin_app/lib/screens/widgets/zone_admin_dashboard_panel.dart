import 'dart:async';
import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/master_admin_providers.dart';

/// Assigned Admin Dashboard & Master Zone Management Panel.
/// Displayed when any zone on the map is clicked.
///
/// Features:
/// 1. Dynamic Admin State: "Assign Admin to this Zone" dropdown if unassigned,
///    Call Sign (📞) + "Change Admin" + "Expel Admin" if assigned.
/// 2. Mode Switch: Normal Mode vs Distribution Mode.
/// 3. Company Ad Campaigns distribution toggles & progress bars.
/// 4. Distribution of Materials toggles & progress bars.
/// 5. Zone-Specific Pricing Configuration Matrix (A5/A6 Stand & Saloon, A6 Design & Print).
class ZoneAdminDashboardPanel extends ConsumerStatefulWidget {
  final Zone zone;
  final List<Shop> shops;
  final VoidCallback onClose;
  final VoidCallback? onEditPolygon;

  const ZoneAdminDashboardPanel({
    super.key,
    required this.zone,
    required this.shops,
    required this.onClose,
    this.onEditPolygon,
  });

  @override
  ConsumerState<ZoneAdminDashboardPanel> createState() =>
      _ZoneAdminDashboardPanelState();
}

class _ZoneAdminDashboardPanelState extends ConsumerState<ZoneAdminDashboardPanel> {
  Timer? _syncTimer;

  // Controllers for Zone-Specific Pricing Override
  late TextEditingController _a5StandOneCtrl;
  late TextEditingController _a5StandBothCtrl;
  late TextEditingController _a6StandOneCtrl;
  late TextEditingController _a6StandBothCtrl;
  late TextEditingController _a5SaloonOneCtrl;
  late TextEditingController _a5SaloonBothCtrl;
  late TextEditingController _a6SaloonOneCtrl;
  late TextEditingController _a6SaloonBothCtrl;
  late TextEditingController _designPrintA6OneCtrl;
  late TextEditingController _designPrintA6BothCtrl;

  bool _isSavingPricing = false;
  String? _adminCode;

  @override
  void initState() {
    super.initState();
    _adminCode = CanonicalZones.getZoneAdminCode(widget.zone.id);
    _initPricingControllers();
    CanonicalZones.zonesRevision.addListener(_onZonesRevisionChanged);

    // Auto-sync remote state every 2 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      final updated = await CanonicalZones.syncWithRemote();
      if (updated && mounted) {
        setState(() {});
      }
    });
  }

  void _onZonesRevisionChanged() {
    if (mounted) {
      setState(() {
        _adminCode = CanonicalZones.getZoneAdminCode(widget.zone.id);
      });
    }
  }

  void _initPricingControllers() {
    final cfg = CanonicalZones.getZonePricing(widget.zone.id);
    _a5StandOneCtrl = TextEditingController(text: cfg.a5StandOneSide.toStringAsFixed(0));
    _a5StandBothCtrl = TextEditingController(text: cfg.a5StandBothSides.toStringAsFixed(0));
    _a6StandOneCtrl = TextEditingController(text: cfg.a6StandOneSide.toStringAsFixed(0));
    _a6StandBothCtrl = TextEditingController(text: cfg.a6StandBothSides.toStringAsFixed(0));
    _a5SaloonOneCtrl = TextEditingController(text: cfg.a5SaloonOneSide.toStringAsFixed(0));
    _a5SaloonBothCtrl = TextEditingController(text: cfg.a5SaloonBothSides.toStringAsFixed(0));
    _a6SaloonOneCtrl = TextEditingController(text: cfg.a6SaloonOneSide.toStringAsFixed(0));
    _a6SaloonBothCtrl = TextEditingController(text: cfg.a6SaloonBothSides.toStringAsFixed(0));
    _designPrintA6OneCtrl = TextEditingController(text: cfg.designPrintA6OneSide.toStringAsFixed(0));
    _designPrintA6BothCtrl = TextEditingController(text: cfg.designPrintA6BothSides.toStringAsFixed(0));
  }

  @override
  void didUpdateWidget(covariant ZoneAdminDashboardPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zone.id != widget.zone.id) {
      _adminCode = CanonicalZones.getZoneAdminCode(widget.zone.id);
      _disposeControllers();
      _initPricingControllers();
    }
  }

  @override
  void dispose() {
    CanonicalZones.zonesRevision.removeListener(_onZonesRevisionChanged);
    _syncTimer?.cancel();
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _a5StandOneCtrl.dispose();
    _a5StandBothCtrl.dispose();
    _a6StandOneCtrl.dispose();
    _a6StandBothCtrl.dispose();
    _a5SaloonOneCtrl.dispose();
    _a5SaloonBothCtrl.dispose();
    _a6SaloonOneCtrl.dispose();
    _a6SaloonBothCtrl.dispose();
    _designPrintA6OneCtrl.dispose();
    _designPrintA6BothCtrl.dispose();
  }

  Color _parseZoneColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return AppColors.primary;
    final clean = hexString.replaceAll('#', '');
    try {
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  void _saveZonePricing() {
    setState(() => _isSavingPricing = true);
    try {
      final updatedConfig = ZonePricingConfig(
        zoneId: widget.zone.id,
        a5StandOneSide: double.tryParse(_a5StandOneCtrl.text) ?? 80.0,
        a5StandBothSides: double.tryParse(_a5StandBothCtrl.text) ?? 80.0,
        a6StandOneSide: double.tryParse(_a6StandOneCtrl.text) ?? 100.0,
        a6StandBothSides: double.tryParse(_a6StandBothCtrl.text) ?? 100.0,
        a5SaloonOneSide: double.tryParse(_a5SaloonOneCtrl.text) ?? 80.0,
        a5SaloonBothSides: double.tryParse(_a5SaloonBothCtrl.text) ?? 80.0,
        a6SaloonOneSide: double.tryParse(_a6SaloonOneCtrl.text) ?? 100.0,
        a6SaloonBothSides: double.tryParse(_a6SaloonBothCtrl.text) ?? 100.0,
        designPrintA6OneSide: double.tryParse(_designPrintA6OneCtrl.text) ?? 5000.0,
        designPrintA6BothSides: double.tryParse(_designPrintA6BothCtrl.text) ?? 10000.0,
        updatedAt: DateTime.now(),
      );

      CanonicalZones.setZonePricing(widget.zone.id, updatedConfig);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Pricing updated for "${widget.zone.name}" only! All other zones remain at standard rates.',
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingPricing = false);
    }
  }

  void _resetZonePricingToDefaults() {
    final defaultConfig = ZonePricingConfig.defaultForZone(widget.zone.id);
    CanonicalZones.setZonePricing(widget.zone.id, defaultConfig);
    _a5StandOneCtrl.text = defaultConfig.a5StandOneSide.toStringAsFixed(0);
    _a5StandBothCtrl.text = defaultConfig.a5StandBothSides.toStringAsFixed(0);
    _a6StandOneCtrl.text = defaultConfig.a6StandOneSide.toStringAsFixed(0);
    _a6StandBothCtrl.text = defaultConfig.a6StandBothSides.toStringAsFixed(0);
    _a5SaloonOneCtrl.text = defaultConfig.a5SaloonOneSide.toStringAsFixed(0);
    _a5SaloonBothCtrl.text = defaultConfig.a5SaloonBothSides.toStringAsFixed(0);
    _a6SaloonOneCtrl.text = defaultConfig.a6SaloonOneSide.toStringAsFixed(0);
    _a6SaloonBothCtrl.text = defaultConfig.a6SaloonBothSides.toStringAsFixed(0);
    _designPrintA6OneCtrl.text = defaultConfig.designPrintA6OneSide.toStringAsFixed(0);
    _designPrintA6BothCtrl.text = defaultConfig.designPrintA6BothSides.toStringAsFixed(0);
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reverted "${widget.zone.name}" to platform default pricing rates.'),
        backgroundColor: Colors.blueGrey,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAdminContactDialog({
    required String adminName,
    required String adminPhone,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0xFFE0E7FF),
                    child: Icon(Icons.person, color: Color(0xFF4338CA), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adminName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          adminPhone.isNotEmpty ? adminPhone : 'No phone number registered',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.call, color: Colors.green.shade700, size: 20),
                ),
                title: const Text('Direct Phone Call / সরাসরি কল', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(adminPhone),
                onTap: () async {
                  Navigator.pop(ctx);
                  final clean = adminPhone.replaceAll(' ', '');
                  final uri = Uri.parse('tel:$clean');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Cannot launch phone dialer for $clean')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF16A34A), size: 20),
                ),
                title: const Text('WhatsApp Chat / হোয়াটসঅ্যাপ চ্যাট', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Send direct message on WhatsApp'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final clean = adminPhone.replaceAll('+', '').replaceAll(' ', '').replaceAll('-', '');
                  final uri = Uri.parse('https://wa.me/$clean');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.copy_rounded, color: Colors.blue.shade700, size: 20),
                ),
                title: const Text('Copy Phone Number / নম্বর কপি করুন', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Copy to clipboard'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: adminPhone));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Admin phone number copied to clipboard!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignAdminDialog({bool isReassign = false}) async {
    final repo = ref.read(masterAdminRepositoryProvider);
    final admins = await repo.getAdmins();

    if (!mounted) return;

    UserProfile? selectedAdmin = admins.isNotEmpty ? admins.first : null;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isReassign ? Icons.swap_horiz_rounded : Icons.person_add_rounded,
                  color: const Color(0xFF0F2A43),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isReassign ? 'Change Zone Admin' : 'Assign Admin to Zone',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select an authorized administrator to assign to "${widget.zone.name}":',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserProfile>(
                      isExpanded: true,
                      value: selectedAdmin,
                      hint: const Text('Select Admin'),
                      items: admins.map((admin) {
                        final displayName = admin.fullName.isNotEmpty
                            ? admin.fullName
                            : 'Admin Code: ${admin.displayId} (Pending)';
                        return DropdownMenuItem<UserProfile>(
                          value: admin,
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 12,
                                backgroundColor: Color(0xFFE0E7FF),
                                child: Icon(Icons.person, size: 14, color: Color(0xFF4338CA)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$displayName • ID: ${admin.displayId}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDlgState(() => selectedAdmin = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Text(
                    'The assigned admin will have full control to assign field employees and run material distributions in this zone.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF0F2A43)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F2A43)),
                onPressed: selectedAdmin == null
                    ? null
                    : () async {
                        Navigator.pop(dlgCtx);
                        final admin = selectedAdmin!;
                        final adminLabel = admin.fullName.isNotEmpty
                            ? '${admin.fullName} (ID: ${admin.displayId})'
                            : 'Admin ID: ${admin.displayId}';

                        CanonicalZones.assignAdminToZone(
                          zoneId: widget.zone.id,
                          adminId: admin.id,
                          adminName: adminLabel,
                          adminPhone: (admin.phoneNumber ?? '').isNotEmpty ? admin.phoneNumber! : '+91 98301 11223',
                          syncRemote: true,
                        );

                        try {
                          final updatedZone = widget.zone.copyWith(
                            assignedAdminId: admin.id,
                            assignedAdminName: adminLabel,
                            updatedAt: DateTime.now(),
                          );
                          await repo.saveZone(
                            updatedZone,
                            widget.zone.vertices,
                            assignedAdminId: admin.id,
                          );
                        } catch (_) {}

                        ref.invalidate(zonesListProvider);
                        if (mounted) {
                          setState(() {});
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Admin "$adminLabel" assigned to "${widget.zone.name}"!'),
                                backgroundColor: Colors.green.shade700,
                              ),
                            );
                          }
                        }
                      },
                child: Text(isReassign ? 'Confirm Change' : 'Assign to Zone'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showExpelAdminConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Expel Admin from Zone?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to expel the assigned admin from "${widget.zone.name}"?',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🛡️ Zero Operational Disruption Guarantee:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F2A43)),
                  ),
                  SizedBox(height: 4),
                  Text('• The zone becomes vacant (No Admin).', style: TextStyle(fontSize: 11)),
                  Text('• Field employees continue working with 0 interruptions.', style: TextStyle(fontSize: 11)),
                  Text('• Ongoing material distributions remain active.', style: TextStyle(fontSize: 11)),
                  Text('• Company ad campaign schedules are unaffected.', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            icon: const Icon(Icons.person_remove_outlined, size: 16),
            label: const Text('Expel Admin'),
            onPressed: () async {
              Navigator.pop(ctx);
              final newAdmin = CanonicalZones.expelAdminFromZoneWithNewCode(widget.zone.id, syncRemote: true);
              try {
                final repo = ref.read(masterAdminRepositoryProvider);
                final updatedZone = widget.zone.copyWith(
                  assignedAdminId: newAdmin.id,
                  assignedAdminName: 'Admin Code: ${newAdmin.displayId}',
                  updatedAt: DateTime.now(),
                );
                await repo.saveZone(
                  updatedZone,
                  widget.zone.vertices,
                  assignedAdminId: newAdmin.id,
                );
              } catch (_) {}

              ref.invalidate(zonesListProvider);
              if (mounted) {
                setState(() {});
                showDialog(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.green, size: 26),
                        SizedBox(width: 8),
                        Text('Admin Expelled & Code Generated'),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'The previous admin has been expelled from "${widget.zone.name}". A fresh unclaimed Admin Code has been generated for this zone:',
                          style: const TextStyle(fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F2A43),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            newAdmin.displayId ?? '',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Provide this 5-digit code to the new administrator. When they log in on Admin App, their name will appear on this zone card automatically.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    actions: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy Code'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: newAdmin.displayId ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Admin Code ${newAdmin.displayId} copied to clipboard!'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F2A43)),
                        onPressed: () => Navigator.pop(dCtx),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
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
      label = '🟢 Live Now';
      bgColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF15803D);
      icon = Icons.bolt;
    } else if (start.isAtSameMomentAs(today)) {
      label = '🔴 Starts Today';
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFFB91C1C);
      icon = Icons.warning_rounded;
    } else if (start.isAfter(today)) {
      final days = start.difference(today).inDays;
      if (days == 1) {
        label = '🔴 Starts in 1 day';
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFB91C1C);
        icon = Icons.timer_outlined;
      } else if (days <= 3) {
        label = '🟡 Starts in $days days';
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFB45309);
        icon = Icons.schedule_rounded;
      } else {
        label = '⚪ Starts in $days days';
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePill(String sideRaw) {
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizePill(String sizeRaw) {
    final isA5 = sizeRaw.toUpperCase().contains('A5');
    final color = isA5 ? const Color(0xFF0F766E) : const Color(0xFF7C3AED);
    final bg = isA5 ? const Color(0xFFF0FDFA) : const Color(0xFFF5F3FF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        sizeRaw.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCategoryPill(String businessType) {
    final isSaloon = businessType.toLowerCase() == 'saloon';
    final bg = isSaloon ? const Color(0xFFFDF2F8) : const Color(0xFFF0FDF4);
    final fg = isSaloon ? const Color(0xFFBE185D) : const Color(0xFF15803D);
    final icon = isSaloon ? Icons.content_cut_rounded : Icons.storefront_rounded;
    final text = isSaloon ? 'SALOON' : 'SHOP';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailCard({
    required BuildContext context,
    required String label,
    required String imageUrl,
    required DateTime? uploadedAt,
  }) {
    return InkWell(
      onTap: () => _showFullScreenImage(context, imageUrl, label, uploadedAt),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.zoom_in_rounded, size: 13, color: Color(0xFF0284C7)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.network(
                imageUrl,
                height: 54,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 54,
                  color: const Color(0xFFE2E8F0),
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 18, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              uploadedAt != null
                  ? _formatDateTime(uploadedAt)
                  : 'Uploaded',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
    final zoneColor = _parseZoneColor(widget.zone.colorHex);
    final isDistributionMode = CanonicalZones.isDistributionModeActive(widget.zone.id);
    final adRuns = List<CompanyAdDistributionRun>.from(
      CanonicalZones.getCompanyAdRuns(widget.zone.id),
    )..sort((a, b) => a.slotStartDate.compareTo(b.slotStartDate));
    final matRuns = CanonicalZones.getMaterialRuns(widget.zone.id);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Zone Panel Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F2A43),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: zoneColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.zone.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${widget.shops.length} Retail Shops Registered',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onEditPolygon != null)
                  IconButton(
                    icon: const Icon(Icons.edit_location_alt_outlined, color: Colors.white, size: 20),
                    tooltip: 'Edit Zone Vertices',
                    onPressed: widget.onEditPolygon,
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  tooltip: 'Close Panel',
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                // 2. DYNAMIC ADMIN CARD (Unassigned vs Assigned)
                Builder(
                  builder: (context) {
                    final zoneObj = CanonicalZones.all.firstWhere(
                      (z) => z.id == widget.zone.id,
                      orElse: () => widget.zone,
                    );
                    final assignedAdminId = zoneObj.assignedAdminId;
                    final assignedAdminName = zoneObj.assignedAdminName;
                    final bool hasAssignedAdmin = assignedAdminId != null &&
                        assignedAdminId.isNotEmpty &&
                        assignedAdminName != null &&
                        assignedAdminName.isNotEmpty;
                    final adminPhone = CanonicalZones.getZoneAdminPhone(widget.zone.id) ?? '+91 98301 11223';

                    if (!hasAssignedAdmin) {
                      // UNASSIGNED STATE
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Color(0xFFE2E8F0),
                                  child: Icon(Icons.person_off_rounded, color: Color(0xFF64748B), size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'No Admin Assigned',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Vacant Zone',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'This zone has no active admin. Assign an admin to manage operations.',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F2A43),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.person_add_rounded, size: 16),
                                label: const Text(
                                  'Assign Admin to this Zone / অ্যাডমিন নিয়োগ করুন',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () => _showAssignAdminDialog(isReassign: false),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // PENDING PAIRING / NEW CODE GENERATED STATE (After expel or new code assigned)
                    final bool isPendingPairing = assignedAdminName.contains('Admin Code:') ||
                        assignedAdminName.contains('Pending Pairing') ||
                        (assignedAdminId.startsWith('admin-code-') && !assignedAdminName.contains('('));

                    if (isPendingPairing) {
                      final cleanCode = assignedAdminName.contains('Admin Code:')
                          ? assignedAdminName.replaceFirst('Admin Code:', '').trim()
                          : (assignedAdminId.replaceFirst('admin-code-', '').trim());

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade300, width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.amber.shade100,
                                  child: Icon(Icons.vpn_key_rounded, color: Colors.amber.shade800, size: 20),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'Admin Code: $cleanCode',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F172A),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '⚪ Pending Pairing / Login',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Awaiting admin sign up with this code on Admin App • Name will bind automatically',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0F2A43),
                                      side: const BorderSide(color: Color(0xFF94A3B8)),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.copy_rounded, size: 15),
                                    label: Text(
                                      'Copy Code ($cleanCode)',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: cleanCode));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Admin Code $cleanCode copied to clipboard!'),
                                          backgroundColor: const Color(0xFF0F2A43),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0F2A43),
                                      side: const BorderSide(color: Color(0xFF94A3B8)),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                                    label: const Text(
                                      'Change Admin',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => _showAssignAdminDialog(isReassign: true),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }

                    // ACTIVE ASSIGNED ADMIN STATE
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0xFFE0E7FF),
                                child: Icon(Icons.person, color: Color(0xFF4338CA), size: 20),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            assignedAdminName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Admin Active',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Assigned Admin ID / Code: ${_adminCode ?? "10001"}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Call Sign (📞) Button beside Admin's Name
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFDCFCE7),
                                  foregroundColor: const Color(0xFF15803D),
                                  shape: const CircleBorder(),
                                  padding: const EdgeInsets.all(8),
                                ),
                                icon: const Icon(Icons.phone, size: 18),
                                tooltip: 'Call / Contact Admin ($adminPhone)',
                                onPressed: () => _showAdminContactDialog(
                                  adminName: assignedAdminName,
                                  adminPhone: adminPhone,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Action Buttons: "Change Admin" and "Expel Admin" side-by-side
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0F2A43),
                                    side: const BorderSide(color: Color(0xFF94A3B8)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                                  label: const Text(
                                    'Change Admin',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () => _showAssignAdminDialog(isReassign: true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                    side: BorderSide(color: Colors.red.shade300),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.person_remove_outlined, size: 16),
                                  label: const Text(
                                    'Expel Admin',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: _showExpelAdminConfirmationDialog,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // 3. MASTER ZONE MODE SWITCH (Normal vs Distribution)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDistributionMode ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDistributionMode ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isDistributionMode ? Icons.local_shipping_rounded : Icons.store_rounded,
                            color: isDistributionMode ? const Color(0xFF059669) : const Color(0xFF475569),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isDistributionMode ? 'Distribution Mode Active' : 'Normal Operating Mode',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDistributionMode ? const Color(0xFF065F46) : const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                isDistributionMode
                                    ? 'Field employees distributing materials'
                                    : 'Standard verification & daily monitoring',
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: isDistributionMode,
                        activeThumbColor: const Color(0xFF10B981),
                        onChanged: (val) {
                          CanonicalZones.setDistributionMode(widget.zone.id, val);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 4. SECTION: COMPANY AD CAMPAIGNS (বিজ্ঞাপন ক্যাম্পেইন বিতরণ)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.campaign_rounded, color: Color(0xFF0284C7), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'COMPANY AD CAMPAIGNS',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F2A43),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (adRuns.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'No active company ad bookings in this zone.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        )
                      else
                        for (final ad in adRuns) ...[
                          () {
                            final hasDesign = ad.hasAdDesign;
                            final hasPrint = ad.hasPrintoutProof;
                            final isDistributionStarted =
                                ad.isDistributionActive || ad.distributedShopIds.isNotEmpty || ad.isCompleted;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: ad.status == 'active'
                                      ? const Color(0xFF0284C7).withValues(alpha: 0.5)
                                      : const Color(0xFFE2E8F0),
                                  width: ad.status == 'active' ? 1.4 : 1.0,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x08000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1. Company Name & Distribution Toggle
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          ad.companyName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: Color(0xFF0F2A43),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 28,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Switch(
                                            value: ad.status == 'active',
                                            activeThumbColor: const Color(0xFF0284C7),
                                            onChanged: (val) {
                                              CanonicalZones.toggleCompanyAdRun(widget.zone.id, ad.id, val);
                                              setState(() {});
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // 2. Info of side, size, category
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      _buildSidePill(ad.placementSide),
                                      _buildSizePill(ad.standSize),
                                      _buildCategoryPill(ad.businessType),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // 3. Booked date slot and starts in days (ALWAYS VIEW)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            'Booked: ${_formatDate(ad.slotStartDate)} - ${_formatDate(ad.slotEndDate)}',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                        _buildUrgencyBadge(ad),
                                      ],
                                    ),
                                  ),

                                  // 4. Add Design & Print Proof Thumbnails (VIEW NOTHING IF NOT UPLOADED)
                                  if (hasDesign || hasPrint) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (hasDesign)
                                          _buildThumbnailCard(
                                            context: context,
                                            label: 'Ad Design',
                                            imageUrl: ad.adCreativeImageUrl!,
                                            uploadedAt: ad.adDesignUploadedAt,
                                          ),
                                        if (hasPrint)
                                          _buildThumbnailCard(
                                            context: context,
                                            label: 'Print Proof',
                                            imageUrl: ad.printoutProofImageUrl!,
                                            uploadedAt: ad.printoutProofUploadedAt,
                                          ),
                                      ],
                                    ),
                                  ],

                                  // 5. Distribution Started on & Percentage Completed (VIEW NOTHING IF NOT STARTED)
                                  if (isDistributionStarted) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF86EFAC)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.local_shipping_rounded,
                                                    size: 13,
                                                    color: Color(0xFF15803D),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Started: ${_formatDateTime(ad.startedAt)}',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF15803D),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                '${ad.progressPercent}% completed',
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF15803D),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: ad.progressFraction,
                                              minHeight: 5,
                                              backgroundColor: const Color(0xFFDCFCE7),
                                              valueColor: const AlwaysStoppedAnimation<Color>(
                                                Color(0xFF16A34A),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${ad.completedOrGoneCount}/${ad.totalTargetCount} Shops completed',
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF15803D),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }(),
                        ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 5. SECTION: DISTRIBUTION OF MATERIALS (দোকানের সামগ্রী বিতরণ)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.inventory_2_rounded, color: Color(0xFF0F9D8A), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'DISTRIBUTION OF MATERIALS',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F2A43),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (matRuns.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'No universal materials assigned yet.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        )
                      else
                        for (final mat in matRuns) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: mat.status == 'active'
                                    ? const Color(0xFF0F9D8A).withValues(alpha: 0.5)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        mat.materialName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                    Switch(
                                      value: mat.status == 'active',
                                      activeThumbColor: const Color(0xFF0F9D8A),
                                      onChanged: (val) {
                                        CanonicalZones.toggleMaterialRun(widget.zone.id, mat.id, val);
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: mat.progressFraction,
                                    minHeight: 4,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F9D8A)),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${mat.progressPercent}% (${mat.completedOrGoneCount}/${mat.totalTargetCount} Shops)',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF0F9D8A)),
                                ),
                              ],
                            ),
                          ),
                        ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 6. ZONE-SPECIFIC PRICING MATRIX CONFIGURATION
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.currency_rupee, color: Color(0xFFB45309), size: 18),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'ZONE PRICING OVERRIDE (জোন মূল্য)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Zone Scoped',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Changes here will only change or affect pricing of this selected zone. Other zones stay unchanged.',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF78350F)),
                      ),
                      const SizedBox(height: 12),

                      // Stand Pricing Section
                      const Text('• Stand / Retail Shops (দোকান স্ট্যান্ড)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPriceInput(
                              label: 'A5 (One Side)',
                              controller: _a5StandOneCtrl,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPriceInput(
                              label: 'A5 (Both Sides)',
                              controller: _a5StandBothCtrl,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPriceInput(
                              label: 'A6 (One Side)',
                              controller: _a6StandOneCtrl,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPriceInput(
                              label: 'A6 (Both Sides)',
                              controller: _a6StandBothCtrl,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Saloon Pricing Section
                      const Text('• Saloon & Parlours (সেলুন)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPriceInput(
                              label: 'A5 (One Side)',
                              controller: _a5SaloonOneCtrl,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPriceInput(
                              label: 'A5 (Both Sides)',
                              controller: _a5SaloonBothCtrl,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPriceInput(
                              label: 'A6 (One Side)',
                              controller: _a6SaloonOneCtrl,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPriceInput(
                              label: 'A6 (Both Sides)',
                              controller: _a6SaloonBothCtrl,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Design & Print Pricing Section
                      const Text('• A6 Design & Print Cost (ডিজাইন ও প্রিন্ট)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPriceInput(
                              label: 'A6 (One Side Fee)',
                              controller: _designPrintA6OneCtrl,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPriceInput(
                              label: 'A6 (Both Sides Fee)',
                              controller: _designPrintA6BothCtrl,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Save and Reset Buttons
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0F9D8A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: _isSavingPricing
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.save_outlined, size: 16),
                              label: const Text('Save Zone Pricing', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: _isSavingPricing ? null : _saveZonePricing,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF78350F),
                              side: const BorderSide(color: Color(0xFFD97706)),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _resetZonePricingToDefaults,
                            child: const Text('Reset', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceInput({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 3),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('₹', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2A43))),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
