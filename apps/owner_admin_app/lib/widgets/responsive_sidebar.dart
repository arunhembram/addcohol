import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/translations.dart';
import '../theme/app_theme.dart';
import '../providers/admin_data_provider.dart';

class ResponsiveSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const ResponsiveSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<AppLocaleProvider>(context);
    final dataProvider = Provider.of<AdminDataProvider>(context);
    final submittedUploadsCount = dataProvider.todayUploads
        .where((u) => u.status == 'submitted')
        .length;
    final openIssuesCount = dataProvider.issues.where((i) => i.status == 'open').length;

    final navItems = [
      {'icon': Icons.dashboard_rounded, 'label': locale.t('nav_dashboard'), 'badge': null},
      {'icon': Icons.layers_rounded, 'label': locale.t('nav_zones'), 'badge': null},
      {'icon': Icons.storefront_rounded, 'label': locale.t('nav_shops'), 'badge': null},
      {'icon': Icons.business_rounded, 'label': locale.t('nav_companies'), 'badge': null},
      {
        'icon': Icons.assignment_turned_in_rounded,
        'label': locale.t('nav_assignments'),
        'badge': null,
      },
      {'icon': Icons.map_rounded, 'label': locale.t('nav_live_map'), 'badge': null},
      {
        'icon': Icons.rate_review_rounded,
        'label': locale.t('nav_upload_review'),
        'badge': submittedUploadsCount > 0 ? submittedUploadsCount.toString() : null,
      },
      {
        'icon': Icons.report_problem_rounded,
        'label': locale.t('nav_issues'),
        'badge': openIssuesCount > 0 ? openIssuesCount.toString() : null,
      },
      {'icon': Icons.history_rounded, 'label': locale.t('nav_audit_logs'), 'badge': null},
      {'icon': Icons.settings_rounded, 'label': locale.t('nav_settings'), 'badge': null},
    ];

    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Column(
        children: [
          // Logo & Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified_outlined, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AdProof',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        locale.isBengali ? 'ওনার অ্যাডমিন' : 'Owner Admin',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Navigation List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = selectedIndex == index;
                final badge = item['badge'] as String?;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: isSelected ? AppTheme.primary.withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => onDestinationSelected(index),
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: AppTheme.primary.withOpacity(0.04),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              item['icon'] as IconData,
                              size: 20,
                              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item['label'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (badge != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.statusRed,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  badge,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Footer: Timezone info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Timezone: Asia/Dhaka\nMidnight Reset: 00:00',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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
