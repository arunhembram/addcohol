import 'dart:convert';
import 'package:http/http.dart' as http;

class PlaceSearchResult {
  final String name;
  final String displayName;
  final double latitude;
  final double longitude;
  final String? type;

  const PlaceSearchResult({
    required this.name,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.type,
  });

  @override
  String toString() => '$name ($latitude, $longitude)';
}

class PlaceSearchService {
  static final http.Client _client = http.Client();

  /// Search places, streets, districts, or landmarks globally
  /// Supports CORS out-of-the-box on Flutter Web, Mobile, and Desktop
  static Future<List<PlaceSearchResult>> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    try {
      final uri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(cleanQuery)}&limit=6',
      );

      final response = await _client.get(uri, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];

        final results = <PlaceSearchResult>[];
        for (final item in features) {
          final props = item['properties'] as Map<String, dynamic>? ?? {};
          final geometry = item['geometry'] as Map<String, dynamic>? ?? {};
          final coordinates = geometry['coordinates'] as List<dynamic>? ?? [];

          if (coordinates.length >= 2) {
            final lng = (coordinates[0] as num).toDouble();
            final lat = (coordinates[1] as num).toDouble();

            final name = (props['name'] as String?) ??
                (props['street'] as String?) ??
                cleanQuery;

            final parts = <String>[];
            if (props['street'] != null && props['street'] != name) {
              parts.add(props['street'] as String);
            }
            if (props['district'] != null) parts.add(props['district'] as String);
            if (props['city'] != null) parts.add(props['city'] as String);
            if (props['state'] != null) parts.add(props['state'] as String);
            if (props['country'] != null) parts.add(props['country'] as String);

            final fullAddress = parts.isNotEmpty ? parts.join(', ') : name;

            results.add(
              PlaceSearchResult(
                name: name,
                displayName: fullAddress,
                latitude: lat,
                longitude: lng,
                type: props['type'] as String?,
              ),
            );
          }
        }
        return results;
      }
    } catch (_) {
      // Graceful fallback for network timeout or connectivity interruption
    }
    return [];
  }
}
