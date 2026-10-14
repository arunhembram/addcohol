-- ============================================================================
-- Migration 02: Zones, Polygon Vertices & Hierarchical Zone Assignments
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Zones Table
-- "A Zone is an editable polygon with at least 3 vertices; the Flutter UI will start with 6 default vertices."
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_zones_code ON public.zones(code);
CREATE INDEX IF NOT EXISTS idx_zones_is_active ON public.zones(is_active);

-- ----------------------------------------------------------------------------
-- 2. Zone Vertices Table
-- Ordered collection of points forming the polygon boundary.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.zone_vertices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    zone_id UUID NOT NULL REFERENCES public.zones(id) ON DELETE CASCADE,
    vertex_index INT NOT NULL CHECK (vertex_index >= 0),
    latitude DOUBLE PRECISION NOT NULL CHECK (latitude >= -90.0 AND latitude <= 90.0),
    longitude DOUBLE PRECISION NOT NULL CHECK (longitude >= -180.0 AND longitude <= 180.0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    CONSTRAINT uq_zone_vertex_order UNIQUE (zone_id, vertex_index)
);

CREATE INDEX IF NOT EXISTS idx_zone_vertices_zone ON public.zone_vertices(zone_id, vertex_index);

-- ----------------------------------------------------------------------------
-- 3. Admin Zone Assignments Table
-- "Master Admin creates Admin accounts and assigns Zones."
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.admin_zone_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    zone_id UUID NOT NULL REFERENCES public.zones(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    CONSTRAINT uq_admin_zone UNIQUE (admin_id, zone_id)
);

CREATE INDEX IF NOT EXISTS idx_admin_zone_admin ON public.admin_zone_assignments(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_zone_zone ON public.admin_zone_assignments(zone_id);

-- ----------------------------------------------------------------------------
-- 4. Employee Zone Assignments Table
-- "Admin creates Employee accounts and assigns only Zones the Admin controls."
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.employee_zone_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    zone_id UUID NOT NULL REFERENCES public.zones(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    CONSTRAINT uq_employee_zone UNIQUE (employee_id, zone_id)
);

CREATE INDEX IF NOT EXISTS idx_employee_zone_employee ON public.employee_zone_assignments(employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_zone_zone ON public.employee_zone_assignments(zone_id);

-- ----------------------------------------------------------------------------
-- 5. Security Definer Zone Ownership Functions
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_has_zone(p_admin_id UUID, p_zone_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.admin_zone_assignments
        WHERE admin_id = p_admin_id AND zone_id = p_zone_id
    ) OR public.is_master_admin(p_admin_id);
$$;

CREATE OR REPLACE FUNCTION public.employee_has_zone(p_employee_id UUID, p_zone_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.employee_zone_assignments
        WHERE employee_id = p_employee_id AND zone_id = p_zone_id
    );
$$;

-- ----------------------------------------------------------------------------
-- 6. Trigger: Validate Admin Zone Assignment (Only Master Admin can assign)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_admin_zone_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_master_admin(auth.uid()) THEN
        RAISE EXCEPTION 'Access denied: Only Master Admin can assign zones to Administrators.';
    END IF;

    -- Verify target user is indeed an admin
    IF (SELECT role FROM public.profiles WHERE id = NEW.admin_id) <> 'admin' THEN
        RAISE EXCEPTION 'Target user must hold the "admin" role.';
    END IF;

    NEW.assigned_by := auth.uid();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_admin_zone ON public.admin_zone_assignments;
CREATE TRIGGER trg_validate_admin_zone
BEFORE INSERT ON public.admin_zone_assignments
FOR EACH ROW
EXECUTE FUNCTION public.validate_admin_zone_assignment();

-- ----------------------------------------------------------------------------
-- 7. Trigger: Validate Employee Zone Assignment (Admin assigns only their own zones)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_employee_zone_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Master admin can assign any zone
    IF public.is_master_admin(auth.uid()) THEN
        NEW.assigned_by := auth.uid();
        RETURN NEW;
    END IF;

    -- Admin can only assign zones that the admin themselves are assigned to
    IF public.is_admin(auth.uid()) THEN
        IF NOT public.admin_has_zone(auth.uid(), NEW.zone_id) THEN
            RAISE EXCEPTION 'Access denied: Administrator cannot assign a zone they do not control.';
        END IF;

        -- Verify target user is an employee
        IF (SELECT role FROM public.profiles WHERE id = NEW.employee_id) <> 'employee' THEN
            RAISE EXCEPTION 'Target user must hold the "employee" role.';
        END IF;

        NEW.assigned_by := auth.uid();
        RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Access denied: Unauthorized to assign zones.';
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_employee_zone ON public.employee_zone_assignments;
CREATE TRIGGER trg_validate_employee_zone
BEFORE INSERT ON public.employee_zone_assignments
FOR EACH ROW
EXECUTE FUNCTION public.validate_employee_zone_assignment();

-- ----------------------------------------------------------------------------
-- 8. Row Level Security: Zones & Vertices
-- ----------------------------------------------------------------------------
ALTER TABLE public.zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zone_vertices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_zone_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employee_zone_assignments ENABLE ROW LEVEL SECURITY;

-- Master Admin: Full control over zones
CREATE POLICY "master_admin_zones_all"
ON public.zones FOR ALL
TO authenticated
USING (public.is_master_admin(auth.uid()))
WITH CHECK (public.is_master_admin(auth.uid()));

-- Master Admin: Full control over vertices
CREATE POLICY "master_admin_zone_vertices_all"
ON public.zone_vertices FOR ALL
TO authenticated
USING (public.is_master_admin(auth.uid()))
WITH CHECK (public.is_master_admin(auth.uid()));

-- Master Admin: Full control over admin zone assignments
CREATE POLICY "master_admin_admin_zone_assignments_all"
ON public.admin_zone_assignments FOR ALL
TO authenticated
USING (public.is_master_admin(auth.uid()))
WITH CHECK (public.is_master_admin(auth.uid()));

-- Master Admin: Full control over employee zone assignments
CREATE POLICY "master_admin_employee_zone_assignments_all"
ON public.employee_zone_assignments FOR ALL
TO authenticated
USING (public.is_master_admin(auth.uid()))
WITH CHECK (public.is_master_admin(auth.uid()));

-- Admin: Can view zones assigned to them
CREATE POLICY "admin_select_assigned_zones"
ON public.zones FOR SELECT
TO authenticated
USING (
    public.is_admin(auth.uid()) AND
    public.admin_has_zone(auth.uid(), id)
);

-- Admin: Can view vertices for zones assigned to them
CREATE POLICY "admin_select_assigned_zone_vertices"
ON public.zone_vertices FOR SELECT
TO authenticated
USING (
    public.is_admin(auth.uid()) AND
    public.admin_has_zone(auth.uid(), zone_id)
);

-- Admin: Can read their own assignments
CREATE POLICY "admin_select_own_zone_assignments"
ON public.admin_zone_assignments FOR SELECT
TO authenticated
USING (
    public.is_admin(auth.uid()) AND
    admin_id = auth.uid()
);

-- Admin: Can select employee zone assignments in their zones
CREATE POLICY "admin_select_controlled_employee_assignments"
ON public.employee_zone_assignments FOR SELECT
TO authenticated
USING (
    public.is_admin(auth.uid()) AND
    public.admin_has_zone(auth.uid(), zone_id)
);

-- Admin: Can insert employee zone assignments for zones they control
CREATE POLICY "admin_insert_employee_zone_assignments"
ON public.employee_zone_assignments FOR INSERT
TO authenticated
WITH CHECK (
    public.is_admin(auth.uid()) AND
    public.admin_has_zone(auth.uid(), zone_id)
);

-- Admin: Can delete employee zone assignments for zones they control
CREATE POLICY "admin_delete_employee_zone_assignments"
ON public.employee_zone_assignments FOR DELETE
TO authenticated
USING (
    public.is_admin(auth.uid()) AND
    public.admin_has_zone(auth.uid(), zone_id)
);

-- Employee: Can view assigned zones
CREATE POLICY "employee_select_assigned_zones"
ON public.zones FOR SELECT
TO authenticated
USING (
    public.is_employee(auth.uid()) AND
    public.employee_has_zone(auth.uid(), id)
);

-- Employee: Can view assigned zone vertices
CREATE POLICY "employee_select_assigned_zone_vertices"
ON public.zone_vertices FOR SELECT
TO authenticated
USING (
    public.is_employee(auth.uid()) AND
    public.employee_has_zone(auth.uid(), zone_id)
);

-- Employee: Can view own zone assignments
CREATE POLICY "employee_select_own_assignments"
ON public.employee_zone_assignments FOR SELECT
TO authenticated
USING (
    public.is_employee(auth.uid()) AND
    employee_id = auth.uid()
);
