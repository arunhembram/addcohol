import 'package:equatable/equatable.dart';

class AuditLog extends Equatable {
  final String id;
  final String? userId;
  final String? userRole;
  final String? userDisplayName;
  final String action;
  final String entityName;
  final String? entityId;
  final Map<String, dynamic> details;
  final String? ipAddress;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    this.userId,
    this.userRole,
    this.userDisplayName,
    required this.action,
    required this.entityName,
    this.entityId,
    this.details = const {},
    this.ipAddress,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String?,
      userRole: json['user_role'] as String?,
      userDisplayName: json['user_display_name'] as String?,
      action: json['action'] as String? ?? 'UNKNOWN',
      entityName: json['entity_name'] as String? ?? '',
      entityId: json['entity_id'] as String?,
      details: json['details'] as Map<String, dynamic>? ?? const {},
      ipAddress: json['ip_address'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_role': userRole,
      'user_display_name': userDisplayName,
      'action': action,
      'entity_name': entityName,
      'entity_id': entityId,
      'details': details,
      'ip_address': ipAddress,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    userRole,
    userDisplayName,
    action,
    entityName,
    entityId,
    details,
    ipAddress,
    createdAt,
  ];
}
