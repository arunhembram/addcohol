import 'package:equatable/equatable.dart';

class ZoneVertex extends Equatable {
  final String? id;
  final String? zoneId;
  final int sequenceOrder;
  final double latitude;
  final double longitude;

  const ZoneVertex({
    this.id,
    this.zoneId,
    required this.sequenceOrder,
    required this.latitude,
    required this.longitude,
  });

  factory ZoneVertex.fromJson(Map<String, dynamic> json) {
    return ZoneVertex(
      id: json['id'] as String?,
      zoneId: json['zone_id'] as String?,
      sequenceOrder: (json['sequence_order'] as num?)?.toInt() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (zoneId != null) 'zone_id': zoneId,
      'sequence_order': sequenceOrder,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  ZoneVertex copyWith({
    String? id,
    String? zoneId,
    int? sequenceOrder,
    double? latitude,
    double? longitude,
  }) {
    return ZoneVertex(
      id: id ?? this.id,
      zoneId: zoneId ?? this.zoneId,
      sequenceOrder: sequenceOrder ?? this.sequenceOrder,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  List<Object?> get props => [id, zoneId, sequenceOrder, latitude, longitude];
}

class Zone extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String colorHex;
  final bool isActive;
  final bool isArchived;
  final String? createdByAdminId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ZoneVertex> vertices;
  final String? assignedAdminId;
  final String? assignedAdminName;
  final String? assignedCompanyId;
  final String? assignedCompanyName;
  final int shopCount;
  final bool isDistributionMode;

  const Zone({
    required this.id,
    required this.name,
    this.description,
    this.colorHex = '#1E88E5',
    this.isActive = true,
    this.isArchived = false,
    this.createdByAdminId,
    required this.createdAt,
    required this.updatedAt,
    this.vertices = const [],
    this.assignedAdminId,
    this.assignedAdminName,
    this.assignedCompanyId,
    this.assignedCompanyName,
    this.shopCount = 0,
    this.isDistributionMode = false,
  });

  factory Zone.fromJson(Map<String, dynamic> json, {List<ZoneVertex>? vertices}) {
    final rawVertices =
        vertices ??
        (json['zone_vertices'] as List<dynamic>?)
            ?.map((v) => ZoneVertex.fromJson(v as Map<String, dynamic>))
            .toList() ??
        const [];

    // Sort vertices by sequence_order
    final sortedVertices = List<ZoneVertex>.from(rawVertices)
      ..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));

    return Zone(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      colorHex: json['color_hex'] as String? ?? '#1E88E5',
      isActive: json['is_active'] as bool? ?? true,
      isArchived: json['is_archived'] as bool? ?? false,
      createdByAdminId: json['created_by_admin_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      vertices: sortedVertices,
      assignedAdminId: json['assigned_admin_id'] as String?,
      assignedAdminName: json['assigned_admin_name'] as String?,
      assignedCompanyId: json['assigned_company_id'] as String?,
      assignedCompanyName: json['assigned_company_name'] as String?,
      shopCount: (json['shop_count'] as num?)?.toInt() ?? 0,
      isDistributionMode: json['is_distribution_mode'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color_hex': colorHex,
      'is_active': isActive,
      'is_archived': isArchived,
      'created_by_admin_id': createdByAdminId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_distribution_mode': isDistributionMode,
      'assigned_admin_id': assignedAdminId,
      'assigned_admin_name': assignedAdminName,
      'assigned_company_id': assignedCompanyId,
      'assigned_company_name': assignedCompanyName,
      'shop_count': shopCount,
      'zone_vertices': vertices.map((v) => v.toJson()).toList(),
    };
  }

  Zone copyWith({
    String? id,
    String? name,
    String? description,
    String? colorHex,
    bool? isActive,
    bool? isArchived,
    String? createdByAdminId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ZoneVertex>? vertices,
    String? assignedAdminId,
    String? assignedAdminName,
    String? assignedCompanyId,
    String? assignedCompanyName,
    int? shopCount,
    bool? isDistributionMode,
  }) {
    return Zone(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      createdByAdminId: createdByAdminId ?? this.createdByAdminId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vertices: vertices ?? this.vertices,
      assignedAdminId: assignedAdminId ?? this.assignedAdminId,
      assignedAdminName: assignedAdminName ?? this.assignedAdminName,
      assignedCompanyId: assignedCompanyId ?? this.assignedCompanyId,
      assignedCompanyName: assignedCompanyName ?? this.assignedCompanyName,
      shopCount: shopCount ?? this.shopCount,
      isDistributionMode: isDistributionMode ?? this.isDistributionMode,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    colorHex,
    isActive,
    isArchived,
    createdByAdminId,
    createdAt,
    updatedAt,
    vertices,
    assignedAdminId,
    assignedAdminName,
    assignedCompanyId,
    assignedCompanyName,
    shopCount,
    isDistributionMode,
  ];
}
