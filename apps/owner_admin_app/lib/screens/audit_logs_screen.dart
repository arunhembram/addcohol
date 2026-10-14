import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_data_provider.dart';
import '../config/translations.dart';
import '../theme/app_theme.dart';

class AuditLogsScreen extends StatelessWidget {
  const AuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<AdminDataProvider>(context);
    final locale = Provider.of<AppLocaleProvider>(context);
    final logs = dataProvider.auditLogs;

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
                    locale.t('nav_audit_logs'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locale.isBengali
                        ? 'সিস্টেমের যাবতীয় কার্যক্রমের অপরিবর্তনযোগ্য অডিট হিস্টোরি'
                        : 'Immutable Audit Trail of all system changes and user actions',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => dataProvider.fetchAll(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(locale.t('btn_refresh')),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Audit Table Card
          Card(
            child: SizedBox(
              width: double.infinity,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                columns: [
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'সময়' : 'Timestamp',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'ব্যবহারকারী' : 'Actor',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'কার্যক্রম' : 'Action Type',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'উপাদান' : 'Entity',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'আইডি' : 'Entity ID',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      locale.isBengali ? 'পরিবর্তিত মান' : 'Details',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                rows: logs.map((log) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          log.createdAt.substring(0, 19).replaceAll('T', ' '),
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ),
                      DataCell(
                        Text(
                          log.actorName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            log.actionType,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(log.entityType, style: const TextStyle(fontSize: 12))),
                      DataCell(
                        Text(
                          log.entityId,
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 250,
                          child: Text(
                            log.newValueJson ?? log.oldValueJson ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ),
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
