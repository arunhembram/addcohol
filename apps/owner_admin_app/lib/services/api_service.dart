import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/zone_model.dart';
import '../models/shop_model.dart';
import '../models/company_model.dart';
import '../models/assignment_model.dart';
import '../models/upload_model.dart';
import '../models/issue_model.dart';
import '../models/audit_model.dart';

class ApiService {
  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> _headers() {
    final headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // --- Auth ---
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      _token = data['token'];
      return data;
    } else {
      throw Exception(data['error'] ?? 'Login failed');
    }
  }

  // --- Dashboard KPIs ---
  Future<Map<String, dynamic>> getDashboardKPIs() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/reports/dashboard');
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load dashboard metrics');
  }

  // --- Zones ---
  Future<List<ZoneModel>> getZones() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/zones');
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => ZoneModel.fromJson(json)).toList();
    }
    throw Exception('Failed to load zones');
  }

  Future<ZoneModel> createZone({
    required String name,
    String? description,
    String? boundaryGeojson,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/zones');
    final response = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'description': description,
        'boundary_geojson': boundaryGeojson,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return ZoneModel.fromJson(data);
    }
    throw Exception(data['error'] ?? 'Failed to create zone');
  }

  Future<void> archiveZone(String zoneId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/zones/$zoneId');
    final response = await http.delete(url, headers: _headers());
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to archive zone');
    }
  }

  Future<void> assignEmployeeToZone({
    required String zoneId,
    required String employeeUserId,
    String role = 'primary',
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/zones/$zoneId/assign-employee');
    final response = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({'employee_user_id': employeeUserId, 'assignment_role': role}),
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to assign employee');
    }
  }

  Future<void> unassignEmployeeFromZone({
    required String zoneId,
    required String employeeUserId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/zones/$zoneId/unassign-employee/$employeeUserId');
    final response = await http.delete(url, headers: _headers());
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to unassign employee');
    }
  }

  // --- Shops ---
  Future<List<ShopModel>> getShops({
    String? zoneId,
    String? category,
    String? uploadMode,
    String? search,
  }) async {
    final queryParams = <String, String>{};
    if (zoneId != null && zoneId.isNotEmpty) queryParams['zone_id'] = zoneId;
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    if (uploadMode != null && uploadMode.isNotEmpty) queryParams['upload_mode'] = uploadMode;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('${ApiConfig.baseUrl}/shops').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => ShopModel.fromJson(json)).toList();
    }
    throw Exception('Failed to load shops');
  }

  Future<Map<String, dynamic>> createShop({
    required String shopName,
    required String category,
    required String address,
    required double latitude,
    required double longitude,
    required String zoneId,
    String? merchantPhone,
    required String uploadMode,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/shops');
    final response = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'shop_name': shopName,
        'category': category,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'zone_id': zoneId,
        'merchant_phone': merchantPhone,
        'upload_mode': uploadMode,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return data;
    }
    throw Exception(data['error'] ?? 'Failed to create shop');
  }

  Future<void> moveShopZone({
    required String shopId,
    required String newZoneId,
    String? reason,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/shops/$shopId/move-zone');
    final response = await http.put(
      url,
      headers: _headers(),
      body: jsonEncode({'new_zone_id': newZoneId, 'reason': reason}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to move shop to new zone');
    }
  }

  // --- Companies & Assignments ---
  Future<List<CompanyModel>> getCompanies() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/companies');
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => CompanyModel.fromJson(json)).toList();
    }
    throw Exception('Failed to load companies');
  }

  Future<CompanyModel> createCompany({
    required String name,
    String? contactPersonName,
    String? contactPhone,
    String? contactEmail,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/companies');
    final response = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'contact_person_name': contactPersonName,
        'contact_phone': contactPhone,
        'contact_email': contactEmail,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return CompanyModel.fromJson(data);
    }
    throw Exception(data['error'] ?? 'Failed to create company');
  }

  Future<void> createCompanyUser({
    required String companyId,
    required String fullName,
    required String phone,
    String? email,
    required String password,
    String permissionLevel = 'company_admin',
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/companies/$companyId/users');
    final response = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'password': password,
        'permission_level': permissionLevel,
      }),
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to create company user');
    }
  }

  Future<List<AssignmentModel>> getAssignments() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/zone-company-assignments');
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => AssignmentModel.fromJson(json)).toList();
    }
    throw Exception('Failed to load assignments');
  }

  Future<AssignmentModel> assignZoneToCompany({
    required String zoneId,
    required String companyId,
    required String campaignName,
    String? campaignDescription,
    required String campaignStartDate,
    required String campaignEndDate,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/zone-company-assignments');
    final response = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'zone_id': zoneId,
        'company_id': companyId,
        'campaign_name': campaignName,
        'campaign_description': campaignDescription,
        'campaign_start_date': campaignStartDate,
        'campaign_end_date': campaignEndDate,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return AssignmentModel.fromJson(data['assignment']);
    }
    throw Exception(data['error'] ?? 'Failed to assign zone to company');
  }

  Future<void> endAssignment(String assignmentId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/zone-company-assignments/$assignmentId/end');
    final response = await http.put(url, headers: _headers());
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to end assignment');
    }
  }

  // --- Uploads & Review ---
  Future<List<UploadModel>> getTodayUploads({String? status, String? zoneId}) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (zoneId != null && zoneId.isNotEmpty) queryParams['zone_id'] = zoneId;

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/uploads/today',
    ).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => UploadModel.fromJson(json)).toList();
    }
    throw Exception('Failed to load uploads');
  }

  Future<void> reviewUpload({
    required String uploadId,
    required String status, // 'verified' or 'rejected'
    String? rejectionReason,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/uploads/$uploadId/review');
    final response = await http.put(
      url,
      headers: _headers(),
      body: jsonEncode({'status': status, 'rejection_reason': rejectionReason}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to review upload');
    }
  }

  Future<Map<String, dynamic>> triggerMidnightExpiry() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/cron/trigger-midnight');
    final response = await http.post(url, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final data = jsonDecode(response.body);
    throw Exception(data['error'] ?? 'Failed to trigger midnight expiry');
  }

  // --- Issues ---
  Future<List<IssueModel>> getIssues() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/issues');
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => IssueModel.fromJson(json)).toList();
    }
    throw Exception('Failed to load issues');
  }

  Future<void> updateIssueStatus({
    required String issueId,
    required String status,
    String? resolutionNotes,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/issues/$issueId/status');
    final response = await http.put(
      url,
      headers: _headers(),
      body: jsonEncode({'status': status, 'resolution_notes': resolutionNotes}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to update issue status');
    }
  }

  // --- Audit Logs ---
  Future<List<AuditLogModel>> getAuditLogs() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/audit-logs');
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => AuditLogModel.fromJson(json)).toList();
    }
    throw Exception('Failed to load audit logs');
  }
}
