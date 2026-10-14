import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import {
  getAuthenticatedUser,
  getServiceClient,
  jsonResponse,
  errorResponse,
} from '../_shared/supabaseClient.ts';
import { RejectPaymentRequest } from '../_shared/types.ts';

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return errorResponse('Method not allowed', 405);
  }

  try {
    const { user, profile, error: authError } = await getAuthenticatedUser(req);
    if (authError || !user || !profile) {
      return errorResponse(authError ?? 'Unauthorized', 401);
    }

    const payload: RejectPaymentRequest = await req.json();
    const { session_id, rejection_reason } = payload;

    if (!session_id) {
      return errorResponse('Missing required parameter: session_id', 400);
    }
    if (!rejection_reason || rejection_reason.trim().length === 0) {
      return errorResponse('Rejection reason is required', 400);
    }

    const serviceClient = getServiceClient();

    // Fetch session
    const { data: session, error: sessionError } = await serviceClient
      .from('payment_sessions')
      .select('*, shops(id, shop_name, owner_name, shopkeeper_id)')
      .eq('id', session_id)
      .maybeSingle();

    if (sessionError || !session) {
      return errorResponse('Payment session not found', 404);
    }

    if (session.status === 'confirmed' || session.status === 'completed') {
      return errorResponse('Cannot reject an already confirmed payment session', 400);
    }
    if (session.status === 'rejected') {
      return errorResponse('Payment session is already rejected', 400);
    }

    // Role check: Shopkeeper who owns shop or Admin
    if (profile.role === 'shopkeeper') {
      if (session.shops?.shopkeeper_id !== user.id) {
        return errorResponse('Shopkeeper not authorized for this shop', 403);
      }
    } else if (profile.role !== 'admin' && profile.role !== 'master_admin') {
      return errorResponse('Role not permitted to reject payment', 403);
    }

    const rejectedAt = new Date().toISOString();

    const { data: updatedSession, error: updateError } = await serviceClient
      .from('payment_sessions')
      .update({
        status: 'rejected',
        rejection_reason: rejection_reason.trim(),
        rejected_at: rejectedAt,
        updated_at: rejectedAt,
      })
      .eq('id', session.id)
      .select()
      .single();

    if (updateError) {
      return errorResponse(`Failed to reject session: ${updateError.message}`, 500);
    }

    // Audit event
    await serviceClient.rpc('log_audit_event', {
      p_action: 'REJECT_PAYMENT',
      p_entity: 'payment_sessions',
      p_entity_id: session.id,
      p_details: {
        rejected_by: user.id,
        reason: rejection_reason,
      },
    });

    return jsonResponse({
      success: true,
      data: {
        session_id: updatedSession.id,
        status: 'rejected',
        rejection_reason: rejection_reason.trim(),
        rejected_at: rejectedAt,
        message: 'Payment rejected and invalidated. A new QR code is required.',
      },
    });
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return errorResponse(`Internal error: ${errorMsg}`, 500);
  }
});
