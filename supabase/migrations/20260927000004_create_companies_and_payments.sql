-- ============================================================================
-- Migration 04: Companies, Scoped Zone Access, Sanitized Views & Secure Payments
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Companies Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    billing_email TEXT NOT NULL,
    phone TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_companies_code ON public.companies(code);

-- ----------------------------------------------------------------------------
-- 2. Company Users Junction Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.company_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    designation TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    CONSTRAINT uq_company_user UNIQUE (company_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_company_users_company ON public.company_users(company_id);
CREATE INDEX IF NOT EXISTS idx_company_users_user ON public.company_users(user_id);

-- ----------------------------------------------------------------------------
-- 3. Company Zone Assignments Table
-- "A Company can read only the Zones assigned by Master Admin."
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.company_zone_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    zone_id UUID NOT NULL REFERENCES public.zones(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    CONSTRAINT uq_company_zone UNIQUE (company_id, zone_id)
);

CREATE INDEX IF NOT EXISTS idx_company_zone_company ON public.company_zone_assignments(company_id);
CREATE INDEX IF NOT EXISTS idx_company_zone_zone ON public.company_zone_assignments(zone_id);

-- ----------------------------------------------------------------------------
-- 4. Helper Functions for Company Membership and Scope
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_company_id(p_user_id UUID DEFAULT auth.uid())
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT company_id FROM public.company_users
    WHERE user_id = p_user_id
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.company_has_zone(p_company_id UUID, p_zone_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.company_zone_assignments
        WHERE company_id = p_company_id AND zone_id = p_zone_id
    );
$$;

-- ----------------------------------------------------------------------------
-- 5. Trigger: Only Master Admin Can Assign Zones to Companies
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_company_zone_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_master_admin(auth.uid()) THEN
        RAISE EXCEPTION 'Access denied: Only Master Admin can assign zones to Companies.';
    END IF;

    NEW.assigned_by := auth.uid();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_company_zone ON public.company_zone_assignments;
CREATE TRIGGER trg_validate_company_zone
BEFORE INSERT ON public.company_zone_assignments
FOR EACH ROW
EXECUTE FUNCTION public.validate_company_zone_assignment();

-- ----------------------------------------------------------------------------
-- 6. Attach Company Policies to Zones and Zone Vertices
-- ----------------------------------------------------------------------------
CREATE POLICY "company_user_select_assigned_zones"
ON public.zones FOR SELECT
TO authenticated
USING (
    public.is_company_user(auth.uid()) AND
    public.company_has_zone(public.get_user_company_id(auth.uid()), id)
);

CREATE POLICY "company_user_select_assigned_zone_vertices"
ON public.zone_vertices FOR SELECT
TO authenticated
USING (
    public.is_company_user(auth.uid()) AND
    public.company_has_zone(public.get_user_company_id(auth.uid()), zone_id)
);

-- Company User can select shops:
-- "A Company can see only agreed/active shops and no Aadhaar document,
-- employee private details, or private photo URLs."
CREATE POLICY "company_user_select_active_shops"
ON public.shops FOR SELECT
TO authenticated
USING (
    public.is_company_user(auth.uid()) AND
    status IN ('agreed', 'active') AND
    is_agreed = TRUE AND
    public.company_has_zone(public.get_user_company_id(auth.uid()), zone_id)
);

-- ----------------------------------------------------------------------------
-- 7. Sanitized View for Companies (Hides Owner Phone, Aadhaar, Rent, Employee details)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.company_visible_shops AS
SELECT
    s.id,
    s.shop_code,
    s.zone_id,
    z.name AS zone_name,
    s.shop_name,
    s.category,
    s.address,
    s.latitude,
    s.longitude,
    s.screen_count,
    s.status,
    s.agreed_at,
    s.created_at
FROM public.shops s
JOIN public.zones z ON s.zone_id = z.id
WHERE s.status IN ('agreed', 'active')
  AND s.is_agreed = TRUE
  AND (
      public.is_master_admin(auth.uid()) OR
      (public.is_company_user(auth.uid()) AND public.company_has_zone(public.get_user_company_id(auth.uid()), s.zone_id))
  );

-- ----------------------------------------------------------------------------
-- 8. Payment Sessions Table
-- "Payment sessions and payment transactions must never be directly writable from client apps."
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_token TEXT UNIQUE NOT NULL,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE RESTRICT,
    initiated_by_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    amount NUMERIC(12,2) CHECK (amount IS NULL OR amount > 0),
    status TEXT NOT NULL DEFAULT 'initiated'
        CHECK (status IN ('initiated', 'qr_scanned', 'amount_submitted', 'completed', 'rejected', 'expired')),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_payment_sessions_token ON public.payment_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_payment_sessions_status ON public.payment_sessions(status);

-- ----------------------------------------------------------------------------
-- 9. Payment Transactions Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.payment_sessions(id) ON DELETE RESTRICT,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE RESTRICT,
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    currency TEXT NOT NULL DEFAULT 'BDT',
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'confirmed', 'rejected', 'reversed')),
    payment_method TEXT NOT NULL DEFAULT 'bank_transfer',
    gateway_reference TEXT,
    verified_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_transactions_session ON public.payment_transactions(session_id);
CREATE INDEX IF NOT EXISTS idx_transactions_company ON public.payment_transactions(company_id);
CREATE INDEX IF NOT EXISTS idx_transactions_shop ON public.payment_transactions(shop_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON public.payment_transactions(status);

-- ----------------------------------------------------------------------------
-- 10. Triggers: Prevent Direct Client Writes to Payment Sessions & Transactions
-- "Payment sessions and payment transactions must never be directly writable from client apps."
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.prevent_client_payment_writes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Allow Postgres background workers and service_role Edge Functions
    IF current_user IN ('postgres', 'service_role') THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    -- If request originates from authenticated client JWT role, reject directly
    IF auth.role() = 'authenticated' THEN
        RAISE EXCEPTION 'Access denied: Payment tables cannot be modified directly from client applications. Use Edge Functions.';
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_payment_sessions ON public.payment_sessions;
CREATE TRIGGER trg_protect_payment_sessions
BEFORE INSERT OR UPDATE OR DELETE ON public.payment_sessions
FOR EACH ROW
EXECUTE FUNCTION public.prevent_client_payment_writes();

DROP TRIGGER IF EXISTS trg_protect_payment_transactions ON public.payment_transactions;
CREATE TRIGGER trg_protect_payment_transactions
BEFORE INSERT OR UPDATE OR DELETE ON public.payment_transactions
FOR EACH ROW
EXECUTE FUNCTION public.prevent_client_payment_writes();

-- ----------------------------------------------------------------------------
-- 11. Row Level Security: Companies, Company Users & Read-Only Payments
-- ----------------------------------------------------------------------------
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_zone_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;

-- Master Admin: Full control over companies & assignments
CREATE POLICY "master_admin_companies_all"
ON public.companies FOR ALL
TO authenticated
USING (public.is_master_admin(auth.uid()))
WITH CHECK (public.is_master_admin(auth.uid()));

CREATE POLICY "master_admin_company_users_all"
ON public.company_users FOR ALL
TO authenticated
USING (public.is_master_admin(auth.uid()))
WITH CHECK (public.is_master_admin(auth.uid()));

CREATE POLICY "master_admin_company_zone_assignments_all"
ON public.company_zone_assignments FOR ALL
TO authenticated
USING (public.is_master_admin(auth.uid()))
WITH CHECK (public.is_master_admin(auth.uid()));

-- Company Users: Can select their own company record
CREATE POLICY "company_user_select_own_company"
ON public.companies FOR SELECT
TO authenticated
USING (
    id = public.get_user_company_id(auth.uid())
);

CREATE POLICY "company_user_select_colleagues"
ON public.company_users FOR SELECT
TO authenticated
USING (
    company_id = public.get_user_company_id(auth.uid())
);

CREATE POLICY "company_user_select_zone_assignments"
ON public.company_zone_assignments FOR SELECT
TO authenticated
USING (
    company_id = public.get_user_company_id(auth.uid())
);

-- Read-Only Policies for Payment Sessions (Clients can only read, NEVER insert/update)
CREATE POLICY "master_admin_select_payment_sessions"
ON public.payment_sessions FOR SELECT
TO authenticated
USING (public.is_master_admin(auth.uid()));

CREATE POLICY "company_select_payment_sessions"
ON public.payment_sessions FOR SELECT
TO authenticated
USING (
    public.is_company_user(auth.uid()) AND
    company_id = public.get_user_company_id(auth.uid())
);

CREATE POLICY "shopkeeper_select_payment_sessions"
ON public.payment_sessions FOR SELECT
TO authenticated
USING (
    public.is_shopkeeper(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id = shop_id AND s.shopkeeper_id = auth.uid()
    )
);

-- Read-Only Policies for Payment Transactions (Clients can only read, NEVER insert/update)
CREATE POLICY "master_admin_select_payment_transactions"
ON public.payment_transactions FOR SELECT
TO authenticated
USING (public.is_master_admin(auth.uid()));

CREATE POLICY "company_select_payment_transactions"
ON public.payment_transactions FOR SELECT
TO authenticated
USING (
    public.is_company_user(auth.uid()) AND
    company_id = public.get_user_company_id(auth.uid())
);

CREATE POLICY "shopkeeper_select_payment_transactions"
ON public.payment_transactions FOR SELECT
TO authenticated
USING (
    public.is_shopkeeper(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id = shop_id AND s.shopkeeper_id = auth.uid()
    )
);
