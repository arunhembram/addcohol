import 'package:equatable/equatable.dart';

class ShopFollowup extends Equatable {
  final String id;
  final String shopId;
  final String shopName;
  final String employeeId;
  final String employeeName;
  final String notes;
  final String outcome;
  final DateTime? nextFollowupDate;
  final DateTime createdAt;

  const ShopFollowup({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.employeeId,
    required this.employeeName,
    required this.notes,
    required this.outcome,
    this.nextFollowupDate,
    required this.createdAt,
  });

  factory ShopFollowup.fromJson(Map<String, dynamic> json) {
    return ShopFollowup(
      id: json['id'] as String? ?? '',
      shopId: json['shop_id'] as String? ?? '',
      shopName: json['shop_name'] as String? ?? 'Shop',
      employeeId: json['employee_id'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? 'Employee',
      notes: json['notes'] as String? ?? '',
      outcome: json['outcome'] as String? ?? 'Pending',
      nextFollowupDate: json['next_followup_date'] != null
          ? DateTime.tryParse(json['next_followup_date'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'shop_name': shopName,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'notes': notes,
      'outcome': outcome,
      if (nextFollowupDate != null)
        'next_followup_date': nextFollowupDate!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    shopId,
    shopName,
    employeeId,
    employeeName,
    notes,
    outcome,
    nextFollowupDate,
    createdAt,
  ];
}
