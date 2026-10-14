import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payment_features/payment_features.dart';
import 'map/widgets/shop_distribution_handover_sheet.dart';

class QrScreen extends ConsumerStatefulWidget {
  const QrScreen({super.key});

  @override
  ConsumerState<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends ConsumerState<QrScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _scannedData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _openShopHandover(String code) {
    final shopId = CanonicalZones.parseShopIdFromDistributionQr(code);
    final shop = CanonicalShops.getShopById(shopId ?? '') ??
        CanonicalShops.getShopByCode(code) ??
        CanonicalShops.getShopById('shop-102') ??
        CanonicalShops.all.firstOrNull;

    if (shop != null) {
      ShopDistributionHandoverSheet.show(
        context,
        shop: shop,
        onSubmitted: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${shop.shopName} এ বিতরণ সফলভাবে সংরক্ষিত হয়েছে!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        },
        onMarkGone: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${shop.shopName} দোকান নেই হিসেবে চিহ্নিত হয়েছে।'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final theme = Theme.of(context);
    const sampleQrData = 'PAYACK_EMP_TOKEN_8921bc44';

    return AppScaffold(
      title: AppStrings.get('qr_features', lang: lang),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            tabs: [
              Tab(
                icon: const Icon(Icons.camera_alt_outlined),
                text: AppStrings.get('qr_scanner', lang: lang),
              ),
              Tab(
                icon: const Icon(Icons.qr_code_rounded),
                text: AppStrings.get('qr_generator', lang: lang),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Expanded(
                        child: QrScannerView(
                          onScanned: (code) {
                            setState(() {
                              _scannedData = code;
                            });
                            _openShopHandover(code);
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Quick Test Button for Instant Testing
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F2A43),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _openShopHandover('shop-102'),
                        icon: const Icon(Icons.inventory_2_rounded, size: 18, color: Color(0xFFFACC15)),
                        label: const Text(
                          '🛍️ ডিস্ট্রিবিউশন লিস্ট খুলুন (Test Sharma Store / 102)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      if (_scannedData != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppCard(
                          backgroundColor: theme.colorScheme.primaryContainer.withAlpha(90),
                          child: Text(
                            'Scanned Shop Screen: $_scannedData',
                            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      QrGeneratorView(
                        data: sampleQrData,
                        title: 'Employee Verification Token',
                        subtitle: 'Present to shopkeeper to pair display screen',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
