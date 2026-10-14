import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/company_state_providers.dart';
import '../shops/company_shop_detail_modal.dart';

class CompanyZoneSummaryScreen extends ConsumerWidget {
  const CompanyZoneSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(companyAuthProvider);
    final company = authState.company;
    final summariesAsync = ref.watch(companyZoneSummariesProvider);
    final theme = Theme.of(context);

    final canViewDailyProof = company?.canViewDailyProof ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zone Advertising Summary'),
        actions: [
          IconButton(
            tooltip: 'Refresh Summaries',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(companyZoneSummariesProvider);
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
                    const Icon(Icons.analytics_outlined, size: 64, color: AppColors.neutral400),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No Zone Summaries Available',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Your company account currently has no assigned zones.',
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

          for (final s in summaries) {
            totalShops += s.totalAgreedShops;
            totalScreens += s.totalScreens;
            if (s.proofVerifiedCount != null) {
              totalProofVerified = (totalProofVerified ?? 0) + s.proofVerifiedCount!;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Metric Cards Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 600;
                    return Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        SizedBox(
                          width: isWide ? (constraints.maxWidth - AppSpacing.md) / 2 : double.infinity,
                          child: _buildMetricCard(
                            icon: Icons.layers_rounded,
                            iconColor: AppColors.primary,
                            title: 'Assigned Zones',
                            value: summaries.length.toString(),
                            subtitle: 'Territories assigned by Master Admin',
                          ),
                        ),
                        SizedBox(
                          width: isWide ? (constraints.maxWidth - AppSpacing.md) / 2 : double.infinity,
                          child: _buildMetricCard(
                            icon: Icons.storefront_rounded,
                            iconColor: AppColors.success,
                            title: 'Active Agreed Shops',
                            value: totalShops.toString(),
                            subtitle: 'Strictly active partner locations',
                          ),
                        ),
                        SizedBox(
                          width: isWide ? (constraints.maxWidth - AppSpacing.md) / 2 : double.infinity,
                          child: _buildMetricCard(
                            icon: Icons.tv_rounded,
                            iconColor: Colors.deepPurple,
                            title: 'Total Advertising Screens',
                            value: totalScreens.toString(),
                            subtitle: 'Installed digital display units',
                          ),
                        ),
                        SizedBox(
                          width: isWide ? (constraints.maxWidth - AppSpacing.md) / 2 : double.infinity,
                          child: _buildMetricCard(
                            icon: canViewDailyProof ? Icons.verified_rounded : Icons.lock_outline_rounded,
                            iconColor: canViewDailyProof ? AppColors.info : AppColors.neutral500,
                            title: 'Daily Photo Proof Status',
                            value: canViewDailyProof
                                ? '$totalProofVerified / $totalShops Verified'
                                : 'Hidden by Default',
                            subtitle: canViewDailyProof
                                ? 'Today\'s active ad verification'
                                : 'Requires flag: can_view_daily_proof',
                            badge: canViewDailyProof
                                ? AppBadge(label: 'Feature Active', variant: AppBadgeVariant.success)
                                : AppBadge(label: 'Pending Flag', variant: AppBadgeVariant.warning),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                // Section Header
                Row(
                  children: [
                    const Icon(Icons.pie_chart_outline_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Assigned Zone Breakdown & Category Counts',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Individual Zone Breakdown Cards
                ...summaries.map((summary) => _buildZoneSummaryCard(context, summary, canViewDailyProof)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading summaries: $err')),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    Widget? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.neutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              ?badge,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral800,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.neutral600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneSummaryCard(
    BuildContext context,
    dynamic summary,
    bool canViewDailyProof,
  ) {
    final theme = Theme.of(context);
    final categoryCounts = summary.categoryCounts as Map<String, int>;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zone Title Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_city_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      summary.zoneName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                AppBadge(
                  label: '${summary.totalAgreedShops} Agreed Shops',
                  variant: AppBadgeVariant.success,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text(
                  'Installed Screens: ',
                  style: TextStyle(fontSize: 12, color: AppColors.neutral600),
                ),
                Text(
                  '${summary.totalScreens} Screens',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: AppSpacing.md),
                if (canViewDailyProof && summary.proofVerifiedCount != null)
                  Text(
                    'Daily Proofs: ${summary.proofVerifiedCount} / ${summary.totalAgreedShops}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  )
                else
                  Text(
                    'Proof: Hidden by Default',
                    style: TextStyle(fontSize: 11, color: AppColors.neutral500),
                  ),
              ],
            ),
            const Divider(height: 20),

            // Category Counts Breakdown
            Text(
              'Category Distribution in Zone:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.neutral700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            if (categoryCounts.isEmpty)
              const Text(
                'No shops categorized in this zone yet.',
                style: TextStyle(fontSize: 12, color: AppColors.neutral500),
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: categoryCounts.entries.map((entry) {
                  final catIcon = CompanyShopDetailModal.getCategoryIcon(entry.key);
                  final catColor = CompanyShopDetailModal.getCategoryColor(entry.key);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: catColor.withAlpha(15),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(color: catColor.withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(catIcon, size: 14, color: catColor),
                        const SizedBox(width: 4),
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: catColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: catColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            entry.value.toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                ),
                onPressed: () {
                  context.push('/book-ad-space?zoneId=${summary.zoneId}');
                },
                icon: const Icon(Icons.touch_app_rounded, size: 16),
                label: const Text(
                  'Book Ad Space',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
