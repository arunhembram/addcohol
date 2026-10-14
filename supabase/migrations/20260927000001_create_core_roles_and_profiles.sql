-- ============================================================================
-- Migration 01: Core Roles, Profiles, Display IDs & Security Definer Helpers
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. Sequences for 5-Digit Display IDs (Range: 10000 to 99999)
-- "Display 5-digit IDs for Admin and Employee, but do not treat an ID alone as authentication."
-- ----------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS staff_display_id_seq
    START WITH 10001
    INCREMENT BY 1
    MINVALUE 10000
    MAXVALUE 99999
    CYCLE;

-- ----------------------------------------------------------------------------
-- 2. Profiles Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('master_admin', 'admin', 'employee', 'shopkeeper', 'company_user')),
    phone_number TEXT,
    display_id VARCHAR(5) UNIQUE,
    avatar_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_display_id ON public.profiles(display_id);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);

-- ----------------------------------------------------------------------------
-- 3. Security Definer Helper Functions (Bypass RLS safely to read user roles)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_role(p_user_id UUID)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT role FROM public.profiles WHERE id = p_user_id AND is_active = TRUE;
$$;

CREATE OR REPLACE FUNCTION public.is_master_admin(p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = p_user_id
          AND role = 'master_admin'
          AND is_active = TRUE
    );
$$;

CREATE OR REPLACE FUNCTION public.is_admin(p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = p_user_id
          AND role = 'admin'
          AND is_active = TRUE
    );
$$;

CREATE OR REPLACE FUNCTION public.is_employee(p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = p_user_id
          AND role = 'employee'
          AND is_active = TRUE
    );
$$;

CREATE OR REPLACE FUNCTION public.is_shopkeeper(p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = p_user_id
          AND role = 'shopkeeper'
          AND is_active = TRUE
    );
$$;

CREATE OR REPLACE FUNCTION public.is_company_user(p_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = p_user_id
          AND role = 'company_user'
          AND is_active = TRUE
    );
$$;

-- ----------------------------------------------------------------------------
-- 4. Triggers: Auto-assign 5-Digit Display ID for Admin and Employee
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_profile_display_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Only generate display_id for admin and employee if not already set
    IF NEW.role IN ('admin', 'employee') AND (NEW.display_id IS NULL OR NEW.display_id = '') THEN
        NEW.display_id := LPAD(nextval('public.staff_display_id_seq')::text, 5, '0');
    END IF;

    -- Ensure non-staff roles do not hold a staff display_id
    IF NEW.role NOT IN ('admin', 'employee') THEN
        NEW.display_id := NULL;
    END IF;

    NEW.updated_at := TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_profile_display_id ON public.profiles;
CREATE TRIGGER trg_assign_profile_display_id
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.handle_profile_display_id();

-- ----------------------------------------------------------------------------
-- 5. Trigger: Prevent Role Self-Escalation
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.prevent_role_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Master admin can change any role
    IF public.is_master_admin(auth.uid()) THEN
        RETURN NEW;
    END IF;

    -- Admin can only create employee profiles
    IF TG_OP = 'INSERT' THEN
        IF public.is_admin(auth.uid()) AND NEW.role = 'employee' THEN
            NEW.created_by := auth.uid();
            RETURN NEW;
        END IF;
    END IF;

    -- Normal users or admins attempting to modify role
    IF TG_OP = 'UPDATE' AND OLD.role IS DISTINCT FROM NEW.role THEN
        RAISE EXCEPTION 'Access denied: role escalation is strictly prohibited.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_role_escalation ON public.profiles;
CREATE TRIGGER trg_prevent_role_escalation
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.prevent_role_escalation();

-- ----------------------------------------------------------------------------
-- 6. Row Level Security on Profiles Table
-- ----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Master Admin can select all profiles
CREATE POLICY "master_admin_select_all_profiles"
ON public.profiles FOR SELECT
TO authenticated
USING (public.is_master_admin(auth.uid()));

-- Master Admin can insert any profile
CREATE POLICY "master_admin_insert_profiles"
ON public.profiles FOR INSERT
TO authenticated
WITH CHECK (public.is_master_admin(auth.uid()));

-- Master Admin can update any profile
CREATE POLICY "master_admin_update_profiles"
ON public.profiles FOR UPDATE
TO authenticated
USING (public.is_master_admin(auth.uid()))
WITH CHECK (public.is_master_admin(auth.uid()));

-- Master Admin can delete profiles
CREATE POLICY "master_admin_delete_profiles"
ON public.profiles FOR DELETE
TO authenticated
USING (public.is_master_admin(auth.uid()));

-- Admins can view other admins and employees they manage
CREATE POLICY "admin_select_staff_profiles"
ON public.profiles FOR SELECT
TO authenticated
USING (
    public.is_admin(auth.uid()) AND (
        id = auth.uid() OR
        created_by = auth.uid() OR
        role IN ('admin', 'employee', 'shopkeeper')
    )
);

-- Admin can create Employee accounts ("Admin creates Employee accounts")
CREATE POLICY "admin_insert_employee_profiles"
ON public.profiles FOR INSERT
TO authenticated
WITH CHECK (
    public.is_admin(auth.uid()) AND
    role = 'employee' AND
    created_by = auth.uid()
);

-- Admin can update Employees they created
CREATE POLICY "admin_update_managed_employees"
ON public.profiles FOR UPDATE
TO authenticated
USING (
    public.is_admin(auth.uid()) AND
    created_by = auth.uid() AND
    role = 'employee'
)
WITH CHECK (
    public.is_admin(auth.uid()) AND
    role = 'employee'
);

-- Users can read their own profile
CREATE POLICY "user_select_own_profile"
ON public.profiles FOR SELECT
TO authenticated
USING (id = auth.uid());

-- Users can update non-critical fields of their own profile (name, phone, avatar)
CREATE POLICY "user_update_own_profile"
ON public.profiles FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());
