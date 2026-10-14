import 'package:equatable/equatable.dart';
import '../enums/user_role.dart';

class UserProfile extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? phoneNumber;
  final String? avatarUrl;
  final String? displayId;
  final String? _displayReference;
  final String? adminAccessId;
  final String? employeeAccessId;
  final bool isActive;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  String? get displayReference =>
      _displayReference ??
      (displayId != null
          ? (role == UserRole.employee ? 'EMP-$displayId' : 'ADM-$displayId')
          : null);

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phoneNumber,
    this.avatarUrl,
    this.displayId,
    String? displayReference,
    this.adminAccessId,
    this.employeeAccessId,
    this.isActive = true,
    required this.createdAt,
    this.metadata = const {},
  }) : _displayReference = displayReference;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final adminId = json['admin_access_id'] as String?;
    final empId = json['employee_access_id'] as String?;
    final dispId = json['display_id'] as String? ?? adminId ?? empId;
    final dispRef = json['display_reference'] as String? ?? 
        (dispId != null ? ((json['role'] == 'employee') ? 'EMP-$dispId' : 'ADM-$dispId') : null);

    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String?),
      phoneNumber: json['phone_number'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      displayId: dispId,
      displayReference: dispRef,
      adminAccessId: adminId,
      employeeAccessId: empId,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.value,
      'phone_number': phoneNumber,
      'avatar_url': avatarUrl,
      'display_id': displayId,
      'display_reference': displayReference,
      'admin_access_id': adminAccessId,
      'employee_access_id': employeeAccessId,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    String? phoneNumber,
    String? avatarUrl,
    String? displayId,
    String? displayReference,
    String? adminAccessId,
    String? employeeAccessId,
    bool? isActive,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      displayId: displayId ?? this.displayId,
      displayReference: displayReference ?? this.displayReference,
      adminAccessId: adminAccessId ?? this.adminAccessId,
      employeeAccessId: employeeAccessId ?? this.employeeAccessId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    fullName,
    role,
    phoneNumber,
    avatarUrl,
    displayId,
    displayReference,
    adminAccessId,
    employeeAccessId,
    isActive,
    createdAt,
    metadata,
  ];
}
