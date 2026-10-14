import 'package:admin_app/app.dart';
import 'package:admin_app/providers/admin_state_providers.dart';
import 'package:admin_app/screens/login/admin_login_screen.dart';
import 'package:admin_app/screens/zones/controlled_zone_map_screen.dart';
import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Admin Login enforces 2-step verification and prohibits login with ID alone',
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

    // Initial state: Step 1 (Enter 5-digit Admin ID)
    expect(find.text('Step 1 of 2: Admin Identification'), findsOneWidget);
    expect(find.text('Enter your 5-digit Admin ID'), findsOneWidget);

    // Enter 5-digit ID
    await tester.enterText(find.byType(TextField), '10001');
    await tester.tap(find.text('Continue to Verification'));
    await tester.pumpAndSettle();

    // Step 2 must appear: Multi-Factor Verification
    expect(find.text('Step 2 of 2: Multi-Factor Verification'), findsOneWidget);
    expect(
      find.textContaining('Security policy: Login with ID alone is prohibited'),
      findsOneWidget,
    );

    // Attempting to submit without OTP/PIN must show error
    await tester.tap(find.text('Verify & Enter Dashboard'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Mobile OTP is mandatory. Login with ID alone is prohibited.'),
      findsOneWidget,
    );
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          currentAppRoleProvider.overrideWithValue(UserRole.admin),
          appHealthDiagnosticsProvider.overrideWith((ref) => Future.value(mockHealth)),
        ],
        child: const AdminApp(),
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
