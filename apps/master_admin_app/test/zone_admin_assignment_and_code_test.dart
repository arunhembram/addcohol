import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_admin_app/screens/admin_directory_screen.dart';
import 'package:master_admin_app/screens/widgets/zone_admin_dashboard_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Zone Admin Assignment & Dashboard Panel Tests', () {
    testWidgets('Unassigned zone displays "No Admin Assigned" and "Assign Admin to this Zone" button', (tester) async {
      final unassignedZone = Zone(
        id: 'z-test-unassigned',
        name: 'Test Unassigned Zone',
        colorHex: '#1E88E5',
        isActive: true,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        assignedAdminId: null,
        assignedAdminName: null,
        vertices: const [
          ZoneVertex(sequenceOrder: 0, latitude: 22.5, longitude: 88.3),
          ZoneVertex(sequenceOrder: 1, latitude: 22.51, longitude: 88.31),
          ZoneVertex(sequenceOrder: 2, latitude: 22.5, longitude: 88.32),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ZoneAdminDashboardPanel(
                zone: unassignedZone,
                shops: const [],
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must find unassigned indicators
      expect(find.text('No Admin Assigned'), findsOneWidget);
      expect(find.text('Vacant Zone'), findsOneWidget);
      expect(find.textContaining('Assign Admin to this Zone'), findsOneWidget);
    });

    testWidgets('Assigned zone displays admin name, Call Sign (📞) button, Change Admin, and Expel Admin', (tester) async {
      final assignedZone = Zone(
        id: 'z-test-assigned',
        name: 'Kolkata Central Zone',
        colorHex: '#1E88E5',
        isActive: true,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        assignedAdminId: 'admin-10001',
        assignedAdminName: 'Subhasis Sen (ID: 10001)',
        vertices: const [
          ZoneVertex(sequenceOrder: 0, latitude: 22.5, longitude: 88.3),
          ZoneVertex(sequenceOrder: 1, latitude: 22.51, longitude: 88.31),
          ZoneVertex(sequenceOrder: 2, latitude: 22.5, longitude: 88.32),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ZoneAdminDashboardPanel(
                zone: assignedZone,
                shops: const [],
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must find assigned indicators
      expect(find.text('Subhasis Sen (ID: 10001)'), findsOneWidget);
      expect(find.text('Admin Active'), findsOneWidget);
      expect(find.byIcon(Icons.phone), findsOneWidget);
      expect(find.text('Change Admin'), findsOneWidget);
      expect(find.text('Expel Admin'), findsOneWidget);
    });
  });

  group('Admin Directory & Code Generation Tests', () {
    testWidgets('Admin Directory renders Create Code CTA and displays admin entries', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AdminDirectoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin Directory & Access Codes'), findsOneWidget);
      expect(find.text('Create Code'), findsOneWidget);
      expect(find.textContaining('Registered & Pending Admins'), findsOneWidget);
    });
  });
}
