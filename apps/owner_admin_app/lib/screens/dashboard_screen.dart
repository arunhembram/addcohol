import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_data_provider.dart';
import '../config/translations.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<AdminDataProvider>(context);
    final locale = Provider.of<AppLocaleProvider>(context);
    final kpis = dataProvider.kpis?['kpis'] ?? {};
    final zoneCompliance = (dataProvider.kpis?['zone_compliance'] as List?) ?? [];
    final employeeTasks = (dataProvider.kpis?['employee_tasks'] as List?) ?? [];

    if (dataProvider.isLoading && dataProvider.kpis == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Notice about Midnight Expiry
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF16A34A), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    locale.t('msg_timezone_notice'),
                    style: const TextStyle(
                      color: Color(0xFF166534),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => onNavigate(9), // Settings
                  child: Text(locale.isBengali ? 'কনফিগারেশন' : 'Configure'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Top KPIs Grid
          Text(
            locale.isBengali ? 'আজকের সার্বিক পরিস্থিতি' : 'Today’s High-Level Overview',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),

          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1100
                  ? 4
                  : (constraints.maxWidth > 700 ? 2 : 1);
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 2.1,
                children: [
                  StatCard(
                    title: locale.t('kpi_total_zones'),
                    value: (kpis['total_active_zones'] ?? 0).toString(),
                    icon: Icons.layers_rounded,
                    iconColor: AppTheme.primary,
                    iconBgColor: AppTheme.primary.withOpacity(0.1),
                  ),
                  StatCard(
                    title: locale.t('kpi_total_shops'),
                    value: (kpis['total_active_shops'] ?? 0).toString(),
                    icon: Icons.storefront_rounded,
                    iconColor: AppTheme.accent,
                    iconBgColor: AppTheme.accent.withOpacity(0.1),
                  ),
                  StatCard(
                    title: locale.t('kpi_uploaded_today'),
                    value: (kpis['uploaded_today'] ?? 0).toString(),
                    icon: Icons.cloud_done_rounded,
                    iconColor: AppTheme.statusGreen,
                    iconBgColor: AppTheme.statusGreenLight,
                    subtitle:
                        '${kpis['verified_today'] ?? 0} ${locale.isBengali ? "অনুমোদিত" : "Verified"}',
                  ),
                  StatCard(
                    title: locale.t('kpi_not_uploaded_today'),
                    value: (kpis['not_uploaded_today'] ?? 0).toString(),
                    icon: Icons.pending_actions_rounded,
                    iconColor: AppTheme.statusYellow,
                    iconBgColor: AppTheme.statusYellowLight,
                  ),
                  StatCard(
                    title: locale.t('kpi_rejected_today'),
                    value: (kpis['rejected_today'] ?? 0).toString(),
                    icon: Icons.cancel_outlined,
                    iconColor: AppTheme.statusRed,
                    iconBgColor: AppTheme.statusRedLight,
                  ),
                  StatCard(
                    title: locale.t('kpi_pending_issues'),
                    value: (kpis['pending_issues'] ?? 0).toString(),
                    icon: Icons.report_problem_outlined,
                    iconColor: Colors.deepOrange,
                    iconBgColor: Colors.deepOrange.withOpacity(0.1),
                  ),
                  StatCard(
                    title: locale.t('kpi_compliance_rate'),
                    value: '${kpis['overall_compliance_percentage'] ?? 0}%',
                    icon: Icons.pie_chart_rounded,
                    iconColor: AppTheme.primaryDark,
                    iconBgColor: AppTheme.primary.withOpacity(0.15),
                  ),
                  StatCard(
                    title: locale.isBengali ? 'পর্যালোচনাধীন প্রুফ' : 'Proofs To Review',
                    value: (kpis['submitted_today'] ?? 0).toString(),
                    icon: Icons.rate_review_rounded,
                    iconColor: Colors.purple,
                    iconBgColor: Colors.purple.withOpacity(0.1),
                    subtitle: locale.isBengali ? 'ক্লিক করে রিভিউ করুন' : 'Click to review',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // Two Column Section: Zone-wise Compliance & Employee-wise Pending Tasks
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Zone-wise Compliance
              Expanded(
                flex: 3,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              locale.isBengali
                                  ? 'জোনভিত্তিক কমপ্লায়েন্স হার'
                                  : 'Zone-Wise Compliance Percentage',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            TextButton(
                              onPressed: () => onNavigate(1), // Zones
                              child: Text(locale.isBengali ? 'সকল জোন' : 'View All Zones'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (zoneCompliance.isEmpty)
                          const Center(child: Text('কোনো সক্রিয় জোন নেই'))
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: zoneCompliance.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 24),
                            itemBuilder: (ctx, i) {
                              final z = zoneCompliance[i];
                              final compliance = z['compliance_percentage'] ?? 0;
                              final total = z['total_shops'] ?? 0;
                              final verified = z['verified'] ?? 0;
                              final notUploaded = z['not_uploaded'] ?? 0;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        z['zone_name'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '$compliance%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: compliance > 60
                                              ? AppTheme.statusGreen
                                              : AppTheme.statusYellow,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(
                                    value: total > 0 ? (verified / total).clamp(0.0, 1.0) : 0.0,
                                    backgroundColor: AppTheme.border,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      compliance > 60
                                          ? AppTheme.statusGreen
                                          : AppTheme.statusYellow,
                                    ),
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${locale.isBengali ? "মোট দোকান" : "Total"}: $total • ${locale.isBengali ? "যাচাইকৃত" : "Verified"}: $verified',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        '${locale.isBengali ? "বাকি" : "Missing"}: $notUploaded',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.statusYellow,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Right: Employee-wise Pending Tasks
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale.isBengali
                              ? 'মাঠকর্মীদের অসমাপ্ত কাজ'
                              : 'Field Employee Pending Tasks',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                        if (employeeTasks.isEmpty)
                          const Center(child: Text('কোনো তথ্য পাওয়া যায়নি'))
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: employeeTasks.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 20),
                            itemBuilder: (ctx, i) {
                              final emp = employeeTasks[i];
                              final pending = emp['pending_shops_count'] ?? 0;
                              final pendingPhoneLess = emp['pending_phone_less_count'] ?? 0;

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppTheme.accent.withOpacity(0.1),
                                    child: const Icon(
                                      Icons.person_pin_rounded,
                                      color: AppTheme.accent,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          emp['employee_name'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          '${emp['assigned_zones_count']} ${locale.isBengali ? "টি জোন বরাদ্দ" : "Zones"} • ${emp['total_shops_count']} ${locale.isBengali ? "টি দোকান" : "Shops"}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: pending > 0
                                              ? AppTheme.statusYellowLight
                                              : AppTheme.statusGreenLight,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$pending ${locale.isBengali ? "বাকি" : "Pending"}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: pending > 0
                                                ? AppTheme.statusYellow
                                                : AppTheme.statusGreen,
                                          ),
                                        ),
                                      ),
                                      if (pendingPhoneLess > 0) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '$pendingPhoneLess ${locale.isBengali ? "ফোনবিহীন" : "Phone-less"}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.statusRed,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
