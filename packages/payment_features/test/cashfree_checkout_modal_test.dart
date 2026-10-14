import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_features/payment_features.dart';

void main() {
  Widget buildTestModal({
    required double amount,
    required String orderTitle,
    required String customerName,
    required String customerPhone,
    Function(CashfreePaymentResult)? onResult,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await CashfreeCheckoutModal.show(
                    context,
                    amount: amount,
                    orderTitle: orderTitle,
                    customerName: customerName,
                    customerPhone: customerPhone,
                  );
                  if (result != null && onResult != null) {
                    onResult(result);
                  }
                },
                child: const Text('Open Cashfree Checkout'),
              ),
            );
          },
        ),
      ),
    );
  }

  testWidgets('CashfreeCheckoutModal opens, displays tabs, and completes UPI payment', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    CashfreePaymentResult? paymentResult;

    await tester.pumpWidget(buildTestModal(
      amount: 4500.0,
      orderTitle: 'Howrah Central • 2w Campaign',
      customerName: 'ITC Limited',
      customerPhone: '9830012345',
      onResult: (res) => paymentResult = res,
    ));

    // Tap button to open Cashfree Checkout Modal
    await tester.tap(find.text('Open Cashfree Checkout'));
    await tester.pumpAndSettle();

    // Verify Cashfree Header & Badges
    expect(find.text('Cashfree'), findsOneWidget);
    expect(find.text(' Payments'), findsOneWidget);
    expect(find.text('SANDBOX'), findsOneWidget);
    expect(find.text('Howrah Central • 2w Campaign'), findsOneWidget);
    expect(find.text('₹4500'), findsOneWidget);

    // Verify Payment Tabs
    expect(find.text('UPI / QR'), findsOneWidget);
    expect(find.text('Cards'), findsOneWidget);
    expect(find.text('NetBanking'), findsOneWidget);

    // Verify UPI App Chips
    expect(find.text('GPay'), findsOneWidget);
    expect(find.text('PhonePe'), findsOneWidget);
    expect(find.text('Paytm'), findsOneWidget);
    expect(find.text('BHIM'), findsOneWidget);

    // Tap GPay quick pay chip
    await tester.tap(find.text('GPay'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Verify Success Screen
    expect(find.text('Payment Successful!'), findsOneWidget);
    expect(find.text('Bank Reference (UTR)'), findsOneWidget);

    // Tap Return button
    await tester.tap(find.text('Proceed to Confirmed Campaign'));
    await tester.pumpAndSettle();

    // Verify payment outcome
    expect(paymentResult, isNotNull);
    expect(paymentResult!.isSuccess, isTrue);
    expect(paymentResult!.amount, 4500.0);
    expect(paymentResult!.cfPaymentId, startsWith('CF_TXN_'));
  });

  testWidgets('CashfreeCheckoutModal NetBanking tab displays popular banks', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    await tester.pumpWidget(buildTestModal(
      amount: 10000.0,
      orderTitle: 'Salt Lake Campaign',
      customerName: 'Tata Consumer',
      customerPhone: '9876543210',
    ));

    await tester.tap(find.text('Open Cashfree Checkout'));
    await tester.pumpAndSettle();

    // Switch to NetBanking tab
    await tester.tap(find.text('NetBanking'));
    await tester.pumpAndSettle();

    // Popular banks should be visible
    expect(find.text('HDFC Bank'), findsWidgets);
    expect(find.text('State Bank of India'), findsWidgets);
    expect(find.text('Axis Bank'), findsWidgets);
    expect(find.text('Pay via HDFC Bank'), findsOneWidget);
  });
}
