import 'dart:convert';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/master_admin_providers.dart';

class AuditReportingScreen extends ConsumerStatefulWidget {
  const AuditReportingScreen({super.key});

  @override
  ConsumerState<AuditReportingScreen> createState() => _AuditReportingScreenState();
}

class _AuditReportingScreenState extends ConsumerState<AuditReportingScreen> {
  String _selectedFilter = 'ALL';

  void _showLogDetailsDialog(BuildContext context, AuditLog log) {
    final prettyJson = const JsonEncoder.withIndent('  ').convert(log.details);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.history_edu, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(child: Text(log.action, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Log ID:', log.id),
              _detailRow('Entity:', log.entityName),
              if (log.entityId != null) _detailRow('Entity ID:', log.entityId!),
              _detailRow('Actor:', log.userDisplayName ?? log.userId ?? 'System'),
              _detailRow('Role:', log.userRole ?? 'N/A'),
              _detailRow('Timestamp:', log.createdAt.toLocal().toString()),
              const SizedBox(height: 12),
              const Text(
                'Event Details Payload:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  prettyJson,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs & Reports / অডিট লগ ও রিপোর্ট'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(auditLogsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                _filterChip('ALL', 'All Events'),
                const SizedBox(width: 8),
                _filterChip('ZONE', 'Zone Changes'),
                const SizedBox(width: 8),
                _filterChip('ADMIN', 'Admin Accounts'),
                const SizedBox(width: 8),
                _filterChip('COMPANY', 'Company Allocs'),
                const SizedBox(width: 8),
                _filterChip('PAYMENT', 'Payments'),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: logsAsync.when(
              data: (logs) {
                final filtered = logs.where((l) {
                  if (_selectedFilter == 'ALL') return true;
                  return l.action.toUpperCase().contains(_selectedFilter) ||
                      l.entityName.toUpperCase().contains(_selectedFilter);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.rule_folder_outlined,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No audit logs matching criteria.',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final log = filtered[index];
                    return InkWell(
                      onTap: () => _showLogDetailsDialog(context, log),
                      borderRadius: AppRadii.radiusSm,
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.security,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          log.action,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Entity: ${log.entityName} • By: ${log.userDisplayName ?? log.userRole ?? "System"}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (log.details.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      log.details.toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (e, _) => AppErrorView(
                title: 'Error loading audit logs',
                message: e.toString(),
                onRetry: () => ref.refresh(auditLogsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFilter == key,
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }
}
