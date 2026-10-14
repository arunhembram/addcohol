import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/admin_data_provider.dart';
import '../config/translations.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_sidebar.dart';

import 'dashboard_screen.dart';
import 'zones_screen.dart';
import 'shops_screen.dart';
import 'companies_screen.dart';
import 'assignments_screen.dart';
import 'live_map_screen.dart';
import 'upload_review_screen.dart';
import 'issue_reports_screen.dart';
import 'audit_logs_screen.dart';
import 'settings_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _selectedIndex = 0;

  void _onNavigate(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final dataProvider = Provider.of<AdminDataProvider>(context);
    final locale = Provider.of<AppLocaleProvider>(context);

    final screens = [
      DashboardScreen(onNavigate: _onNavigate),
      const ZonesScreen(),
      const ShopsScreen(),
      const CompaniesScreen(),
      const AssignmentsScreen(),
      const LiveMapScreen(),
      const UploadReviewScreen(),
      const IssueReportsScreen(),
      const AuditLogsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          ResponsiveSidebar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
          ),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top App Bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Current Screen Title
                      Text(
                        _getScreenTitle(locale, _selectedIndex),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),

                      // Actions: WS Indicator, Language toggle, Refresh, User Profile & Logout
                      Row(
                        children: [
                          // Real-time WebSocket status indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: dataProvider.isWsConnected
                                  ? AppTheme.statusGreenLight
                                  : AppTheme.statusRedLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: dataProvider.isWsConnected
                                        ? AppTheme.statusGreen
                                        : AppTheme.statusRed,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  dataProvider.isWsConnected
                                      ? locale.t('msg_connected')
                                      : locale.t('msg_disconnected'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: dataProvider.isWsConnected
                                        ? AppTheme.statusGreen
                                        : AppTheme.statusRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Language switcher
                          OutlinedButton.icon(
                            onPressed: () => locale.toggleLocale(),
                            icon: const Icon(Icons.language, size: 16),
                            label: Text(locale.isBengali ? 'English' : 'বাংলা'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Refresh button
                          IconButton(
                            onPressed: () => dataProvider.fetchAll(),
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            tooltip: locale.t('btn_refresh'),
                          ),
                          const SizedBox(width: 8),

                          // User profile & Logout
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppTheme.primary.withOpacity(0.1),
                                child: const Icon(Icons.person, size: 18, color: AppTheme.primary),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                auth.user?['full_name'] ?? 'Owner Admin',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(
                                  Icons.logout_rounded,
                                  size: 18,
                                  color: AppTheme.textSecondary,
                                ),
                                tooltip: locale.t('nav_logout'),
                                onPressed: () => auth.logout(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Active Page Content
                Expanded(child: screens[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getScreenTitle(AppLocaleProvider locale, int index) {
    switch (index) {
      case 0:
        return locale.t('nav_dashboard');
      case 1:
        return locale.t('nav_zones');
      case 2:
        return locale.t('nav_shops');
      case 3:
        return locale.t('nav_companies');
      case 4:
        return locale.t('nav_assignments');
      case 5:
        return locale.t('nav_live_map');
      case 6:
        return locale.t('nav_upload_review');
      case 7:
        return locale.t('nav_issues');
      case 8:
        return locale.t('nav_audit_logs');
      case 9:
        return locale.t('nav_settings');
      default:
        return locale.t('app_title');
    }
  }
}
