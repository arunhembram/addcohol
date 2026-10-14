-- ============================================================================
-- Migration 09: Daily Photo Expiry at Midnight Asia/Kolkata
-- "Daily photo expiry occurs server-side at midnight Asia/Kolkata."
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Trigger Function: Compute Asia/Kolkata Business Date and Midnight Expiry
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_daily_photo_kolkata_expiry()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_kolkata_now TIMESTAMP;
    v_business_date DATE;
    v_midnight_kolkata TIMESTAMPTZ;
BEGIN
    -- Determine current or provided timestamp in Asia/Kolkata (IST = UTC + 5:30)
    v_kolkata_now := TIMEZONE('Asia/Kolkata', COALESCE(NEW.created_at, NOW()));
    v_business_date := v_kolkata_now::DATE;

    -- Compute midnight at the end of the current Asia/Kolkata business day (18:30 UTC)
    v_midnight_kolkata := (v_business_date + INTERVAL '1 day')::TIMESTAMP AT TIME ZONE 'Asia/Kolkata';

    -- Set immutable business date and server-enforced expiry
    NEW.business_date := v_business_date;
    NEW.expires_at := v_midnight_kolkata;
    NEW.is_expired := FALSE;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_daily_photo_expiry ON public.shop_daily_uploads;
CREATE TRIGGER trg_set_daily_photo_expiry
BEFORE INSERT ON public.shop_daily_uploads
FOR EACH ROW
EXECUTE FUNCTION public.set_daily_photo_kolkata_expiry();

-- ----------------------------------------------------------------------------
-- 2. Stored Procedure: Purge Expired Daily Photos (Callable via pg_cron or Edge Function)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.purge_expired_daily_photos(p_batch_size INT DEFAULT 100)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INT := 0;
    v_expired_ids UUID[];
BEGIN
    -- Select IDs of records that have passed their Asia/Kolkata midnight expiry
    SELECT ARRAY_AGG(id) INTO v_expired_ids
    FROM (
        SELECT id
        FROM public.shop_daily_uploads
        WHERE expires_at <= NOW()
        LIMIT p_batch_size
    ) sub;

    IF v_expired_ids IS NOT NULL AND ARRAY_LENGTH(v_expired_ids, 1) > 0 THEN
        -- Mark as expired and delete
        DELETE FROM public.shop_daily_uploads
        WHERE id = ANY(v_expired_ids);

        GET DIAGNOSTICS v_count = ROW_COUNT;

        -- Record tamper-resistant audit log
        PERFORM public.log_audit_event(
            NULL,
            'DAILY_PHOTOS_EXPIRED_SERVER_SIDE',
            'shop_daily_uploads',
            v_count::text,
            jsonb_build_object(
                'purged_count', v_count,
                'timezone', 'Asia/Kolkata',
                'executed_at', NOW()
            )
        );
    END IF;

    RETURN v_count;
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. Cron Schedule Configuration (pg_cron)
-- Midnight in Asia/Kolkata (IST = UTC+5:30) occurs at 18:30 UTC every day.
-- Cron expression: '30 18 * * *'
-- ----------------------------------------------------------------------------
COMMENT ON FUNCTION public.purge_expired_daily_photos(INT) IS 
'Server-side scheduled purge executing daily at midnight Asia/Kolkata (18:30 UTC / 30 18 * * *)';
