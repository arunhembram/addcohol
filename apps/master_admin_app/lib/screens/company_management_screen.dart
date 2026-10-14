import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/master_admin_providers.dart';

class CompanyManagementScreen extends ConsumerWidget {
  const CompanyManagementScreen({super.key});

  Future<void> _showAddCompanyDialog(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final legalNameCtrl = TextEditingController();
    final tradeNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register Company / নতুন কোম্পানি নথিভুক্তকরণ'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: legalNameCtrl,
                  decoration: const InputDecoration(labelText: 'Legal Entity Name *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: tradeNameCtrl,
                  decoration: const InputDecoration(labelText: 'Trade / Brand Name *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Contact Email *'),
                  validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                ),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Contact Phone'),
                ),
                TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Registered Office Address'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);

              final repo = ref.read(masterAdminRepositoryProvider);
              await repo.createCompany(
                legalName: legalNameCtrl.text.trim(),
                tradeName: tradeNameCtrl.text.trim(),
                contactEmail: emailCtrl.text.trim(),
                contactPhone: phoneCtrl.text.trim(),
                address: addressCtrl.text.trim(),
              );

              ref.invalidate(companiesListProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Company registered successfully.')));
              }
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignZoneDialog(
    BuildContext context,
    WidgetRef ref,
    Company company,
    List<Zone> allZones,
  ) async {
    final availableZones = allZones.where((z) => !z.isArchived).toList();
    String? selectedZoneId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Assign Zone to ${company.tradeName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The company will only be able to view and book advertisements in agreed shops within the assigned zone.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Zone / জোন নির্বাচন করুন',
                    border: OutlineInputBorder(),
                  ),
                  items: availableZones.map((z) {
                    final isAlreadyAssigned = company.assignedZoneIds.contains(z.id);
                    return DropdownMenuItem<String>(
                      value: z.id,
                      enabled: !isAlreadyAssigned,
                      child: Text(
                        '${z.name}${isAlreadyAssigned ? " (Already assigned)" : ""}',
                        style: TextStyle(color: isAlreadyAssigned ? Colors.grey : null),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedZoneId = val),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: selectedZoneId == null
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        final repo = ref.read(masterAdminRepositoryProvider);
                        await repo.assignZoneToCompany(company.id, selectedZoneId!);
                        ref.invalidate(companiesListProvider);
                        ref.invalidate(zonesListProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Zone assigned to company successfully.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                child: const Text('Assign Zone'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final companiesAsync = ref.watch(companiesListProvider);
    final zonesAsync = ref.watch(zonesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Management / কোম্পানি পার্টনারশিপ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(companiesListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCompanyDialog(context, ref),
        icon: const Icon(Icons.business_outlined),
        label: const Text('Add Company / নতুন কোম্পানি'),
      ),
      body: companiesAsync.when(
        data: (companies) {
          if (companies.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business_outlined, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: AppSpacing.md),
                  Text('No companies registered yet.', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: () => _showAddCompanyDialog(context, ref),
                    child: const Text('Register First Company'),
                  ),
                ],
              ),
            );
          }

          final allZones = zonesAsync.value ?? [];

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: companies.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final comp = companies[index];

              return AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.teal.withAlpha(40),
                          child: const Icon(Icons.business, color: Colors.teal),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comp.tradeName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                comp.legalName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppBadge(label: 'Verified Partner', variant: AppBadgeVariant.success),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Email: ${comp.contactEmail} • Phone: ${comp.contactPhone ?? "N/A"}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.sm),

                    // Assigned Zones Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Assigned Zones (${comp.assignedZoneNames.length}):',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: () => _showAssignZoneDialog(context, ref, comp, allZones),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Assign Zone'),
                        ),
                      ],
                    ),
                    if (comp.assignedZoneNames.isEmpty) ...[
                      Text(
                        'No zones assigned. Company cannot view any shops until a zone is assigned by Master Admin.',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange.shade800),
                      ),
                    ] else ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: comp.assignedZoneNames.map((zName) {
                          return Chip(
                            label: Text(zName, style: const TextStyle(fontSize: 12)),
                            avatar: const Icon(Icons.layers, size: 14),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () async {
                              // Find zone id
                              final match = allZones.where((z) => z.name == zName);
                              if (match.isNotEmpty) {
                                final repo = ref.read(masterAdminRepositoryProvider);
                                await repo.removeZoneFromCompany(comp.id, match.first.id);
                                ref.invalidate(companiesListProvider);
                                ref.invalidate(zonesListProvider);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppErrorView(
          title: 'Error loading companies',
          message: e.toString(),
          onRetry: () => ref.refresh(companiesListProvider),
        ),
      ),
    );
  }
}
