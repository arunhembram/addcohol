import 'dart:convert';
import 'dart:io';

void main() async {
  final Map<String, Map<String, dynamic>> zoneModes = {};
  final Set<String> distributedShops = {};
  final Set<String> goneShops = {};
  final Set<String> closedTodayShops = {};
  final Set<String> crossedShops = {};
  final List<Map<String, dynamic>> catalogMaterials = [];
  final Map<String, Map<String, String>> materialRunStatuses = {};
  final Map<String, Map<String, dynamic>> customZones = {};
  final Map<String, Map<String, dynamic>> zonePricings = {};
  final Map<String, List<String>> employeeZoneAssignments = {};

  final zonesStorageFile = File('tool/.sync_zones.json');
  if (zonesStorageFile.existsSync()) {
    try {
      final text = zonesStorageFile.readAsStringSync();
      if (text.isNotEmpty) {
        final decoded = jsonDecode(text) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is Map<String, dynamic>) {
            customZones[entry.key] = entry.value as Map<String, dynamic>;
          }
        }
        print('SYNC: Loaded ${customZones.length} custom zones from storage');
      }
    } catch (e) {
      print('SYNC: Error loading saved zones: $e');
    }
  }

  void saveZonesToStorage() {
    try {
      zonesStorageFile.writeAsStringSync(jsonEncode(customZones));
    } catch (e) {
      print('SYNC: Error persisting custom zones: $e');
    }
  }

  final pricingStorageFile = File('tool/.sync_pricing.json');
  if (pricingStorageFile.existsSync()) {
    try {
      final text = pricingStorageFile.readAsStringSync();
      if (text.isNotEmpty) {
        final decoded = jsonDecode(text) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is Map<String, dynamic>) {
            zonePricings[entry.key] = entry.value as Map<String, dynamic>;
          }
        }
        print('SYNC: Loaded ${zonePricings.length} zone pricing overrides from storage');
      }
    } catch (e) {
      print('SYNC: Error loading saved pricing overrides: $e');
    }
  }

  void savePricingToStorage() {
    try {
      pricingStorageFile.writeAsStringSync(jsonEncode(zonePricings));
    } catch (e) {
      print('SYNC: Error persisting pricing overrides: $e');
    }
  }

  final employeeStorageFile = File('tool/.sync_employee_assignments.json');
  if (employeeStorageFile.existsSync()) {
    try {
      final text = employeeStorageFile.readAsStringSync();
      if (text.isNotEmpty) {
        final decoded = jsonDecode(text) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is List) {
            employeeZoneAssignments[entry.key] =
                (entry.value as List).map((e) => e.toString()).toList();
          }
        }
        print('SYNC: Loaded ${employeeZoneAssignments.length} employee assignments from storage');
      }
    } catch (e) {
      print('SYNC: Error loading saved employee assignments: $e');
    }
  }

  void saveEmployeeAssignmentsToStorage() {
    try {
      employeeStorageFile.writeAsStringSync(jsonEncode(employeeZoneAssignments));
    } catch (e) {
      print('SYNC: Error persisting employee assignments: $e');
    }
  }

  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8089);
  print('DISTRIBUTION_SYNC_SERVER_STARTED: http://localhost:8089');

  await for (HttpRequest request in server) {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      continue;
    }

    final path = request.uri.path;
    if (path == '/distribution-state') {
      if (request.method == 'GET') {
        final body = jsonEncode({
          'zones': zoneModes,
          'distributedShops': distributedShops.toList(),
          'goneShops': goneShops.toList(),
          'closedTodayShops': closedTodayShops.toList(),
          'crossedShops': crossedShops.toList(),
          'materials': catalogMaterials,
          'materialRunStatuses': materialRunStatuses,
          'customZones': customZones.values.toList(),
          'zonePricings': zonePricings,
          'employeeZoneAssignments': employeeZoneAssignments,
        });
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.ok
          ..write(body);
        await request.response.close();
      } else if (request.method == 'POST') {
        try {
          final content = await utf8.decoder.bind(request).join();
          if (content.isNotEmpty) {
            final data = jsonDecode(content) as Map<String, dynamic>;

            // 1. Zone mode & configuration
            if (data.containsKey('zoneId') && data.containsKey('enabled')) {
              final zoneId = data['zoneId'] as String;
              final enabled = data['enabled'] as bool;
              final prevConfig = zoneModes[zoneId] ?? {};
              final categories = data.containsKey('categories') && data['categories'] is List
                  ? (data['categories'] as List).map((e) => e.toString()).toList()
                  : (prevConfig['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
              final driveCompleted = data.containsKey('driveCompleted')
                  ? data['driveCompleted'] as bool
                  : (prevConfig['driveCompleted'] as bool? ?? false);
              final startTime = data.containsKey('startTime')
                  ? data['startTime'] as String?
                  : (prevConfig['startTime'] as String?);

              zoneModes[zoneId] = {
                'enabled': enabled,
                'categories': categories,
                'driveCompleted': driveCompleted,
                'startTime': startTime ?? (enabled ? DateTime.now().toIso8601String() : null),
              };
              print('SYNC: Zone $zoneId enabled=$enabled driveCompleted=$driveCompleted categories=$categories');
            }

            // 2. Mark shop distributed
            if (data.containsKey('markDistributedShopId')) {
              final sId = data['markDistributedShopId'] as String;
              distributedShops.add(sId);
              closedTodayShops.remove(sId);
              crossedShops.remove(sId);
              print('SYNC: Shop $sId marked distributed');
            }

            // 3. Mark shop gone (permanently closed/vacated)
            if (data.containsKey('markGoneShopId')) {
              final sId = data['markGoneShopId'] as String;
              goneShops.add(sId);
              distributedShops.remove(sId);
              closedTodayShops.remove(sId);
              crossedShops.remove(sId);
              print('SYNC: Shop $sId marked GONE (permanently closed/vacated)');
            }

            // 4. Mark shop closed today
            if (data.containsKey('markClosedTodayShopId')) {
              final sId = data['markClosedTodayShopId'] as String;
              closedTodayShops.add(sId);
              crossedShops.add(sId);
              print('SYNC: Shop $sId marked closed today (showing red cross)');
            }

            // 5. Reset distribution drive for a zone
            if (data.containsKey('resetZoneDriveId')) {
              final zId = data['resetZoneDriveId'] as String;
              final prevConfig = zoneModes[zId] ?? {};
              final categories = (prevConfig['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['Shops', 'Saloons'];
              zoneModes[zId] = {
                'enabled': true,
                'categories': categories,
                'driveCompleted': false,
                'startTime': DateTime.now().toIso8601String(),
              };
              // Clear distributed & closed statuses (gone shops remain archived)
              distributedShops.clear();
              closedTodayShops.clear();
              crossedShops.clear();
              print('SYNC: Zone $zId distribution drive reset for new campaign');
            }

            // 6. Materials catalog management
            if (data.containsKey('material') && data['material'] is Map<String, dynamic>) {
              final mat = data['material'] as Map<String, dynamic>;
              catalogMaterials.removeWhere((m) => m['id'] == mat['id']);
              catalogMaterials.add(mat);
              print('SYNC: Material added/updated: ${mat['name']}');
            }

            if (data.containsKey('removeMaterialId')) {
              final mId = data['removeMaterialId'] as String;
              catalogMaterials.removeWhere((m) => m['id'] == mId);
              print('SYNC: Material removed: $mId');
            }

            // 7. Material run status toggle
            if (data.containsKey('materialRunToggle') && data['materialRunToggle'] is Map<String, dynamic>) {
              final toggle = data['materialRunToggle'] as Map<String, dynamic>;
              final zId = toggle['zoneId'] as String?;
              final mId = toggle['materialId'] as String?;
              final status = toggle['status'] as String?;
              if (zId != null && mId != null && status != null) {
                materialRunStatuses.putIfAbsent(zId, () => {})[mId] = status;
                print('SYNC: Zone $zId material $mId status=$status');
              }
            }

            // 8. Custom Zones management (Master Admin created/updated zones)
            if (data.containsKey('customZone') && data['customZone'] is Map<String, dynamic>) {
              final zMap = data['customZone'] as Map<String, dynamic>;
              final zId = zMap['id'] as String?;
              if (zId != null && zId.isNotEmpty) {
                final isNew = !customZones.containsKey(zId);
                customZones[zId] = zMap;
                saveZonesToStorage();
                print('SYNC: Custom Zone registered/updated: ${zMap['name']} ($zId)');

                if (isNew) {
                  final emp1List = employeeZoneAssignments.putIfAbsent('emp-20001', () => [
                    'z-kolkata-central',
                    'z-saltlake-sector5',
                  ]);
                  if (!emp1List.contains(zId)) {
                    emp1List.add(zId);
                    saveEmployeeAssignmentsToStorage();
                    print('SYNC: Auto-assigned new custom zone $zId to emp-20001');
                  }
                }
              }
            }

            if (data.containsKey('zone') && data['zone'] is Map<String, dynamic>) {
              final zMap = data['zone'] as Map<String, dynamic>;
              final zId = zMap['id'] as String?;
              if (zId != null && zId.isNotEmpty) {
                final isNew = !customZones.containsKey(zId);
                customZones[zId] = zMap;
                saveZonesToStorage();
                print('SYNC: Custom Zone registered/updated: ${zMap['name']} ($zId)');

                if (isNew) {
                  final emp1List = employeeZoneAssignments.putIfAbsent('emp-20001', () => [
                    'z-kolkata-central',
                    'z-saltlake-sector5',
                  ]);
                  if (!emp1List.contains(zId)) {
                    emp1List.add(zId);
                    saveEmployeeAssignmentsToStorage();
                    print('SYNC: Auto-assigned new custom zone $zId to emp-20001');
                  }
                }
              }
            }

            if (data.containsKey('removeZoneId')) {
              final zId = data['removeZoneId'] as String;
              customZones.remove(zId);
              saveZonesToStorage();
              print('SYNC: Custom Zone removed: $zId');
            }

            // 9. Zone pricing configuration override
            if (data.containsKey('zonePricing') && data['zonePricing'] is Map<String, dynamic>) {
              final pricingMap = data['zonePricing'] as Map<String, dynamic>;
              final zId = (data['zoneId'] ?? pricingMap['zone_id']) as String?;
              if (zId != null && zId.isNotEmpty) {
                zonePricings[zId] = pricingMap;
                savePricingToStorage();
                print('SYNC: Zone $zId pricing override updated: $pricingMap');
              }
            }

            // 9b. Employee Zone Assignments
            if (data.containsKey('employeeZoneAssignment') && data['employeeZoneAssignment'] is Map<String, dynamic>) {
              final assign = data['employeeZoneAssignment'] as Map<String, dynamic>;
              final empId = assign['employeeId'] as String?;
              final zIds = (assign['zoneIds'] as List<dynamic>?)?.map((e) => e.toString()).toList();
              if (empId != null && zIds != null) {
                employeeZoneAssignments[empId] = zIds;
                saveEmployeeAssignmentsToStorage();
                print('SYNC: Employee $empId assigned to zones: $zIds');
              }
            }

            // 10. Reset all (for fresh development state)
            if (data.containsKey('resetAll') && data['resetAll'] == true) {
              zoneModes.clear();
              distributedShops.clear();
              goneShops.clear();
              closedTodayShops.clear();
              crossedShops.clear();
              catalogMaterials.clear();
              materialRunStatuses.clear();
              customZones.clear();
              zonePricings.clear();
              employeeZoneAssignments.clear();
              saveZonesToStorage();
              savePricingToStorage();
              saveEmployeeAssignmentsToStorage();
              print('SYNC: All distribution, gone states, custom zones, pricing and employee assignments cleared');
            }
          }
        } catch (e) {
          print('SYNC ERROR: $e');
        }
        final body = jsonEncode({
          'success': true,
          'zones': zoneModes,
          'distributedShops': distributedShops.toList(),
          'goneShops': goneShops.toList(),
          'closedTodayShops': closedTodayShops.toList(),
          'crossedShops': crossedShops.toList(),
          'materials': catalogMaterials,
          'materialRunStatuses': materialRunStatuses,
          'customZones': customZones.values.toList(),
          'zonePricings': zonePricings,
          'employeeZoneAssignments': employeeZoneAssignments,
        });
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.ok
          ..write(body);
        await request.response.close();
      }
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }
}
