-- ============================================================================
-- Migration 07: Payment Acknowledgement Flow & Concurrency Safeguards
-- ============================================================================

-- 1. Ensure columns exist on payment_sessions
ALTER TABLE public.payment_sessions
    ALTER COLUMN company_id DROP NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payment_sessions' AND column_name = 'qr_token_hash') THEN
        ALTER TABLE public.payment_sessions ADD COLUMN qr_token_hash TEXT UNIQUE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payment_sessions' AND column_name = 'scanned_by_employee_id') THEN
        ALTER TABLE public.payment_sessions ADD COLUMN scanned_by_employee_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payment_sessions' AND column_name = 'currency') THEN
        ALTER TABLE public.payment_sessions ADD COLUMN currency TEXT NOT NULL DEFAULT 'INR';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payment_sessions' AND column_name = 'transaction_reference') THEN
        ALTER TABLE public.payment_sessions ADD COLUMN transaction_reference TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payment_sessions' AND column_name = 'rejection_reason') THEN
        ALTER TABLE public.payment_sessions ADD COLUMN rejection_reason TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payment_sessions' AND column_name = 'scanned_at') THEN
        ALTER TABLE public.payment_sessions ADD COLUMN scanned_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payment_sessions' AND column_name = 'amount_submitted_at') THEN
        ALTER TABLE public.payment_sessions ADD COLUMN amount_submitted_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payment_sessions' AND column_name = 'confirmed_at') THEN
        ALTER TABLE public.payment_sessions ADD COLUMN confirmed_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payment_sessions' AND column_name = 'rejected_at') THEN
        ALTER TABLE public.payment_sessions ADD COLUMN rejected_at TIMESTAMPTZ;
    END IF;
END $$;

-- 2. Update status constraint on payment_sessions to support all 8 required states
ALTER TABLE public.payment_sessions DROP CONSTRAINT IF EXISTS payment_sessions_status_check;
ALTER TABLE public.payment_sessions ADD CONSTRAINT payment_sessions_status_check
    CHECK (status IN (
        'created',
        'scanned',
        'amount_submitted',
        'awaiting_confirmation',
        'confirmed',
        'rejected',
        'expired',
        'cancelled',
        'initiated',
        'completed',
        'qr_scanned'
    ));

-- 3. Ensure columns exist on payment_transactions
ALTER TABLE public.payment_transactions
    ALTER COLUMN company_id DROP NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payment_transactions' AND column_name = 'currency') THEN
        ALTER TABLE public.payment_transactions ADD COLUMN currency TEXT NOT NULL DEFAULT 'INR';
    END IF;
END $$;

ALTER TABLE public.payment_transactions DROP CONSTRAINT IF EXISTS payment_transactions_status_check;
ALTER TABLE public.payment_transactions ADD CONSTRAINT payment_transactions_status_check
    CHECK (status IN ('pending', 'confirmed', 'success', 'rejected', 'failed', 'reversed'));

-- 4. Atomic QR Scan Function (Row-locking concurrency protection)
CREATE OR REPLACE FUNCTION public.scan_payment_qr_atomic(
    p_qr_token_hash TEXT,
    p_employee_id UUID
)
RETURNS TABLE (
    success BOOLEAN,
    session_id UUID,
    shop_id UUID,
    shop_name TEXT,
    owner_name TEXT,
    shop_code TEXT,
    status TEXT,
    error_code TEXT,
    error_message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_session RECORD;
    v_now TIMESTAMPTZ := TIMEZONE('utc'::text, NOW());
BEGIN
    -- 1. Lock the session row to prevent race conditions across simultaneous scans
    SELECT s.id, s.shop_id, s.status, s.expires_at, sh.shop_name, sh.owner_name, sh.shop_code
    INTO v_session
    FROM payment_sessions s
    JOIN shops sh ON s.shop_id = sh.id
    WHERE s.qr_token_hash = p_qr_token_hash
    FOR UPDATE OF s;

    -- Not found
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, NULL::UUID, NULL::UUID, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, 'NOT_FOUND', 'Payment session not found for provided QR token';
        RETURN;
    END IF;

    -- Expired
    IF v_session.expires_at <= v_now THEN
        UPDATE payment_sessions SET status = 'expired', updated_at = v_now WHERE id = v_session.id;
        RETURN QUERY SELECT FALSE, v_session.id, v_session.shop_id, v_session.shop_name, v_session.owner_name, v_session.shop_code, 'expired', 'EXPIRED', 'This payment QR token has expired. Please ask the shopkeeper for a fresh QR.';
        RETURN;
    END IF;

    -- Already scanned or processed (Replay prevention)
    IF v_session.status <> 'created' AND v_session.status <> 'initiated' THEN
        RETURN QUERY SELECT FALSE, v_session.id, v_session.shop_id, v_session.shop_name, v_session.owner_name, v_session.shop_code, v_session.status, 'ALREADY_SCANNED', 'This QR code has already been scanned. Replays are rejected.';
        RETURN;
    END IF;

    -- 2. Atomically claim the scan
    UPDATE payment_sessions
    SET status = 'scanned',
        scanned_by_employee_id = p_employee_id,
        scanned_at = v_now,
        updated_at = v_now
    WHERE id = v_session.id;

    -- 3. Return verified session data
    RETURN QUERY SELECT TRUE, v_session.id, v_session.shop_id, v_session.shop_name, v_session.owner_name, v_session.shop_code, 'scanned', NULL::TEXT, NULL::TEXT;
END;
$$;

-- 5. Enable Real-Time replication on payment_sessions
ALTER PUBLICATION supabase_realtime ADD TABLE public.payment_sessions;
