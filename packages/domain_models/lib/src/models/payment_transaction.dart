import 'package:equatable/equatable.dart';

class PaymentTransaction extends Equatable {
  final String id;
  final String? campaignId;
  final String userId;
  final double amount;
  final String currency;
  final String status;
  final String method;
  final String? gatewayReference;
  final DateTime createdAt;

  const PaymentTransaction({
    required this.id,
    this.campaignId,
    required this.userId,
    required this.amount,
    this.currency = 'BDT',
    required this.status,
    this.method = 'mock_bkash',
    this.gatewayReference,
    required this.createdAt,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id'] as String? ?? '',
      campaignId: json['campaign_id'] as String?,
      userId: json['user_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'BDT',
      status: json['status'] as String? ?? 'pending',
      method: json['method'] as String? ?? 'mock_bkash',
      gatewayReference: json['gateway_reference'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'user_id': userId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'method': method,
      'gateway_reference': gatewayReference,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isSuccessful => status.toLowerCase() == 'success' || status.toLowerCase() == 'completed';

  @override
  List<Object?> get props => [
    id,
    campaignId,
    userId,
    amount,
    currency,
    status,
    method,
    gatewayReference,
    createdAt,
  ];
}
