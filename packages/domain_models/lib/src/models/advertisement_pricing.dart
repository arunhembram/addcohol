import 'package:equatable/equatable.dart';

/// Configurable pricing for advertising spaces on payment scanner stands.
class AdvertisementPricing extends Equatable {
  final String id;
  final String businessType; // 'shops' or 'saloons'
  final String adSize; // 'A5' or 'A6'
  final String sideOption; // 'both' or 'one'
  final double pricePerLocation; // INR per shop/saloon
  final bool isActive;
  final DateTime? updatedAt;

  const AdvertisementPricing({
    required this.id,
    required this.businessType,
    required this.adSize,
    required this.sideOption,
    required this.pricePerLocation,
    this.isActive = true,
    this.updatedAt,
  });

  /// Default baseline admin pricing matrix
  static const List<AdvertisementPricing> defaultPricings = [
    // Regular Retail Shops (Meat, Fish, Grocery, Fast Food, Pharmacy, etc.)
    AdvertisementPricing(
      id: 'price-shop-a5-both',
      businessType: 'shops',
      adSize: 'A5',
      sideOption: 'both',
      pricePerLocation: 80.0,
    ),
    AdvertisementPricing(
      id: 'price-shop-a5-one',
      businessType: 'shops',
      adSize: 'A5',
      sideOption: 'one',
      pricePerLocation: 80.0,
    ),
    AdvertisementPricing(
      id: 'price-shop-a6-both',
      businessType: 'shops',
      adSize: 'A6',
      sideOption: 'both',
      pricePerLocation: 100.0,
    ),
    AdvertisementPricing(
      id: 'price-shop-a6-one',
      businessType: 'shops',
      adSize: 'A6',
      sideOption: 'one',
      pricePerLocation: 100.0,
    ),

    // Saloons & Parlours
    AdvertisementPricing(
      id: 'price-saloon-a5-both',
      businessType: 'saloons',
      adSize: 'A5',
      sideOption: 'both',
      pricePerLocation: 80.0,
    ),
    AdvertisementPricing(
      id: 'price-saloon-a5-one',
      businessType: 'saloons',
      adSize: 'A5',
      sideOption: 'one',
      pricePerLocation: 80.0,
    ),
    AdvertisementPricing(
      id: 'price-saloon-a6-both',
      businessType: 'saloons',
      adSize: 'A6',
      sideOption: 'both',
      pricePerLocation: 100.0,
    ),
    AdvertisementPricing(
      id: 'price-saloon-a6-one',
      businessType: 'saloons',
      adSize: 'A6',
      sideOption: 'one',
      pricePerLocation: 100.0,
    ),
  ];

  /// Finds the price matching the given options or returns a sensible default
  static double resolvePrice({
    required List<AdvertisementPricing> pricingList,
    required String businessType,
    required String adSize,
    required String sideOption,
  }) {
    final bType = businessType.toLowerCase();
    final size = adSize.toUpperCase();
    final side = sideOption.toLowerCase();

    final match = pricingList.cast<AdvertisementPricing?>().firstWhere(
      (p) =>
          p != null &&
          p.isActive &&
          p.businessType.toLowerCase() == bType &&
          p.adSize.toUpperCase() == size &&
          p.sideOption.toLowerCase() == side,
      orElse: () => null,
    );

    if (match != null) {
      return match.pricePerLocation;
    }

    // Fallback to default matrix
    final fallback = defaultPricings.cast<AdvertisementPricing?>().firstWhere(
      (p) =>
          p != null &&
          p.businessType.toLowerCase() == bType &&
          p.adSize.toUpperCase() == size &&
          p.sideOption.toLowerCase() == side,
      orElse: () => null,
    );

    return fallback?.pricePerLocation ?? (size == 'A6' ? 100.0 : 80.0);
  }

  factory AdvertisementPricing.fromJson(Map<String, dynamic> json) {
    return AdvertisementPricing(
      id: json['id'] as String? ?? '',
      businessType: (json['business_type'] as String? ?? 'shops').toLowerCase(),
      adSize: (json['ad_size'] as String? ?? 'A5').toUpperCase(),
      sideOption: (json['side_option'] as String? ?? 'both').toLowerCase(),
      pricePerLocation: (json['price_per_location'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_type': businessType,
      'ad_size': adSize,
      'side_option': sideOption,
      'price_per_location': pricePerLocation,
      'is_active': isActive,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        businessType,
        adSize,
        sideOption,
        pricePerLocation,
        isActive,
        updatedAt,
      ];
}
