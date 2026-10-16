-- ============================================================================
-- Migration 12: Admin Codes, First-Time Pairing & Expulsion Sync
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.admin_codes (
    code VARCHAR(5) PRIMARY KEY,
    full_name TEXT NOT NULL DEFAULT '',
    phone_number TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'claimed', 'expelled')),
    assigned_zone_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_admin_codes_status ON public.admin_codes(status);
CREATE INDEX IF NOT EXISTS idx_admin_codes_updated_at ON public.admin_codes(updated_at);

-- Enable Row Level Security
ALTER TABLE public.admin_codes ENABLE ROW LEVEL SECURITY;

-- 1. Master Admin has full management access (SELECT, INSERT, UPDATE, DELETE)
DROP POLICY IF EXISTS "master_admin_manage_admin_codes" ON public.admin_codes;
CREATE POLICY "master_admin_manage_admin_codes"
ON public.admin_codes FOR ALL
TO authenticated
USING (public.is_master_admin(auth.uid()))
WITH CHECK (public.is_master_admin(auth.uid()));

-- 2. Authenticated users and public/anonymous can read admin codes for pairing & login verification
DROP POLICY IF EXISTS "public_select_admin_codes" ON public.admin_codes;
CREATE POLICY "public_select_admin_codes"
ON public.admin_codes FOR SELECT
TO anon, authenticated
USING (true);

-- 3. Public/anonymous & authenticated can claim/pair their admin code or update status
DROP POLICY IF EXISTS "public_upsert_admin_codes" ON public.admin_codes;
CREATE POLICY "public_upsert_admin_codes"
ON public.admin_codes FOR INSERT
TO anon, authenticated
WITH CHECK (true);

DROP POLICY IF EXISTS "public_update_admin_codes" ON public.admin_codes;
CREATE POLICY "public_update_admin_codes"
ON public.admin_codes FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- 4. Enable Supabase Realtime publication on admin_codes
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND tablename = 'admin_codes'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.admin_codes;
        END IF;
    END IF;
END $$;
