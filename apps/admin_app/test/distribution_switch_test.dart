import 'package:admin_app/app.dart';
import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Admin dashboard renders separate Company Ads and Material distribution sections',
      (WidgetTester tester) async {
    CanonicalZones.resetAll();

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

    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

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

    // Check Company Ad Campaigns section
    expect(find.textContaining('COMPANY AD CAMPAIGNS'), findsWidgets);
    // Check Distribution of Materials section
    expect(find.textContaining('DISTRIBUTION OF MATERIALS'), findsWidgets);

    // CRITICAL REQUIREMENT: Normal Admin App must NOT have "Add Material" button
    expect(find.text('Add Material'), findsNothing);

    // CRITICAL REQUIREMENT: Salt Lake Sector V and any zone must have ALL Master Catalog materials
    final catalogMaterials = CanonicalZones.getAllMaterials();
    expect(catalogMaterials.length, equals(4));

    final saltLakeRuns = CanonicalZones.getMaterialRuns(CanonicalZones.saltLakeSector5Id);
    expect(saltLakeRuns.length, equals(4));
    expect(saltLakeRuns.map((r) => r.materialName), containsAll([
      'Cello Tape',
      'Marker Pen',
      'Glue Stick',
      'QR Acrylic Stand',
    ]));

    final kolkataRuns = CanonicalZones.getMaterialRuns(CanonicalZones.kolkataCentralId);
    expect(kolkataRuns.length, equals(4));

    // Any newly created zone automatically gets all materials
    final newZoneRuns = CanonicalZones.getMaterialRuns('z-newly-created-zone');
    expect(newZoneRuns.length, equals(4));

    // Switches exist for independent company campaigns and materials
    final switches = find.byType(Switch);
    expect(switches, findsWidgets);

    // Tapping the first switch toggles it
    final Switch firstSwitch = tester.widget(switches.first);
    final initialVal = firstSwitch.value;

    await tester.tap(switches.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final Switch updatedSwitch = tester.widget(switches.first);
    expect(updatedSwitch.value, equals(!initialVal));
  });
}
