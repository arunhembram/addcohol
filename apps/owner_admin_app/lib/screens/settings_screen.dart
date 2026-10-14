import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_data_provider.dart';
import '../config/translations.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isTriggeringMidnight = false;
  String? _midnightResult;

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<AdminDataProvider>(context);
    final locale = Provider.of<AppLocaleProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            locale.t('nav_settings'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            locale.isBengali
                ? 'সিস্টেম কনফিগারেশন, টাইমজোন এবং দৈনিক মিডিয়া অটোমেশন'
                : 'System Configuration, Business Timezone, and Daily Expiry Automation',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),

          // 1. Language Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.language_rounded, size: 28, color: AppTheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale.isBengali ? 'ইন্টারফেস ভাষা (Language)' : 'Interface Language',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          locale.isBengali ? 'বর্তমান ভাষা: বাংলা' : 'Current Language: English',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'bn', label: Text('বাংলা')),
                      ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {locale.locale},
                    onSelectionChanged: (val) => locale.setLocale(val.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Business Timezone & Expiry Rule Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 28, color: AppTheme.accent),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              locale.isBengali
                                  ? 'বিজনেস টাইমজোন ও ইমেজ রিটেনশন নীতি'
                                  : 'Business Timezone & Retention Policy',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Timezone: Asia/Dhaka (UTC+6) • Scheduled Job: 00:00:00',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_delete_outlined, color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              locale.isBengali
                                  ? 'দৈনিক ইমেজ বিলোপ নীতি (Daily Image Expiry Rule):'
                                  : 'Daily Expiry Rule:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          locale.isBengali
                              ? '• প্রতিদিন রাত ১২:০০ টায় সার্ভার প্রাইভেট স্টোরেজ থেকে বিজ্ঞাপনের মূল ইমেজ ফাইল মুছে ফেলে।\n• অডিট মেটাডেটা (দোকান, জোন, মাঠকর্মী, সময় ও ভেরিফিকেশন স্ট্যাটাস) আজীবন সংরক্ষিত থাকে।\n• নতুন দিনের শুরুতে সকল দোকানের স্ট্যাটাস "আপলোড করা হয়নি" হিসেবে রিসেট হয়।'
                              : '• Every midnight at 12:00 AM, server deletes physical proof files from private storage.\n• Audit metadata (timestamps, GPS, shop, and verification status) is preserved permanently.\n• Shop upload status automatically resets to "Not Uploaded Yet" for the new day.',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Manual Trigger Button for Testing
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isTriggeringMidnight
                            ? null
                            : () async {
                                setState(() {
                                  _isTriggeringMidnight = true;
                                  _midnightResult = null;
                                });
                                try {
                                  await dataProvider.triggerMidnightJob();
                                  setState(() {
                                    _midnightResult = locale.isBengali
                                        ? 'মিডনাইট ক্লিনআপ সফলভাবে সম্পন্ন হয়েছে! পুরনো ইমেজ মুছে নতুন দিনের জন্য রিসেট করা হয়েছে।'
                                        : 'Midnight expiry job executed successfully! Files cleared and daily state reset.';
                                  });
                                } catch (e) {
                                  setState(() {
                                    _midnightResult = 'Error: $e';
                                  });
                                } finally {
                                  setState(() => _isTriggeringMidnight = false);
                                }
                              },
                        icon: _isTriggeringMidnight
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.flash_on_rounded, size: 18),
                        label: Text(locale.t('btn_trigger_midnight')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        locale.isBengali
                            ? '(পরীক্ষা ও যাচাইয়ের জন্য তাৎক্ষণিক মধ্যরাত রিসেট চালান)'
                            : '(Manually test the midnight expiry cleanup instantly)',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  if (_midnightResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.statusGreenLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _midnightResult!,
                        style: const TextStyle(
                          color: AppTheme.statusGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Proximity Distance Tolerance
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.social_distance_rounded, size: 28, color: Colors.indigo),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale.isBengali
                              ? 'জিপিএস দূরত্বের সর্বোচ্চ সহনশীলতা'
                              : 'GPS Distance Tolerance',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          locale.isBengali
                              ? 'দোকানের নিবন্ধিত অবস্থান থেকে ১৫০ মিটারের বেশি দূরত্বের আপলোড স্বয়ংক্রিয়ভাবে "সন্দেহজনক" হিসেবে ফ্ল্যাগ করা হয়।'
                              : 'Uploads captured > 150 meters away from shop coordinates are automatically flagged as suspicious.',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: const Text(
                      '150 Meters (Def)',
                      style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
