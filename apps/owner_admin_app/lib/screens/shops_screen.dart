import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_data_provider.dart';
import '../config/translations.dart';
import '../theme/app_theme.dart';
import '../models/shop_model.dart';
import '../widgets/status_badge.dart';
import '../widgets/category_chip.dart';
import '../widgets/shop_detail_modal.dart';

class ShopsScreen extends StatefulWidget {
  const ShopsScreen({super.key});

  @override
  State<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends State<ShopsScreen> {
  String _searchQuery = '';
  String? _selectedZoneId;
  String? _selectedCategory;

  void _showAddShopDialog(BuildContext context) {
    final dataProvider = Provider.of<AdminDataProvider>(context, listen: false);
    final locale = Provider.of<AppLocaleProvider>(context, listen: false);

    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final latCtrl = TextEditingController(text: '23.8041');
    final lonCtrl = TextEditingController(text: '90.3687');
    final phoneCtrl = TextEditingController();

    String selectedCategory = 'tea_stall';
    String selectedZoneId = dataProvider.zones.isNotEmpty ? dataProvider.zones.first.id : '';
    String selectedUploadMode = 'both';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isPhoneEmpty = phoneCtrl.text.trim().isEmpty;
          // Rule: If phone is empty, must be employee_managed_upload
          if (isPhoneEmpty && selectedUploadMode != 'employee_managed_upload') {
            selectedUploadMode = 'employee_managed_upload';
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              locale.t('btn_add_shop'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              locale.isBengali
                                  ? 'অনন্য ৮-ডিজিটের দোকান কোড (Shop Code) সার্ভার স্বয়ংক্রিয়ভাবে তৈরি করবে।'
                                  : 'A unique 8-digit immutable Shop Code will be auto-generated upon saving.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Shop Name
                    Text(
                      locale.isBengali ? 'দোকানের নাম' : 'Shop Name',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. চা ও কফি কর্নার / Fresh Corner',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category & Zone Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                locale.isBengali ? 'ক্যাটেগরি' : 'Category',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: selectedCategory,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'tea_stall',
                                    child: Text(locale.t('cat_tea_stall')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'food_stall',
                                    child: Text(locale.t('cat_food_stall')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'vegetable_shop',
                                    child: Text(locale.t('cat_vegetable_shop')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'fish_shop',
                                    child: Text(locale.t('cat_fish_shop')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'grocery_shop',
                                    child: Text(locale.t('cat_grocery_shop')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'pharmacy',
                                    child: Text(locale.t('cat_pharmacy')),
                                  ),
                                  DropdownMenuItem(
                                    value: 'other',
                                    child: Text(locale.t('cat_other')),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) setModalState(() => selectedCategory = val);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                locale.isBengali ? 'জোন' : 'Zone',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: selectedZoneId.isNotEmpty ? selectedZoneId : null,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                items: dataProvider.zones
                                    .map((z) => DropdownMenuItem(value: z.id, child: Text(z.name)))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setModalState(() => selectedZoneId = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Address
                    Text(
                      locale.isBengali ? 'ঠিকানা' : 'Address',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: addressCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Road 12, Mirpur 1, Dhaka',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // GPS Latitude & Longitude
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Latitude (GPS)',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: latCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Longitude (GPS)',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: lonCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Merchant Phone
                    Text(
                      locale.isBengali
                          ? 'মার্চেন্ট ফোন নম্বর (ঐচ্ছিক)'
                          : 'Merchant Phone (Optional)',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneCtrl,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: 'e.g. 01811000001 (যদি ফোন না থাকে খালি রাখুন)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Upload Mode
                    Text(
                      locale.isBengali ? 'আপলোড মোড' : 'Upload Mode',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedUploadMode,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'employee_managed_upload',
                          child: Text(locale.t('mode_employee_managed_upload')),
                        ),
                        if (!isPhoneEmpty) ...[
                          DropdownMenuItem(
                            value: 'merchant_self_upload',
                            child: Text(locale.t('mode_merchant_self_upload')),
                          ),
                          DropdownMenuItem(value: 'both', child: Text(locale.t('mode_both'))),
                        ],
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedUploadMode = val);
                      },
                    ),
                    if (isPhoneEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        locale.isBengali
                            ? '* ফোনবিহীন দোকানের ক্ষেত্রে শুধুমাত্র মাঠকর্মী দ্বারা আপলোড প্রযোজ্য।'
                            : '* For phone-less shops, Employee Managed Upload is required.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(locale.t('btn_cancel'))),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty ||
                      addressCtrl.text.trim().isEmpty ||
                      selectedZoneId.isEmpty)
                    return;
                  final lat = double.tryParse(latCtrl.text.trim()) ?? 23.8041;
                  final lon = double.tryParse(lonCtrl.text.trim()) ?? 90.3687;

                  final res = await dataProvider.addShop(
                    shopName: nameCtrl.text.trim(),
                    category: selectedCategory,
                    address: addressCtrl.text.trim(),
                    latitude: lat,
                    longitude: lon,
                    zoneId: selectedZoneId,
                    merchantPhone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                    uploadMode: selectedUploadMode,
                  );

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    if (res['boundary_warning'] != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res['boundary_warning']),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(locale.t('btn_save')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMoveZoneDialog(BuildContext context, ShopModel shop) {
    final dataProvider = Provider.of<AdminDataProvider>(context, listen: false);
    final locale = Provider.of<AppLocaleProvider>(context, listen: false);
    final reasonCtrl = TextEditingController(text: 'জোন পুনর্বিন্যাস / Territory re-allocation');

    final otherZones = dataProvider.zones.where((z) => z.id != shop.zoneId).toList();
    if (otherZones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            locale.isBengali
                ? 'স্থানান্তরের জন্য অন্য কোনো জোন নেই।'
                : 'No other zones available to move to.',
          ),
        ),
      );
      return;
    }
    String targetZoneId = otherZones.first.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            '${locale.t("btn_move_zone")} (${shop.shopName})',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${locale.isBengali ? "বর্তমান জোন" : "Current Zone"}: ${shop.zoneName}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                Text(
                  locale.isBengali ? 'নতুন গন্তব্য জোন' : 'Destination Zone',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: targetZoneId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: otherZones
                      .map((z) => DropdownMenuItem(value: z.id, child: Text(z.name)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => targetZoneId = val);
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  locale.isBengali
                      ? 'স্থানান্তরের কারণ (অডিট লগে সংরক্ষিত হবে)'
                      : 'Reason (Saved in Audit Log)',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(
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
                await dataProvider.moveShopZone(
                  shopId: shop.id,
                  newZoneId: targetZoneId,
                  reason: reasonCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(locale.t('btn_save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<AdminDataProvider>(context);
    final locale = Provider.of<AppLocaleProvider>(context);

    var filteredShops = dataProvider.shops;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredShops = filteredShops
          .where(
            (s) =>
                s.shopName.toLowerCase().contains(q) ||
                s.shopCode.contains(q) ||
                s.address.toLowerCase().contains(q),
          )
          .toList();
    }
    if (_selectedZoneId != null) {
      filteredShops = filteredShops.where((s) => s.zoneId == _selectedZoneId).toList();
    }
    if (_selectedCategory != null) {
      filteredShops = filteredShops.where((s) => s.category == _selectedCategory).toList();
    }

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
                    locale.t('nav_shops'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locale.isBengali
                        ? 'অনন্য ৮-ডিজিট কোডযুক্ত দোকানসমূহ এবং দৈনিক বিজ্ঞাপন প্রমাণ তালিকা'
                        : 'Manage Shops with 8-digit unique codes and daily proof states',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddShopDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(locale.t('btn_add_shop')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Search
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 20),
                        hintText: locale.isBengali
                            ? 'দোকানের নাম বা ৮-ডিজিটের কোড দিয়ে খুঁজুন...'
                            : 'Search by name or 8-digit code...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Zone filter
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _selectedZoneId,
                      decoration: InputDecoration(
                        labelText: locale.isBengali ? 'জোন ফিল্টার' : 'Filter by Zone',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(locale.isBengali ? 'সকল জোন' : 'All Zones'),
                        ),
                        ...dataProvider.zones.map(
                          (z) => DropdownMenuItem(value: z.id, child: Text(z.name)),
                        ),
                      ],
                      onChanged: (val) => setState(() => _selectedZoneId = val),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Category filter
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: locale.isBengali ? 'ক্যাটেগরি' : 'Category',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(locale.isBengali ? 'সকল ক্যাটেগরি' : 'All Categories'),
                        ),
                        DropdownMenuItem(
                          value: 'tea_stall',
                          child: Text(locale.t('cat_tea_stall')),
                        ),
                        DropdownMenuItem(
                          value: 'food_stall',
                          child: Text(locale.t('cat_food_stall')),
                        ),
                        DropdownMenuItem(
                          value: 'vegetable_shop',
                          child: Text(locale.t('cat_vegetable_shop')),
                        ),
                        DropdownMenuItem(
                          value: 'fish_shop',
                          child: Text(locale.t('cat_fish_shop')),
                        ),
                        DropdownMenuItem(
                          value: 'grocery_shop',
                          child: Text(locale.t('cat_grocery_shop')),
                        ),
                        DropdownMenuItem(value: 'pharmacy', child: Text(locale.t('cat_pharmacy'))),
                      ],
                      onChanged: (val) => setState(() => _selectedCategory = val),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Shops Table Card
          Card(
            child: SizedBox(
              width: double.infinity,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                columns: [
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'কোড' : 'Code',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'দোকানের নাম' : 'Shop Name',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'ক্যাটেগরি' : 'Category',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'জোন' : 'Zone',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'মোড' : 'Upload Mode',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'আজকের অবস্থা' : 'Today Status',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'অ্যাকশন' : 'Actions',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                rows: filteredShops.map((s) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            s.shopCode,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        InkWell(
                          onTap: () => ShopDetailModal.show(context, s),
                          child: Text(
                            s.shopName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ),
                      ),
                      DataCell(CategoryChip(category: s.category)),
                      DataCell(Text(s.zoneName, style: const TextStyle(fontSize: 12))),
                      DataCell(
                        Text(
                          locale.t('mode_${s.uploadMode}'),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(StatusBadge(status: s.todayUploadState)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility_outlined, size: 18),
                              tooltip: locale.isBengali ? 'বিস্তারিত দেখুন' : 'View Details',
                              onPressed: () => ShopDetailModal.show(context, s),
                            ),
                            IconButton(
                              icon: const Icon(Icons.drive_file_move_outlined, size: 18),
                              tooltip: locale.t('btn_move_zone'),
                              onPressed: () => _showMoveZoneDialog(context, s),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
