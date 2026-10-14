import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:domain_models/domain_models.dart';
import 'package:employee_app/providers/employee_state_providers.dart';
import 'package:employee_app/screens/followups/followups_list_screen.dart';
import 'package:employee_app/screens/login/employee_login_screen.dart';
import 'package:employee_app/screens/map/employee_zone_map_screen.dart';
import 'package:employee_app/screens/shop/add_shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockEmployeeAuthNotifier extends EmployeeAuthNotifier {
  MockEmployeeAuthNotifier(super.repo) {
    state = EmployeeAuthState(
      isAuthenticated: true,
      currentEmployee: UserProfile(
        id: 'emp-20001',
        email: 'rahul.das@shopad.local',
        fullName: 'Rahul Das',
        role: UserRole.employee,
        displayId: '20001',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    );
  }
}

void main() {
  late SupabaseEmployeeRepository repo;

  setUp(() {
    const config = AppConfig(
      environment: AppEnvironment.dev,
      appName: 'Employee Widget Test',
      supabaseUrl: '',
      supabaseAnonKey: '',
      googleMapsApiKey: '',
      apiBaseUrl: '',
    );
    final sm = SupabaseManager(config: config);
    repo = SupabaseEmployeeRepository(supabaseManager: sm);
  });

  Widget buildTestableWidget(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        employeeRepositoryProvider.overrideWithValue(repo),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  group('Employee Login Widget Tests', () {
    testWidgets('Renders 2-step login and strictly rejects login with ID alone', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const EmployeeLoginScreen()));
      await tester.pumpAndSettle();

      // Check header and step 1 elements
      expect(find.text('ShopAd Field Pro'), findsOneWidget);
      expect(find.text('Field Employee Portal'), findsOneWidget);
      expect(find.text('Enter Your Employee ID'), findsOneWidget);

      // Enter valid 5-digit Employee ID
      await tester.enterText(find.byType(TextField), '20001');
      await tester.pump();

      // Tap Verify ID & Send OTP
      await tester.tap(find.text('Verify ID & Send OTP'));
      await tester.pumpAndSettle();

      // Should now be on Step 2: Verify Mobile OTP
      expect(find.text('Verify Mobile OTP'), findsOneWidget);
      expect(find.text('Verify & Open Zone Map'), findsOneWidget);

      // Attempt to submit WITHOUT OTP (testing strict rule: never login with ID alone!)
      await tester.tap(find.text('Verify & Open Zone Map'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Mobile OTP is mandatory. Login with ID alone is strictly prohibited.'),
        findsOneWidget,
      );

      // Switch to PIN mode
      await tester.tap(find.text('Use Secure PIN instead'));
      await tester.pumpAndSettle();

      expect(find.text('Enter Secure PIN'), findsOneWidget);

      // Attempt submit without PIN
      await tester.tap(find.text('Verify & Open Zone Map'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Security PIN is mandatory. Login with ID alone is strictly prohibited.'),
        findsOneWidget,
      );

      // Now enter valid PIN 1234
      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();

      // Verify button is ready
      expect(find.text('Verify & Open Zone Map'), findsOneWidget);
    });
  });

  group('Employee Zone Map Widget Tests', () {
    testWidgets('Renders Employee Profile header, Quick count badges, and Category filters', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(
        const EmployeeZoneMapScreen(),
        overrides: [
          employeeAuthProvider.overrideWith((ref) => MockEmployeeAuthNotifier(repo)),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Header info
      expect(find.textContaining('Rahul Das'), findsOneWidget);
      expect(find.textContaining('ID: 20001'), findsOneWidget);

      // Quick count badges
      expect(find.textContaining('Today:'), findsOneWidget);
      expect(find.textContaining('Overdue:'), findsOneWidget);
      expect(find.textContaining('Drafts:'), findsOneWidget);

      // Search field is removed
      expect(
        find.widgetWithText(TextField, 'Search shops by name, code, phone, or owner...'),
        findsNothing,
      );

      // Category filters (only 3: All, Shops, Saloons)
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Shops'), findsOneWidget);
      expect(find.text('Saloons'), findsOneWidget);

      // Guidance banner
      expect(
        find.text('Long-press inside your assigned zone to add a shop'),
        findsOneWidget,
      );
    });
  });

  group('Add Shop Widget Tests', () {
    testWidgets('Renders form fields and validates follow-up mandatory reason', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(
        const AddShopScreen(
          zoneId: 'z-kolkata-central',
          zoneName: 'Kolkata Central Zone',
          latitude: 22.5726,
          longitude: 88.3639,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Add Shop to Assigned Zone'), findsOneWidget);
      expect(find.text('Kolkata Central Zone'), findsOneWidget);
      expect(find.text('Zone Verified'), findsOneWidget);

      // In Agreed mode: Opening Time clock exists, Closing Time is removed
      expect(find.textContaining('Opening Time'), findsOneWidget);
      expect(find.textContaining('Close Time'), findsNothing);

      // Weekly closed days as Bengali bars without dates
      expect(find.text('কোনো বন্ধ নেই'), findsOneWidget);
      expect(find.text('সোম'), findsOneWidget);
      expect(find.text('রবি'), findsOneWidget);

      // Category is displayed in the zone banner from Step 1, not as an editable dropdown
      expect(find.textContaining('Grocery (মুদি দোকান)'), findsOneWidget);
      expect(find.textContaining('Category * (Selected from Map)'), findsNothing);

      // Landmark and Photo URL removed, only Capture Photo box exists
      expect(find.textContaining('Landmark'), findsNothing);
      expect(find.textContaining('Upload / Paste shopfront photo URL'), findsNothing);
      expect(find.text('Capture Shopfront Photo'), findsOneWidget);

      // Switch to Follow-up
      await tester.tap(find.text('Needs Follow-up'));
      await tester.pumpAndSettle();

      // Check follow-up section appears without category dropdown
      expect(find.text('Follow-up Parameters (Mandatory)'), findsOneWidget);
      expect(find.text('Reason for Follow-up *'), findsOneWidget);
      expect(find.text('Phone Number (Optional)'), findsOneWidget);
      expect(find.textContaining('Category * (Selected from Map)'), findsNothing);
      expect(find.textContaining('Landmark'), findsNothing);

      // Save Draft button exists
      expect(find.text('Save as Offline Draft'), findsOneWidget);
    });

    testWidgets('Follow-up revisit time dropdown starts unselected and adheres to clock rules', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(
        const AddShopScreen(
          zoneId: 'z-kolkata-central',
          zoneName: 'Kolkata Central Zone',
          latitude: 22.5726,
          longitude: 88.3639,
        ),
      ));
      await tester.pumpAndSettle();

      // Switch to Follow-up
      await tester.tap(find.text('Needs Follow-up'));
      await tester.pumpAndSettle();

      // Ensure dropdown is visible
      await tester.ensureVisible(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();

      // Dropdown should start with hint 'সময়' and nothing pre-selected
      expect(find.text('সময়'), findsOneWidget);
      expect(find.text('সময় বাছুন'), findsNWidgets(2)); // in header pill and period area
      expect(find.textContaining('সময় নির্বাচন করুন'), findsOneWidget);

      // Open Dropdown
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();

      // Select 11 -> Automatically sokal only
      await tester.tap(find.widgetWithText(DropdownMenuItem<int>, '11').last, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('সকাল'), findsWidgets);
      expect(find.text('দুপুর'), findsNothing);
      expect(find.text('সন্ধ্যা'), findsNothing);

      // Select 2 -> Automatically dupur only
      await tester.tap(find.byType(DropdownButton<int>), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownMenuItem<int>, '2').last, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('দুপুর'), findsWidgets);
      expect(find.text('সকাল'), findsNothing);
      expect(find.text('সন্ধ্যা'), findsNothing);

      // Select 5 -> Automatically bikel only
      await tester.tap(find.byType(DropdownButton<int>), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownMenuItem<int>, '5').last, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('বিকাল'), findsWidgets);
      expect(find.text('সন্ধ্যা'), findsNothing);
      expect(find.text('সকাল'), findsNothing);
      expect(find.text('দুপুর'), findsNothing);

      // Select 6 -> Automatically sondhya only
      await tester.tap(find.byType(DropdownButton<int>), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownMenuItem<int>, '6').last, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('সন্ধ্যা'), findsWidgets);
      expect(find.text('বিকাল'), findsNothing);
      expect(find.text('সকাল'), findsNothing);
      expect(find.text('দুপুর'), findsNothing);

      // Select 8 -> Two options: sokal and rat
      await tester.tap(find.byType(DropdownButton<int>), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownMenuItem<int>, '8').last, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('সকাল'), findsWidgets);
      expect(find.text('রাত'), findsWidgets);
      expect(find.text('দুপুর'), findsNothing);
      expect(find.text('সন্ধ্যা'), findsNothing);
      expect(find.text('বিকাল'), findsNothing);
    });

    testWidgets('Follow-up date starts unselected and enforces date & future time selection', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(
        const AddShopScreen(
          zoneId: 'z-kolkata-central',
          zoneName: 'Kolkata Central Zone',
          latitude: 22.5726,
          longitude: 88.3639,
        ),
      ));
      await tester.pumpAndSettle();

      // Switch to Follow-up
      await tester.tap(find.text('Needs Follow-up'));
      await tester.pumpAndSettle();

      // Ensure banner shows unselected date prompt
      expect(find.textContaining('তারিখ নির্বাচন করুন'), findsOneWidget);

      // Enter Reason
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reason for Follow-up *'),
        'Owner asked to revisit later',
      );
      await tester.pumpAndSettle();

      // Try submitting without date
      await tester.tap(find.text('Save Follow-up Shop'));
      await tester.pumpAndSettle();
      expect(find.text('Please select a revisit date (তারিখ নির্বাচন করুন)!'), findsOneWidget);

      // Select 'আজকে'
      await tester.tap(find.text('আজকে'));
      await tester.pumpAndSettle();

      // Try submitting without time
      await tester.tap(find.text('Save Follow-up Shop'));
      await tester.pumpAndSettle();
      expect(find.text('Please select a revisit time (সময় নির্বাচন করুন)!'), findsOneWidget);
    });
  });

  group('Follow-up Management Widget Tests', () {
    testWidgets('Renders Due Today, Overdue, and All Follow-ups tabs', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const FollowupsListScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Follow-up Management'), findsOneWidget);
      expect(find.text('Due Today'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('All Follow-ups'), findsOneWidget);

      // Overdue tab switch
      await tester.tap(find.text('Overdue'));
      await tester.pumpAndSettle();

      // All Follow-ups tab switch
      await tester.tap(find.text('All Follow-ups'));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
