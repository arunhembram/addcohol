import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import {
  getAuthenticatedUser,
  getServiceClient,
  jsonResponse,
  errorResponse,
} from '../_shared/supabaseClient.ts';
import { SubmitPaymentAmountRequest } from '../_shared/types.ts';

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

    const payload: SubmitPaymentAmountRequest = await req.json();
    const { session_id, amount } = payload;

    if (!session_id) {
      return errorResponse('Missing required parameter: session_id', 400);
    }
    if (typeof amount !== 'number' || amount <= 0 || isNaN(amount)) {
      return errorResponse('Amount must be a positive INR number', 400);
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

    // Verify status is 'scanned'
    if (session.status !== 'scanned') {
      return errorResponse(
        `Cannot submit amount for session in '${session.status}' state. QR must be scanned first.`,
        400
      );
    }

    // Only the employee who scanned it (or admin) can submit the amount
    if (profile.role === 'employee' && session.scanned_by_employee_id && session.scanned_by_employee_id !== user.id) {
      return errorResponse('Only the employee who scanned this QR can submit the payment amount', 403);
    }

    const nowIso = new Date().toISOString();
    const dateStr = nowIso.slice(0, 10).replace(/-/g, '');
    const randomHex = crypto.randomUUID().slice(0, 6).toUpperCase();
    const txnRef = `ACK-${dateStr}-${randomHex}`;

    // Transition status to awaiting_confirmation
    const { data: updatedSession, error: updateError } = await serviceClient
      .from('payment_sessions')
      .update({
        amount,
        currency: 'INR',
        status: 'awaiting_confirmation',
        transaction_reference: txnRef,
        amount_submitted_at: nowIso,
        metadata: {
          ...session.metadata,
          employee_name: profile.full_name,
          employee_phone: profile.phone_number,
        },
        updated_at: nowIso,
      })
      .eq('id', session.id)
      .select()
      .single();

    if (updateError) {
      return errorResponse(`Failed to submit payment amount: ${updateError.message}`, 500);
    }

    // Audit log
    await serviceClient.rpc('log_audit_event', {
      p_action: 'SUBMIT_PAYMENT_AMOUNT',
      p_entity: 'payment_sessions',
      p_entity_id: session.id,
      p_details: {
        submitted_by: user.id,
        amount,
        currency: 'INR',
        transaction_reference: txnRef,
      },
    });

    return jsonResponse({
      success: true,
      data: {
        session_id: updatedSession.id,
        shop_id: updatedSession.shop_id,
        amount: updatedSession.amount,
        currency: 'INR',
        transaction_reference: txnRef,
        status: 'awaiting_confirmation',
        owner_name: session.shops?.owner_name,
        employee_name: profile.full_name,
        updated_at: updatedSession.updated_at,
      },
    });
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return errorResponse(`Internal error: ${errorMsg}`, 500);
  }
});
