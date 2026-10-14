import 'package:data_repository/data_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CompanyAuthState {
  final bool isLoading;
  final Company? company;
  final String? errorMessage;
  final bool otpSent;
  final String? pendingPhone;
  final String? pendingCompanyName;

  const CompanyAuthState({
    this.isLoading = false,
    this.company,
    this.errorMessage,
    this.otpSent = false,
    this.pendingPhone,
    this.pendingCompanyName,
  });

  CompanyAuthState copyWith({
    bool? isLoading,
    Company? company,
    String? errorMessage,
    bool? otpSent,
    String? pendingPhone,
    String? pendingCompanyName,
  }) {
    return CompanyAuthState(
      isLoading: isLoading ?? this.isLoading,
      company: company ?? this.company,
      errorMessage: errorMessage,
      otpSent: otpSent ?? this.otpSent,
      pendingPhone: pendingPhone ?? this.pendingPhone,
      pendingCompanyName: pendingCompanyName ?? this.pendingCompanyName,
    );
  }

  bool get isAuthenticated => company != null;
  bool get hasAssignedZones => company?.hasAssignedZones ?? false;
  bool get isPendingApproval => isAuthenticated && !hasAssignedZones;
}

class CompanyAuthNotifier extends StateNotifier<CompanyAuthState> {
  final ICompanyRepository _repository;

  CompanyAuthNotifier(this._repository) : super(const CompanyAuthState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);
    try {
      final comp = await _repository.getCurrentCompany();
      state = state.copyWith(
        isLoading: false,
        company: comp,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> requestOtp({
    required String companyName,
    required String phoneNumber,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.requestCompanyOtp(
        companyName: companyName,
        phoneNumber: phoneNumber,
      );
      state = state.copyWith(
        isLoading: false,
        otpSent: true,
        pendingPhone: phoneNumber,
        pendingCompanyName: companyName,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> verifyOtp({required String otp}) async {
    final phone = state.pendingPhone;
    if (phone == null || phone.isEmpty) {
      state = state.copyWith(errorMessage: 'Session expired. Please re-enter phone number.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final company = await _repository.verifyCompanyOtp(
        phoneNumber: phone,
        otp: otp,
      );
      state = state.copyWith(
        isLoading: false,
        company: company,
        otpSent: false,
        pendingPhone: null,
        pendingCompanyName: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<void> refreshCompanyStatus() async {
    if (state.company == null) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // Re-fetch current company
      final comp = await _repository.getCurrentCompany();
      state = state.copyWith(
        isLoading: false,
        company: comp,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void logout() {
    state = const CompanyAuthState();
  }

  void resetOtp() {
    state = state.copyWith(otpSent: false, errorMessage: null);
  }
}

final companyAuthProvider =
    StateNotifierProvider<CompanyAuthNotifier, CompanyAuthState>((ref) {
  final repo = ref.watch(companyRepositoryProvider);
  return CompanyAuthNotifier(repo);
});

final companyAssignedZonesProvider = FutureProvider<List<Zone>>((ref) async {
  final authState = ref.watch(companyAuthProvider);
  final company = authState.company;
  if (company == null || !company.hasAssignedZones) {
    return [];
  }
  final repo = ref.watch(companyRepositoryProvider);
  return repo.getAssignedZones(company.id);
});

/// All active platform advertising zones created by Master Admin (dynamically synchronized)
final companyAllZonesProvider = FutureProvider<List<Zone>>((ref) async {
  final repo = ref.watch(companyRepositoryProvider);
  return repo.getAllActiveZones();
});

final companySelectedZoneFilterProvider = StateProvider<String?>((ref) => null);
final companySelectedCategoryFilterProvider = StateProvider<String>((ref) => 'All');
final companySearchQueryProvider = StateProvider<String>((ref) => '');

final companyAssignedShopsProvider =
    FutureProvider<List<CompanyVisibleShop>>((ref) async {
  final authState = ref.watch(companyAuthProvider);
  final company = authState.company;
  if (company == null || !company.hasAssignedZones) {
    return [];
  }

  final zoneFilter = ref.watch(companySelectedZoneFilterProvider);
  final categoryFilter = ref.watch(companySelectedCategoryFilterProvider);
  final searchQuery = ref.watch(companySearchQueryProvider);

  final repo = ref.watch(companyRepositoryProvider);
  return repo.getAssignedShops(
    companyId: company.id,
    zoneId: zoneFilter,
    category: categoryFilter,
    searchQuery: searchQuery,
  );
});

final companyZoneSummariesProvider =
    FutureProvider<List<CompanyZoneSummary>>((ref) async {
  final authState = ref.watch(companyAuthProvider);
  final company = authState.company;
  if (company == null || !company.hasAssignedZones) {
    return [];
  }

  final repo = ref.watch(companyRepositoryProvider);
  return repo.getAllZoneSummaries(company.id);
});

final companyZoneSummaryProvider =
    FutureProvider.family<CompanyZoneSummary, String>((ref, zoneId) async {
  final authState = ref.watch(companyAuthProvider);
  final company = authState.company;
  if (company == null) {
    throw Exception('Not authenticated');
  }

  final repo = ref.watch(companyRepositoryProvider);
  return repo.getZoneSummary(companyId: company.id, zoneId: zoneId);
});

/// Advertisement stand space pricing list provider
final companyPricingListProvider =
    FutureProvider<List<AdvertisementPricing>>((ref) async {
  final repo = ref.watch(companyRepositoryProvider);
  return repo.getAdvertisementPricings();
});

/// Get all eligible shops in a specific zone assigned to the company
final companyZoneShopsProvider =
    FutureProvider.family<List<CompanyVisibleShop>, String>((ref, zoneId) async {
  final authState = ref.watch(companyAuthProvider);
  final company = authState.company;
  if (company == null || !company.assignedZoneIds.contains(zoneId)) {
    return [];
  }

  final repo = ref.watch(companyRepositoryProvider);
  return repo.getAssignedShops(
    companyId: company.id,
    zoneId: zoneId,
  );
});

/// Active brand name used for the dynamic tabletop retail counter banner mockup
final previewBrandNameProvider = StateProvider<String>((ref) {
  final company = ref.watch(companyAuthProvider).company;
  return company?.tradeName ?? 'Britannia';
});

/// Whether the brand entry onboarding overlay with frosted hazy background is displayed
final isBrandModalOpenProvider = StateProvider<bool>((ref) => true);

