import 'package:admin_app/app.dart';
import 'package:admin_app/providers/admin_state_providers.dart';
import 'package:admin_app/screens/dashboard/admin_dashboard_screen.dart';
import 'package:admin_app/screens/login/admin_login_screen.dart';
import 'package:admin_app/screens/zones/controlled_zone_map_screen.dart';
import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Admin Login screen renders Sign up and Log in tabs and validates inputs',
      (WidgetTester tester) async {
    const config = AppConfig(
      environment: AppEnvironment.dev,
      appName: 'Admin App Test',
      supabaseUrl: '',
      supabaseAnonKey: '',
      googleMapsApiKey: '',
      apiBaseUrl: '',
    );
    final supabaseManager = SupabaseManager(config: config);
    final repository = SupabaseAdminRepository(supabaseManager: supabaseManager);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          adminRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: AdminLoginScreen(),
        ),
      ),
    );

    // Initial state: Sign up tab and Log in tab rendered
    expect(find.text('Sign up'), findsWidgets);
    expect(find.text('Log in'), findsWidgets);
    expect(find.text('FIRST NAME'), findsOneWidget);
    expect(find.text('LAST NAME'), findsOneWidget);
    expect(find.text('PHONE NUMBER'), findsOneWidget);

    // Attempting to submit empty form must trigger validation
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('First name is required'), findsOneWidget);
    expect(find.text('Last name is required'), findsOneWidget);
    expect(find.text('Phone number is required'), findsOneWidget);
    expect(find.text('5-digit admin code is required'), findsOneWidget);
  });

  testWidgets('ControlledZoneMapScreen safely displays error banner on ForbiddenZoneException',
      (WidgetTester tester) async {
    const config = AppConfig(
      environment: AppEnvironment.dev,
      appName: 'Admin App Test',
      supabaseUrl: '',
      supabaseAnonKey: '',
      googleMapsApiKey: '',
      apiBaseUrl: '',
    );
    final supabaseManager = SupabaseManager(config: config);
    final repository = SupabaseAdminRepository(supabaseManager: supabaseManager);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          adminRepositoryProvider.overrideWithValue(repository),
          // Admin 10001 is logged in
          currentAdminIdProvider.overrideWithValue('admin-10001'),
        ],
        child: const MaterialApp(
          home: ControlledZoneMapScreen(zoneId: 'z-howrah-industrial'), // Forbidden zone!
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // The backend throws ForbiddenZoneException and the UI safely catches it
    expect(find.text('Zone Access Denied'), findsOneWidget);
    expect(
      find.textContaining('You do not have administrative control over zone "z-howrah-industrial"'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Admins cannot view or manage zones outside their explicit Master Admin assignment'),
      findsOneWidget,
    );
    expect(find.text('Return to My Controlled Zones'), findsOneWidget);
  });

  testWidgets('ControlledZoneMapScreen renders read-only boundary for authorized zone',
      (WidgetTester tester) async {
    const config = AppConfig(
      environment: AppEnvironment.dev,
      appName: 'Admin App Test',
      supabaseUrl: '',
      supabaseAnonKey: '',
      googleMapsApiKey: '',
      apiBaseUrl: '',
    );
    final supabaseManager = SupabaseManager(config: config);
    final repository = SupabaseAdminRepository(supabaseManager: supabaseManager);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          adminRepositoryProvider.overrideWithValue(repository),
          currentAdminIdProvider.overrideWithValue('admin-10001'),
        ],
        child: const MaterialApp(
          home: ControlledZoneMapScreen(zoneId: 'z-kolkata-central'), // Controlled zone!
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kolkata Central Zone (Controlled)'), findsOneWidget);
    expect(find.text('Read-Only Boundary'), findsOneWidget);
    expect(find.textContaining('Assigned Employees in this Zone:'), findsOneWidget);
  });

  testWidgets('Admin App boots and renders Dashboard Shell with profile and controlled zones',
      (WidgetTester tester) async {
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
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('ShopAd Admin'), findsOneWidget);
    expect(find.text('Controlled Zones'), findsAtLeastNWidgets(1));
    expect(find.text('Subhasis Sen'), findsOneWidget);
    expect(find.text('Kolkata Central Zone'), findsOneWidget);
    expect(find.text('Salt Lake Sector V'), findsOneWidget);
  });
}
