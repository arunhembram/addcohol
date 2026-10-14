import 'package:equatable/equatable.dart';

class CompanyZoneSummary extends Equatable {
  final String zoneId;
  final String zoneName;
  final int totalAgreedShops;
  final int totalScreens;
  final Map<String, int> categoryCounts;
  final int? proofVerifiedCount; // Only non-null if can_view_daily_proof is true

  const CompanyZoneSummary({
    required this.zoneId,
    required this.zoneName,
    required this.totalAgreedShops,
    this.totalScreens = 0,
    required this.categoryCounts,
    this.proofVerifiedCount,
  });

  @override
  List<Object?> get props => [
    zoneId,
    zoneName,
    totalAgreedShops,
    totalScreens,
    categoryCounts,
    proofVerifiedCount,
  ];
}
