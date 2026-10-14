import 'package:equatable/equatable.dart';

class Company extends Equatable {
  final String id;
  final String legalName;
  final String tradeName;
  final String contactEmail;
  final String? contactPhone;
  final String? address;
  final bool isActive;
  final bool canViewDailyProof;
  final DateTime createdAt;
  final List<String> assignedZoneIds;
  final List<String> assignedZoneNames;

  const Company({
    required this.id,
    required this.legalName,
    required this.tradeName,
    required this.contactEmail,
    this.contactPhone,
    this.address,
    this.isActive = true,
    this.canViewDailyProof = false,
    required this.createdAt,
    this.assignedZoneIds = const [],
    this.assignedZoneNames = const [],
  });

  bool get hasAssignedZones => assignedZoneIds.isNotEmpty;
  String get name => tradeName.isNotEmpty
      ? tradeName
      : (legalName.isNotEmpty ? legalName : 'Company');
  String get phone => contactPhone ?? '';

  factory Company.fromJson(
    Map<String, dynamic> json, {
    List<String>? zoneIds,
    List<String>? zoneNames,
  }) {
    return Company(
      id: json['id'] as String? ?? '',
      legalName: json['legal_name'] as String? ?? json['name'] as String? ?? '',
      tradeName: json['trade_name'] as String? ?? json['name'] as String? ?? '',
      contactEmail: json['contact_email'] as String? ?? json['billing_email'] as String? ?? '',
      contactPhone: json['contact_phone'] as String? ?? json['phone'] as String?,
      address: json['address'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      canViewDailyProof: json['can_view_daily_proof'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      assignedZoneIds:
          zoneIds ??
          (json['assigned_zone_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      assignedZoneNames:
          zoneNames ??
          (json['assigned_zone_names'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'legal_name': legalName,
      'trade_name': tradeName,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'address': address,
      'is_active': isActive,
      'can_view_daily_proof': canViewDailyProof,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Company copyWith({
    String? id,
    String? legalName,
    String? tradeName,
    String? contactEmail,
    String? contactPhone,
    String? address,
    bool? isActive,
    bool? canViewDailyProof,
    DateTime? createdAt,
    List<String>? assignedZoneIds,
    List<String>? assignedZoneNames,
  }) {
    return Company(
      id: id ?? this.id,
      legalName: legalName ?? this.legalName,
      tradeName: tradeName ?? this.tradeName,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      canViewDailyProof: canViewDailyProof ?? this.canViewDailyProof,
      createdAt: createdAt ?? this.createdAt,
      assignedZoneIds: assignedZoneIds ?? this.assignedZoneIds,
      assignedZoneNames: assignedZoneNames ?? this.assignedZoneNames,
    );
  }

  @override
  List<Object?> get props => [
    id,
    legalName,
    tradeName,
    contactEmail,
    contactPhone,
    address,
    isActive,
    canViewDailyProof,
    createdAt,
    assignedZoneIds,
    assignedZoneNames,
  ];
}
