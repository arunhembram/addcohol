-- ============================================================================
-- Migration 10: Access Identifiers, Display References & Safe Data Preservation
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Extend Profiles Table: 5-digit admin_access_id, employee_access_id & display_reference
-- "Keep readable references such as EMP-0001 only as display_reference."
-- "Add unique immutable admin_access_id and employee_access_id as exactly 5 numeric digits."
-- ----------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'display_reference'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN display_reference TEXT;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'admin_access_id'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN admin_access_id VARCHAR(5) UNIQUE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'employee_access_id'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN employee_access_id VARCHAR(5) UNIQUE;
    END IF;
END $$;

-- Safe backfill for existing profiles
UPDATE public.profiles
SET 
    admin_access_id = CASE 
        WHEN role IN ('admin', 'master_admin') THEN 
            COALESCE(admin_access_id, display_id, LPAD(nextval('public.staff_display_id_seq')::text, 5, '0'))
        ELSE NULL 
    END,
    employee_access_id = CASE 
        WHEN role = 'employee' THEN 
            COALESCE(employee_access_id, display_id, LPAD(nextval('public.staff_display_id_seq')::text, 5, '0'))
        ELSE NULL 
    END,
    display_reference = CASE 
        WHEN role IN ('admin', 'master_admin') THEN 
            COALESCE(display_reference, 'ADM-' || LPAD(COALESCE(admin_access_id, display_id, '1')::text, 4, '0'))
        WHEN role = 'employee' THEN 
            COALESCE(display_reference, 'EMP-' || LPAD(COALESCE(employee_access_id, display_id, '1')::text, 4, '0'))
        ELSE display_reference
    END
WHERE role IN ('admin', 'master_admin', 'employee');

-- Add check constraints for exactly 5 numeric digits
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS chk_admin_access_id_5_digits;
ALTER TABLE public.profiles ADD CONSTRAINT chk_admin_access_id_5_digits 
    CHECK (admin_access_id IS NULL OR admin_access_id ~ '^[0-9]{5}$');

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS chk_employee_access_id_5_digits;
ALTER TABLE public.profiles ADD CONSTRAINT chk_employee_access_id_5_digits 
    CHECK (employee_access_id IS NULL OR employee_access_id ~ '^[0-9]{5}$');

-- Updated profile trigger for immutable 5-digit access IDs and display references
CREATE OR REPLACE FUNCTION public.handle_profile_access_identifiers()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Admin & Master Admin: 5-digit admin_access_id
        IF NEW.role IN ('admin', 'master_admin') THEN
            IF NEW.admin_access_id IS NULL OR NEW.admin_access_id = '' THEN
                NEW.admin_access_id := LPAD(nextval('public.staff_display_id_seq')::text, 5, '0');
            END IF;
            NEW.display_id := NEW.admin_access_id;
            NEW.display_reference := 'ADM-' || LPAD(NEW.admin_access_id, 4, '0');
            NEW.employee_access_id := NULL;
        -- Employee: 5-digit employee_access_id
        ELSIF NEW.role = 'employee' THEN
            IF NEW.employee_access_id IS NULL OR NEW.employee_access_id = '' THEN
                NEW.employee_access_id := LPAD(nextval('public.staff_display_id_seq')::text, 5, '0');
            END IF;
            NEW.display_id := NEW.employee_access_id;
            NEW.display_reference := 'EMP-' || LPAD(NEW.employee_access_id, 4, '0');
            NEW.admin_access_id := NULL;
        ELSE
            NEW.admin_access_id := NULL;
            NEW.employee_access_id := NULL;
            NEW.display_id := NULL;
        END IF;

        NEW.updated_at := TIMEZONE('utc'::text, NOW());
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        -- Immutability enforcement: access IDs can NEVER be modified once assigned
        IF OLD.admin_access_id IS NOT NULL AND NEW.admin_access_id IS DISTINCT FROM OLD.admin_access_id THEN
            RAISE EXCEPTION 'Access denied: admin_access_id is immutable and cannot be changed.';
        END IF;

        IF OLD.employee_access_id IS NOT NULL AND NEW.employee_access_id IS DISTINCT FROM OLD.employee_access_id THEN
            RAISE EXCEPTION 'Access denied: employee_access_id is immutable and cannot be changed.';
        END IF;

        NEW.updated_at := TIMEZONE('utc'::text, NOW());
        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_profile_display_id ON public.profiles;
DROP TRIGGER IF EXISTS trg_profile_access_identifiers ON public.profiles;
CREATE TRIGGER trg_profile_access_identifiers
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.handle_profile_access_identifiers();


-- ----------------------------------------------------------------------------
-- 2. Extend Shops Table: 8-digit shop_access_code & display_reference
-- "Keep readable references such as SHP-KOL-0001 only as display_reference."
-- "Add unique immutable shop_access_code as exactly 8 numeric digits."
-- ----------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'shops' AND column_name = 'display_reference'
    ) THEN
        ALTER TABLE public.shops ADD COLUMN display_reference TEXT;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'shops' AND column_name = 'shop_access_code'
    ) THEN
        ALTER TABLE public.shops ADD COLUMN shop_access_code VARCHAR(8) UNIQUE;
    END IF;
END $$;

-- Safe backfill for existing shops
UPDATE public.shops
SET 
    shop_access_code = COALESCE(shop_access_code, shop_code),
    display_reference = COALESCE(
        display_reference, 
        'SHP-KOL-' || LPAD(SUBSTRING(COALESCE(shop_access_code, shop_code) FROM 5), 4, '0')
    )
WHERE shop_access_code IS NULL OR display_reference IS NULL;

-- Enforce NOT NULL and exactly 8 numeric digits
ALTER TABLE public.shops ALTER COLUMN shop_access_code SET NOT NULL;
ALTER TABLE public.shops DROP CONSTRAINT IF EXISTS chk_shop_access_code_8_digits;
ALTER TABLE public.shops ADD CONSTRAINT chk_shop_access_code_8_digits 
    CHECK (shop_access_code ~ '^[0-9]{8}$');

CREATE INDEX IF NOT EXISTS idx_shops_access_code ON public.shops(shop_access_code);
CREATE INDEX IF NOT EXISTS idx_shops_display_ref ON public.shops(display_reference);

-- Update trigger for shops: Generate 8-digit shop_access_code & format display_reference
CREATE OR REPLACE FUNCTION public.handle_shop_code_generation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Generate 8-digit numeric access code
        IF NEW.shop_access_code IS NULL OR NEW.shop_access_code = '' THEN
            NEW.shop_access_code := nextval('public.shop_code_seq')::text;
        END IF;

        -- Keep shop_code backwards compatible
        NEW.shop_code := NEW.shop_access_code;

        -- Format display_reference as SHP-KOL-XXXX or based on zone
        IF NEW.display_reference IS NULL OR NEW.display_reference = '' THEN
            NEW.display_reference := 'SHP-KOL-' || LPAD(SUBSTRING(NEW.shop_access_code FROM 5), 4, '0');
        END IF;

        NEW.updated_at := TIMEZONE('utc'::text, NOW());
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        -- Strictly enforce immutability of shop_access_code and shop_code
        IF OLD.shop_access_code IS DISTINCT FROM NEW.shop_access_code THEN
            RAISE EXCEPTION 'Access denied: shop_access_code is immutable and cannot be altered.';
        END IF;

        IF OLD.shop_code IS DISTINCT FROM NEW.shop_code THEN
            RAISE EXCEPTION 'Access denied: shop_code is immutable and cannot be altered.';
        END IF;

        NEW.updated_at := TIMEZONE('utc'::text, NOW());
        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$;


-- ----------------------------------------------------------------------------
-- 3. Stored Procedure: Retain Audit Metadata on Daily Photo Expiry
-- "Delete the storage object but retain audit metadata."
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.purge_expired_daily_photos(p_batch_size INT DEFAULT 100)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INT := 0;
    v_record RECORD;
BEGIN
    -- Select daily photos expired past midnight Asia/Kolkata
    FOR v_record IN (
        SELECT id, shop_id, photo_storage_path, expires_at
        FROM public.shop_daily_uploads
        WHERE expires_at <= NOW() AND is_expired = FALSE
        LIMIT p_batch_size
    ) LOOP
        -- 1. Remove storage object from storage.objects
        DELETE FROM storage.objects
        WHERE bucket_id = 'shop-daily-photos'
          AND name = v_record.photo_storage_path;

        -- 2. Mark database record as expired while RETAINING audit metadata
        UPDATE public.shop_daily_uploads
        SET 
            is_expired = TRUE,
            verification_status = 'expired'
        WHERE id = v_record.id;

        -- 3. Record immutable audit log
        PERFORM public.log_audit_event(
            NULL,
            'DAILY_PHOTO_EXPIRED_OBJECT_DELETED',
            'shop_daily_uploads',
            v_record.id::text,
            jsonb_build_object(
                'shop_id', v_record.shop_id,
                'photo_storage_path', v_record.photo_storage_path,
                'expires_at', v_record.expires_at,
                'deleted_from_storage', TRUE,
                'metadata_retained', TRUE,
                'timezone', 'Asia/Kolkata',
                'executed_at', NOW()
            )
        );

        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$;


-- ----------------------------------------------------------------------------
-- 4. Enable pg_cron and Schedule Daily Photo Expiry at Midnight Asia/Kolkata
-- (18:30 UTC = 00:00 Asia/Kolkata IST)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_cron;
    
    -- Unschedule previous job if present
    PERFORM cron.unschedule('purge-expired-daily-photos-midnight-kolkata')
    WHERE EXISTS (
        SELECT 1 FROM cron.job WHERE jobname = 'purge-expired-daily-photos-midnight-kolkata'
    );

    -- Schedule job to execute daily at 18:30 UTC (00:00 IST / midnight Kolkata)
    PERFORM cron.schedule(
        'purge-expired-daily-photos-midnight-kolkata',
        '30 18 * * *',
        'SELECT public.purge_expired_daily_photos(200)'
    );
EXCEPTION WHEN OTHERS THEN
    -- In environments where pg_cron extension is managed by cloud console, log notice
    RAISE NOTICE 'pg_cron schedule setup handled or requires cloud settings: %', SQLERRM;
END $$;
