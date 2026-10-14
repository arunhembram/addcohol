import 'package:app_core/app_core.dart';
import 'package:domain_models/domain_models.dart';

abstract class IShopRepository {
  Future<List<Shop>> getShops({int limit = 20});
  Future<Shop?> getShopById(String id);
}

class SupabaseShopRepository implements IShopRepository {
  final SupabaseManager supabaseManager;

  const SupabaseShopRepository({required this.supabaseManager});

  @override
  Future<List<Shop>> getShops({int limit = 20}) async {
    final client = supabaseManager.client;
    if (client == null) return [];

    try {
      final response = await client
          .from('shops')
          .select()
          .limit(limit)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((item) => Shop.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Shop?> getShopById(String id) async {
    final client = supabaseManager.client;
    if (client == null) return null;

    try {
      final response = await client.from('shops').select().eq('id', id).maybeSingle();

      if (response == null) return null;
      return Shop.fromJson(response);
    } catch (_) {
      return null;
    }
  }
}
