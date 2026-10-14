import 'package:app_core/app_core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Shopkeeper Repository Unit Tests', () {
    late IShopkeeperRepository repo;

    setUp(() {
      const config = AppConfig(
        environment: AppEnvironment.dev,
        appName: 'Shopkeeper Test',
        supabaseUrl: '',
        supabaseAnonKey: '',
        googleMapsApiKey: '',
        apiBaseUrl: '',
      );
      final sm = SupabaseManager(config: config);
      repo = SupabaseShopkeeperRepository(supabaseManager: sm);
    });

    test('Step 1: verifyShopCode succeeds for valid active 8-digit Shop Code', () async {
      final shop = await repo.verifyShopCode('10000001');
      expect(shop, isNotNull);
      expect(shop!.shopCode, '10000001');
      expect(shop.shopName, 'Maa Tara Electronic Hub');
      expect(shop.status, 'active');
    });

    test('Step 1: verifyShopCode rejects invalid format or non-existent code', () async {
      expect(
        () => repo.verifyShopCode('123'),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => repo.verifyShopCode('99999999'),
        throwsA(isA<AuthException>()),
      );
    });

    test('sendShopOtp dispatches OTP to registered phone', () async {
      final phone = await repo.sendShopOtp('10000001');
      expect(phone, '9876500001');
    });

    test('Step 2: STRICT RULE - Never allow access using Shop Code alone', () async {
      expect(
        () => repo.verifyOtpAndBindShop(
          shopCode: '10000001',
          otp: '',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('Step 2: Valid OTP binds user to only that shop', () async {
      final shop = await repo.verifyOtpAndBindShop(
        shopCode: '10000001',
        otp: '123456',
      );
      expect(shop.shopCode, '10000001');
      expect(shop.id, 'shop-101');
    });

    test('Step 2: Invalid OTP is rejected', () async {
      expect(
        () => repo.verifyOtpAndBindShop(
          shopCode: '10000001',
          otp: '000000',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('Geofence validation: In-radius photo upload succeeds and stores private metadata', () async {
      // Shop 101 is located at (22.5720, 88.3620)
      final upload = await repo.uploadDailyPhoto(
        shopId: 'shop-101',
        uploaderId: 'owner-1',
        localPhotoPath: '/local/device/photos/shop101_today.jpg',
        latitude: 22.57202, // ~2-3 meters away (well within 50m)
        longitude: 88.36202,
        captureTime: DateTime.now(),
        maxGeofenceRadiusMeters: 50.0,
      );

      expect(upload, isNotNull);
      expect(upload.shopId, 'shop-101');
      expect(upload.isGeofenceVerified, isTrue);
      expect(upload.geofenceDistanceMeters, lessThan(50.0));
      expect(upload.photoStoragePath, contains('private/shops/shop-101/daily_uploads/'));
      expect(upload.metadata['local_file_retained_on_device'], isTrue);

      // Verify today's upload can now be fetched
      final fetched = await repo.getTodayUpload('shop-101');
      expect(fetched, isNotNull);
      expect(fetched!.id, upload.id);
    });

    test('Geofence validation: Photo captured outside 50m radius throws LocationOutsideRadiusException', () async {
      // Capture 500m away
      expect(
        () => repo.uploadDailyPhoto(
          shopId: 'shop-102',
          uploaderId: 'owner-2',
          localPhotoPath: '/local/device/photos/shop102_far.jpg',
          latitude: 22.5800, // far from shop-102 at 22.5740
          longitude: 88.3800,
          captureTime: DateTime.now(),
          maxGeofenceRadiusMeters: 50.0,
        ),
        throwsA(isA<LocationOutsideRadiusException>()),
      );
    });

    test('AlreadyUploadedTodayException: Disallows duplicate uploads on the same business date', () async {
      // shop-101 was already uploaded in earlier test
      expect(
        () => repo.uploadDailyPhoto(
          shopId: 'shop-101',
          uploaderId: 'owner-1',
          localPhotoPath: '/local/device/photos/shop101_second.jpg',
          latitude: 22.5720,
          longitude: 88.3620,
          captureTime: DateTime.now(),
        ),
        throwsA(isA<AlreadyUploadedTodayException>()),
      );
    });
  });
}
