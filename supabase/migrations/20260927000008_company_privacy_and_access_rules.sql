-- ============================================================================
-- Migration 08: Company Privacy, Access Rules & can_view_daily_proof Feature Flag
-- ============================================================================

-- 1. Add can_view_daily_proof feature flag to companies table (Default: FALSE)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'companies' AND column_name = 'can_view_daily_proof'
    ) THEN
        ALTER TABLE public.companies ADD COLUMN can_view_daily_proof BOOLEAN NOT NULL DEFAULT FALSE;
    END IF;
END $$;

-- 2. Enhanced Trigger: Strictly prevent Company users from self-assigning Zones
CREATE OR REPLACE FUNCTION public.validate_company_zone_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Only Master Admin can assign a Zone to a Company.
    -- A Company cannot select or grant itself Zone access.
    IF NOT public.is_master_admin(auth.uid()) THEN
        RAISE EXCEPTION 'Access denied: Only Master Admin can assign zones to Companies. Self-assignment by companies is strictly forbidden.';
    END IF;

    NEW.assigned_by := auth.uid();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_company_zone ON public.company_zone_assignments;
CREATE TRIGGER trg_validate_company_zone
BEFORE INSERT OR UPDATE ON public.company_zone_assignments
FOR EACH ROW
EXECUTE FUNCTION public.validate_company_zone_assignment();

-- 3. Sanitized View: company_visible_shops
-- Shows ONLY agreed and active shops inside assigned zones.
-- Excludes: Aadhaar documents, employee IDs, personal audit logs, raw private storage URLs.
-- Daily proof is strictly hidden by default unless can_view_daily_proof feature flag is enabled.
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
    s.created_at,
    CASE 
        WHEN c.can_view_daily_proof = TRUE THEN (
            EXISTS (
                SELECT 1 FROM public.shop_daily_uploads u
                WHERE u.shop_id = s.id 
                  AND u.business_date = CURRENT_DATE::text 
                  AND u.is_geofence_verified = TRUE
            )
        )
        ELSE NULL
    END AS has_today_proof,
    CASE 
        WHEN c.can_view_daily_proof = TRUE THEN (
            SELECT u.photo_storage_path FROM public.shop_daily_uploads u
            WHERE u.shop_id = s.id 
              AND u.business_date = CURRENT_DATE::text 
              AND u.is_geofence_verified = TRUE
            ORDER BY u.created_at DESC LIMIT 1
        )
        ELSE NULL
    END AS today_proof_storage_path
FROM public.shops s
JOIN public.zones z ON s.zone_id = z.id
JOIN public.company_zone_assignments cza ON cza.zone_id = s.zone_id
JOIN public.companies c ON cza.company_id = c.id
WHERE s.status IN ('agreed', 'active')
  AND s.is_agreed = TRUE
  AND (
      public.is_master_admin(auth.uid()) OR
      (
          public.is_company_user(auth.uid()) AND
          cza.company_id = public.get_user_company_id(auth.uid())
      )
  );

-- 4. RLS on shops: Company users can ONLY select agreed/active shops in assigned zones
DROP POLICY IF EXISTS "company_user_select_active_shops" ON public.shops;
CREATE POLICY "company_user_select_active_shops"
ON public.shops FOR SELECT
TO authenticated
USING (
    public.is_company_user(auth.uid()) AND
    status IN ('agreed', 'active') AND
    is_agreed = TRUE AND
    public.company_has_zone(public.get_user_company_id(auth.uid()), zone_id)
);

-- 5. RLS on zones: Company users can ONLY select zones assigned to their company
DROP POLICY IF EXISTS "company_user_select_assigned_zones" ON public.zones;
CREATE POLICY "company_user_select_assigned_zones"
ON public.zones FOR SELECT
TO authenticated
USING (
    public.is_company_user(auth.uid()) AND
    public.company_has_zone(public.get_user_company_id(auth.uid()), id)
);

-- 6. RLS on zone_vertices: Company users can ONLY select vertices of assigned zones
DROP POLICY IF EXISTS "company_user_select_assigned_zone_vertices" ON public.zone_vertices;
CREATE POLICY "company_user_select_assigned_zone_vertices"
ON public.zone_vertices FOR SELECT
TO authenticated
USING (
    public.is_company_user(auth.uid()) AND
    public.company_has_zone(public.get_user_company_id(auth.uid()), zone_id)
);
