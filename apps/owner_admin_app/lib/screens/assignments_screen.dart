import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_data_provider.dart';
import '../config/translations.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  void _showAssignDialog(BuildContext context) {
    final dataProvider = Provider.of<AdminDataProvider>(context, listen: false);
    final locale = Provider.of<AppLocaleProvider>(context, listen: false);

    if (dataProvider.zones.isEmpty || dataProvider.companies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            locale.isBengali
                ? 'জোন বরাদ্দ করতে কমপক্ষে ১টি জোন ও ১টি কোম্পানি থাকতে হবে।'
                : 'Requires at least 1 Zone and 1 Company.',
          ),
        ),
      );
      return;
    }

    String selectedZoneId = dataProvider.zones.first.id;
    String selectedCompanyId = dataProvider.companies.first.id;
    final campaignCtrl = TextEditingController(text: 'Summer Campaign 2026');
    final descCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
    final endCtrl = TextEditingController(
      text: DateTime.now().add(const Duration(days: 90)).toIso8601String().split('T')[0],
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            locale.t('btn_assign_zone'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.security_rounded, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            locale.isBengali
                                ? 'এক্সক্লুসিভিটি নিয়ম: একটি জোনে একসাথে শুধুমাত্র একটি কোম্পানির সক্রিয় অ্যাসাইনমেন্ট থাকতে পারে।'
                                : 'Exclusivity Rule: Only 1 Company can be actively assigned to a Zone at any given time.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Zone Selection
                  Text(
                    locale.isBengali ? 'জোন নির্বাচন করুন' : 'Select Zone',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedZoneId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: dataProvider.zones
                        .map((z) => DropdownMenuItem(value: z.id, child: Text(z.name)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedZoneId = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Company Selection
                  Text(
                    locale.isBengali ? 'কোম্পানি নির্বাচন করুন' : 'Select Company',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedCompanyId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: dataProvider.companies
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCompanyId = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Campaign Name
                  Text(
                    locale.isBengali ? 'ক্যাম্পেইনের নাম' : 'Campaign Name',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: campaignCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. PRAN Frooto Summer 2026',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Dates Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              locale.isBengali ? 'শুরুর তারিখ (YYYY-MM-DD)' : 'Start Date',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: startCtrl,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                              locale.isBengali ? 'শেষের তারিখ (YYYY-MM-DD)' : 'End Date',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: endCtrl,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(locale.t('btn_cancel'))),
            ElevatedButton(
              onPressed: () async {
                try {
                  await dataProvider.assignZoneToCompany(
                    zoneId: selectedZoneId,
                    companyId: selectedCompanyId,
                    campaignName: campaignCtrl.text.trim(),
                    campaignDescription: descCtrl.text.trim(),
                    campaignStartDate: startCtrl.text.trim(),
                    campaignEndDate: endCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: AppTheme.statusRed,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<AdminDataProvider>(context);
    final locale = Provider.of<AppLocaleProvider>(context);
    final assignments = dataProvider.assignments;

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
                    locale.t('nav_assignments'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locale.isBengali
                        ? 'সম্পূর্ণ জোনভিত্তিক কোম্পানি ক্যাম্পেইন এক্সক্লুসিভিটি এবং অ্যাক্সেস কন্ট্রোল'
                        : 'Zone-level Company Campaign Exclusivity & Access Enforcement',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAssignDialog(context),
                icon: const Icon(Icons.add_task_rounded, size: 18),
                label: Text(locale.t('btn_assign_zone')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Assignments Table Card
          Card(
            child: SizedBox(
              width: double.infinity,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                columns: [
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'জোন' : 'Zone',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'কোম্পানি' : 'Company',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'ক্যাম্পেইনের নাম' : 'Campaign Name',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'শুরু' : 'Start Date',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'শেষ' : 'End Date',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'অবস্থা' : 'Status',
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
                rows: assignments.map((a) {
                  final isActive = a.status == 'active';
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          a.zoneName ?? a.zoneId,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(
                        Text(
                          a.companyName ?? a.companyId,
                          style: const TextStyle(
                            color: AppTheme.primaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(Text(a.campaignName)),
                      DataCell(Text(a.campaignStartDate, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(a.campaignEndDate, style: const TextStyle(fontSize: 12))),
                      DataCell(StatusBadge(status: a.status)),
                      DataCell(
                        isActive
                            ? OutlinedButton(
                                onPressed: () async {
                                  await dataProvider.endAssignment(a.id);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.statusRed,
                                  side: const BorderSide(color: AppTheme.statusRed),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(locale.isBengali ? 'সমাপ্ত করুন' : 'End Campaign'),
                              )
                            : const Text('—', style: TextStyle(color: Colors.grey)),
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
