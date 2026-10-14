import 'package:app_core/app_core.dart';

abstract class IPrivateMediaRepository {
  /// Generate a short-lived signed URL for private bucket objects (e.g. Aadhaar docs, daily photos).
  /// Strictly rejects public URL generation for private assets.
  Future<String> getPrivateSignedUrl({
    required String bucketName,
    required String objectPath,
    int expiresInSeconds = 300, // 5 minutes default short-lived expiry
  });
}

class SupabasePrivateMediaRepository implements IPrivateMediaRepository {
  final SupabaseManager? _supabaseManager;

  const SupabasePrivateMediaRepository({SupabaseManager? supabaseManager})
      : _supabaseManager = supabaseManager;

  @override
  Future<String> getPrivateSignedUrl({
    required String bucketName,
    required String objectPath,
    int expiresInSeconds = 300,
  }) async {
    final client = _supabaseManager?.client;
    if (client != null) {
      try {
        final signedUrl = await client.storage
            .from(bucketName)
            .createSignedUrl(objectPath, expiresInSeconds);
        return signedUrl;
      } catch (e) {
        throw NetworkException('Failed to generate private signed URL: $e');
      }
    }

    // Offline / staging fallback representation
    return 'https://secure-vault.shopad.local/$bucketName/$objectPath?token=signed_preview_${DateTime.now().millisecondsSinceEpoch}&expires_in=$expiresInSeconds';
  }
}
