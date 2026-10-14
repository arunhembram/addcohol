import 'package:data_repository/data_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shopkeeper_app/screens/payments/accept_payment_screen.dart';
import 'package:shopkeeper_app/providers/shopkeeper_payment_providers.dart';

void main() {
  group('Shopkeeper Payment Acknowledgement Widget Tests', () {
    late SupabasePaymentAcknowledgementRepository mockRepo;

    setUp(() {
      mockRepo = SupabasePaymentAcknowledgementRepository();
    });

    testWidgets('1. Renders AcceptPaymentScreen with disclaimer and opaque QR code', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentAcknowledgementRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: AcceptPaymentScreen(),
          ),
        ),
      );

      // Verify disclaimer banner is present
      expect(find.textContaining('Field Payment Acknowledgement only'), findsOneWidget);
      expect(find.textContaining('Does not transfer money via UPI/card'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));

      // Verify QR Code image is displayed
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Scan to Acknowledge Payment'), findsOneWidget);
      expect(find.textContaining('Server expiry enforced'), findsOneWidget);
    });

    testWidgets('2. Immediately removes usable QR once scanned and shows Payment pending confirmation', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentAcknowledgementRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: AcceptPaymentScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      final container = ProviderScope.containerOf(tester.element(find.byType(AcceptPaymentScreen)));
      final session = container.read(acceptPaymentProvider).session;
      expect(session, isNotNull);

      // Simulate Employee scanning the QR and submitting amount
      await mockRepo.scanPaymentQr(
        qrToken: session!.qrToken!,
        employeeId: 'emp_test_1',
        employeeName: 'Rahul Sen',
      );
      await mockRepo.submitPaymentAmount(
        sessionId: session.id,
        amount: 3500.0,
      );

      // Pump to reflect real-time update
      await tester.pump(const Duration(milliseconds: 100));

      // QR Code must NOT be visible anymore
      expect(find.byType(QrImageView), findsNothing, reason: 'Usable QR must immediately disappear upon scan');

      // Pending confirmation screen displayed
      expect(find.text('Payment pending confirmation'), findsOneWidget);
      expect(find.text('Rahul Sen'), findsOneWidget);
      expect(find.text('₹3500'), findsOneWidget);
      expect(find.text('Confirm amount received'), findsOneWidget);
      expect(find.text('Reject / Incorrect amount'), findsOneWidget);
    });

    testWidgets('3. Confirm amount received displays exact status "Received ₹[amount]"', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentAcknowledgementRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: AcceptPaymentScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      final container = ProviderScope.containerOf(tester.element(find.byType(AcceptPaymentScreen)));
      final session = container.read(acceptPaymentProvider).session!;

      // Employee scans and submits ₹2500
      await mockRepo.scanPaymentQr(
        qrToken: session.qrToken!,
        employeeId: 'emp_test_1',
        employeeName: 'Rahul Sen',
      );
      await mockRepo.submitPaymentAmount(
        sessionId: session.id,
        amount: 2500.0,
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Shopkeeper taps "Confirm amount received"
      final confirmBtn = find.text('Confirm amount received');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);

      await tester.pump(const Duration(milliseconds: 100));

      // Exact status message assertion: "Received ₹2500"
      expect(find.text('Received ₹2500'), findsOneWidget);
      expect(find.textContaining('successfully recorded'), findsOneWidget);
    });
  });
}
