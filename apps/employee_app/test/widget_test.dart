import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:employee_app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Employee App boots and renders Field Employee Zone Map Shell', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    const config = AppConfig(
      environment: AppEnvironment.dev,
      appName: 'Field Employee Test',
      supabaseUrl: '',
      supabaseAnonKey: '',
      googleMapsApiKey: '',
      apiBaseUrl: 'https://api.test',
    );

    final sm = SupabaseManager(config: config);
    final repo = SupabaseEmployeeRepository(supabaseManager: sm);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          currentAppRoleProvider.overrideWithValue(UserRole.employee),
          employeeRepositoryProvider.overrideWithValue(repo),
        ],
        child: const EmployeeApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Shops'), findsOneWidget);
    expect(find.text('Saloons'), findsOneWidget);
    expect(find.text('Long-press inside your assigned zone to add a shop'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Search shops by name, code, phone, or owner...'), findsNothing);
  });
}
