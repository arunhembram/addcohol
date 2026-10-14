import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payment_features/payment_features.dart';

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

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final theme = Theme.of(context);
    final shopkeeperQr = 'PAYACK_SAMPLE_7f8a9b2c3d4e';

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
                icon: const Icon(Icons.qr_code_rounded),
                text: AppStrings.get('qr_generator', lang: lang),
              ),
              Tab(
                icon: const Icon(Icons.camera_alt_outlined),
                text: AppStrings.get('qr_scanner', lang: lang),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      QrGeneratorView(
                        data: shopkeeperQr,
                        title: 'Shop Settlement QR Code',
                        subtitle:
                            'Display to advertiser or field employee to confirm impression payout',
                      ),
                    ],
                  ),
                ),
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
                          },
                        ),
                      ),
                      if (_scannedData != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppCard(
                          backgroundColor: theme.colorScheme.primaryContainer.withAlpha(90),
                          child: Text(
                            'Scanned Screen QR: $_scannedData',
                            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                          ),
                        ),
                      ],
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
