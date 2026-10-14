import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MapReverseGeocodeService {
  static final http.Client _client = http.Client();
  static final Map<String, String> _cache = {};

  /// Reverse geocode latitude and longitude to a human-readable landmark or address.
  /// Falls back gracefully to formatted coordinates if network is unavailable or times out.
  static Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final key = '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    try {
      final uri = Uri.parse(
        'https://photon.komoot.io/reverse?lat=$latitude&lon=$longitude',
      );

      final response = await _client.get(uri, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];

        if (features.isNotEmpty) {
          final props = features[0]['properties'] as Map<String, dynamic>? ?? {};
          final name = props['name'] as String?;
          final street = props['street'] as String?;
          final district = props['district'] as String?;
          final city = props['city'] as String?;
          final state = props['state'] as String?;

          final parts = <String>[];
          if (name != null && name.isNotEmpty) parts.add(name);
          if (street != null && street.isNotEmpty && street != name) parts.add(street);
          if (district != null && district.isNotEmpty && !parts.contains(district)) parts.add(district);
          if (city != null && city.isNotEmpty && !parts.contains(city)) parts.add(city);
          if (parts.isEmpty && state != null && state.isNotEmpty) parts.add(state);

          if (parts.isNotEmpty) {
            final resolved = parts.join(', ');
            _cache[key] = resolved;
            return resolved;
          }
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }

    return null;
  }
}
