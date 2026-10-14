import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:employee_app/screens/map/services/map_reverse_geocode_service.dart';
import 'package:map_features/map_features.dart';
import 'package:employee_app/screens/map/widgets/shop_category_picker_modal.dart';
import 'package:employee_app/screens/shop/add_shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShopCategoryPickerModal Tests', () {
    testWidgets('Renders all standard categories with English & Bengali names and icons',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      ShopCategory? selectedCategory;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedCategory = await ShopCategoryPickerModal.show(context);
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      // Open modal
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Select Shop Category'), findsOneWidget);
      expect(find.text('দোকানের ক্যাটাগরি বেছে নিন'), findsOneWidget);

      // Check that standard categories are visible
      expect(find.text('Grocery'), findsOneWidget);
      expect(find.text('Fast Food'), findsOneWidget);
      expect(find.text('Chicken'), findsOneWidget);
      expect(find.text('Saloon'), findsOneWidget);
      expect(find.text('Pharmacy'), findsOneWidget);
      expect(find.text('Tea Stall'), findsOneWidget);
      expect(find.text('Bakery'), findsOneWidget);
      expect(find.text('Clothing'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);

      // Tap on Pharmacy category
      await tester.tap(find.text('Pharmacy'));
      await tester.pumpAndSettle();

      // Verify that modal popped with Pharmacy selected
      expect(selectedCategory, equals(ShopCategory.pharmacy));
    });

    testWidgets('Filters categories dynamically based on search query', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ShopCategoryPickerModal.show(context),
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Search for "tea"
      await tester.enterText(find.byType(TextField), 'tea');
      await tester.pumpAndSettle();

      // Tea Stall should be present, others should be filtered out
      expect(find.text('Tea Stall'), findsOneWidget);
      expect(find.text('Grocery'), findsNothing);
      expect(find.text('Fast Food'), findsNothing);

      // Search in Bengali "মুদি"
      await tester.enterText(find.byType(TextField), 'মুদি');
      await tester.pumpAndSettle();

      expect(find.text('Grocery'), findsOneWidget);
      expect(find.text('Tea Stall'), findsNothing);
    });
  });

  group('CategoryMarkerHelper Tests', () {
    test('Successfully generates and caches custom category marker bitmaps', () async {
      final marker = await CategoryMarkerHelper.getCategoryMarkerBitmap(
        category: ShopCategory.grocery,
        color: AppColors.primary,
      );
      expect(marker, isNotNull);

      // Calling again returns cached instance
      final cachedMarker = await CategoryMarkerHelper.getCategoryMarkerBitmap(
        category: ShopCategory.grocery,
        color: AppColors.primary,
      );
      expect(cachedMarker, equals(marker));
    });
  });

  group('AddShopScreen Category Pre-filling Tests', () {
    testWidgets('Pre-fills initialCategory and coordinates from map confirmation',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AddShopScreen(
              zoneId: 'zone-101',
              zoneName: 'Bowbazar Market Zone',
              latitude: 22.5697,
              longitude: 88.3697,
              initialCategory: 'Saloon',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verified zone banner
      expect(find.text('Bowbazar Market Zone'), findsOneWidget);
      expect(find.textContaining('22.5697'), findsOneWidget);
      expect(find.textContaining('88.3697'), findsOneWidget);

      // Verified category pre-fill
      expect(find.text('Saloon (সেলুন / পার্লার)'), findsOneWidget);

      // Verified all mandatory shop fields are present
      expect(find.text('Shop Name *'), findsOneWidget);
      expect(find.text('Owner Name *'), findsOneWidget);
      expect(find.text('Phone Number (10 Digits) *'), findsOneWidget);
      expect(find.text('Operating Hours & Schedule'), findsOneWidget);
    });
  });
}
