import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

enum DistributionItemType {
  material,
  adCampaign,
}

class DistributionDisplayItem {
  final String id;
  final String name;
  final DistributionItemType type;
  final String? imageUrl;
  final String? placementSide;
  final String? companyName;
  final bool isDistributed;
  final DateTime? distributedAt;

  const DistributionDisplayItem({
    required this.id,
    required this.name,
    required this.type,
    this.imageUrl,
    this.placementSide,
    this.companyName,
    required this.isDistributed,
    this.distributedAt,
  });
}

class ShopDistributionHandoverSheet extends StatefulWidget {
  final Shop shop;
  final VoidCallback onSubmitted;
  final VoidCallback onMarkGone;

  const ShopDistributionHandoverSheet({
    super.key,
    required this.shop,
    required this.onSubmitted,
    required this.onMarkGone,
  });

  static Future<void> show(
    BuildContext context, {
    required Shop shop,
    required VoidCallback onSubmitted,
    required VoidCallback onMarkGone,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ShopDistributionHandoverSheet(
        shop: shop,
        onSubmitted: onSubmitted,
        onMarkGone: onMarkGone,
      ),
    );
  }

  @override
  State<ShopDistributionHandoverSheet> createState() =>
      _ShopDistributionHandoverSheetState();
}

class _ShopDistributionHandoverSheetState
    extends State<ShopDistributionHandoverSheet> {
  late List<DistributionDisplayItem> _allItems;

  @override
  void initState() {
    super.initState();
    _loadApplicableRuns();
  }

  void _loadApplicableRuns() {
    final zoneId = widget.shop.zoneId ?? CanonicalZones.kolkataCentralId;
    final isSaloon =
        ShopCategory.fromString(widget.shop.category) == ShopCategory.saloon;
    final shopType = isSaloon ? 'saloon' : 'shop';

    final items = <DistributionDisplayItem>[];

    // 1. Material runs (Stationery, Stands, Admin items)
    final allMatRuns = CanonicalZones.getMaterialRuns(zoneId);
    for (final mat in allMatRuns) {
      if (mat.status != 'active') continue;
      if (mat.targetBusinessType == 'saloon' && !isSaloon) continue;
      if (mat.targetBusinessType == 'shop' && isSaloon) continue;

      final isDist = CanonicalZones.isShopItemDistributed(
              widget.shop.id, mat.materialId) ||
          CanonicalZones.isShopItemDistributed(widget.shop.id, mat.id) ||
          mat.distributedShopIds.contains(widget.shop.id);

      final distAt = CanonicalZones.getShopItemDistributedTimestamp(
              widget.shop.id, mat.materialId) ??
          CanonicalZones.getShopItemDistributedTimestamp(
              widget.shop.id, mat.id) ??
          (isDist ? mat.startedAt : null);

      items.add(DistributionDisplayItem(
        id: mat.materialId,
        name: mat.materialName,
        type: DistributionItemType.material,
        isDistributed: isDist,
        distributedAt: distAt,
      ));
    }

    // 2. Company Ad runs (With admin uploaded printout photo)
    final allAdRuns = CanonicalZones.getCompanyAdRuns(zoneId);
    for (final ad in allAdRuns) {
      if (ad.businessType.toLowerCase() != 'all' &&
          ad.businessType.toLowerCase() != shopType.toLowerCase()) {
        continue;
      }

      final isDist = CanonicalZones.isShopItemDistributed(
              widget.shop.id, ad.id) ||
          CanonicalZones.isShopItemDistributed(widget.shop.id, ad.companyId) ||
          ad.distributedShopIds.contains(widget.shop.id);

      final distAt = CanonicalZones.getShopItemDistributedTimestamp(
              widget.shop.id, ad.id) ??
          CanonicalZones.getShopItemDistributedTimestamp(
              widget.shop.id, ad.companyId) ??
          (isDist ? ad.startedAt : null);

      // Admin uploaded printout proof image prioritised over design image
      final displayImage = ad.printoutProofImageUrl ?? ad.adCreativeImageUrl;

      items.add(DistributionDisplayItem(
        id: ad.id,
        name: ad.companyName,
        type: DistributionItemType.adCampaign,
        imageUrl: displayImage,
        placementSide: ad.placementSide,
        companyName: ad.companyName,
        isDistributed: isDist,
        distributedAt: distAt,
      ));
    }

    _allItems = items;
  }

  void _handleToggle(DistributionDisplayItem item, bool newValue) {
    final zoneId = widget.shop.zoneId ?? CanonicalZones.kolkataCentralId;
    setState(() {
      if (newValue) {
        CanonicalZones.recordShopItemDistributed(
          zoneId: zoneId,
          shopId: widget.shop.id,
          itemId: item.id,
          timestamp: DateTime.now(),
        );
      } else {
        CanonicalZones.unmarkShopItemDistributed(
          zoneId: zoneId,
          shopId: widget.shop.id,
          itemId: item.id,
        );
      }
      _loadApplicableRuns();
    });
  }

  void _handleCompleteHandover() {
    final zoneId = widget.shop.zoneId ?? CanonicalZones.kolkataCentralId;
    CanonicalZones.recordShopDistributionComplete(
      zoneId: zoneId,
      shopId: widget.shop.id,
      isGone: false,
    );
    Navigator.of(context).pop();
    widget.onSubmitted();
  }

  void _handleShopGone() {
    final zoneId = widget.shop.zoneId ?? CanonicalZones.kolkataCentralId;
    CanonicalZones.recordShopDistributionComplete(
      zoneId: zoneId,
      shopId: widget.shop.id,
      isGone: true,
    );
    Navigator.of(context).pop();
    widget.onMarkGone();
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showImagePreviewDialog(
      BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: Colors.grey.shade900,
                    alignment: Alignment.center,
                    child: const Text('Image unavailable',
                        style: TextStyle(color: Colors.white54)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Verified Admin Print Proof • আসল প্রিন্ট আউটের ছবি',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final shop = widget.shop;
    final isSaloon =
        ShopCategory.fromString(shop.category) == ShopCategory.saloon;

    // 1. Items to distribute today (untoggled)
    final toDistributeToday =
        _allItems.where((i) => !i.isDistributed).toList();

    // 2. Items distributed today (toggled today)
    final distributedToday = _allItems
        .where((i) =>
            i.isDistributed &&
            i.distributedAt != null &&
            _isSameDay(i.distributedAt!, now))
        .toList();

    // 3. Past dates distribution items
    final pastDistributedItems = _allItems
        .where((i) =>
            i.isDistributed &&
            (i.distributedAt == null || !_isSameDay(i.distributedAt!, now)))
        .toList();

    // Group past items by date
    final Map<DateTime, List<DistributionDisplayItem>> pastGrouped = {};
    for (final item in pastDistributedItems) {
      final dt = item.distributedAt ?? now.subtract(const Duration(days: 1));
      final dateKey = DateTime(dt.year, dt.month, dt.day);
      pastGrouped.putIfAbsent(dateKey, () => []).add(item);
    }

    final sortedPastDates = pastGrouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Dark slate theme
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFF475569),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFACC15).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isSaloon
                        ? Icons.content_cut_rounded
                        : Icons.storefront_rounded,
                    color: const Color(0xFFFACC15),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.shopName,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Owner: ${shop.ownerName ?? "N/A"} • ID: ${shop.shopCode ?? shop.id}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF94A3B8),
                        ),
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

          // QR Verified Badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_scanner_rounded,
                      size: 16, color: Color(0xFF34D399)),
                  SizedBox(width: 8),
                  Text(
                    'QR Code Verified • দোকান নিশ্চিত হয়েছে',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 16, thickness: 1, color: Color(0xFF1E293B)),

          // Scrollable Date-Wise List
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              children: [
                // ==========================================
                // 1. TODAY'S DATE SECTION (AT THE TOP)
                // ==========================================
                _buildDateHeaderBox(
                  dateText: _formatDate(now),
                  isToday: true,
                ),
                const SizedBox(height: 12),

                // Sub-heading 1: ⏳ To Distribute
                if (toDistributeToday.isNotEmpty) ...[
                  Row(
                    children: const [
                      Icon(Icons.hourglass_top_rounded,
                          size: 15, color: Color(0xFFFACC15)),
                      SizedBox(width: 6),
                      Text(
                        'TO DISTRIBUTE (বিতরণ করতে হবে)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Color(0xFFFACC15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final item in toDistributeToday)
                    _buildItemCard(
                      item: item,
                      canToggle: true,
                      onToggle: (val) => _handleToggle(item, val),
                    ),
                  const SizedBox(height: 14),
                ],

                // Sub-heading 2: ✅ Distributed Today (Strikethrough)
                if (distributedToday.isNotEmpty) ...[
                  Row(
                    children: const [
                      Icon(Icons.check_circle_rounded,
                          size: 15, color: Color(0xFF34D399)),
                      SizedBox(width: 6),
                      Text(
                        'DISTRIBUTED TODAY (আজ বিতরণ হয়েছে)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Color(0xFF34D399),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final item in distributedToday)
                    _buildItemCard(
                      item: item,
                      canToggle: true,
                      isStrikethrough: true,
                      onToggle: (val) => _handleToggle(item, val),
                    ),
                  const SizedBox(height: 14),
                ],

                if (toDistributeToday.isEmpty && distributedToday.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'আজকের জন্য নতুন কোনো বিতরণ বাকি নেই',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ==========================================
                // 2. PAST DISTRIBUTION DATES (HISTORY)
                // ==========================================
                for (final pastDate in sortedPastDates) ...[
                  const SizedBox(height: 10),
                  _buildDateHeaderBox(
                    dateText: _formatDate(pastDate),
                    isToday: false,
                  ),
                  const SizedBox(height: 8),
                  for (final item in pastGrouped[pastDate]!) ...[
                    // Calculate days difference
                    Builder(builder: (ctx) {
                      final daysAgo = todayStart.difference(pastDate).inDays;
                      final isWithin2Days = daysAgo <= 2;

                      return _buildItemCard(
                        item: item,
                        canToggle: isWithin2Days,
                        isLocked: !isWithin2Days,
                        isStrikethrough: true,
                        onToggle: isWithin2Days
                            ? (val) => _handleToggle(item, val)
                            : null,
                      );
                    }),
                  ],
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),

          // Bottom Actions
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: Color(0xFF090D14),
              border: Border(
                top: BorderSide(color: Color(0xFF1E293B), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _handleShopGone,
                    icon: const Icon(Icons.delete_forever_outlined, size: 18),
                    label: const Text(
                      'দোকান নেই',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFACC15),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _handleCompleteHandover,
                    icon: const Icon(Icons.check_circle_rounded,
                        size: 18, color: Colors.black),
                    label: const Text(
                      'বিতরণ সম্পন্ন করুন',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds clean date header box (like user's sketch [1/2/27], [31/1/27])
  Widget _buildDateHeaderBox({
    required String dateText,
    required bool isToday,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isToday
            ? const Color(0xFF1E293B)
            : const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isToday ? const Color(0xFFFACC15) : const Color(0xFF334155),
          width: isToday ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: isToday ? const Color(0xFFFACC15) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 8),
              Text(
                dateText,
                style: TextStyle(
                  color: isToday ? Colors.white : const Color(0xFFE2E8F0),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: isToday
                  ? const Color(0xFFFACC15).withValues(alpha: 0.2)
                  : const Color(0xFF334155).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isToday ? "TODAY'S DATE" : 'DISTRIBUTION DATE',
              style: TextStyle(
                color: isToday ? const Color(0xFFFACC15) : const Color(0xFF94A3B8),
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds individual item card with toggle switch or locked badge
  Widget _buildItemCard({
    required DistributionDisplayItem item,
    required bool canToggle,
    bool isLocked = false,
    bool isStrikethrough = false,
    ValueChanged<bool>? onToggle,
  }) {
    final isAd = item.type == DistributionItemType.adCampaign;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isStrikethrough
            ? const Color(0xFF131D31)
            : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isStrikethrough
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : const Color(0xFF334155),
        ),
      ),
      child: Row(
        children: [
          // Left Icon or Ad Printout Image Thumbnail
          if (isAd && item.imageUrl != null)
            GestureDetector(
              onTap: () => _showImagePreviewDialog(
                context,
                item.imageUrl!,
                item.name,
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: Colors.black26,
                      child: Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.campaign_rounded,
                          color: Color(0xFF38BDF8),
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.zoom_in,
                          color: Colors.white, size: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isStrikethrough
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : const Color(0xFF38BDF8).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isAd ? Icons.campaign_rounded : Icons.inventory_2_outlined,
                color: isStrikethrough
                    ? const Color(0xFF34D399)
                    : const Color(0xFF38BDF8),
                size: 20,
              ),
            ),
          const SizedBox(width: 12),

          // Name and Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isStrikethrough
                        ? const Color(0xFF94A3B8)
                        : Colors.white,
                    decoration: isStrikethrough
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: const Color(0xFF94A3B8),
                    decorationThickness: 2,
                  ),
                ),
                if (isAd && item.placementSide != null) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: item.placementSide == 'left'
                          ? Colors.blue.withValues(alpha: 0.2)
                          : Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${item.placementSide!.toUpperCase()} STAND STICKER',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: item.placementSide == 'left'
                            ? const Color(0xFF60A5FA)
                            : const Color(0xFFFDBA74),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right: Toggle Switch OR Locked Badge
          if (canToggle)
            Switch.adaptive(
              value: item.isDistributed,
              activeThumbColor: const Color(0xFF10B981),
              activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.4),
              inactiveThumbColor: const Color(0xFF94A3B8),
              inactiveTrackColor: const Color(0xFF334155),
              onChanged: onToggle,
            )
          else if (isLocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle_rounded,
                      size: 13, color: Color(0xFF34D399)),
                  SizedBox(width: 4),
                  Text(
                    'ডেলিভার্ড (লক)',
                    style: TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 10.5,
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
