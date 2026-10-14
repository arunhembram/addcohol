import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:owner_admin_app/config/translations.dart';
import 'package:owner_admin_app/services/api_service.dart';
import 'package:owner_admin_app/providers/auth_provider.dart';
import 'package:owner_admin_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final apiService = ApiService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppLocaleProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider(apiService)),
        ],
        child: const AdProofOwnerApp(),
      ),
    );
    expect(find.byType(AdProofOwnerApp), findsOneWidget);
  });
}
