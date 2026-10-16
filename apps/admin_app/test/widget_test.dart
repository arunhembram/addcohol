import 'package:admin_app/providers/admin_state_providers.dart';
import 'package:admin_app/screens/dashboard/admin_dashboard_screen.dart';
import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Admin App boots and renders Dashboard Shell', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const config = AppConfig(
      environment: AppEnvironment.dev,
      appName: 'Admin App Test',
      supabaseUrl: '',
      supabaseAnonKey: '',
      googleMapsApiKey: '',
      apiBaseUrl: 'https://api.test',
    );

    final mockHealth = AppHealthInfo(
      appName: 'Admin App Test',
      targetRole: UserRole.admin,
      environment: 'dev',
      overallState: AppHealthState.healthy,
      checkTimestamp: DateTime.now(),
      subsystems: const [
        SubsystemStatus(name: 'Storage', status: ServiceStatus.connected, message: 'OK'),
      ],
    );

    final adminUser = UserProfile(
      id: 'admin-10001',
      email: 'subhasis@shopad.local',
      fullName: 'Subhasis Sen',
      role: UserRole.admin,
      displayId: '10001',
      isActive: true,
      createdAt: DateTime.now(),
    );
    final supabaseManager = SupabaseManager(config: config);
    final repository = SupabaseAdminRepository(supabaseManager: supabaseManager);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          currentAppRoleProvider.overrideWithValue(UserRole.admin),
          appHealthDiagnosticsProvider.overrideWith((ref) => Future.value(mockHealth)),
          adminAuthProvider.overrideWith((ref) => AdminAuthNotifier(repository)..setAuthenticatedAdmin(adminUser)),
        ],
        child: const MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('ShopAd Admin'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });
}
