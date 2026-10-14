-- ============================================================================
-- Migration 06: Private Storage Buckets & Strict Storage RLS Policies
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Create Private Storage Buckets for Aadhaar Documents and Daily Shop Photos
-- "Aadhaar images must use a private storage bucket."
-- "Daily shop photos must be private."
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    (
        'secure-identity-docs',
        'secure-identity-docs',
        false, -- Strictly Private
        10485760, -- 10MB limit
        ARRAY['image/jpeg', 'image/png', 'application/pdf']
    ),
    (
        'shop-daily-photos',
        'shop-daily-photos',
        false, -- Strictly Private
        15728640, -- 15MB limit
        ARRAY['image/jpeg', 'image/png', 'image/webp']
    )
ON CONFLICT (id) DO UPDATE SET
    public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ----------------------------------------------------------------------------
-- 2. Storage RLS Policies: Secure Identity Documents (Aadhaar & Licenses)
-- Path format: {shop_id}/{shopkeeper_id}/{filename}
-- ----------------------------------------------------------------------------

-- Master Admin: Full storage control
CREATE POLICY "master_admin_identity_docs_all"
ON storage.objects FOR ALL
TO authenticated
USING (
    bucket_id = 'secure-identity-docs' AND
    public.is_master_admin(auth.uid())
)
WITH CHECK (
    bucket_id = 'secure-identity-docs' AND
    public.is_master_admin(auth.uid())
);

-- Admin: Can view and verify documents for shops in zones they control
CREATE POLICY "admin_identity_docs_select"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'secure-identity-docs' AND
    public.is_admin(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id::text = (storage.foldername(name))[1]
          AND public.admin_has_zone(auth.uid(), s.zone_id)
    )
);

-- Employee: Can upload and view documents for shops in their assigned zones
CREATE POLICY "employee_identity_docs_select"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'secure-identity-docs' AND
    public.is_employee(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id::text = (storage.foldername(name))[1]
          AND public.employee_has_zone(auth.uid(), s.zone_id)
    )
);

CREATE POLICY "employee_identity_docs_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'secure-identity-docs' AND
    public.is_employee(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id::text = (storage.foldername(name))[1]
          AND public.employee_has_zone(auth.uid(), s.zone_id)
    )
);

-- Shopkeeper: Can select and upload only their own identity documents
CREATE POLICY "shopkeeper_identity_docs_select"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'secure-identity-docs' AND
    public.is_shopkeeper(auth.uid()) AND
    (storage.foldername(name))[2] = auth.uid()::text
);

CREATE POLICY "shopkeeper_identity_docs_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'secure-identity-docs' AND
    public.is_shopkeeper(auth.uid()) AND
    (storage.foldername(name))[2] = auth.uid()::text
);

-- Company User: NO POLICY (Implicit Deny on secure-identity-docs)

-- ----------------------------------------------------------------------------
-- 3. Storage RLS Policies: Shop Daily Photos
-- Path format: {shop_id}/{business_date}/{uploader_id}/{filename}
-- ----------------------------------------------------------------------------

-- Master Admin: Full control
CREATE POLICY "master_admin_daily_photos_all"
ON storage.objects FOR ALL
TO authenticated
USING (
    bucket_id = 'shop-daily-photos' AND
    public.is_master_admin(auth.uid())
)
WITH CHECK (
    bucket_id = 'shop-daily-photos' AND
    public.is_master_admin(auth.uid())
);

-- Admin: Can view daily photos for shops in their zones
CREATE POLICY "admin_daily_photos_select"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'shop-daily-photos' AND
    public.is_admin(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id::text = (storage.foldername(name))[1]
          AND public.admin_has_zone(auth.uid(), s.zone_id)
    )
);

-- Employee: Can upload and view daily photos in assigned zones
CREATE POLICY "employee_daily_photos_select"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'shop-daily-photos' AND
    public.is_employee(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id::text = (storage.foldername(name))[1]
          AND public.employee_has_zone(auth.uid(), s.zone_id)
    )
);

CREATE POLICY "employee_daily_photos_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'shop-daily-photos' AND
    public.is_employee(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id::text = (storage.foldername(name))[1]
          AND public.employee_has_zone(auth.uid(), s.zone_id)
    )
);

-- Shopkeeper: Can upload and view daily photos for their own linked shop
CREATE POLICY "shopkeeper_daily_photos_select"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'shop-daily-photos' AND
    public.is_shopkeeper(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id::text = (storage.foldername(name))[1]
          AND s.shopkeeper_id = auth.uid()
    )
);

CREATE POLICY "shopkeeper_daily_photos_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'shop-daily-photos' AND
    public.is_shopkeeper(auth.uid()) AND
    EXISTS (
        SELECT 1 FROM public.shops s
        WHERE s.id::text = (storage.foldername(name))[1]
          AND s.shopkeeper_id = auth.uid()
    )
);

-- Company User: NO POLICY (Implicit Deny - cannot access private photo storage)
