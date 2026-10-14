import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/admin_state_providers.dart';

class EmployeePerformanceScreen extends ConsumerWidget {
  const EmployeePerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performanceAsync = ref.watch(employeePerformanceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Performance Summary'),
        actions: [
          IconButton(
            tooltip: 'Refresh Performance',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(employeePerformanceProvider),
          ),
        ],
      ),
      body: performanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading performance: $err'),
        ),
        data: (summaries) {
          if (summaries.isEmpty) {
            return const Center(
              child: Text('No employee records in your controlled zones.'),
            );
          }

          // Sort by shops onboarded descending
          final sorted = List<EmployeePerformanceSummary>.from(summaries)
            ..sort((a, b) => b.shopsOnboarded.compareTo(a.shopsOnboarded));

          final totalShops = sorted.fold<int>(0, (sum, e) => sum + e.shopsOnboarded);
          final totalFollowups =
              sorted.fold<int>(0, (sum, e) => sum + e.followupsCompleted);
          final topPerformer = sorted.first;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Metrics KPI Cards
                Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                                SizedBox(width: AppSpacing.xs),
                                Text(
                                  'Top Onboarder',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              topPerformer.employeeName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${topPerformer.shopsOnboarded} shops • ⭐ ${topPerformer.performanceRating}',
                              style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.storefront, color: AppColors.primary, size: 20),
                                SizedBox(width: AppSpacing.xs),
                                Text(
                                  'Total Onboarded',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '$totalShops',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              '$totalFollowups follow-ups logged',
                              style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Performance Leaderboard Header
                Text(
                  'Employee Performance Breakdown',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Aggregated metrics from your controlled zones',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.neutral600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Employee Performance Cards
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sorted.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final emp = sorted[index];
                    final rank = index + 1;

                    return AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: rank == 1
                                      ? Colors.amber
                                      : rank == 2
                                          ? Colors.grey.shade400
                                          : rank == 3
                                              ? Colors.brown.shade300
                                              : AppColors.neutral200,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '#$rank',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          emp.employeeName,
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        AppBadge(
                                          label: 'ID: ${emp.displayId}',
                                          variant: AppBadgeVariant.neutral,
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Zones: ${emp.assignedZoneNames.join(", ")}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.neutral600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppRadii.sm),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    const SizedBox(width: 2),
                                    Text(
                                      emp.performanceRating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Visual Progress for Shops
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Shops Onboarded: ${emp.shopsOnboarded}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${emp.followupsCompleted} follow-ups done',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.neutral600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: totalShops > 0
                                          ? (emp.shopsOnboarded / totalShops).clamp(0.05, 1.0)
                                          : 0.0,
                                      backgroundColor: AppColors.neutral200,
                                      color: AppColors.primary,
                                      minHeight: 6,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
