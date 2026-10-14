import 'package:equatable/equatable.dart';
import '../enums/app_status.dart';
import '../enums/user_role.dart';

class SubsystemStatus extends Equatable {
  final String name;
  final ServiceStatus status;
  final String message;
  final int? latencyMs;

  const SubsystemStatus({
    required this.name,
    required this.status,
    required this.message,
    this.latencyMs,
  });

  @override
  List<Object?> get props => [name, status, message, latencyMs];
}

class AppHealthInfo extends Equatable {
  final String appName;
  final UserRole targetRole;
  final String environment;
  final AppHealthState overallState;
  final DateTime checkTimestamp;
  final List<SubsystemStatus> subsystems;

  const AppHealthInfo({
    required this.appName,
    required this.targetRole,
    required this.environment,
    required this.overallState,
    required this.checkTimestamp,
    this.subsystems = const [],
  });

  @override
  List<Object?> get props => [
    appName,
    targetRole,
    environment,
    overallState,
    checkTimestamp,
    subsystems,
  ];
}
