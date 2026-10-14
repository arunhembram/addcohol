import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopkeeper_app/app.dart';

void main() {
  testWidgets('Shopkeeper App boots and renders Today Dashboard Shell', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    const config = AppConfig(
      environment: AppEnvironment.dev,
      appName: 'Shopkeeper Portal Test',
      supabaseUrl: '',
      supabaseAnonKey: '',
      googleMapsApiKey: '',
      apiBaseUrl: 'https://api.test',
    );

    final sm = SupabaseManager(config: config);
    final repo = SupabaseShopkeeperRepository(supabaseManager: sm);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          currentAppRoleProvider.overrideWithValue(UserRole.shopkeeper),
          shopkeeperRepositoryProvider.overrideWithValue(repo),
        ],
        child: const ShopkeeperApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Maa Tara Electronic Hub'), findsWidgets);
    expect(find.text('Code: 10000001'), findsOneWidget);
    expect(find.text('Upload Photo'), findsOneWidget);
  });
}
