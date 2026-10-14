import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_data_provider.dart';
import '../config/translations.dart';
import '../theme/app_theme.dart';
import '../models/company_model.dart';
import '../services/api_service.dart';

class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  void _showAddCompanyDialog(BuildContext context) {
    final dataProvider = Provider.of<AdminDataProvider>(context, listen: false);
    final locale = Provider.of<AppLocaleProvider>(context, listen: false);

    final nameCtrl = TextEditingController();
    final personCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          locale.t('btn_add_company'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                locale.isBengali ? 'কোম্পানির নাম' : 'Company Name',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. PRAN-RFL Group / প্রাণ আরএফএল',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                locale.isBengali ? 'যোগাযোগকারী ব্যক্তি' : 'Contact Person',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: personCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Sarah Khan',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                locale.isBengali ? 'ফোন নম্বর' : 'Phone Number',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. 01911000001',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                locale.isBengali ? 'ইমেইল' : 'Email Address',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. sarah@pran.com',
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
              if (nameCtrl.text.trim().isEmpty) return;
              await dataProvider.addCompany(
                name: nameCtrl.text.trim(),
                contactPersonName: personCtrl.text.trim(),
                contactPhone: phoneCtrl.text.trim(),
                contactEmail: emailCtrl.text.trim(),
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

  void _showAddUserDialog(BuildContext context, CompanyModel company) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final dataProvider = Provider.of<AdminDataProvider>(context, listen: false);
    final locale = Provider.of<AppLocaleProvider>(context, listen: false);

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'CompanyPass123!');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${locale.isBengali ? "কোম্পানি ব্যবহারকারী তৈরি করুন" : "Add Company User"} (${company.name})',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                locale.isBengali ? 'পূর্ণ নাম' : 'Full Name',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Sarah Khan',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                locale.isBengali ? 'ফোন নম্বর' : 'Phone Number',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. 01911000001',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                locale.isBengali ? 'ইমেইল' : 'Email',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. sarah@pran.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                locale.isBengali ? 'পাসওয়ার্ড' : 'Password',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: passCtrl,
                decoration: InputDecoration(
                  hintText: '••••••••',
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
              if (nameCtrl.text.trim().isEmpty ||
                  phoneCtrl.text.trim().isEmpty ||
                  passCtrl.text.trim().isEmpty)
                return;
              try {
                await apiService.createCompanyUser(
                  companyId: company.id,
                  fullName: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                  password: passCtrl.text.trim(),
                );
                await dataProvider.fetchAll(silent: true);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<AdminDataProvider>(context);
    final locale = Provider.of<AppLocaleProvider>(context);
    final companies = dataProvider.companies;

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
                    locale.t('nav_companies'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locale.isBengali
                        ? 'ক্লায়েন্ট কোম্পানি এবং কোম্পানি ইউজার অ্যাকাউন্ট পরিচালনা করুন'
                        : 'Manage Client Companies and Company User Accounts',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddCompanyDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(locale.t('btn_add_company')),
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

          // Companies List
          if (companies.isEmpty)
            Center(
              child: Text(locale.isBengali ? 'কোনো কোম্পানি পাওয়া যায়নি।' : 'No companies found.'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: companies.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 16),
              itemBuilder: (ctx, i) {
                final c = companies[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.business_rounded,
                                color: AppTheme.accent,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${c.contactPersonName ?? ""} • ${c.contactPhone ?? ""} • ${c.contactEmail ?? ""}',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showAddUserDialog(context, c),
                              icon: const Icon(Icons.person_add_outlined, size: 16),
                              label: Text(locale.isBengali ? 'ব্যবহারকারী যোগ করুন' : 'Add User'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 10),

                        // Users and Assignments Count
                        Row(
                          children: [
                            Text(
                              '${locale.isBengali ? "সক্রিয় জোন বরাদ্দ" : "Active Assigned Zones"}: ${c.activeZonesCount}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            const SizedBox(width: 20),
                            Text(
                              '${locale.isBengali ? "ব্যবহারকারী একাউন্ট" : "User Accounts"}: ${c.users.length}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ],
                        ),
                        if (c.users.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: c.users.map<Widget>((u) {
                              return Chip(
                                avatar: const Icon(Icons.account_circle, size: 16),
                                label: Text(
                                  '${u['full_name']} (${u['email'] ?? u['phone']})',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                              );
                            }).toList(),
                          ),
                        ],
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
}
