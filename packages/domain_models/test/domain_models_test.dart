import 'package:flutter_test/flutter_test.dart';
import 'package:domain_models/domain_models.dart';

void main() {
  group('UserRole Tests', () {
    test('UserRole parsing from string', () {
      expect(UserRole.fromString('master_admin'), UserRole.masterAdmin);
      expect(UserRole.fromString('ADMIN'), UserRole.admin);
      expect(UserRole.fromString('employee'), UserRole.employee);
      expect(UserRole.fromString('shopkeeper'), UserRole.shopkeeper);
      expect(UserRole.fromString('company'), UserRole.company);
      expect(UserRole.fromString('company_user'), UserRole.companyUser);
      expect(UserRole.fromString('unknown'), UserRole.shopkeeper);
      expect(UserRole.fromString(null), UserRole.shopkeeper);
    });

    test('UserRole helper getters', () {
      expect(UserRole.masterAdmin.isMasterAdmin, isTrue);
      expect(UserRole.masterAdmin.isAdministrative, isTrue);
      expect(UserRole.admin.isAdministrative, isTrue);
      expect(UserRole.employee.isEmployee, isTrue);
      expect(UserRole.shopkeeper.isShopkeeper, isTrue);
      expect(UserRole.company.isCompany, isTrue);
    });
  });

  group('Domain Models Serialization', () {
    test('UserProfile serialization roundtrip', () {
      final now = DateTime.now();
      final profile = UserProfile(
        id: 'usr-123',
        email: 'admin@shopad.com',
        fullName: 'Admin User',
        role: UserRole.admin,
        phoneNumber: '+8801700000000',
        createdAt: now,
      );

      final json = profile.toJson();
      expect(json['id'], 'usr-123');
      expect(json['role'], 'admin');

      final reconstructed = UserProfile.fromJson(json);
      expect(reconstructed.id, profile.id);
      expect(reconstructed.role, UserRole.admin);
      expect(reconstructed.fullName, 'Admin User');
    });

    test('Shop model serialization roundtrip', () {
      final shop = Shop(
        id: 'shop-001',
        ownerId: 'owner-1',
        shopName: 'Dhaka Super Store',
        category: 'Electronics',
        address: 'Dhanmondi 27, Dhaka',
        latitude: 23.754,
        longitude: 90.375,
        createdAt: DateTime.now(),
      );

      final json = shop.toJson();
      final fromJson = Shop.fromJson(json);
      expect(fromJson.shopName, 'Dhaka Super Store');
      expect(fromJson.latitude, 23.754);
    });

    test('Shop follow-up status and date category getters', () {
      final now = DateTime.now();

      // 1. Agreed shop is not a follow-up
      final agreedShop = Shop(
        id: 'shp-agreed',
        ownerId: 'own-1',
        shopName: 'Agreed Shop',
        category: 'Grocery',
        address: '123 Main St',
        latitude: 22.5,
        longitude: 88.3,
        isAgreed: true,
        status: 'active',
        createdAt: now,
      );
      expect(agreedShop.isFollowup, isFalse);
      expect(agreedShop.isFollowupToday, isFalse);
      expect(agreedShop.isFollowupMissed, isFalse);

      // 2. Follow-up today
      final todayShop = Shop(
        id: 'shp-today',
        ownerId: 'own-2',
        shopName: 'Today Follow-up Shop',
        category: 'Grocery',
        address: '123 Main St',
        latitude: 22.5,
        longitude: 88.3,
        isAgreed: false,
        status: 'follow_up',
        nextFollowupDate: DateTime(now.year, now.month, now.day, 14, 30),
        createdAt: now,
      );
      expect(todayShop.isFollowup, isTrue);
      expect(todayShop.isFollowupToday, isTrue);
      expect(todayShop.isFollowupMissed, isFalse);
      expect(todayShop.isFollowupFuture, isFalse);

      // 3. Follow-up missed (yesterday or earlier)
      final missedShop = Shop(
        id: 'shp-missed',
        ownerId: 'own-3',
        shopName: 'Missed Follow-up Shop',
        category: 'Saloon',
        address: '123 Main St',
        latitude: 22.5,
        longitude: 88.3,
        isAgreed: false,
        status: 'follow_up',
        nextFollowupDate: now.subtract(const Duration(days: 2)),
        createdAt: now,
      );
      expect(missedShop.isFollowup, isTrue);
      expect(missedShop.isFollowupToday, isFalse);
      expect(missedShop.isFollowupMissed, isTrue);
      expect(missedShop.isFollowupFuture, isFalse);

      // 4. Follow-up future (tomorrow or later)
      final futureShop = Shop(
        id: 'shp-future',
        ownerId: 'own-4',
        shopName: 'Future Follow-up Shop',
        category: 'Chemist',
        address: '123 Main St',
        latitude: 22.5,
        longitude: 88.3,
        isAgreed: false,
        status: 'follow_up',
        nextFollowupDate: now.add(const Duration(days: 2)),
        createdAt: now,
      );
      expect(futureShop.isFollowup, isTrue);
      expect(futureShop.isFollowupToday, isFalse);
      expect(futureShop.isFollowupMissed, isFalse);
      expect(futureShop.isFollowupFuture, isTrue);
    });

    test('AdCampaign and DeviceScreen models', () {
      final campaign = AdCampaign(
        id: 'camp-1',
        companyId: 'comp-1',
        title: 'Eid Mega Sale',
        mediaUrl: 'https://example.com/ad.mp4',
        status: 'active',
        budget: 50000.0,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
        createdAt: DateTime.now(),
      );

      expect(campaign.title, 'Eid Mega Sale');
      expect(campaign.budget, 50000.0);

      final screen = DeviceScreen(
        id: 'screen-1',
        shopId: 'shop-1',
        screenCode: 'SCR-9901',
        createdAt: DateTime.now(),
      );
      expect(screen.screenCode, 'SCR-9901');
      expect(screen.isOnline, isFalse);
    });

    test('PaymentTransaction serialization', () {
      final tx = PaymentTransaction(
        id: 'tx-100',
        userId: 'u-1',
        amount: 1500.0,
        status: 'success',
        createdAt: DateTime.now(),
      );
      expect(tx.isSuccessful, isTrue);
      expect(tx.amount, 1500.0);
    });
  });
}
