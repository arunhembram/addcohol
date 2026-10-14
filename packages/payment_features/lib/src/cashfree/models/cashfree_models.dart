import 'package:equatable/equatable.dart';

/// Supported Cashfree operational environments
enum CashfreeEnvironment {
  sandbox,
  production,
}

/// Configuration settings for Cashfree Payment Gateway
class CashfreeConfig extends Equatable {
  final String appId;
  final String secretKey;
  final CashfreeEnvironment environment;
  final String apiVersion;
  final String? returnUrl;
  final String? notifyUrl;
  final bool isSimulator;

  const CashfreeConfig({
    this.appId = '',
    this.secretKey = '',
    this.environment = CashfreeEnvironment.sandbox,
    this.apiVersion = '2023-08-01',
    this.returnUrl,
    this.notifyUrl,
    bool? isSimulator,
  }) : isSimulator = isSimulator ?? (appId == '' || secretKey == '');

  String get baseUrl => environment == CashfreeEnvironment.production
      ? 'https://api.cashfree.com/pg'
      : 'https://sandbox.cashfree.com/pg';

  bool get isProduction => environment == CashfreeEnvironment.production;

  /// Factory pulling configuration from dart-define or defaults
  factory CashfreeConfig.fromEnvironment() {
    const envAppId = String.fromEnvironment('CASHFREE_APP_ID', defaultValue: '');
    const envSecretKey = String.fromEnvironment('CASHFREE_SECRET_KEY', defaultValue: '');
    const envMode = String.fromEnvironment('CASHFREE_ENV', defaultValue: 'sandbox');

    final environment = envMode.toLowerCase() == 'production'
        ? CashfreeEnvironment.production
        : CashfreeEnvironment.sandbox;

    return CashfreeConfig(
      appId: envAppId,
      secretKey: envSecretKey,
      environment: environment,
      isSimulator: envAppId.isEmpty || envSecretKey.isEmpty,
    );
  }

  @override
  List<Object?> get props => [appId, secretKey, environment, apiVersion, returnUrl, notifyUrl, isSimulator];
}

/// Customer details required by Cashfree Order API
class CashfreeCustomerDetails extends Equatable {
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerEmail;

  const CashfreeCustomerDetails({
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail = 'billing@customer.com',
  });

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_email': customerEmail,
      };

  factory CashfreeCustomerDetails.fromJson(Map<String, dynamic> json) => CashfreeCustomerDetails(
        customerId: json['customer_id'] as String? ?? '',
        customerName: json['customer_name'] as String? ?? '',
        customerPhone: json['customer_phone'] as String? ?? '',
        customerEmail: json['customer_email'] as String? ?? 'billing@customer.com',
      );

  @override
  List<Object?> get props => [customerId, customerName, customerPhone, customerEmail];
}

/// Represents an Order initiated in Cashfree
class CashfreeOrder extends Equatable {
  final String orderId;
  final double orderAmount;
  final String orderCurrency;
  final CashfreeCustomerDetails customerDetails;
  final String? cfOrderId;
  final String? paymentSessionId;
  final String orderStatus; // 'ACTIVE', 'PAID', 'EXPIRED', 'FAILED'
  final String? orderNote;
  final String? bookingId;
  final DateTime createdAt;

  const CashfreeOrder({
    required this.orderId,
    required this.orderAmount,
    this.orderCurrency = 'INR',
    required this.customerDetails,
    this.cfOrderId,
    this.paymentSessionId,
    this.orderStatus = 'ACTIVE',
    this.orderNote,
    this.bookingId,
    required this.createdAt,
  });

  bool get isPaid => orderStatus.toUpperCase() == 'PAID';

  Map<String, dynamic> toJson() => {
        'order_id': orderId,
        'order_amount': orderAmount,
        'order_currency': orderCurrency,
        'customer_details': customerDetails.toJson(),
        if (cfOrderId != null) 'cf_order_id': cfOrderId,
        if (paymentSessionId != null) 'payment_session_id': paymentSessionId,
        'order_status': orderStatus,
        if (orderNote != null) 'order_note': orderNote,
        'created_at': createdAt.toIso8601String(),
      };

  factory CashfreeOrder.fromJson(Map<String, dynamic> json) => CashfreeOrder(
        orderId: json['order_id'] as String? ?? '',
        orderAmount: (json['order_amount'] as num?)?.toDouble() ?? 0.0,
        orderCurrency: json['order_currency'] as String? ?? 'INR',
        customerDetails: json['customer_details'] is Map<String, dynamic>
            ? CashfreeCustomerDetails.fromJson(json['customer_details'] as Map<String, dynamic>)
            : const CashfreeCustomerDetails(customerId: 'cust_001', customerName: 'Guest', customerPhone: '9999999999'),
        cfOrderId: json['cf_order_id']?.toString(),
        paymentSessionId: json['payment_session_id']?.toString(),
        orderStatus: json['order_status'] as String? ?? 'ACTIVE',
        orderNote: json['order_note'] as String?,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      );

  @override
  List<Object?> get props => [orderId, orderAmount, orderCurrency, customerDetails, cfOrderId, paymentSessionId, orderStatus, createdAt];
}

/// Final payment transaction outcome returned by Cashfree
class CashfreePaymentResult extends Equatable {
  final bool isSuccess;
  final String orderId;
  final String? cfOrderId;
  final String? cfPaymentId;
  final String paymentMethod; // 'UPI', 'CARD', 'NETBANKING', 'WALLET'
  final String paymentStatus; // 'SUCCESS', 'FAILED', 'CANCELLED', 'PENDING'
  final String? referenceId; // UTR or Bank Ref Number
  final String? bankReference;
  final double amount;
  final String? errorMessage;
  final DateTime? paidAt;
  final Map<String, dynamic>? rawResponse;

  const CashfreePaymentResult({
    required this.isSuccess,
    required this.orderId,
    this.cfOrderId,
    this.cfPaymentId,
    this.paymentMethod = 'UPI',
    this.paymentStatus = 'SUCCESS',
    this.referenceId,
    this.bankReference,
    required this.amount,
    this.errorMessage,
    this.paidAt,
    this.rawResponse,
  });

  factory CashfreePaymentResult.cancelled(String orderId, double amount) => CashfreePaymentResult(
        isSuccess: false,
        orderId: orderId,
        paymentStatus: 'CANCELLED',
        amount: amount,
        errorMessage: 'Payment cancelled by user',
      );

  factory CashfreePaymentResult.failed(String orderId, double amount, String error) => CashfreePaymentResult(
        isSuccess: false,
        orderId: orderId,
        paymentStatus: 'FAILED',
        amount: amount,
        errorMessage: error,
      );

  @override
  List<Object?> get props => [isSuccess, orderId, cfOrderId, cfPaymentId, paymentMethod, paymentStatus, referenceId, amount, errorMessage];
}
