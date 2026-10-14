-- ============================================================================
-- Migration 11: Zone Pricing Overrides & Supabase Realtime Stream
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.zone_pricing (
    zone_id TEXT PRIMARY KEY,
    a5_stand_one_side NUMERIC(10,2) NOT NULL DEFAULT 80.00,
    a5_stand_both_sides NUMERIC(10,2) NOT NULL DEFAULT 80.00,
    a6_stand_one_side NUMERIC(10,2) NOT NULL DEFAULT 100.00,
    a6_stand_both_sides NUMERIC(10,2) NOT NULL DEFAULT 100.00,
    a5_saloon_one_side NUMERIC(10,2) NOT NULL DEFAULT 80.00,
    a5_saloon_both_sides NUMERIC(10,2) NOT NULL DEFAULT 80.00,
    a6_saloon_one_side NUMERIC(10,2) NOT NULL DEFAULT 100.00,
    a6_saloon_both_sides NUMERIC(10,2) NOT NULL DEFAULT 100.00,
    design_print_a6_one_side NUMERIC(10,2) NOT NULL DEFAULT 5000.00,
    design_print_a6_both_sides NUMERIC(10,2) NOT NULL DEFAULT 10000.00,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_zone_pricing_updated_at ON public.zone_pricing(updated_at);

-- Enable Row Level Security
ALTER TABLE public.zone_pricing ENABLE ROW LEVEL SECURITY;

-- 1. Master Admin has full management privileges (SELECT, INSERT, UPDATE, DELETE)
DROP POLICY IF EXISTS "master_admin_zone_pricing_all" ON public.zone_pricing;
CREATE POLICY "master_admin_zone_pricing_all"
ON public.zone_pricing FOR ALL
TO authenticated
USING (public.is_master_admin(auth.uid()))
WITH CHECK (public.is_master_admin(auth.uid()));

-- 2. Authenticated users (Companies, Admins, Employees) can view all zone prices
DROP POLICY IF EXISTS "authenticated_select_zone_pricing" ON public.zone_pricing;
CREATE POLICY "authenticated_select_zone_pricing"
ON public.zone_pricing FOR SELECT
TO authenticated
USING (true);

-- 3. Anonymous/Public can view zone prices for initial booking calculation previews
DROP POLICY IF EXISTS "anon_select_zone_pricing" ON public.zone_pricing;
CREATE POLICY "anon_select_zone_pricing"
ON public.zone_pricing FOR SELECT
TO anon
USING (true);

-- 4. Enable Supabase Realtime publication on zone_pricing
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND tablename = 'zone_pricing'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.zone_pricing;
        END IF;
    END IF;
END $$;
