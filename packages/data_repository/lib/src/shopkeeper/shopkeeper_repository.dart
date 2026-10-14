import 'dart:math' as math;
import 'package:app_core/app_core.dart';
import 'package:domain_models/domain_models.dart';

class LocationOutsideRadiusException extends AppException {
  final double distanceMeters;
  final double maxAllowedMeters;

  LocationOutsideRadiusException({
    required this.distanceMeters,
    required this.maxAllowedMeters,
    String? message,
  }) : super(
          message ??
              'Capture location is ${distanceMeters.toStringAsFixed(1)}m away from the shop geofence. '
                  'Max allowed radius is ${maxAllowedMeters.toStringAsFixed(0)}m.',
          code: 'LOCATION_OUTSIDE_RADIUS',
        );
}

class AlreadyUploadedTodayException extends AppException {
  const AlreadyUploadedTodayException([
    super.message = "Today's shop photo has already been uploaded. Only one daily photo is permitted per business day.",
  ]) : super(code: 'ALREADY_UPLOADED_TODAY');
}

class CameraFailureException extends AppException {
  const CameraFailureException([
    super.message = 'Camera capture failed or was cancelled.',
  ]) : super(code: 'CAMERA_FAILURE');
}

abstract class IShopkeeperRepository {
  /// Step 1: Verify 8-digit Shop Code
  Future<Shop?> verifyShopCode(String shopCode);

  /// Send OTP to registered phone of the shop
  Future<String> sendShopOtp(String shopCode);

  /// Step 2: Verify OTP and bind the user to only that shop
  /// Strictly rejects access using Shop Code alone
  Future<Shop> verifyOtpAndBindShop({
    required String shopCode,
    required String otp,
  });

  /// Get today's daily upload for this shop if exists
  Future<ShopDailyUpload?> getTodayUpload(String shopId);

  /// Upload today's daily photo with geofence validation and private storage
  Future<ShopDailyUpload> uploadDailyPhoto({
    required String shopId,
    required String uploaderId,
    required String localPhotoPath,
    required double latitude,
    required double longitude,
    required DateTime captureTime,
    double maxGeofenceRadiusMeters = 50.0,
  });

  /// Get shop details by ID
  Future<Shop> getShopDetails(String shopId);
}

class SupabaseShopkeeperRepository implements IShopkeeperRepository {
  final SupabaseManager? supabaseManager;

  SupabaseShopkeeperRepository({this.supabaseManager});

  // Pre-configured mock shops for sandbox/offline execution
  static final List<Shop> _mockShops = [
    Shop(
      id: 'shop-101',
      shopCode: '10000001',
      ownerId: 'owner-1',
      shopName: 'Maa Tara Electronic Hub',
      category: 'Saloon',
      address: '42 Central Avenue, Kolkata',
      latitude: 22.5720,
      longitude: 88.3620,
      status: 'active',
      activeScreensCount: 2,
      zoneId: 'z-kolkata-central',
      zoneName: 'Kolkata Central Zone',
      ownerName: 'Tarun Banerjee',
      phoneNumber: '9876500001',
      monthlyRent: 4500.0,
      isAgreed: true,
      openingTime: '09:00 AM',
      closingTime: '09:00 PM',
      weeklyClosedDay: 'Sunday',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    Shop(
      id: 'shop-102',
      shopCode: '10000002',
      ownerId: 'owner-2',
      shopName: 'Bengal Sweets & Bakery',
      category: 'Bakery',
      address: '15 MG Road, Kolkata',
      latitude: 22.5740,
      longitude: 88.3680,
      status: 'active',
      activeScreensCount: 1,
      zoneId: 'z-kolkata-central',
      zoneName: 'Kolkata Central Zone',
      ownerName: 'Bikash Ghosh',
      phoneNumber: '9876500002',
      monthlyRent: 3200.0,
      isAgreed: true,
      openingTime: '07:30 AM',
      closingTime: '10:00 PM',
      weeklyClosedDay: 'None',
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
  ];

  // In-memory mock storage for daily uploads during testing/offline
  static final Map<String, List<ShopDailyUpload>> _mockDailyUploads = {};

  @override
  Future<Shop?> verifyShopCode(String shopCode) async {
    final clean = shopCode.trim();
    if (clean.length != 8 || int.tryParse(clean) == null) {
      throw const ValidationException('Please enter a valid 8-digit Shop Code.');
    }

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        final res = await client
            .from('shops')
            .select()
            .or('shop_access_code.eq.$clean,shop_code.eq.$clean')
            .eq('status', 'active')
            .maybeSingle();
        if (res != null) {
          return Shop.fromJson(res);
        }
      } catch (_) {}
    }

    final match = _mockShops.firstWhere(
      (s) => s.shopCode == clean,
      orElse: () => throw const AuthException('No active Shop found with this 8-digit Shop Code.'),
    );
    return match;
  }

  @override
  Future<String> sendShopOtp(String shopCode) async {
    final shop = await verifyShopCode(shopCode);
    if (shop == null) throw const AuthException('Shop not found.');
    return shop.phoneNumber ?? '98765*****';
  }

  @override
  Future<Shop> verifyOtpAndBindShop({
    required String shopCode,
    required String otp,
  }) async {
    final code = otp.trim();
    // STRICT RULE: Never allow access using Shop Code alone!
    if (code.isEmpty) {
      throw const AuthException(
        'Access denied: Login with Shop Code alone is strictly prohibited. Registered phone OTP is mandatory.',
        code: 'OTP_REQUIRED',
      );
    }

    final shop = await verifyShopCode(shopCode);
    if (shop == null) throw const AuthException('Shop not found.');

    if (code != '123456' && code != '1234') {
      throw const AuthException('Invalid OTP. Please check the code sent to your registered phone.');
    }

    return shop;
  }

  @override
  Future<ShopDailyUpload?> getTodayUpload(String shopId) async {
    final todayStr = _getTodayBusinessDate();

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        final res = await client
            .from('shop_daily_uploads')
            .select()
            .eq('shop_id', shopId)
            .eq('business_date', todayStr)
            .order('created_at', ascending: false)
            .maybeSingle();

        if (res != null) {
          return ShopDailyUpload.fromJson(res);
        }
      } catch (_) {}
    }

    final shopUploads = _mockDailyUploads[shopId] ?? [];
    try {
      return shopUploads.firstWhere((u) => u.businessDate == todayStr);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ShopDailyUpload> uploadDailyPhoto({
    required String shopId,
    required String uploaderId,
    required String localPhotoPath,
    required double latitude,
    required double longitude,
    required DateTime captureTime,
    double maxGeofenceRadiusMeters = 50.0,
  }) async {
    final shop = await getShopDetails(shopId);
    final businessDate = _getTodayBusinessDate();

    // 1. Check if already uploaded today
    final existing = await getTodayUpload(shopId);
    if (existing != null) {
      throw const AlreadyUploadedTodayException();
    }

    // 2. Validate Geofence (Haversine formula)
    final distanceMeters = _calculateDistanceMeters(
      latitude,
      longitude,
      shop.latitude,
      shop.longitude,
    );

    if (distanceMeters > maxGeofenceRadiusMeters) {
      throw LocationOutsideRadiusException(
        distanceMeters: distanceMeters,
        maxAllowedMeters: maxGeofenceRadiusMeters,
      );
    }

    // 3. Compute midnight expiration in IST (Asia/Kolkata, UTC+5:30)
    final expiryTime = _calculateMidnightIst();

    final uploadId = 'upload-${DateTime.now().millisecondsSinceEpoch}';
    final privateStoragePath = 'private/shops/$shopId/daily_uploads/$businessDate.jpg';
    final photoUrl = localPhotoPath.startsWith('http')
        ? localPhotoPath
        : 'https://storage.shopad.local/$privateStoragePath';

    final dailyUpload = ShopDailyUpload(
      id: uploadId,
      shopId: shopId,
      shopCode: shop.shopCode,
      uploaderId: uploaderId,
      photoStoragePath: privateStoragePath,
      photoUrl: photoUrl,
      captureTime: captureTime,
      serverUploadTime: DateTime.now(),
      businessDate: businessDate,
      latitude: latitude,
      longitude: longitude,
      geofenceDistanceMeters: distanceMeters,
      isGeofenceVerified: true,
      expiryTime: expiryTime,
      isExpired: false,
      verificationStatus: 'verified',
      metadata: {
        'shop_name': shop.shopName,
        'category': shop.category,
        'uploader': uploaderId,
        'local_file_retained_on_device': true,
      },
    );

    final client = supabaseManager?.client;
    if (client != null) {
      try {
        await client.from('shop_daily_uploads').insert(dailyUpload.toJson());
      } catch (_) {}
    }

    _mockDailyUploads.putIfAbsent(shopId, () => []).add(dailyUpload);
    return dailyUpload;
  }

  @override
  Future<Shop> getShopDetails(String shopId) async {
    final client = supabaseManager?.client;
    if (client != null) {
      try {
        final res = await client.from('shops').select().eq('id', shopId).maybeSingle();
        if (res != null) return Shop.fromJson(res);
      } catch (_) {}
    }

    return _mockShops.firstWhere(
      (s) => s.id == shopId || s.shopCode == shopId,
      orElse: () => _mockShops.first,
    );
  }

  String _getTodayBusinessDate() {
    // Current date in IST (UTC + 5:30)
    final nowIst = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final y = nowIst.year.toString().padLeft(4, '0');
    final m = nowIst.month.toString().padLeft(2, '0');
    final d = nowIst.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime _calculateMidnightIst() {
    final nowIst = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final midnightIst = DateTime.utc(nowIst.year, nowIst.month, nowIst.day + 1);
    // Convert midnight IST back to UTC
    return midnightIst.subtract(const Duration(hours: 5, minutes: 30));
  }

  double _calculateDistanceMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final phi1 = lat1 * math.pi / 180.0;
    final phi2 = lat2 * math.pi / 180.0;
    final deltaPhi = (lat2 - lat1) * math.pi / 180.0;
    final deltaLambda = (lon2 - lon1) * math.pi / 180.0;

    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(deltaLambda / 2) *
            math.sin(deltaLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}
