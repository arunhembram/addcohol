import 'package:data_repository/data_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:employee_app/screens/payment/employee_payment_flow_screen.dart';
import 'package:employee_app/providers/employee_payment_providers.dart';

void main() {
  group('Employee Payment Flow Widget & State Tests', () {
    late SupabasePaymentAcknowledgementRepository mockRepo;

    setUp(() {
      mockRepo = SupabasePaymentAcknowledgementRepository();
    });

    testWidgets('1. Renders scanner view and system disclaimer', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentAcknowledgementRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: EmployeePaymentFlowScreen(),
          ),
        ),
      );

      // Verify system disclaimer banner
      expect(find.textContaining('Field Payment Acknowledgement only'), findsOneWidget);
      expect(find.textContaining('Does not transfer money via UPI/card'), findsOneWidget);

      // Verify scanner header
      expect(find.text('Scan Shopkeeper QR Code'), findsOneWidget);
    });

    testWidgets('2. Valid scan transitions to positive amount entry and rejects negative amount', (tester) async {
      final session = await mockRepo.createPaymentSession(shopId: '10000001');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentAcknowledgementRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: EmployeePaymentFlowScreen(),
          ),
        ),
      );

      final container = ProviderScope.containerOf(tester.element(find.byType(EmployeePaymentFlowScreen)));
      final notifier = container.read(employeePaymentFlowProvider.notifier);

      // Employee scans the QR token
      await notifier.scanQrToken(session.qrToken!);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify transitioned to amount entry step
      expect(find.text('Enter Acknowledged Amount'), findsOneWidget);
      expect(find.text('Submit Payment Amount'), findsOneWidget);

      // Attempt submitting invalid zero/negative amount
      await notifier.submitAmount(0.0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('positive INR number'), findsOneWidget);

      // Enter valid positive INR amount
      await notifier.submitAmount(1800.0);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify transitioned to awaiting confirmation step
      expect(find.text('Awaiting shopkeeper confirmation'), findsOneWidget);
      expect(find.textContaining('Submitted ₹1800 to Tarun Banerjee'), findsOneWidget);
    });

    testWidgets('3. Replay Prevention: Attempting to scan the same QR twice displays error banner', (tester) async {
      final session = await mockRepo.createPaymentSession(shopId: '10000001');

      // First device scans
      await mockRepo.scanPaymentQr(
        qrToken: session.qrToken!,
        employeeId: 'emp_01',
        employeeName: 'Officer 1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentAcknowledgementRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: EmployeePaymentFlowScreen(),
          ),
        ),
      );

      final container = ProviderScope.containerOf(tester.element(find.byType(EmployeePaymentFlowScreen)));
      final notifier = container.read(employeePaymentFlowProvider.notifier);

      // Second device/attempt scans the same token
      await notifier.scanQrToken(session.qrToken!);
      await tester.pump(const Duration(milliseconds: 100));

      // Must display already-scanned error banner
      expect(find.textContaining('already been scanned'), findsOneWidget);
      expect(container.read(employeePaymentFlowProvider).step, EmployeePaymentStep.scanning);
    });

    testWidgets('4. Shopkeeper confirmation triggers exact status "₹[amount] paid successfully to [owner name]"', (tester) async {
      final session = await mockRepo.createPaymentSession(shopId: '10000001');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentAcknowledgementRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: EmployeePaymentFlowScreen(),
          ),
        ),
      );

      final container = ProviderScope.containerOf(tester.element(find.byType(EmployeePaymentFlowScreen)));
      final notifier = container.read(employeePaymentFlowProvider.notifier);

      // Scan and submit ₹4500
      await notifier.scanQrToken(session.qrToken!);
      await tester.pump(const Duration(milliseconds: 100));

      await notifier.submitAmount(4500.0);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Awaiting shopkeeper confirmation'), findsOneWidget);

      // Simulate Shopkeeper tapping "Confirm amount received" on their device
      await mockRepo.confirmPaymentReceived(sessionId: session.id);
      await tester.pump(const Duration(milliseconds: 100));

      // Exact status message assertion: "₹4500 paid successfully to Tarun Banerjee"
      expect(find.text('₹4500 paid successfully to Tarun Banerjee'), findsOneWidget);
      expect(find.text('Return to Zone Map'), findsOneWidget);
    });
  });
}
