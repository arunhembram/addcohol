import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Interactive Table Grid View for Zone Company Tasks:
/// Task 1: Ad Design Upload -> Task 2: Print Out Proof -> Task 3: Store Distribution
/// Sorted with the nearest campaign start date ranked 1st.
class ZoneCompanyTasksTable extends StatefulWidget {
  final String zoneId;
  final VoidCallback? onStateChanged;

  const ZoneCompanyTasksTable({
    super.key,
    required this.zoneId,
    this.onStateChanged,
  });

  @override
  State<ZoneCompanyTasksTable> createState() => _ZoneCompanyTasksTableState();
}

class _ZoneCompanyTasksTableState extends State<ZoneCompanyTasksTable> {
  final ImagePicker _picker = ImagePicker();

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

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: textColor.withValues(alpha: 0.3), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideBadge(CompanyAdDistributionRun ad) {
    final side = ad.placementSide.toLowerCase();
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

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: fg.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: fg,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeBadge(CompanyAdDistributionRun ad) {
    final isA5 = ad.standSize.toUpperCase().contains('A5');
    final color = isA5 ? const Color(0xFF0F766E) : const Color(0xFF7C3AED);
    final bg = isA5 ? const Color(0xFFF0FDFA) : const Color(0xFFF5F3FF);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Text(
          ad.standSize.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(CompanyAdDistributionRun ad) {
    final isSaloon = ad.businessType.toLowerCase() == 'saloon';
    final bg = isSaloon ? const Color(0xFFFDF2F8) : const Color(0xFFF0FDF4);
    final fg = isSaloon ? const Color(0xFFBE185D) : const Color(0xFF15803D);
    final icon = isSaloon ? Icons.content_cut_rounded : Icons.storefront_rounded;
    final text = isSaloon ? 'SALOON' : 'SHOP';

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: fg.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: fg,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl, String title, DateTime? uploadedAt) {
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
                  // Title bar
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
                  // Zoomable Image
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

  void _showUploadImageDialog({
    required BuildContext context,
    required CompanyAdDistributionRun ad,
    required bool isPrintProof,
  }) {
    final title = isPrintProof
        ? 'Upload Print Out Photo (Task 2)'
        : 'Upload Ad Design (Task 1)';
    final currentUrl = isPrintProof ? ad.printoutProofImageUrl : ad.adCreativeImageUrl;
    final controller = TextEditingController(text: currentUrl ?? '');

    final presets = isPrintProof
        ? [
            {'name': 'Print Proof A5 Banner', 'url': 'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=500'},
            {'name': 'Print Proof A6 Poster', 'url': 'https://images.unsplash.com/photo-1572945550745-37421bed2e66?w=500'},
            {'name': 'Stand Sticker Roll', 'url': 'https://images.unsplash.com/photo-1506784983877-45594efa4cbe?w=500'},
          ]
        : [
            {'name': 'Pepsi Creative', 'url': 'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=500'},
            {'name': 'Cadbury Creative', 'url': 'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=500'},
            {'name': 'Britannia Creative', 'url': 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=500'},
          ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isPrintProof ? Icons.print_rounded : Icons.brush_rounded,
                color: isPrintProof ? const Color(0xFF0F9D8A) : const Color(0xFF0284C7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Company: ${ad.companyName} • ${ad.placementSide.toUpperCase()} Side',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  if (controller.text.trim().isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        controller.text.trim(),
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 140,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Text('Image preview unavailable', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: isPrintProof ? 'Print Proof Image URL' : 'Ad Design Image URL',
                      hintText: 'https://...',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: const Icon(Icons.link),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),

                  // Option to pick photo from device camera/gallery
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 38),
                    ),
                    icon: const Icon(Icons.photo_camera_back_outlined, size: 18),
                    label: const Text('Pick Image from Device / Camera'),
                    onPressed: () async {
                      try {
                        final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
                        if (file != null) {
                          setDialogState(() {
                            controller.text = file.path;
                          });
                        }
                      } catch (_) {}
                    },
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Quick Presets / নমুনা ছবি নির্বাচন করুন:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: presets.map((p) => ActionChip(
                      label: Text(p['name']!, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        setDialogState(() {
                          controller.text = p['url']!;
                        });
                      },
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: isPrintProof ? const Color(0xFF0F9D8A) : const Color(0xFF0284C7),
              ),
              icon: const Icon(Icons.check, size: 16),
              label: Text(isPrintProof ? 'Save Print Proof' : 'Save Ad Design'),
              onPressed: () {
                final url = controller.text.trim();
                if (url.isNotEmpty) {
                  if (isPrintProof) {
                    CanonicalZones.updateCompanyPrintoutProof(widget.zoneId, ad.id, url);
                  } else {
                    CanonicalZones.updateCompanyAdDesign(widget.zoneId, ad.id, url);
                  }
                  setState(() {});
                  widget.onStateChanged?.call();
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isPrintProof
                          ? '✅ ${ad.companyName} এর প্রিন্ট আউটের ছবি আপলোড সম্পন্ন (Task 2 Complete)!'
                          : '✅ ${ad.companyName} এর ডিজাইন আপলোড সম্পন্ন (Task 1 Complete)!',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete({
    required BuildContext context,
    required CompanyAdDistributionRun ad,
    required bool isPrintProof,
  }) {
    final title = isPrintProof
        ? 'Delete Print Out Proof Photo?'
        : 'Delete Ad Design Artwork?';
    final warning = isPrintProof
        ? 'Removing this print proof photo will revert Task 2 and lock Distribution until a new print proof is uploaded.'
        : 'Removing this design will reset both Task 1 and Task 2, locking Print Out and Distribution.';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: Text(warning, style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (isPrintProof) {
                CanonicalZones.deleteCompanyPrintoutProof(widget.zoneId, ad.id);
              } else {
                CanonicalZones.deleteCompanyAdDesign(widget.zoneId, ad.id);
              }
              setState(() {});
              widget.onStateChanged?.call();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isPrintProof
                        ? '🗑️ Print proof photo removed for ${ad.companyName}.'
                        : '🗑️ Ad design removed for ${ad.companyName}.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmStartDistribution({
    required BuildContext context,
    required CompanyAdDistributionRun ad,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.local_shipping_rounded, color: Color(0xFF0F9D8A)),
            SizedBox(width: 8),
            Text('Start Distribution to Stores?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Company: ${ad.companyName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Target: ${ad.businessType.toUpperCase()} stores (${ad.placementSide.toUpperCase()} Side Stand)',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F9D8A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront, color: Color(0xFF0F9D8A), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ready to dispatch ad stickers to ${ad.totalTargetCount} registered retail stores in this zone.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F9D8A)),
                    ),
                  ),
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
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F9D8A)),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Start Distribution Now'),
            onPressed: () {
              CanonicalZones.startCompanyDistribution(widget.zoneId, ad.id);
              setState(() {});
              widget.onStateChanged?.call();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🚀 ${ad.companyName} এর বিতরণ শুরু হলো (Distribution Active)!'),
                  backgroundColor: const Color(0xFF0F9D8A),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 1. Fetch runs for this zone
    final allRuns = List<CompanyAdDistributionRun>.from(
      CanonicalZones.getCompanyAdRuns(widget.zoneId),
    );

    // 2. Nearest date ranked 1st: Sort ascending by slotStartDate!
    allRuns.sort((a, b) => a.slotStartDate.compareTo(b.slotStartDate));

    if (allRuns.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'এই জোনে কোনো কোম্পানির বুক করা বিজ্ঞাপন ক্যাম্পেইন নেই।',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-heading
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.table_chart_rounded, size: 16, color: Color(0xFF0284C7)),
                SizedBox(width: 6),
                Text(
                  'TASK VIEW & DISTRIBUTION PIPELINE (কার্যতালিকা)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F2A43)),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Nearest Live Date Ranked 1st ⏱️',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Responsive Horizontal Scroll Table Grid
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              border: Border.all(color: borderColor, width: 1.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: FixedColumnWidth(165), // Company Name
                  1: FixedColumnWidth(105), // Side (Booked Side)
                  2: FixedColumnWidth(85),  // Size (A5 / A6)
                  3: FixedColumnWidth(110), // Category (Shop / Saloon)
                  4: FixedColumnWidth(170), // Ad Design (Task 1)
                  5: FixedColumnWidth(170), // Print Out (Task 2)
                  6: FixedColumnWidth(205), // Distribution (Task 3)
                  7: FixedColumnWidth(165), // Live On (Date Slot)
                },
                border: TableBorder(
                  horizontalInside: BorderSide(color: borderColor, width: 1.0),
                  verticalInside: BorderSide(color: borderColor, width: 1.0),
                ),
                children: [
                  // --- HEADER ROW ---
                  TableRow(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    ),
                    children: const [
                      _HeaderCell(label: 'COMPANY NAME'),
                      _HeaderCell(label: 'SIDE\n(BOOKED)'),
                      _HeaderCell(label: 'SIZE\n(A5 / A6)'),
                      _HeaderCell(label: 'CATEGORY\n(SHOP/SALOON)'),
                      _HeaderCell(label: 'AD DESIGN\n(TASK 1)'),
                      _HeaderCell(label: 'PRINT OUT\n(TASK 2)'),
                      _HeaderCell(label: 'DISTRIBUTION\n(TASK 3)'),
                      _HeaderCell(label: 'LIVE ON\n(DATE SLOT)'),
                    ],
                  ),

                  // --- DATA ROWS ---
                  ...allRuns.map((ad) {
                    return TableRow(
                      children: [
                        // Col 1: Company Name
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ad.companyName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.storefront_outlined, size: 12, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${ad.totalTargetCount} shops',
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Col 2: Side (Booked Side)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                          child: Center(
                            child: _buildSideBadge(ad),
                          ),
                        ),

                        // Col 3: Size (A5 or A6)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                          child: Center(
                            child: _buildSizeBadge(ad),
                          ),
                        ),

                        // Col 4: Category (Shop or Saloon)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                          child: Center(
                            child: _buildCategoryBadge(ad),
                          ),
                        ),

                        // Col 5: Ad Design (Task 1)
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: ad.hasAdDesign
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _showFullScreenImage(
                                        context,
                                        ad.adCreativeImageUrl!,
                                        '${ad.companyName} - Ad Design',
                                        ad.adDesignUploadedAt,
                                      ),
                                      child: Stack(
                                        alignment: Alignment.topRight,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Image.network(
                                              ad.adCreativeImageUrl!,
                                              width: 100,
                                              height: 64,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Container(
                                                width: 100,
                                                height: 64,
                                                color: Colors.grey.shade200,
                                                alignment: Alignment.center,
                                                child: const Icon(Icons.image_not_supported, size: 20),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(6)),
                                            ),
                                            child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Uploaded: ${_formatDateTime(ad.adDesignUploadedAt)}',
                                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        InkWell(
                                          onTap: () => _showUploadImageDialog(
                                            context: context,
                                            ad: ad,
                                            isPrintProof: false,
                                          ),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            child: Icon(Icons.edit, size: 14, color: Color(0xFF0284C7)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () => _confirmDelete(
                                            context: context,
                                            ad: ad,
                                            isPrintProof: false,
                                          ),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            child: Icon(Icons.delete_outline, size: 15, color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        side: const BorderSide(color: Color(0xFF0284C7)),
                                      ),
                                      icon: const Icon(Icons.upload_rounded, size: 15, color: Color(0xFF0284C7)),
                                      label: const Text(
                                        'Upload Design',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                      ),
                                      onPressed: () => _showUploadImageDialog(
                                        context: context,
                                        ad: ad,
                                        isPrintProof: false,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text('Task 1 Pending', style: TextStyle(fontSize: 9.5, color: Colors.orange)),
                                  ],
                                ),
                        ),

                        // Col 3: Print Out (Task 2)
                        // Shows X until Task 1 (Ad Design) is uploaded
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: !ad.hasAdDesign
                              ? Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.close_rounded, color: Colors.redAccent, size: 28),
                                      const SizedBox(height: 2),
                                      Text(
                                        'X Locked\n(Requires Ad Design)',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : ad.hasPrintoutProof
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: () => _showFullScreenImage(
                                            context,
                                            ad.printoutProofImageUrl!,
                                            '${ad.companyName} - Print Out Proof',
                                            ad.printoutProofUploadedAt,
                                          ),
                                          child: Stack(
                                            alignment: Alignment.topRight,
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(6),
                                                child: Image.network(
                                                  ad.printoutProofImageUrl!,
                                                  width: 100,
                                                  height: 64,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) => Container(
                                                    width: 100,
                                                    height: 64,
                                                    color: Colors.grey.shade200,
                                                    alignment: Alignment.center,
                                                    child: const Icon(Icons.image_not_supported, size: 20),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(6)),
                                                ),
                                                child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Uploaded: ${_formatDateTime(ad.printoutProofUploadedAt)}',
                                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            InkWell(
                                              onTap: () => _showUploadImageDialog(
                                                context: context,
                                                ad: ad,
                                                isPrintProof: true,
                                              ),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                child: Icon(Icons.edit, size: 14, color: Color(0xFF0F9D8A)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () => _confirmDelete(
                                                context: context,
                                                ad: ad,
                                                isPrintProof: true,
                                              ),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                child: Icon(Icons.delete_outline, size: 15, color: Colors.red),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(0xFF0F9D8A),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          ),
                                          icon: const Icon(Icons.print_rounded, size: 15),
                                          label: const Text(
                                            'Upload Print Photo',
                                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () => _showUploadImageDialog(
                                            context: context,
                                            ad: ad,
                                            isPrintProof: true,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text('Task 2 Ready', style: TextStyle(fontSize: 9.5, color: Color(0xFF0F9D8A))),
                                      ],
                                    ),
                        ),

                        // Col 4: Distribution (Task 3)
                        // Shows X until Task 2 (Print Out) is complete
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: !ad.hasPrintoutProof
                              ? Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.close_rounded, color: Colors.redAccent, size: 28),
                                      const SizedBox(height: 2),
                                      Text(
                                        'X Locked\n(Requires Print Proof)',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : !ad.isDistributionActive && ad.deliveredCount == 0
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(0xFF0284C7),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          ),
                                          icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                          label: const Text(
                                            'START',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                          ),
                                          onPressed: () => _confirmStartDistribution(
                                            context: context,
                                            ad: ad,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Ready for Store Delivery',
                                          style: TextStyle(fontSize: 9.5, color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${ad.progressPercent}% Complete',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0284C7),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${ad.completedOrGoneCount}/${ad.totalTargetCount}',
                                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: ad.progressFraction,
                                            minHeight: 6,
                                            backgroundColor: const Color(0xFFE2E8F0),
                                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            TextButton.icon(
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              icon: const Icon(Icons.map_outlined, size: 13),
                                              label: const Text('View Map', style: TextStyle(fontSize: 10.5)),
                                              onPressed: () => context.push('/zones/${widget.zoneId}/map'),
                                            ),
                                            const Spacer(),
                                            Switch(
                                              value: ad.status == 'active',
                                              activeThumbColor: const Color(0xFF0284C7),
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              onChanged: (val) {
                                                CanonicalZones.toggleCompanyAdRun(widget.zoneId, ad.id, val);
                                                setState(() {});
                                                widget.onStateChanged?.call();
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                        ),

                        // Col 5: Live On (Date Slot & Urgency)
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_formatDate(ad.slotStartDate)} - ${_formatDate(ad.slotEndDate)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildUrgencyBadge(ad),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;

  const _HeaderCell({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F2A43),
          letterSpacing: 0.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
