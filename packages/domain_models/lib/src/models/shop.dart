import 'package:equatable/equatable.dart';

class Shop extends Equatable {
  final String id;
  final String ownerId;
  final String shopName;
  final String category;
  final String address;
  final double latitude;
  final double longitude;
  final String status;
  final int activeScreensCount;
  final DateTime createdAt;
  final String? shopCode;
  final String? _shopAccessCode;
  final String? _displayReference;
  final String? zoneId;
  final String? zoneName;
  final String? ownerName;
  final String? phoneNumber;
  final double monthlyRent;
  final bool isAgreed;

  String? get shopAccessCode => _shopAccessCode ?? shopCode;
  String? get displayReference =>
      _displayReference ??
      (shopAccessCode != null
          ? 'SHP-KOL-${shopAccessCode!.length >= 4 ? shopAccessCode!.substring(shopAccessCode!.length - 4) : shopAccessCode}'
          : null);

  final String? openingTime;
  final String? closingTime;
  final String? weeklyClosedDay;
  final String? shopfrontPhotoUrl;
  final String? landmark;
  final String? followupReason;
  final DateTime? nextFollowupDate;
  final bool isDistributed;
  final DateTime? distributedAt;

  const Shop({
    required this.id,
    required this.ownerId,
    required this.shopName,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.status = 'active',
    this.activeScreensCount = 1,
    required this.createdAt,
    this.shopCode,
    String? shopAccessCode,
    String? displayReference,
    this.zoneId,
    this.zoneName,
    this.ownerName,
    this.phoneNumber,
    this.monthlyRent = 0.0,
    this.isAgreed = false,
    this.openingTime,
    this.closingTime,
    this.weeklyClosedDay,
    this.shopfrontPhotoUrl,
    this.landmark,
    this.followupReason,
    this.nextFollowupDate,
    this.isDistributed = false,
    this.distributedAt,
  }) : _shopAccessCode = shopAccessCode,
       _displayReference = displayReference;

  bool get isUnderProcess =>
      status.toLowerCase() == 'under_process' ||
      status.toLowerCase() == 'pending_approval';

  bool get isFollowup =>
      status.toLowerCase() == 'follow_up' ||
      (!isAgreed && nextFollowupDate != null && !isUnderProcess);

  /// Check if the follow-up is scheduled for today (local calendar day)
  bool get isFollowupToday {
    if (!isFollowup || nextFollowupDate == null) return false;
    final now = DateTime.now();
    final local = nextFollowupDate!.toLocal();
    return local.year == now.year && local.month == now.month && local.day == now.day;
  }

  /// Check if the follow-up day was missed (scheduled date was on a calendar day before today)
  bool get isFollowupMissed {
    if (!isFollowup || nextFollowupDate == null) return false;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return nextFollowupDate!.toLocal().isBefore(startOfToday);
  }

  /// Check if the follow-up is scheduled for a future day or general follow-up
  bool get isFollowupFuture {
    if (!isFollowup) return false;
    if (nextFollowupDate == null) return true;
    return !isFollowupToday && !isFollowupMissed;
  }

  bool get isOverdue => isFollowupMissed;

  /// Check whether today (or given [referenceTime]) is the shop's weekly closed day.
  /// Evaluated in Indian Standard Time (UTC+05:30) or the local reference day.
  bool isWeeklyClosedToday([DateTime? referenceTime]) {
    if (status.toLowerCase() == 'inactive' ||
        status.toLowerCase() == 'suspended' ||
        status.toLowerCase() == 'closed') {
      return true;
    }

    final dayStr = weeklyClosedDay?.trim().toLowerCase();
    if (dayStr == null || dayStr.isEmpty || dayStr == 'none' || dayStr == 'null') {
      return false;
    }

    // Default to Indian Standard Time (UTC+05:30)
    final ref = referenceTime != null
        ? referenceTime.toUtc().add(const Duration(hours: 5, minutes: 30))
        : DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    const fullDays = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    const shortDays = [
      'mon',
      'tue',
      'wed',
      'thu',
      'fri',
      'sat',
      'sun',
    ];
    final currentFull = fullDays[ref.weekday - 1];
    final currentShort = shortDays[ref.weekday - 1];

    if (dayStr == currentFull || dayStr == currentShort) {
      return true;
    }

    final tokens = dayStr
        .split(RegExp(r'[,/;&\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    for (final token in tokens) {
      if (token == currentFull || token == currentShort) {
        return true;
      }
    }
    return false;
  }

  /// Parse the shop's opening time (e.g. "09:00 AM", "6 PM", "6:00 PM", "18:00")
  /// into a DateTime on the target business date (in IST).
  DateTime? parseOpeningTimeToday([DateTime? referenceTime]) {
    final timeStr = openingTime?.trim();
    if (timeStr == null || timeStr.isEmpty) return null;

    final ref = referenceTime != null
        ? referenceTime.toUtc().add(const Duration(hours: 5, minutes: 30))
        : DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final clean = timeStr.toUpperCase();

    // Match 12-hour format e.g. "09:00 AM", "6 PM", "6:00 PM", "6PM"
    final match12 =
        RegExp(r'^(\d{1,2})(?::(\d{2}))?(?::\d{2})?\s*(AM|PM)$').firstMatch(clean);
    if (match12 != null) {
      int hour = int.parse(match12.group(1)!);
      final minute =
          match12.group(2) != null ? int.parse(match12.group(2)!) : 0;
      final period = match12.group(3)!;

      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;

      return DateTime.utc(ref.year, ref.month, ref.day, hour, minute);
    }

    // Match 24-hour format e.g. "09:00", "21:30"
    final match24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(clean);
    if (match24 != null) {
      final hour = int.parse(match24.group(1)!);
      final minute = int.parse(match24.group(2)!);
      return DateTime.utc(ref.year, ref.month, ref.day, hour, minute);
    }

    return null;
  }

  /// Check whether the shop's scheduled opening time is later than the current time on the target date.
  bool isBeforeOpeningTime([DateTime? referenceTime]) {
    final opening = parseOpeningTimeToday(referenceTime);
    if (opening == null) return false;
    final now = referenceTime != null
        ? referenceTime.toUtc().add(const Duration(hours: 5, minutes: 30))
        : DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    return now.isBefore(opening);
  }


  Shop copyWith({
    String? id,
    String? ownerId,
    String? shopName,
    String? category,
    String? address,
    double? latitude,
    double? longitude,
    String? status,
    int? activeScreensCount,
    DateTime? createdAt,
    String? shopCode,
    String? shopAccessCode,
    String? displayReference,
    String? zoneId,
    String? zoneName,
    String? ownerName,
    String? phoneNumber,
    double? monthlyRent,
    bool? isAgreed,
    String? openingTime,
    String? closingTime,
    String? weeklyClosedDay,
    String? shopfrontPhotoUrl,
    String? landmark,
    String? followupReason,
    DateTime? nextFollowupDate,
    bool? isDistributed,
    DateTime? distributedAt,
  }) {
    return Shop(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      shopName: shopName ?? this.shopName,
      category: category ?? this.category,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      activeScreensCount: activeScreensCount ?? this.activeScreensCount,
      createdAt: createdAt ?? this.createdAt,
      shopCode: shopCode ?? this.shopCode,
      shopAccessCode: shopAccessCode ?? this.shopAccessCode,
      displayReference: displayReference ?? this.displayReference,
      zoneId: zoneId ?? this.zoneId,
      zoneName: zoneName ?? this.zoneName,
      ownerName: ownerName ?? this.ownerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      isAgreed: isAgreed ?? this.isAgreed,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      weeklyClosedDay: weeklyClosedDay ?? this.weeklyClosedDay,
      shopfrontPhotoUrl: shopfrontPhotoUrl ?? this.shopfrontPhotoUrl,
      landmark: landmark ?? this.landmark,
      followupReason: followupReason ?? this.followupReason,
      nextFollowupDate: nextFollowupDate ?? this.nextFollowupDate,
      isDistributed: isDistributed ?? this.isDistributed,
      distributedAt: distributedAt ?? this.distributedAt,
    );
  }

  factory Shop.fromJson(Map<String, dynamic> json) {
    final accessCode = json['shop_access_code'] as String? ?? json['shop_code'] as String?;
    final dispRef = json['display_reference'] as String? ?? 
        (accessCode != null ? 'SHP-KOL-${accessCode.length >= 4 ? accessCode.substring(accessCode.length - 4) : accessCode}' : null);

    return Shop(
      id: json['id'] as String? ?? '',
      ownerId: json['owner_id'] as String? ?? json['shopkeeper_id'] as String? ?? '',
      shopName: json['shop_name'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'active',
      activeScreensCount: (json['active_screens_count'] as num?)?.toInt() ?? (json['screen_count'] as num?)?.toInt() ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      shopCode: accessCode,
      shopAccessCode: accessCode,
      displayReference: dispRef,
      zoneId: json['zone_id'] as String?,
      zoneName: json['zone_name'] as String?,
      ownerName: json['owner_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      monthlyRent: (json['monthly_rent'] as num?)?.toDouble() ?? 0.0,
      isAgreed: json['is_agreed'] as bool? ?? false,
      openingTime: json['opening_time'] as String?,
      closingTime: json['closing_time'] as String?,
      weeklyClosedDay: json['weekly_closed_day'] as String?,
      shopfrontPhotoUrl: json['shopfront_photo_url'] as String?,
      landmark: json['landmark'] as String?,
      followupReason: json['followup_reason'] as String?,
      nextFollowupDate: json['next_followup_date'] != null
          ? DateTime.tryParse(json['next_followup_date'] as String)
          : null,
      isDistributed: json['is_distributed'] as bool? ?? (json['distributed_at'] != null),
      distributedAt: json['distributed_at'] != null
          ? DateTime.tryParse(json['distributed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'shop_name': shopName,
      'category': category,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'active_screens_count': activeScreensCount,
      'created_at': createdAt.toIso8601String(),
      if (shopCode != null) 'shop_code': shopCode,
      if (shopAccessCode != null) 'shop_access_code': shopAccessCode,
      if (displayReference != null) 'display_reference': displayReference,
      if (zoneId != null) 'zone_id': zoneId,
      if (zoneName != null) 'zone_name': zoneName,
      if (ownerName != null) 'owner_name': ownerName,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      'monthly_rent': monthlyRent,
      'is_agreed': isAgreed,
      if (openingTime != null) 'opening_time': openingTime,
      if (closingTime != null) 'closing_time': closingTime,
      if (weeklyClosedDay != null) 'weekly_closed_day': weeklyClosedDay,
      if (shopfrontPhotoUrl != null) 'shopfront_photo_url': shopfrontPhotoUrl,
      if (landmark != null) 'landmark': landmark,
      if (followupReason != null) 'followup_reason': followupReason,
      if (nextFollowupDate != null)
        'next_followup_date': nextFollowupDate!.toIso8601String(),
      'is_distributed': isDistributed,
      if (distributedAt != null) 'distributed_at': distributedAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    ownerId,
    shopName,
    category,
    address,
    latitude,
    longitude,
    status,
    activeScreensCount,
    createdAt,
    shopCode,
    shopAccessCode,
    displayReference,
    zoneId,
    zoneName,
    ownerName,
    phoneNumber,
    monthlyRent,
    isAgreed,
    openingTime,
    closingTime,
    weeklyClosedDay,
    shopfrontPhotoUrl,
    landmark,
    followupReason,
    nextFollowupDate,
    isDistributed,
    distributedAt,
  ];
}

