import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_data_provider.dart';
import '../config/translations.dart';
import '../theme/app_theme.dart';
import '../models/issue_model.dart';

class IssueReportsScreen extends StatelessWidget {
  const IssueReportsScreen({super.key});

  void _showResolveDialog(BuildContext context, IssueModel issue) {
    final dataProvider = Provider.of<AdminDataProvider>(context, listen: false);
    final locale = Provider.of<AppLocaleProvider>(context, listen: false);
    final notesCtrl = TextEditingController(
      text: 'নতুন পোস্টার লাগানো হয়েছে ও সমস্যার সমাধান সম্পন্ন।',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          locale.isBengali ? 'সমস্যা সমাধান সম্পন্ন করুন' : 'Resolve Issue',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${locale.isBengali ? "দোকান" : "Shop"}: ${issue.shopName}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                locale.isBengali ? 'সমাধানের নোট (ঐচ্ছিক):' : 'Resolution Notes:',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
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
              await dataProvider.updateIssueStatus(
                issueId: issue.id,
                status: 'resolved',
                resolutionNotes: notesCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusGreen,
              foregroundColor: Colors.white,
            ),
            child: Text(locale.isBengali ? 'সমাধান চিহ্নিত করুন' : 'Mark Resolved'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<AdminDataProvider>(context);
    final locale = Provider.of<AppLocaleProvider>(context);
    final issues = dataProvider.issues;

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
                    locale.t('nav_issues'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locale.isBengali
                        ? 'মার্চেন্ট এবং মাঠকর্মীদের উত্থাপিত বিজ্ঞাপন ও কিউআর কোড সংক্রান্ত সমস্যা'
                        : 'Manage Merchant and Employee reported field issues (Damaged poster, QR covered, etc.)',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Issues List
          if (issues.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Text(
                  locale.isBengali ? 'কোনো অমীমাংসিত সমস্যা নেই।' : 'No reported issues found.',
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: issues.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 14),
              itemBuilder: (ctx, i) {
                final issue = issues[i];
                final isResolved = issue.status == 'resolved' || issue.status == 'closed';

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isResolved ? AppTheme.statusGreenLight : AppTheme.statusRedLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isResolved ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                            color: isResolved ? AppTheme.statusGreen : AppTheme.statusRed,
                            size: 24,
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
                                    locale.t('issue_${issue.issueType}'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isResolved
                                          ? AppTheme.statusGreenLight
                                          : AppTheme.statusRedLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isResolved
                                          ? (locale.isBengali ? "মীমাংসিত" : "Resolved")
                                          : (locale.isBengali ? "খোলা" : "Open"),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isResolved
                                            ? AppTheme.statusGreen
                                            : AppTheme.statusRed,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${issue.shopName} (${issue.shopCode}) • ${issue.zoneName}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(issue.notes, style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 8),
                              Text(
                                '${locale.isBengali ? "রিপোর্টকারী" : "Reported by"}: ${issue.reporterName} • ${locale.isBengali ? "নির্ধারিত মাঠকর্মী" : "Assigned Employee"}: ${issue.assignedEmployeeName ?? "None"}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (!isResolved) ...[
                          ElevatedButton(
                            onPressed: () => _showResolveDialog(context, issue),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.statusGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(locale.isBengali ? 'মীমাংসা করুন' : 'Resolve'),
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
