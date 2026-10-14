import 'package:equatable/equatable.dart';

/// Represents a booking request or completed booking of advertisement space on QR payment stands.
class AdSpaceBooking extends Equatable {
  final String id;
  final String companyId;
  final String companyName;
  final String zoneId;
  final String zoneName;
  final String businessType; // 'shops' or 'saloons'
  final String adSize; // 'A5' or 'A6'
  final String sideOption; // 'both' or 'one'
  final double pricePerLocation;
  final int eligibleLocationCount;
  final double totalAmount;
  final String status; // 'pending_payment', 'confirmed', 'active'
  final DateTime createdAt;
  final DateTime? slotStartDate;
  final DateTime? slotEndDate;
  final int selectedWeeksCount;
  final List<String> selectedSlotLabels;
  final String? paymentMethod;
  final String? paymentId;
  final String? orderId;
  final DateTime? paidAt;

  const AdSpaceBooking({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.zoneId,
    required this.zoneName,
    required this.businessType,
    required this.adSize,
    required this.sideOption,
    required this.pricePerLocation,
    required this.eligibleLocationCount,
    required this.totalAmount,
    this.status = 'pending_payment',
    required this.createdAt,
    this.slotStartDate,
    this.slotEndDate,
    this.selectedWeeksCount = 1,
    this.selectedSlotLabels = const [],
    this.paymentMethod,
    this.paymentId,
    this.orderId,
    this.paidAt,
  });

  factory AdSpaceBooking.fromJson(Map<String, dynamic> json) {
    return AdSpaceBooking(
      id: json['id'] as String? ?? '',
      companyId: json['company_id'] as String? ?? '',
      companyName: json['company_name'] as String? ?? '',
      zoneId: json['zone_id'] as String? ?? '',
      zoneName: json['zone_name'] as String? ?? '',
      businessType: json['business_type'] as String? ?? 'shops',
      adSize: json['ad_size'] as String? ?? 'A5',
      sideOption: json['side_option'] as String? ?? 'both',
      pricePerLocation: (json['price_per_location'] as num?)?.toDouble() ?? 0.0,
      eligibleLocationCount: (json['eligible_location_count'] as num?)?.toInt() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending_payment',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      slotStartDate: json['slot_start_date'] != null
          ? DateTime.tryParse(json['slot_start_date'] as String)
          : null,
      slotEndDate: json['slot_end_date'] != null
          ? DateTime.tryParse(json['slot_end_date'] as String)
          : null,
      selectedWeeksCount: (json['selected_weeks_count'] as num?)?.toInt() ?? 1,
      selectedSlotLabels: (json['selected_slot_labels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      paymentMethod: json['payment_method'] as String?,
      paymentId: json['payment_id'] as String?,
      orderId: json['order_id'] as String?,
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'company_name': companyName,
      'zone_id': zoneId,
      'zone_name': zoneName,
      'business_type': businessType,
      'ad_size': adSize,
      'side_option': sideOption,
      'price_per_location': pricePerLocation,
      'eligible_location_count': eligibleLocationCount,
      'total_amount': totalAmount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      if (slotStartDate != null)
        'slot_start_date': slotStartDate!.toIso8601String(),
      if (slotEndDate != null) 'slot_end_date': slotEndDate!.toIso8601String(),
      'selected_weeks_count': selectedWeeksCount,
      'selected_slot_labels': selectedSlotLabels,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (paymentId != null) 'payment_id': paymentId,
      if (orderId != null) 'order_id': orderId,
      if (paidAt != null) 'paid_at': paidAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        companyId,
        companyName,
        zoneId,
        zoneName,
        businessType,
        adSize,
        sideOption,
        pricePerLocation,
        eligibleLocationCount,
        totalAmount,
        status,
        createdAt,
        slotStartDate,
        slotEndDate,
        selectedWeeksCount,
        selectedSlotLabels,
        paymentMethod,
        paymentId,
        orderId,
        paidAt,
      ];
}
