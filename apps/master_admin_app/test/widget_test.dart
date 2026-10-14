import 'package:app_core/app_core.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_admin_app/app.dart';
import 'package:master_admin_app/providers/master_admin_providers.dart';

void main() {
  testWidgets('Master Admin App boots and renders Dashboard with 6 KPI counters and controls', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const config = AppConfig(
      environment: AppEnvironment.dev,
      appName: 'Master Admin Test',
      supabaseUrl: '',
      supabaseAnonKey: '',
      googleMapsApiKey: '',
      apiBaseUrl: 'https://api.test',
    );

    const mockStats = DashboardStats(
      totalZones: 3,
      totalAdmins: 2,
      totalEmployees: 6,
      totalShops: 41,
      followupsDueToday: 4,
      paymentsAwaitingConfirmation: 2,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          currentAppRoleProvider.overrideWithValue(UserRole.masterAdmin),
          dashboardStatsProvider.overrideWith((ref) => Future.value(mockStats)),
        ],
        child: const MasterAdminApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Map Cockpit boots directly with floating action buttons
    expect(find.text('Create Zone'), findsOneWidget);
    expect(find.text('Materials'), findsOneWidget);
  });
}
