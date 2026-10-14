import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import {
  getAuthenticatedUser,
  getServiceClient,
  jsonResponse,
  errorResponse,
} from '../_shared/supabaseClient.ts';
import { ConfirmPaymentRequest } from '../_shared/types.ts';

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

    const payload: ConfirmPaymentRequest = await req.json();
    const { session_id, verification_notes } = payload;

    if (!session_id) {
      return errorResponse('Missing required parameter: session_id', 400);
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
      return errorResponse('This payment session has already been confirmed', 400);
    }
    if (session.status === 'rejected') {
      return errorResponse('Cannot confirm a rejected payment session', 400);
    }
    if (session.status !== 'awaiting_confirmation' && session.status !== 'amount_submitted') {
      return errorResponse(`Cannot confirm payment session in '${session.status}' state`, 400);
    }
    if (!session.amount || session.amount <= 0) {
      return errorResponse('Cannot confirm a payment session without a valid positive amount', 400);
    }

    // Role authorization: only Shopkeeper who owns the shop (or Admin/Master Admin) can confirm receipt
    if (profile.role === 'shopkeeper') {
      if (session.shops?.shopkeeper_id !== user.id) {
        return errorResponse('Only the shopkeeper of this shop can confirm receipt of payment', 403);
      }
    } else if (profile.role !== 'admin' && profile.role !== 'master_admin') {
      return errorResponse('Role not permitted to confirm payment receipt', 403);
    }

    const confirmedAt = new Date().toISOString();
    const txRef = session.transaction_reference ??
      `ACK-${confirmedAt.slice(0, 10).replace(/-/g, '')}-${crypto.randomUUID().slice(0, 6).toUpperCase()}`;

    // 1. Insert payment transaction record (service role)
    const { data: transaction, error: txError } = await serviceClient
      .from('payment_transactions')
      .insert({
        session_id: session.id,
        shop_id: session.shop_id,
        amount: session.amount,
        currency: 'INR',
        status: 'confirmed',
        payment_method: 'field_acknowledgement',
        transaction_reference: txRef,
        verified_by: user.id,
        verified_at: confirmedAt,
        verification_notes: verification_notes ?? 'Field payment acknowledgement confirmed by shopkeeper.',
      })
      .select()
      .single();

    if (txError) {
      return errorResponse(`Failed to create transaction record: ${txError.message}`, 500);
    }

    // 2. Update payment session to confirmed
    const { error: sessionUpdateError } = await serviceClient
      .from('payment_sessions')
      .update({
        status: 'confirmed',
        confirmed_at: confirmedAt,
        transaction_reference: txRef,
        updated_at: confirmedAt,
      })
      .eq('id', session.id);

    if (sessionUpdateError) {
      return errorResponse(`Failed to mark session as confirmed: ${sessionUpdateError.message}`, 500);
    }

    // Audit event
    await serviceClient.rpc('log_audit_event', {
      p_action: 'CONFIRM_PAYMENT_RECEIVED',
      p_entity: 'payment_transactions',
      p_entity_id: transaction.id,
      p_details: {
        session_id: session.id,
        shop_id: session.shop_id,
        amount: session.amount,
        currency: 'INR',
        transaction_reference: txRef,
        confirmed_by: user.id,
      },
    });

    return jsonResponse({
      success: true,
      data: {
        transaction_id: transaction.id,
        session_id: session.id,
        shop_id: session.shop_id,
        owner_name: session.shops?.owner_name,
        amount: session.amount,
        currency: 'INR',
        transaction_reference: txRef,
        status: 'confirmed',
        confirmed_at: confirmedAt,
        shopkeeper_message: `Received ₹${session.amount}`,
        employee_message: `₹${session.amount} paid successfully to ${session.shops?.owner_name ?? 'shopkeeper'}`,
      },
    });
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return errorResponse(`Internal error: ${errorMsg}`, 500);
  }
});
