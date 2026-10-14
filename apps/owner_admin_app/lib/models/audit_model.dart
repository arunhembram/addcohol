class AuditLogModel {
  final String id;
  final String? actorUserId;
  final String actorName;
  final String actionType;
  final String entityType;
  final String entityId;
  final String? oldValueJson;
  final String? newValueJson;
  final String createdAt;

  AuditLogModel({
    required this.id,
    this.actorUserId,
    required this.actorName,
    required this.actionType,
    required this.entityType,
    required this.entityId,
    this.oldValueJson,
    this.newValueJson,
    required this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'] ?? '',
      actorUserId: json['actor_user_id'],
      actorName: json['actor_name'] ?? 'System',
      actionType: json['action_type'] ?? '',
      entityType: json['entity_type'] ?? '',
      entityId: json['entity_id'] ?? '',
      oldValueJson: json['old_value_json'],
      newValueJson: json['new_value_json'],
      createdAt: json['created_at'] ?? '',
    );
  }
}
