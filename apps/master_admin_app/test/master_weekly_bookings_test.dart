import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_admin_app/screens/master_weekly_bookings_screen.dart';

void main() {
  testWidgets('MasterWeeklyBookingsScreen renders booked weekly slots and opens zone cards', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Pump the MasterWeeklyBookingsScreen
    await tester.pumpWidget(
      const MaterialApp(
        home: MasterWeeklyBookingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 2. Verify header and slots list rendered
    expect(find.text('Weekly Booking Status & Progress'), findsOneWidget);
    expect(find.text('Active Campaign Week Slots'), findsOneWidget);

    // 3. Verify "View Bookings" stadium capsule button exists
    final anyViewBookings = find.byType(ElevatedButton);
    expect(anyViewBookings, findsWidgets);

    // 4. Tap the first "View Bookings" button
    await tester.tap(anyViewBookings.first);
    await tester.pumpAndSettle();

    // 5. Verify the window opened with MULTIPLE Zone Cards & Tables
    expect(find.text('Back to Weekly Slots'), findsOneWidget);
    // Multiple zone cards each have their own table headers!
    expect(find.text('COMPANY NAME'), findsWidgets);
    expect(find.text('LIVE IN REMAINING DAYS'), findsWidgets);
    expect(find.text('AD DESIGN\n(TASK 1)'), findsWidgets);
    expect(find.text('PRINT OUT\n(TASK 2)'), findsWidgets);
    expect(find.text('DISTRIBUTION\n(TASK 3)'), findsWidgets);

    // 6. Verify Call Admin button exists on zone card
    expect(find.text('Call Admin'), findsWidgets);

    // 7. Tap "Call Admin" to test popup
    await tester.tap(find.text('Call Admin').first);
    await tester.pumpAndSettle();

    // 8. Verify Calling Popup dialog details
    expect(find.text('Call Admin Now'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    // 9. Close popup
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // 10. Verify back button returns to slots list
    await tester.tap(find.text('Back to Weekly Slots'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly Booking Status & Progress'), findsOneWidget);
  });
}
