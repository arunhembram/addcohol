-- ============================================================================
-- Migration 03: Shops, Identity Documents, Followups & Daily Private Uploads
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Sequence for Immutable 8-Digit Shop Codes
-- "Generate immutable 8-digit Shop Codes server-side."
-- ----------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS shop_code_seq
    START WITH 10000001
    INCREMENT BY 1
    MINVALUE 10000000
    MAXVALUE 99999999
    CYCLE;

-- ----------------------------------------------------------------------------
-- 2. Shops Table
-- "Each shop has one active zone_id."
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_code VARCHAR(8) UNIQUE NOT NULL,
    zone_id UUID NOT NULL REFERENCES public.zones(id) ON DELETE RESTRICT,
    shopkeeper_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_by_employee_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    shop_name TEXT NOT NULL,
    owner_name TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'General',
    address TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL CHECK (latitude >= -90.0 AND latitude <= 90.0),
    longitude DOUBLE PRECISION NOT NULL CHECK (longitude >= -180.0 AND longitude <= 180.0),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'under_review', 'agreed', 'active', 'inactive', 'rejected')),
    monthly_rent NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (monthly_rent >= 0),
    screen_count INT NOT NULL DEFAULT 1 CHECK (screen_count >= 1),
    is_agreed BOOLEAN NOT NULL DEFAULT FALSE,
    agreed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_shops_shop_code ON public.shops(shop_code);
CREATE INDEX IF NOT EXISTS idx_shops_zone_id ON public.shops(zone_id);
CREATE INDEX IF NOT EXISTS idx_shops_shopkeeper_id ON public.shops(shopkeeper_id);
CREATE INDEX IF NOT EXISTS idx_shops_status ON public.shops(status);
CREATE INDEX IF NOT EXISTS idx_shops_is_agreed ON public.shops(is_agreed);

-- ----------------------------------------------------------------------------
-- 3. Secure Identity Documents Table
-- "Aadhaar images must use a private storage bucket. Do not store Aadhaar numbers.
-- Store only an encrypted/private document path, consent time, and audit history."
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.secure_identity_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    shopkeeper_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    document_type TEXT NOT NULL DEFAULT 'aadhaar_card'
        CHECK (document_type IN ('aadhaar_card', 'trade_license', 'tax_certificate', 'pan_card')),
    storage_path TEXT NOT NULL,
    consent_given_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    verified_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    verified_at TIMESTAMPTZ,
    verification_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (verification_status IN ('pending', 'verified', 'rejected')),
    audit_history JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_secure_docs_shop ON public.secure_identity_documents(shop_id);
CREATE INDEX IF NOT EXISTS idx_secure_docs_shopkeeper ON public.secure_identity_documents(shopkeeper_id);

-- ----------------------------------------------------------------------------
-- 4. Shop Followups Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.shop_followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    notes TEXT NOT NULL,
    outcome TEXT NOT NULL,
    next_followup_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_shop_followups_shop ON public.shop_followups(shop_id);
CREATE INDEX IF NOT EXISTS idx_shop_followups_employee ON public.shop_followups(employee_id);

-- ----------------------------------------------------------------------------
-- 5. Shop Daily Uploads Table
-- "Daily shop photos must be private. Store GPS, business date, uploader identity,
-- expiry time, and verification status."
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.shop_daily_uploads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
    uploader_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    business_date DATE NOT NULL DEFAULT CURRENT_DATE,
    photo_storage_path TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL CHECK (latitude >= -90.0 AND latitude <= 90.0),
    longitude DOUBLE PRECISION NOT NULL CHECK (longitude >= -180.0 AND longitude <= 180.0),
    verification_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (verification_status IN ('pending', 'verified', 'flagged', 'rejected')),
    verified_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    verified_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (TIMEZONE('utc'::text, NOW()) + INTERVAL '30 days'),
    is_expired BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_daily_uploads_shop_date ON public.shop_daily_uploads(shop_id, business_date);
CREATE INDEX IF NOT EXISTS idx_daily_uploads_expires_at ON public.shop_daily_uploads(expires_at);

-- ----------------------------------------------------------------------------
-- 6. Trigger: Generate Immutable 8-Digit Shop Code & Validate Immutability
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_shop_code_generation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Generate 8-digit numeric code from sequence server-side
        NEW.shop_code := nextval('public.shop_code_seq')::text;
        NEW.updated_at := TIMEZONE('utc'::text, NOW());
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        -- Strictly enforce immutability of shop_code
        IF OLD.shop_code IS DISTINCT FROM NEW.shop_code THEN
            RAISE EXCEPTION 'Access denied: shop_code is immutable and cannot be altered.';
        END IF;
        NEW.updated_at := TIMEZONE('utc'::text, NOW());
        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_shop_code_lifecycle ON public.shops;
CREATE TRIGGER trg_shop_code_lifecycle
BEFORE INSERT OR UPDATE ON public.shops
FOR EACH ROW
EXECUTE FUNCTION public.handle_shop_code_generation();

-- ----------------------------------------------------------------------------
-- 7. Trigger: Enforce Employee Zone Restrictions on Shop Creation & Editing
-- "Employee can create or edit shops only in assigned Zones."
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_employee_shop_scope()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Master admin has universal access
    IF public.is_master_admin(auth.uid()) THEN
        RETURN NEW;
    END IF;

    -- Admin must be assigned to the zone
    IF public.is_admin(auth.uid()) THEN
        IF NOT public.admin_has_zone(auth.uid(), NEW.zone_id) THEN
            RAISE EXCEPTION 'Access denied: Admin is not assigned to zone %.', NEW.zone_id;
        END IF;
        RETURN NEW;
    END IF;

    -- Employee can create or edit shops ONLY in assigned zones
    IF public.is_employee(auth.uid()) THEN
        IF NOT public.employee_has_zone(auth.uid(), NEW.zone_id) THEN
            RAISE EXCEPTION 'Access denied: Employee is not assigned to zone %.', NEW.zone_id;
        END IF;

        IF TG_OP = 'INSERT' THEN
            NEW.created_by_employee_id := auth.uid();
        END IF;

        RETURN NEW;
    END IF;

    -- Shopkeeper can only update their own linked shop, but cannot change zone or status
    IF public.is_shopkeeper(auth.uid()) THEN
        IF TG_OP = 'UPDATE' THEN
            IF OLD.shopkeeper_id <> auth.uid() THEN
                RAISE EXCEPTION 'Access denied: Shopkeeper does not own this shop.';
            END IF;
            -- Prevent shopkeeper from changing critical platform fields
            NEW.zone_id := OLD.zone_id;
            NEW.status := OLD.status;
            NEW.shopkeeper_id := OLD.shopkeeper_id;
            NEW.monthly_rent := OLD.monthly_rent;
            NEW.is_agreed := OLD.is_agreed;
            RETURN NEW;
        END IF;
    END IF;

    RAISE EXCEPTION 'Access denied: Unauthorized shop operation.';
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_employee_shop_scope ON public.shops;
CREATE TRIGGER trg_validate_employee_shop_scope
BEFORE INSERT OR UPDATE ON public.shops
FOR EACH ROW
EXECUTE FUNCTION public.validate_employee_shop_scope();

-- ----------------------------------------------------------------------------
-- 8. Row Level Security: Shops, Documents, Followups & Daily Uploads
-- ----------------------------------------------------------------------------
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.secure_identity_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_daily_uploads ENABLE ROW LEVEL SECURITY;

-- Master Admin: Full access
CREATE POLICY "master_admin_shops_all"
ON public.shops FOR ALL
TO authenticated
USING (public.is_master_admin(auth.uid()))
WITH CHECK (public.is_master_admin(auth.uid()));

CREATE POLICY "master_admin_docs_all"
ON public.secure_identity_documents FOR ALL
TO authenticated
USING (public.is_master_admin(auth.uid()))
WITH CHECK (public.is_master_admin(auth.uid()));

CREATE POLICY "master_admin_followups_all"
ON public.shop_followups FOR ALL
TO authenticated
USING (public.is_master_admin(auth.uid()))
WITH CHECK (public.is_master_admin(auth.uid()));

CREATE POLICY "master_admin_daily_uploads_all"
ON public.shop_daily_uploads FOR ALL
TO authenticated
USING (public.is_master_admin(auth.uid()))
WITH CHECK (public.is_master_admin(auth.uid()));

-- Admin: Can select shops in their zones
CREATE POLICY "admin_select_zone_shops"
ON public.shops FOR SELECT
TO authenticated
USING (
    public.is_admin(auth.uid()) AND
    public.admin_has_zone(auth.uid(), zone_id)
);

-- Admin: Can update shops in their zones
CREATE POLICY "admin_update_zone_shops"
ON public.shops FOR UPDATE
TO authenticated
USING (
    public.is_admin(auth.uid()) AND
    public.admin_has_zone(auth.uid(), zone_id)
)
WITH CHECK (
    public.is_admin(auth.uid()) AND
    public.admin_has_zone(auth.uid(), zone_id)
);

-- Admin: Can view and verify documents for shops in their zones
CREATE POLICY "admin_manage_zone_docs"
ON public.secure_identity_documents FOR ALL
TO authenticated
USING (
    public.is_admin(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id = shop_id AND public.admin_has_zone(auth.uid(), s.zone_id)
    )
);

-- Admin: Can view and manage followups in their zones
CREATE POLICY "admin_manage_zone_followups"
ON public.shop_followups FOR ALL
TO authenticated
USING (
    public.is_admin(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id = shop_id AND public.admin_has_zone(auth.uid(), s.zone_id)
    )
);

-- Admin: Can view and verify daily uploads in their zones
CREATE POLICY "admin_manage_zone_daily_uploads"
ON public.shop_daily_uploads FOR ALL
TO authenticated
USING (
    public.is_admin(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id = shop_id AND public.admin_has_zone(auth.uid(), s.zone_id)
    )
);

-- Employee: Can select shops in assigned zones
CREATE POLICY "employee_select_assigned_shops"
ON public.shops FOR SELECT
TO authenticated
USING (
    public.is_employee(auth.uid()) AND
    public.employee_has_zone(auth.uid(), zone_id)
);

-- Employee: Can insert shops in assigned zones
CREATE POLICY "employee_insert_assigned_shops"
ON public.shops FOR INSERT
TO authenticated
WITH CHECK (
    public.is_employee(auth.uid()) AND
    public.employee_has_zone(auth.uid(), zone_id)
);

-- Employee: Can update shops in assigned zones
CREATE POLICY "employee_update_assigned_shops"
ON public.shops FOR UPDATE
TO authenticated
USING (
    public.is_employee(auth.uid()) AND
    public.employee_has_zone(auth.uid(), zone_id)
)
WITH CHECK (
    public.is_employee(auth.uid()) AND
    public.employee_has_zone(auth.uid(), zone_id)
);

-- Employee: Can upload and view documents for shops in assigned zones
CREATE POLICY "employee_manage_assigned_docs"
ON public.secure_identity_documents FOR ALL
TO authenticated
USING (
    public.is_employee(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id = shop_id AND public.employee_has_zone(auth.uid(), s.zone_id)
    )
)
WITH CHECK (
    public.is_employee(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id = shop_id AND public.employee_has_zone(auth.uid(), s.zone_id)
    )
);

-- Employee: Can create and view followups for their assigned shops
CREATE POLICY "employee_manage_assigned_followups"
ON public.shop_followups FOR ALL
TO authenticated
USING (
    public.is_employee(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id = shop_id AND public.employee_has_zone(auth.uid(), s.zone_id)
    )
)
WITH CHECK (
    public.is_employee(auth.uid()) AND
    employee_id = auth.uid()
);

-- Employee: Can upload daily photos for their assigned shops
CREATE POLICY "employee_manage_assigned_daily_uploads"
ON public.shop_daily_uploads FOR ALL
TO authenticated
USING (
    public.is_employee(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id = shop_id AND public.employee_has_zone(auth.uid(), s.zone_id)
    )
)
WITH CHECK (
    public.is_employee(auth.uid()) AND
    uploader_id = auth.uid()
);

-- Shopkeeper: "A Shopkeeper can access only their linked shop."
CREATE POLICY "shopkeeper_select_own_shop"
ON public.shops FOR SELECT
TO authenticated
USING (
    public.is_shopkeeper(auth.uid()) AND
    shopkeeper_id = auth.uid()
);

CREATE POLICY "shopkeeper_update_own_shop"
ON public.shops FOR UPDATE
TO authenticated
USING (
    public.is_shopkeeper(auth.uid()) AND
    shopkeeper_id = auth.uid()
)
WITH CHECK (
    public.is_shopkeeper(auth.uid()) AND
    shopkeeper_id = auth.uid()
);

-- Shopkeeper: Can select their own identity document
CREATE POLICY "shopkeeper_select_own_docs"
ON public.secure_identity_documents FOR SELECT
TO authenticated
USING (
    public.is_shopkeeper(auth.uid()) AND
    shopkeeper_id = auth.uid()
);

-- Shopkeeper: Can upload and view daily photos for their own shop
CREATE POLICY "shopkeeper_manage_own_daily_uploads"
ON public.shop_daily_uploads FOR ALL
TO authenticated
USING (
    public.is_shopkeeper(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id = shop_id AND s.shopkeeper_id = auth.uid()
    )
)
WITH CHECK (
    public.is_shopkeeper(auth.uid()) AND
    uploader_id = auth.uid() AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id = shop_id AND s.shopkeeper_id = auth.uid()
    )
);
