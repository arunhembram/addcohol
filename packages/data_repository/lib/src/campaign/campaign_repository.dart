import 'package:app_core/app_core.dart';
import 'package:domain_models/domain_models.dart';

abstract class ICampaignRepository {
  Future<List<AdCampaign>> getCampaigns({int limit = 20});
  Future<AdCampaign?> getCampaignById(String id);
}

class SupabaseCampaignRepository implements ICampaignRepository {
  final SupabaseManager supabaseManager;

  const SupabaseCampaignRepository({required this.supabaseManager});

  @override
  Future<List<AdCampaign>> getCampaigns({int limit = 20}) async {
    final client = supabaseManager.client;
    if (client == null) return [];

    try {
      final response = await client
          .from('campaigns')
          .select()
          .limit(limit)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((item) => AdCampaign.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<AdCampaign?> getCampaignById(String id) async {
    final client = supabaseManager.client;
    if (client == null) return null;

    try {
      final response = await client.from('campaigns').select().eq('id', id).maybeSingle();

      if (response == null) return null;
      return AdCampaign.fromJson(response);
    } catch (_) {
      return null;
    }
  }
}
