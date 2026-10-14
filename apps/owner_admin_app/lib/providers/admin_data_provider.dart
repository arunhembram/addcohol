import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../models/zone_model.dart';
import '../models/shop_model.dart';
import '../models/company_model.dart';
import '../models/assignment_model.dart';
import '../models/upload_model.dart';
import '../models/issue_model.dart';
import '../models/audit_model.dart';

class AdminDataProvider extends ChangeNotifier {
  final ApiService _apiService;
  final WebSocketService _wsService;
  StreamSubscription? _wsSub;

  Map<String, dynamic>? _kpis;
  List<ZoneModel> _zones = [];
  List<ShopModel> _shops = [];
  List<CompanyModel> _companies = [];
  List<AssignmentModel> _assignments = [];
  List<UploadModel> _todayUploads = [];
  List<IssueModel> _issues = [];
  List<AuditLogModel> _auditLogs = [];

  bool _isLoading = false;
  String? _error;
  String? _lastRealtimeEvent;

  AdminDataProvider(this._apiService, this._wsService) {
    _initWebSocketListener();
  }

  // Getters
  Map<String, dynamic>? get kpis => _kpis;
  List<ZoneModel> get zones => _zones;
  List<ShopModel> get shops => _shops;
  List<CompanyModel> get companies => _companies;
  List<AssignmentModel> get assignments => _assignments;
  List<UploadModel> get todayUploads => _todayUploads;
  List<IssueModel> get issues => _issues;
  List<AuditLogModel> get auditLogs => _auditLogs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get lastRealtimeEvent => _lastRealtimeEvent;
  bool get isWsConnected => _wsService.isConnected;

  void _initWebSocketListener() {
    _wsService.connect();
    _wsSub = _wsService.eventStream.listen((event) {
      final type = event['type'] ?? '';
      _lastRealtimeEvent = type;
      debugPrint('[ADMIN DATA] Real-time event received: $type');

      // Refresh data on real-time triggers
      if (type.startsWith('upload:') ||
          type.startsWith('shop:') ||
          type.startsWith('zone:') ||
          type.startsWith('issue:') ||
          type == 'day:reset') {
        fetchAll(silent: true);
      }
    });
  }

  Future<void> fetchAll({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        _apiService.getDashboardKPIs(),
        _apiService.getZones(),
        _apiService.getShops(),
        _apiService.getCompanies(),
        _apiService.getAssignments(),
        _apiService.getTodayUploads(),
        _apiService.getIssues(),
        _apiService.getAuditLogs(),
      ]);

      _kpis = results[0] as Map<String, dynamic>;
      _zones = results[1] as List<ZoneModel>;
      _shops = results[2] as List<ShopModel>;
      _companies = results[3] as List<CompanyModel>;
      _assignments = results[4] as List<AssignmentModel>;
      _todayUploads = results[5] as List<UploadModel>;
      _issues = results[6] as List<IssueModel>;
      _auditLogs = results[7] as List<AuditLogModel>;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[ADMIN DATA] Fetch error: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Actions ---
  Future<void> reviewProof({
    required String uploadId,
    required String status,
    String? rejectionReason,
  }) async {
    await _apiService.reviewUpload(
      uploadId: uploadId,
      status: status,
      rejectionReason: rejectionReason,
    );
    await fetchAll(silent: true);
  }

  Future<void> triggerMidnightJob() async {
    await _apiService.triggerMidnightExpiry();
    await fetchAll(silent: true);
  }

  Future<void> addZone({required String name, String? description, String? boundaryGeojson}) async {
    await _apiService.createZone(
      name: name,
      description: description,
      boundaryGeojson: boundaryGeojson,
    );
    await fetchAll(silent: true);
  }

  Future<void> archiveZone(String zoneId) async {
    await _apiService.archiveZone(zoneId);
    await fetchAll(silent: true);
  }

  Future<void> assignEmployee({required String zoneId, required String employeeUserId}) async {
    await _apiService.assignEmployeeToZone(zoneId: zoneId, employeeUserId: employeeUserId);
    await fetchAll(silent: true);
  }

  Future<Map<String, dynamic>> addShop({
    required String shopName,
    required String category,
    required String address,
    required double latitude,
    required double longitude,
    required String zoneId,
    String? merchantPhone,
    required String uploadMode,
  }) async {
    final res = await _apiService.createShop(
      shopName: shopName,
      category: category,
      address: address,
      latitude: latitude,
      longitude: longitude,
      zoneId: zoneId,
      merchantPhone: merchantPhone,
      uploadMode: uploadMode,
    );
    await fetchAll(silent: true);
    return res;
  }

  Future<void> moveShopZone({
    required String shopId,
    required String newZoneId,
    String? reason,
  }) async {
    await _apiService.moveShopZone(shopId: shopId, newZoneId: newZoneId, reason: reason);
    await fetchAll(silent: true);
  }

  Future<void> addCompany({
    required String name,
    String? contactPersonName,
    String? contactPhone,
    String? contactEmail,
  }) async {
    await _apiService.createCompany(
      name: name,
      contactPersonName: contactPersonName,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
    );
    await fetchAll(silent: true);
  }

  Future<void> assignZoneToCompany({
    required String zoneId,
    required String companyId,
    required String campaignName,
    String? campaignDescription,
    required String campaignStartDate,
    required String campaignEndDate,
  }) async {
    await _apiService.assignZoneToCompany(
      zoneId: zoneId,
      companyId: companyId,
      campaignName: campaignName,
      campaignDescription: campaignDescription,
      campaignStartDate: campaignStartDate,
      campaignEndDate: campaignEndDate,
    );
    await fetchAll(silent: true);
  }

  Future<void> endAssignment(String assignmentId) async {
    await _apiService.endAssignment(assignmentId);
    await fetchAll(silent: true);
  }

  Future<void> updateIssueStatus({
    required String issueId,
    required String status,
    String? resolutionNotes,
  }) async {
    await _apiService.updateIssueStatus(
      issueId: issueId,
      status: status,
      resolutionNotes: resolutionNotes,
    );
    await fetchAll(silent: true);
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }
}
