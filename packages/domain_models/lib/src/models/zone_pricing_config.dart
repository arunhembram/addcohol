import 'package:equatable/equatable.dart';

/// Configurable pricing configuration scoped to an individual Zone.
/// Allows Master Admin to override pricing for specific zones (e.g. Salt Lake vs Howrah)
/// without altering default global platform pricing or other zones.
class ZonePricingConfig extends Equatable {
  final String zoneId;
  final double a5StandOneSide;
  final double a5StandBothSides;
  final double a6StandOneSide;
  final double a6StandBothSides;
  final double a5SaloonOneSide;
  final double a5SaloonBothSides;
  final double a6SaloonOneSide;
  final double a6SaloonBothSides;
  final double designPrintA6OneSide;
  final double designPrintA6BothSides;
  final DateTime? updatedAt;

  const ZonePricingConfig({
    required this.zoneId,
    this.a5StandOneSide = 80.0,
    this.a5StandBothSides = 80.0,
    this.a6StandOneSide = 100.0,
    this.a6StandBothSides = 100.0,
    this.a5SaloonOneSide = 80.0,
    this.a5SaloonBothSides = 80.0,
    this.a6SaloonOneSide = 100.0,
    this.a6SaloonBothSides = 100.0,
    this.designPrintA6OneSide = 5000.0,
    this.designPrintA6BothSides = 10000.0,
    this.updatedAt,
  });

  /// Factory producing sensible platform default values for any given zone ID
  factory ZonePricingConfig.defaultForZone(String zoneId) {
    return ZonePricingConfig(
      zoneId: zoneId,
      a5StandOneSide: 80.0,
      a5StandBothSides: 80.0,
      a6StandOneSide: 100.0,
      a6StandBothSides: 100.0,
      a5SaloonOneSide: 80.0,
      a5SaloonBothSides: 80.0,
      a6SaloonOneSide: 100.0,
      a6SaloonBothSides: 100.0,
      designPrintA6OneSide: 5000.0,
      designPrintA6BothSides: 10000.0,
      updatedAt: DateTime.now(),
    );
  }

  /// Resolves the price per location based on business type, ad size, and placement side.
  double resolvePrice({
    required String businessType,
    required String adSize,
    required String sideOption,
  }) {
    final bType = businessType.toLowerCase();
    final size = adSize.toUpperCase();
    final isBoth = sideOption.toLowerCase().contains('both');

    if (bType.contains('saloon')) {
      if (size == 'A5') {
        return isBoth ? a5SaloonBothSides : a5SaloonOneSide;
      } else {
        return isBoth ? a6SaloonBothSides : a6SaloonOneSide;
      }
    } else {
      // Default to regular stand / retail shops
      if (size == 'A5') {
        return isBoth ? a5StandBothSides : a5StandOneSide;
      } else {
        return isBoth ? a6StandBothSides : a6StandOneSide;
      }
    }
  }

  /// Resolves the one-time Design & Print fee.
  /// A5 is always free. A6 returns one-side or both-side cost.
  double resolveDesignPrintFee({
    required String adSize,
    required String sideOption,
  }) {
    if (adSize.toUpperCase() != 'A6') {
      return 0.0;
    }
    final isBoth = sideOption.toLowerCase().contains('both');
    return isBoth ? designPrintA6BothSides : designPrintA6OneSide;
  }

  factory ZonePricingConfig.fromJson(Map<String, dynamic> json) {
    return ZonePricingConfig(
      zoneId: json['zone_id'] as String? ?? '',
      a5StandOneSide: (json['a5_stand_one_side'] as num?)?.toDouble() ?? 80.0,
      a5StandBothSides: (json['a5_stand_both_sides'] as num?)?.toDouble() ?? 80.0,
      a6StandOneSide: (json['a6_stand_one_side'] as num?)?.toDouble() ?? 100.0,
      a6StandBothSides: (json['a6_stand_both_sides'] as num?)?.toDouble() ?? 100.0,
      a5SaloonOneSide: (json['a5_saloon_one_side'] as num?)?.toDouble() ?? 80.0,
      a5SaloonBothSides: (json['a5_saloon_both_sides'] as num?)?.toDouble() ?? 80.0,
      a6SaloonOneSide: (json['a6_saloon_one_side'] as num?)?.toDouble() ?? 100.0,
      a6SaloonBothSides: (json['a6_saloon_both_sides'] as num?)?.toDouble() ?? 100.0,
      designPrintA6OneSide: (json['design_print_a6_one_side'] as num?)?.toDouble() ?? 5000.0,
      designPrintA6BothSides: (json['design_print_a6_both_sides'] as num?)?.toDouble() ?? 10000.0,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'zone_id': zoneId,
      'a5_stand_one_side': a5StandOneSide,
      'a5_stand_both_sides': a5StandBothSides,
      'a6_stand_one_side': a6StandOneSide,
      'a6_stand_both_sides': a6StandBothSides,
      'a5_saloon_one_side': a5SaloonOneSide,
      'a5_saloon_both_sides': a5SaloonBothSides,
      'a6_saloon_one_side': a6SaloonOneSide,
      'a6_saloon_both_sides': a6SaloonBothSides,
      'design_print_a6_one_side': designPrintA6OneSide,
      'design_print_a6_both_sides': designPrintA6BothSides,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ZonePricingConfig copyWith({
    String? zoneId,
    double? a5StandOneSide,
    double? a5StandBothSides,
    double? a6StandOneSide,
    double? a6StandBothSides,
    double? a5SaloonOneSide,
    double? a5SaloonBothSides,
    double? a6SaloonOneSide,
    double? a6SaloonBothSides,
    double? designPrintA6OneSide,
    double? designPrintA6BothSides,
    DateTime? updatedAt,
  }) {
    return ZonePricingConfig(
      zoneId: zoneId ?? this.zoneId,
      a5StandOneSide: a5StandOneSide ?? this.a5StandOneSide,
      a5StandBothSides: a5StandBothSides ?? this.a5StandBothSides,
      a6StandOneSide: a6StandOneSide ?? this.a6StandOneSide,
      a6StandBothSides: a6StandBothSides ?? this.a6StandBothSides,
      a5SaloonOneSide: a5SaloonOneSide ?? this.a5SaloonOneSide,
      a5SaloonBothSides: a5SaloonBothSides ?? this.a5SaloonBothSides,
      a6SaloonOneSide: a6SaloonOneSide ?? this.a6SaloonOneSide,
      a6SaloonBothSides: a6SaloonBothSides ?? this.a6SaloonBothSides,
      designPrintA6OneSide: designPrintA6OneSide ?? this.designPrintA6OneSide,
      designPrintA6BothSides: designPrintA6BothSides ?? this.designPrintA6BothSides,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    zoneId,
    a5StandOneSide,
    a5StandBothSides,
    a6StandOneSide,
    a6StandBothSides,
    a5SaloonOneSide,
    a5SaloonBothSides,
    a6SaloonOneSide,
    a6SaloonBothSides,
    designPrintA6OneSide,
    designPrintA6BothSides,
  ];
}
