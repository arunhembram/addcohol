import 'package:equatable/equatable.dart';
import '../enums/payment_session_status.dart';

class PaymentSession extends Equatable {
  final String id;
  final String shopId;
  final String? shopName;
  final String? ownerName;
  final String? shopCode;
  final String? employeeId;
  final String? employeeName;
  final double? amount;
  final String currency;
  final PaymentSessionStatus status;
  final String? qrToken;
  final String? qrTokenHash;
  final String? transactionReference;
  final String? rejectionReason;
  final DateTime expiresAt;
  final DateTime? scannedAt;
  final DateTime? confirmedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PaymentSession({
    required this.id,
    required this.shopId,
    this.shopName,
    this.ownerName,
    this.shopCode,
    this.employeeId,
    this.employeeName,
    this.amount,
    this.currency = 'INR',
    required this.status,
    this.qrToken,
    this.qrTokenHash,
    this.transactionReference,
    this.rejectionReason,
    required this.expiresAt,
    this.scannedAt,
    this.confirmedAt,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isExpired =>
      DateTime.now().isAfter(expiresAt) && status == PaymentSessionStatus.created;

  bool get isAwaitingConfirmation =>
      status == PaymentSessionStatus.awaitingConfirmation ||
      status == PaymentSessionStatus.amountSubmitted;

  bool get isConfirmed => status == PaymentSessionStatus.confirmed;

  bool get isRejected => status == PaymentSessionStatus.rejected;

  factory PaymentSession.fromJson(Map<String, dynamic> json) {
    return PaymentSession(
      id: json['id'] as String? ?? json['session_id'] as String? ?? '',
      shopId: json['shop_id'] as String? ?? '',
      shopName: json['shop_name'] as String?,
      ownerName: json['owner_name'] as String?,
      shopCode: json['shop_code'] as String?,
      employeeId:
          json['employee_id'] as String? ??
          json['scanned_by_employee_id'] as String?,
      employeeName: json['employee_name'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      status: PaymentSessionStatus.fromString(json['status'] as String?),
      qrToken: json['qr_token'] as String?,
      qrTokenHash: json['qr_token_hash'] as String?,
      transactionReference: json['transaction_reference'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String) ??
              DateTime.now().add(const Duration(seconds: 15))
          : DateTime.now().add(const Duration(seconds: 15)),
      scannedAt: json['scanned_at'] != null
          ? DateTime.tryParse(json['scanned_at'] as String)
          : null,
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.tryParse(json['confirmed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'shop_name': shopName,
      'owner_name': ownerName,
      'shop_code': shopCode,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'amount': amount,
      'currency': currency,
      'status': status.apiValue,
      'qr_token': qrToken,
      'qr_token_hash': qrTokenHash,
      'transaction_reference': transactionReference,
      'rejection_reason': rejectionReason,
      'expires_at': expiresAt.toIso8601String(),
      'scanned_at': scannedAt?.toIso8601String(),
      'confirmed_at': confirmedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  PaymentSession copyWith({
    String? id,
    String? shopId,
    String? shopName,
    String? ownerName,
    String? shopCode,
    String? employeeId,
    String? employeeName,
    double? amount,
    String? currency,
    PaymentSessionStatus? status,
    String? qrToken,
    String? qrTokenHash,
    String? transactionReference,
    String? rejectionReason,
    DateTime? expiresAt,
    DateTime? scannedAt,
    DateTime? confirmedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentSession(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      ownerName: ownerName ?? this.ownerName,
      shopCode: shopCode ?? this.shopCode,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      qrToken: qrToken ?? this.qrToken,
      qrTokenHash: qrTokenHash ?? this.qrTokenHash,
      transactionReference: transactionReference ?? this.transactionReference,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      expiresAt: expiresAt ?? this.expiresAt,
      scannedAt: scannedAt ?? this.scannedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    shopId,
    shopName,
    ownerName,
    shopCode,
    employeeId,
    employeeName,
    amount,
    currency,
    status,
    qrToken,
    qrTokenHash,
    transactionReference,
    rejectionReason,
    expiresAt,
    scannedAt,
    confirmedAt,
    createdAt,
    updatedAt,
  ];
}
