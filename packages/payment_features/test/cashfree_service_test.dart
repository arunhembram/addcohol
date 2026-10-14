import 'package:flutter_test/flutter_test.dart';
import 'package:payment_features/payment_features.dart';

void main() {
  group('CashfreeConfig & Models Tests', () {
    test('CashfreeConfig correctly recognizes simulator vs real credentials', () {
      const config = CashfreeConfig(
        appId: '',
        secretKey: '',
        environment: CashfreeEnvironment.sandbox,
      );

      expect(config.isSimulator, isTrue);
      expect(config.isProduction, isFalse);
      expect(config.baseUrl, 'https://sandbox.cashfree.com/pg');

      const prodConfig = CashfreeConfig(
        appId: 'CF_LIVE_APP_123',
        secretKey: 'CF_LIVE_SECRET_456',
        environment: CashfreeEnvironment.production,
      );

      expect(prodConfig.isSimulator, isFalse);
      expect(prodConfig.isProduction, isTrue);
      expect(prodConfig.baseUrl, 'https://api.cashfree.com/pg');
    });

    test('CashfreeCustomerDetails serialization', () {
      const customer = CashfreeCustomerDetails(
        customerId: 'cust_001',
        customerName: 'Adani FMCG Ltd',
        customerEmail: 'finance@adani.com',
        customerPhone: '9876543210',
      );

      final json = customer.toJson();
      expect(json['customer_id'], 'cust_001');
      expect(json['customer_name'], 'Adani FMCG Ltd');
      expect(json['customer_email'], 'finance@adani.com');
      expect(json['customer_phone'], '9876543210');
    });

    test('CashfreePaymentResult properties', () {
      final now = DateTime.now();
      final result = CashfreePaymentResult(
        isSuccess: true,
        orderId: 'cf_order_12345',
        cfPaymentId: 'CF_TXN_998877',
        paymentStatus: 'SUCCESS',
        paymentMethod: 'UPI',
        amount: 5250.0,
        referenceId: 'UTR9988776655',
        paidAt: now,
      );

      expect(result.isSuccess, isTrue);
      expect(result.cfPaymentId, 'CF_TXN_998877');
      expect(result.amount, 5250.0);
      expect(result.paymentMethod, 'UPI');
    });
  });

  group('CashfreeService Operations', () {
    test('createOrder in simulator mode generates active order with paymentSessionId', () async {
      final service = CashfreeService(
        config: const CashfreeConfig(
          appId: '',
          secretKey: '',
          environment: CashfreeEnvironment.sandbox,
        ),
      );

      final order = await service.createOrder(
        orderAmount: 14000.0,
        customerDetails: const CashfreeCustomerDetails(
          customerId: 'comp-101',
          customerName: 'Tata Consumer Products',
          customerEmail: 'brand@tataconsumer.com',
          customerPhone: '9876543210',
        ),
        orderNote: 'Week 41 Slot Booking in Zone Howrah',
      );

      expect(order.orderId, startsWith('CF_ORD_'));
      expect(order.orderAmount, 14000.0);
      expect(order.orderCurrency, 'INR');
      expect(order.orderStatus, 'ACTIVE');
      expect(order.paymentSessionId, startsWith('session_sim_'));
    });

    test('simulateSuccessfulPayment returns completed transaction with UTR', () async {
      final service = CashfreeService();

      final result = service.simulateSuccessfulPayment(
        orderId: 'order_test_123',
        amount: 7000.0,
        paymentMethod: 'upi (gpay)',
      );

      expect(result.orderId, 'order_test_123');
      expect(result.paymentStatus, 'SUCCESS');
      expect(result.paymentMethod, 'upi (gpay)');
      expect(result.cfPaymentId, startsWith('CF_TXN_'));
      expect(result.referenceId, startsWith('UTR'));
      expect(result.isSuccess, isTrue);
    });

    test('verifyOrderPayment in simulator mode reports SUCCESS', () async {
      final service = CashfreeService();

      final result = await service.verifyOrderPayment(
        orderId: 'order_test_456',
        orderAmount: 3500.0,
      );

      expect(result.isSuccess, isTrue);
      expect(result.orderId, 'order_test_456');
      expect(result.amount, 3500.0);
    });
  });
}
