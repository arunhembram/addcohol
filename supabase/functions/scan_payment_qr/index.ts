import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import {
  getAuthenticatedUser,
  getServiceClient,
  jsonResponse,
  errorResponse,
} from '../_shared/supabaseClient.ts';
import { ScanPaymentQrRequest } from '../_shared/types.ts';
import { hashQrToken, checkRateLimit } from '../_shared/tokenUtils.ts';

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

    const payload: ScanPaymentQrRequest = await req.json();
    const { qr_token } = payload;

    if (!qr_token || typeof qr_token !== 'string' || qr_token.trim().length === 0) {
      return errorResponse('Missing required parameter: qr_token', 400);
    }

    // Rate limiting: max 40 scans per minute per employee
    const rateLimitAllowed = checkRateLimit(`scan_qr:${user.id}`, 40, 60);
    if (!rateLimitAllowed) {
      return errorResponse('Too many scan attempts. Please wait a moment.', 429);
    }

    const serviceClient = getServiceClient();
    const qrTokenHash = await hashQrToken(qr_token);
    const nowIso = new Date().toISOString();

    // 1. Attempt atomic update: ONLY transitions from 'created' AND non-expired
    // In PostgreSQL, row-level locks on update guarantee that only ONE simultaneous scan succeeds.
    const { data: updatedSession, error: updateError } = await serviceClient
      .from('payment_sessions')
      .update({
        status: 'scanned',
        scanned_by_employee_id: user.id,
        scanned_at: nowIso,
        updated_at: nowIso,
      })
      .eq('qr_token_hash', qrTokenHash)
      .eq('status', 'created')
      .gt('expires_at', nowIso)
      .select('*, shops(id, shop_name, owner_name, shop_code)')
      .maybeSingle();

    if (updateError) {
      return errorResponse(`Scan transaction failed: ${updateError.message}`, 500);
    }

    // If atomic update succeeded, return verified session details
    if (updatedSession) {
      // Audit log
      await serviceClient.rpc('log_audit_event', {
        p_action: 'SCAN_PAYMENT_QR',
        p_entity: 'payment_sessions',
        p_entity_id: updatedSession.id,
        p_details: {
          scanned_by: user.id,
          employee_role: profile.role,
          qr_token_hash: qrTokenHash,
          shop_id: updatedSession.shop_id,
        },
      });

      return jsonResponse({
        success: true,
        data: {
          session_id: updatedSession.id,
          shop_id: updatedSession.shop_id,
          shop_name: updatedSession.shops?.shop_name,
          owner_name: updatedSession.shops?.owner_name,
          shop_code: updatedSession.shops?.shop_code,
          status: 'scanned',
          scanned_at: updatedSession.scanned_at,
          expires_at: updatedSession.expires_at,
        },
      });
    }

    // 2. Atomic update failed: Diagnose exact reason for informative, secure error
    const { data: existingSession } = await serviceClient
      .from('payment_sessions')
      .select('id, status, expires_at')
      .eq('qr_token_hash', qrTokenHash)
      .maybeSingle();

    if (!existingSession) {
      return errorResponse('Payment session not found for provided QR token', 404);
    }

    if (new Date(existingSession.expires_at) <= new Date()) {
      if (existingSession.status === 'created') {
        await serviceClient
          .from('payment_sessions')
          .update({ status: 'expired', updated_at: nowIso })
          .eq('id', existingSession.id);
      }
      return errorResponse('This payment QR token has expired. Please ask the shopkeeper to display a fresh QR.', 410);
    }

    // Replay prevention: the QR was already scanned or processed
    return errorResponse(
      `This QR code has already been scanned (status: ${existingSession.status}). The same QR cannot be scanned twice.`,
      409
    );
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return errorResponse(`Internal error: ${errorMsg}`, 500);
  }
});
