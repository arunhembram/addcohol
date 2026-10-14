import 'package:equatable/equatable.dart';

class EmployeePerformanceSummary extends Equatable {
  final String employeeId;
  final String employeeName;
  final String displayId;
  final String phoneNumber;
  final bool isActive;
  final List<String> assignedZoneNames;
  final int shopsOnboarded;
  final int followupsCompleted;
  final int pendingFollowups;
  final double performanceRating;

  const EmployeePerformanceSummary({
    required this.employeeId,
    required this.employeeName,
    required this.displayId,
    required this.phoneNumber,
    this.isActive = true,
    this.assignedZoneNames = const [],
    this.shopsOnboarded = 0,
    this.followupsCompleted = 0,
    this.pendingFollowups = 0,
    this.performanceRating = 5.0,
  });

  factory EmployeePerformanceSummary.fromJson(Map<String, dynamic> json) {
    return EmployeePerformanceSummary(
      employeeId: json['employee_id'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      displayId: json['display_id'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      assignedZoneNames: (json['assigned_zone_names'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      shopsOnboarded: (json['shops_onboarded'] as num?)?.toInt() ?? 0,
      followupsCompleted: (json['followups_completed'] as num?)?.toInt() ?? 0,
      pendingFollowups: (json['pending_followups'] as num?)?.toInt() ?? 0,
      performanceRating: (json['performance_rating'] as num?)?.toDouble() ?? 5.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'employee_name': employeeName,
      'display_id': displayId,
      'phone_number': phoneNumber,
      'is_active': isActive,
      'assigned_zone_names': assignedZoneNames,
      'shops_onboarded': shopsOnboarded,
      'followups_completed': followupsCompleted,
      'pending_followups': pendingFollowups,
      'performance_rating': performanceRating,
    };
  }

  @override
  List<Object?> get props => [
    employeeId,
    employeeName,
    displayId,
    phoneNumber,
    isActive,
    assignedZoneNames,
    shopsOnboarded,
    followupsCompleted,
    pendingFollowups,
    performanceRating,
  ];
}
