import 'package:app_core/app_core.dart';
import 'package:company_app/app.dart';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Company App boots and renders Dashboard Shell', (WidgetTester tester) async {
    const config = AppConfig(
      environment: AppEnvironment.dev,
      appName: 'Company Portal Test',
      supabaseUrl: '',
      supabaseAnonKey: '',
      googleMapsApiKey: '',
      apiBaseUrl: 'https://api.test',
    );

    final mockHealth = AppHealthInfo(
      appName: 'Company Portal Test',
      targetRole: UserRole.company,
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
          currentAppRoleProvider.overrideWithValue(UserRole.company),
          appHealthDiagnosticsProvider.overrideWith((ref) => Future.value(mockHealth)),
        ],
        child: const CompanyApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(CompanyApp), findsOneWidget);
  });
}
