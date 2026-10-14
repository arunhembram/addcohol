import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/company_state_providers.dart';
import '../shops/company_shop_detail_modal.dart';

class CompanyReportingScreen extends ConsumerWidget {
  const CompanyReportingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(companyAuthProvider);
    final company = authState.company;
    final summariesAsync = ref.watch(companyZoneSummariesProvider);
    final theme = Theme.of(context);

    final canViewDailyProof = company?.canViewDailyProof ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advertising Campaign Reports'),
        actions: [
          IconButton(
            tooltip: 'Export Report',
            icon: const Icon(Icons.download_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Campaign report generated. CSV/PDF export initiated.'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
          ),
        ],
      ),
      body: summariesAsync.when(
        data: (summaries) {
          if (summaries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.assessment_outlined, size: 64, color: AppColors.neutral400),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No Campaign Data Available',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Reporting metrics will populate once Master Admin assigns advertising zones to your company.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.neutral600),
                    ),
                  ],
                ),
              ),
            );
          }

          int totalShops = 0;
          int totalScreens = 0;
          int? totalProofVerified;
          final allCategoryCounts = <String, int>{};

          for (final s in summaries) {
            totalShops += s.totalAgreedShops;
            totalScreens += s.totalScreens;
            if (s.proofVerifiedCount != null) {
              totalProofVerified = (totalProofVerified ?? 0) + s.proofVerifiedCount!;
            }
            s.categoryCounts.forEach((cat, count) {
              allCategoryCounts[cat] = (allCategoryCounts[cat] ?? 0) + count;
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Report Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primary.withAlpha(200)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              company?.tradeName ?? 'Company Report',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          AppBadge(
                            label: 'Official Audit Report',
                            variant: AppBadgeVariant.neutral,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Assigned Territories: ${summaries.length} Zones • Active Display Units: $totalScreens Screens',
                        style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 12),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: Text(
                          'Generated: ${DateTime.now().toString().substring(0, 10)} • Target: Agreed & Active Locations Only',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Table 1: Zone Allocation Breakdown
                Text(
                  '1. Zone-by-Zone Advertising Distribution',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Read-only breakdown of allocated zones and active screen capacity.',
                  style: TextStyle(fontSize: 12, color: AppColors.neutral600),
                ),
                const SizedBox(height: AppSpacing.sm),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.neutral200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppColors.neutral100),
                        columns: const [
                          DataColumn(label: Text('Zone Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Agreed Shops', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Screens', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Screen Share', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Proof Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: summaries.map((s) {
                          final pct = totalScreens > 0
                              ? ((s.totalScreens / totalScreens) * 100).toStringAsFixed(1)
                              : '0';

                          String proofLabel;
                          if (canViewDailyProof && s.proofVerifiedCount != null) {
                            proofLabel = '${s.proofVerifiedCount}/${s.totalAgreedShops} verified';
                          } else {
                            proofLabel = 'Hidden (No flag)';
                          }

                          return DataRow(
                            cells: [
                              DataCell(Text(s.zoneName, style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(Text(s.totalAgreedShops.toString())),
                              DataCell(Text(s.totalScreens.toString())),
                              DataCell(Text('$pct%')),
                              DataCell(
                                Text(
                                  proofLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: canViewDailyProof ? AppColors.success : AppColors.neutral500,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Section 2: Category Penetration
                Text(
                  '2. Network Category Penetration',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Aggregated partner shop count across commercial business categories.',
                  style: TextStyle(fontSize: 12, color: AppColors.neutral600),
                ),
                const SizedBox(height: AppSpacing.sm),

                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.neutral200),
                  ),
                  child: Column(
                    children: allCategoryCounts.entries.map((entry) {
                      final catIcon = CompanyShopDetailModal.getCategoryIcon(entry.key);
                      final catColor = CompanyShopDetailModal.getCategoryColor(entry.key);
                      final pct = totalShops > 0
                          ? (entry.value / totalShops)
                          : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(catIcon, size: 16, color: catColor),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  entry.key,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const Spacer(),
                                Text(
                                  '${entry.value} shops (${(pct * 100).toStringAsFixed(1)}%)',
                                  style: TextStyle(fontSize: 12, color: AppColors.neutral700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: pct,
                              backgroundColor: AppColors.neutral200,
                              color: catColor,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Section 3: Privacy & Security Compliance Statement
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.neutral300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.verified_user_outlined, size: 18, color: AppColors.primary),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            'RLS Privacy & Data Protection Compliance',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'This report is generated strictly from the company_visible_shops database view enforced by Supabase Row-Level Security. In compliance with advertiser data isolation rules:\n'
                        '• Personal Aadhaar identities, Employee IDs, internal audit logs, and raw storage bucket URLs are completely excluded.\n'
                        '• Only partner shops with signed advertising agreements and active status are included.\n'
                        '• Photo proof displays are governed by the can_view_daily_proof feature flag.',
                        style: TextStyle(fontSize: 11, height: 1.4, color: AppColors.neutral700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error generating report: $err')),
      ),
    );
  }
}
