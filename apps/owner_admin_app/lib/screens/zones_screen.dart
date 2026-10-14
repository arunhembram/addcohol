import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_data_provider.dart';
import '../config/translations.dart';
import '../theme/app_theme.dart';
import '../models/zone_model.dart';
import '../widgets/status_badge.dart';

class ZonesScreen extends StatefulWidget {
  const ZonesScreen({super.key});

  @override
  State<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends State<ZonesScreen> {
  void _showCreateZoneDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final boundaryCtrl = TextEditingController();
    final dataProvider = Provider.of<AdminDataProvider>(context, listen: false);
    final locale = Provider.of<AppLocaleProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(locale.t('btn_add_zone'), style: const TextStyle(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                locale.isBengali ? 'জোনের নাম' : 'Zone Name',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Mirpur Zone A / মিরপুর জোন এ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                locale.isBengali ? 'বিবরণ' : 'Description',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. Commercial Area & Markets',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                locale.isBengali
                    ? 'ম্যাপ বাউন্ডারি (GeoJSON Polygon, ঐচ্ছিক)'
                    : 'Map Boundary (GeoJSON Polygon, optional)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: boundaryCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '{"type":"Polygon","coordinates":[[[90.35,23.79],[90.38,23.79]...]]}',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintStyle: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(locale.t('btn_cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await dataProvider.addZone(
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim(),
                boundaryGeojson: boundaryCtrl.text.trim().isNotEmpty
                    ? boundaryCtrl.text.trim()
                    : null,
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
    );
  }

  void _showAssignEmployeeDialog(BuildContext context, ZoneModel zone) {
    final dataProvider = Provider.of<AdminDataProvider>(context, listen: false);
    final locale = Provider.of<AppLocaleProvider>(context, listen: false);
    final empCtrl = TextEditingController(text: 'usr-emp-01');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${locale.t("btn_assign_employee")} (${zone.name})',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                locale.isBengali ? 'মাঠকর্মী নির্বাচন করুন' : 'Select Field Employee',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: 'usr-emp-01',
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'usr-emp-01', child: Text('Tariqul Islam (01711000002)')),
                  DropdownMenuItem(value: 'usr-emp-02', child: Text('Kamal Hossain (01711000003)')),
                ],
                onChanged: (val) {
                  if (val != null) empCtrl.text = val;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(locale.t('btn_cancel'))),
          ElevatedButton(
            onPressed: () async {
              await dataProvider.assignEmployee(zoneId: zone.id, employeeUserId: empCtrl.text);
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<AdminDataProvider>(context);
    final locale = Provider.of<AppLocaleProvider>(context);
    final zones = dataProvider.zones;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locale.t('nav_zones'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locale.isBengali
                        ? 'সকল জোন, নির্ধারিত মাঠকর্মী এবং কোম্পানি ক্যাম্পেইন পরিচালনা করুন'
                        : 'Manage Zones, assigned Field Employees, and Company Campaigns',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateZoneDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(locale.t('btn_add_zone')),
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

          // Zones Grid
          if (zones.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Text(locale.isBengali ? 'কোনো জোন পাওয়া যায়নি।' : 'No zones found.'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: zones.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 16),
              itemBuilder: (ctx, i) {
                final z = zones[i];
                final summary = z.summary;
                final activeCompany = summary?.activeCompany;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.location_city_rounded,
                                color: AppTheme.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        z.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      StatusBadge(status: z.status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    z.description ?? '',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'assign_emp') {
                                  _showAssignEmployeeDialog(context, z);
                                } else if (val == 'archive') {
                                  dataProvider.archiveZone(z.id);
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'assign_emp',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_add_alt_1_rounded, size: 18),
                                      const SizedBox(width: 8),
                                      Text(locale.t('btn_assign_employee')),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'archive',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.archive_outlined,
                                        size: 18,
                                        color: AppTheme.statusRed,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        locale.t('btn_archive'),
                                        style: const TextStyle(color: AppTheme.statusRed),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),

                        // Summary Statistics Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildZoneMetric(
                                locale.isBengali ? 'মোট দোকান' : 'Total Shops',
                                '${summary?.totalShops ?? 0}',
                                Icons.storefront_outlined,
                              ),
                            ),
                            Expanded(
                              child: _buildZoneMetric(
                                locale.isBengali ? 'আজকে আপলোড' : 'Today Uploads',
                                '${summary?.todayUploadsCount ?? 0} (${summary?.compliancePercentage ?? 0}%)',
                                Icons.cloud_done_outlined,
                              ),
                            ),
                            Expanded(
                              child: _buildZoneMetric(
                                locale.isBengali ? 'বরাদ্দকৃত কোম্পানি' : 'Assigned Company',
                                activeCompany != null
                                    ? activeCompany['company_name']
                                    : (locale.isBengali ? 'কোনোটি নয়' : 'None'),
                                Icons.business_outlined,
                                subtitle: activeCompany != null
                                    ? activeCompany['campaign_name']
                                    : null,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    locale.isBengali ? 'নির্ধারিত মাঠকর্মী' : 'Assigned Employees',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (summary?.assignedEmployees == null ||
                                      summary!.assignedEmployees.isEmpty)
                                    Text(
                                      locale.isBengali ? 'কেউ বরাদ্দ নেই' : 'No employee assigned',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 6,
                                      children: summary.assignedEmployees.map<Widget>((ea) {
                                        return Chip(
                                          label: Text(
                                            ea['full_name'] ?? '',
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildZoneMetric(String label, String value, IconData icon, {String? subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
