import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import {
  getAuthenticatedUser,
  getServiceClient,
  jsonResponse,
  errorResponse,
} from '../_shared/supabaseClient.ts';
import { CreatePaymentSessionRequest } from '../_shared/types.ts';
import {
  generateOpaqueQrToken,
  hashQrToken,
  checkRateLimit,
} from '../_shared/tokenUtils.ts';

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

    const payload: CreatePaymentSessionRequest = await req.json();
    const { shop_id, duration_seconds = 15 } = payload;

    if (!shop_id) {
      return errorResponse('Missing required field: shop_id', 400);
    }

    // Rate limiting: max 30 creates per minute per shop
    const rateLimitAllowed = checkRateLimit(`create_session:${shop_id}`, 30, 60);
    if (!rateLimitAllowed) {
      return errorResponse('Too many requests. Please wait a moment before creating a new session.', 429);
    }

    const serviceClient = getServiceClient();

    // Verify shop exists
    const { data: shop, error: shopError } = await serviceClient
      .from('shops')
      .select('id, zone_id, shopkeeper_id, shop_name, owner_name, shop_code')
      .eq('id', shop_id)
      .single();

    if (shopError || !shop) {
      return errorResponse('Shop not found', 404);
    }

    // Authorization: Shopkeeper must own the shop; or Employee/Admin assigned
    if (profile.role === 'shopkeeper') {
      if (shop.shopkeeper_id !== user.id) {
        return errorResponse('Shopkeeper can only create payment sessions for their own shop', 403);
      }
    } else if (profile.role === 'employee') {
      const { data: assignment } = await serviceClient
        .from('employee_zone_assignments')
        .select('id')
        .eq('employee_id', user.id)
        .eq('zone_id', shop.zone_id)
        .maybeSingle();

      if (!assignment) {
        return errorResponse('Employee is not assigned to the zone containing this shop', 403);
      }
    } else if (profile.role !== 'admin' && profile.role !== 'master_admin') {
      return errorResponse('Role not permitted to create payment sessions', 403);
    }

    // Generate secure opaque token (NEVER contain secrets, amount, or phone inside QR)
    const qrToken = generateOpaqueQrToken();
    const qrTokenHash = await hashQrToken(qrToken);

    // Server-enforced expiry: 15 seconds (shopkeeper refreshes every 10 seconds while unscanned)
    const expiresAt = new Date(Date.now() + Math.max(10, duration_seconds) * 1000).toISOString();

    // Check for an existing 'created' session for this shop (or specific session_id)
    // Rule: Exactly ONE payment session opens; rotate only the QR token every 10s
    let existingSession = null;
    if (payload.session_id) {
      const { data } = await serviceClient
        .from('payment_sessions')
        .select('*')
        .eq('id', payload.session_id)
        .eq('status', 'created')
        .maybeSingle();
      existingSession = data;
    } else {
      const { data } = await serviceClient
        .from('payment_sessions')
        .select('*')
        .eq('shop_id', shop_id)
        .eq('status', 'created')
        .gt('created_at', new Date(Date.now() - 5 * 60 * 1000).toISOString())
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      existingSession = data;
    }

    let session = null;
    if (existingSession) {
      // Rotate ONLY the QR token on this existing session!
      const { data: rotated, error: rotateError } = await serviceClient
        .from('payment_sessions')
        .update({
          qr_token: qrToken,
          qr_token_hash: qrTokenHash,
          expires_at: expiresAt,
          updated_at: new Date().toISOString(),
        })
        .eq('id', existingSession.id)
        .eq('status', 'created')
        .select()
        .single();

      if (rotateError || !rotated) {
        return errorResponse(`Failed to rotate session QR: ${rotateError?.message}`, 500);
      }
      session = rotated;
    } else {
      // Supersede any older stale sessions for this shop
      await serviceClient
        .from('payment_sessions')
        .update({ status: 'expired', updated_at: new Date().toISOString() })
        .eq('shop_id', shop_id)
        .eq('status', 'created');

      // Create new session
      const { data: created, error: sessionError } = await serviceClient
        .from('payment_sessions')
        .insert({
          shop_id,
          initiated_by_user_id: user.id,
          created_by_employee_id: profile.role === 'employee' ? user.id : null,
          amount: null,
          status: 'created',
          qr_token: qrToken,
          qr_token_hash: qrTokenHash,
          expires_at: expiresAt,
          metadata: {
            field_acknowledgement: true,
            created_by_role: profile.role,
          },
        })
        .select()
        .single();

      if (sessionError || !created) {
        return errorResponse(`Failed to create payment session: ${sessionError?.message}`, 500);
      }
      session = created;
    }

    // Audit logging
    await serviceClient.rpc('log_audit_event', {
      p_action: 'CREATE_PAYMENT_SESSION',
      p_entity: 'payment_sessions',
      p_entity_id: session.id,
      p_details: {
        shop_id,
        qr_token_hash: qrTokenHash,
        expires_at: expiresAt,
        created_by: user.id,
      },
    });

    return jsonResponse({
      success: true,
      data: {
        session_id: session.id,
        qr_token: qrToken, // Sent to client for rendering in QR
        shop_id: session.shop_id,
        shop_name: shop.shop_name,
        shop_code: shop.shop_code,
        status: 'created',
        expires_at: session.expires_at,
        disclaimer: 'Field payment acknowledgement only. No automatic bank transfer.',
      },
    });
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return errorResponse(`Internal error: ${errorMsg}`, 500);
  }
});
