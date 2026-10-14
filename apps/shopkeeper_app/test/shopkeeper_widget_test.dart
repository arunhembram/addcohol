import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopkeeper_app/screens/dashboard/shopkeeper_dashboard_screen.dart';
import 'package:shopkeeper_app/screens/login/shopkeeper_login_screen.dart';
import 'package:shopkeeper_app/screens/payments/payments_placeholder_screen.dart';
import 'package:shopkeeper_app/screens/photo/fullscreen_photo_screen.dart';
import 'package:shopkeeper_app/screens/photo/upload_photo_screen.dart';
import 'package:shopkeeper_app/screens/profile/shopkeeper_profile_screen.dart';

void main() {
  late SupabaseShopkeeperRepository repo;

  setUp(() {
    const config = AppConfig(
      environment: AppEnvironment.dev,
      appName: 'Shopkeeper Widget Test',
      supabaseUrl: '',
      supabaseAnonKey: '',
      googleMapsApiKey: '',
      apiBaseUrl: '',
    );
    final sm = SupabaseManager(config: config);
    repo = SupabaseShopkeeperRepository(supabaseManager: sm);
  });

  Widget buildTestableWidget(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        shopkeeperRepositoryProvider.overrideWithValue(repo),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  group('Shopkeeper Login Widget Tests', () {
    testWidgets('Enforces 8-digit Shop Code and strictly rejects access without OTP', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const ShopkeeperLoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('ShopAd Partner'), findsOneWidget);
      expect(find.text('First-Time Shopkeeper Access'), findsOneWidget);

      // Enter 8-digit Shop Code
      await tester.enterText(find.byType(TextField), '10000001');
      await tester.tap(find.text('Verify Code & Send OTP'));
      await tester.pumpAndSettle();

      // Step 2 appears: Verify Registered Phone OTP
      expect(find.text('Verify Registered Phone OTP'), findsOneWidget);

      // Attempt to submit WITHOUT OTP (testing strict rule: never allow access using code alone!)
      await tester.tap(find.text('Verify & Bind My Shop'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Registered phone OTP is mandatory. Access using Shop Code alone is strictly prohibited.'),
        findsOneWidget,
      );

      // Now enter valid OTP
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();

      expect(find.text('Verify & Bind My Shop'), findsOneWidget);
    });
  });

  group('Today Dashboard Widget Tests', () {
    testWidgets('Renders Shop Name, Category, 8-Digit Shop Code, and Navigation Hub', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const ShopkeeperDashboardScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Maa Tara Electronic Hub'), findsWidgets);
      expect(find.text('Code: 10000001'), findsOneWidget);
      expect(find.text('Active Ad Partner'), findsOneWidget);

      // Quick Nav cards
      expect(find.text('Upload Photo'), findsOneWidget);
      expect(find.text('View Today Photo'), findsOneWidget);
      expect(find.text('Ad Payments'), findsOneWidget);
      expect(find.text('Shop Profile'), findsOneWidget);
    });
  });

  group('Upload Photo Screen Widget Tests', () {
    testWidgets('Renders camera capture rules and outside-geofence state', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const UploadPhotoScreen()));
      await tester.pumpAndSettle();

      expect(find.text("Capture Today's Shop Photo"), findsOneWidget);
      expect(find.textContaining('Direct camera capture required (Gallery upload is disabled).'), findsOneWidget);
      expect(find.textContaining('Foreground GPS location verified against shop geofence'), findsOneWidget);

      // Simulate outside-geofence capture
      await tester.tap(find.text('Simulate Outside-Geofence Capture (Dev Test)'));
      await tester.pumpAndSettle();

      // Outside radius failure state
      expect(find.text('Location Outside Shop Radius'), findsOneWidget);
      expect(find.text('Stand Near Shop & Retry'), findsOneWidget);
    });
  });

  group('Fullscreen Photo Screen Widget Tests', () {
    testWidgets('Renders empty state or watermarked view with Shop Code overlay', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const FullscreenPhotoScreen()));
      await tester.pumpAndSettle();

      // In initial mock state without today's upload
      expect(find.text('No Photo Uploaded Today'), findsOneWidget);
      expect(find.text("Capture Today's Photo"), findsOneWidget);
    });
  });

  group('Shopkeeper Profile Widget Tests', () {
    testWidgets('Renders Operating Hours, Registered Shopkeeper, and Support Contact', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const ShopkeeperProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Maa Tara Electronic Hub'), findsOneWidget);
      expect(find.text('SHOP CODE: 10000001'), findsOneWidget);
      expect(find.text('Operating Hours & Schedule'), findsOneWidget);
      expect(find.text('Opening Time'), findsOneWidget);
      expect(find.text('09:00 AM'), findsOneWidget);
      expect(find.text('Closing Time'), findsOneWidget);
      expect(find.text('09:00 PM'), findsOneWidget);
      expect(find.text('Dedicated Support Contact'), findsOneWidget);
      expect(find.text('1800-889-SHOP (Toll-Free)'), findsOneWidget);
      expect(find.text('Sign Out & Unbind Device'), findsOneWidget);
    });
  });

  group('Payments Placeholder Widget Tests', () {
    testWidgets('Renders partner rent and ShopAd Pay placeholder banner', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const PaymentsPlaceholderScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Monthly Partner Rent'), findsOneWidget);
      expect(find.text('₹4500'), findsWidgets);
      expect(find.text('Direct UPI & QR Payouts (Coming Soon)'), findsOneWidget);
    });
  });
}
