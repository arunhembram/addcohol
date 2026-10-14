import 'package:equatable/equatable.dart';

class DashboardStats extends Equatable {
  final int totalZones;
  final int totalAdmins;
  final int totalEmployees;
  final int totalShops;
  final int followupsDueToday;
  final int paymentsAwaitingConfirmation;

  const DashboardStats({
    this.totalZones = 0,
    this.totalAdmins = 0,
    this.totalEmployees = 0,
    this.totalShops = 0,
    this.followupsDueToday = 0,
    this.paymentsAwaitingConfirmation = 0,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalZones: (json['total_zones'] as num?)?.toInt() ?? 0,
      totalAdmins: (json['total_admins'] as num?)?.toInt() ?? 0,
      totalEmployees: (json['total_employees'] as num?)?.toInt() ?? 0,
      totalShops: (json['total_shops'] as num?)?.toInt() ?? 0,
      followupsDueToday: (json['followups_due_today'] as num?)?.toInt() ?? 0,
      paymentsAwaitingConfirmation: (json['payments_awaiting_confirmation'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_zones': totalZones,
      'total_admins': totalAdmins,
      'total_employees': totalEmployees,
      'total_shops': totalShops,
      'followups_due_today': followupsDueToday,
      'payments_awaiting_confirmation': paymentsAwaitingConfirmation,
    };
  }

  @override
  List<Object?> get props => [
    totalZones,
    totalAdmins,
    totalEmployees,
    totalShops,
    followupsDueToday,
    paymentsAwaitingConfirmation,
  ];
}
