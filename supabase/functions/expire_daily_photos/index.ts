import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import {
  getServiceClient,
  jsonResponse,
  errorResponse,
} from '../_shared/supabaseClient.ts';
import { ExpireDailyPhotosRequest } from '../_shared/types.ts';

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return errorResponse('Method not allowed', 405);
  }

  try {
    // Check for authorization: Either service role invocation or authenticated master_admin/admin
    const authHeader = req.headers.get('Authorization') ?? '';
    const serviceClient = getServiceClient();

    // Verify token
    const token = authHeader.replace(/^Bearer\s+/i, '');
    let isAuthorized = false;
    let executorId = 'system_cron';

    if (token === Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')) {
      isAuthorized = true;
    } else {
      const { data: { user } } = await serviceClient.auth.getUser(token);
      if (user) {
        const { data: profile } = await serviceClient
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

        if (profile && (profile.role === 'master_admin' || profile.role === 'admin')) {
          isAuthorized = true;
          executorId = user.id;
        }
      }
    }

    if (!isAuthorized) {
      return errorResponse('Unauthorized: service-role or admin privilege required', 403);
    }

    let payload: ExpireDailyPhotosRequest = {};
    try {
      payload = await req.json();
    } catch {
      // Empty body is acceptable for cron triggers
    }

    const batchSize = payload.batch_size ?? 100;
    const nowIso = new Date().toISOString();

    // Query daily photos that have passed their expires_at timestamp
    const { data: expiredPhotos, error: fetchError } = await serviceClient
      .from('shop_daily_uploads')
      .select('id, shop_id, photo_storage_path, expires_at')
      .lt('expires_at', nowIso)
      .limit(batchSize);

    if (fetchError) {
      return errorResponse(`Failed to query expired photos: ${fetchError.message}`, 500);
    }

    if (!expiredPhotos || expiredPhotos.length === 0) {
      return jsonResponse({
        success: true,
        message: 'No expired daily photos found to process.',
        expired_count: 0,
      });
    }

    const pathsToDelete: string[] = expiredPhotos
      .map((p) => p.photo_storage_path)
      .filter((p): p is string => Boolean(p));

    const idsToDelete: string[] = expiredPhotos.map((p) => p.id);

    // Delete files from storage bucket
    if (pathsToDelete.length > 0) {
      const { error: storageError } = await serviceClient.storage
        .from('shop-daily-photos')
        .remove(pathsToDelete);

      if (storageError) {
        console.error('Storage deletion warning:', storageError.message);
      }
    }

    // Mark records as expired in database while strictly RETAINING audit metadata
    const { error: updateError } = await serviceClient
      .from('shop_daily_uploads')
      .update({
        is_expired: true,
        verification_status: 'expired',
      })
      .in('id', idsToDelete);

    if (updateError) {
      return errorResponse(`Failed to update database records: ${updateError.message}`, 500);
    }

    // Audit event: records that storage objects were removed but metadata was retained
    await serviceClient.rpc('log_audit_event', {
      p_action: 'EXPIRE_DAILY_PHOTOS',
      p_entity: 'shop_daily_uploads',
      p_entity_id: null,
      p_details: {
        expired_count: idsToDelete.length,
        executor: executorId,
        storage_objects_deleted: pathsToDelete.length,
        metadata_retained: true,
        record_ids: idsToDelete,
      },
    });

    return jsonResponse({
      success: true,
      message: `Successfully expired and purged ${idsToDelete.length} daily photo(s).`,
      expired_count: idsToDelete.length,
    });
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return errorResponse(`Internal error: ${errorMsg}`, 500);
  }
});
