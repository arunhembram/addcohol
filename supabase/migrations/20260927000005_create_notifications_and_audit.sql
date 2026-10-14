-- ============================================================================
-- Migration 05: Notifications, Security Audit Logs & Automated Audit Logging
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Notifications Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'system_alert',
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON public.notifications(recipient_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);

-- ----------------------------------------------------------------------------
-- 2. Audit Logs Table (Tamper-Resistant Platform History)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON public.audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON public.audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at);

-- ----------------------------------------------------------------------------
-- 3. Security Definer Function: Log Audit Event
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_audit_event(
    p_actor_id UUID,
    p_action TEXT,
    p_entity_type TEXT,
    p_entity_id TEXT,
    p_metadata JSONB DEFAULT '{}'::jsonb,
    p_ip INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO public.audit_logs (
        actor_id,
        action,
        entity_type,
        entity_id,
        metadata,
        ip_address,
        user_agent,
        created_at
    ) VALUES (
        p_actor_id,
        p_action,
        p_entity_type,
        p_entity_id,
        p_metadata,
        p_ip,
        p_user_agent,
        TIMEZONE('utc'::text, NOW())
    ) RETURNING id INTO v_log_id;

    RETURN v_log_id;
END;
$$;

-- ----------------------------------------------------------------------------
-- 4. Triggers: Automatically Audit Critical State Transitions
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.audit_shop_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status OR OLD.is_agreed IS DISTINCT FROM NEW.is_agreed THEN
        PERFORM public.log_audit_event(
            auth.uid(),
            'SHOP_STATUS_CHANGED',
            'shop',
            NEW.id::text,
            jsonb_build_object(
                'old_status', OLD.status,
                'new_status', NEW.status,
                'old_agreed', OLD.is_agreed,
                'new_agreed', NEW.is_agreed,
                'shop_code', NEW.shop_code
            )
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_shop_status ON public.shops;
CREATE TRIGGER trg_audit_shop_status
AFTER UPDATE ON public.shops
FOR EACH ROW
EXECUTE FUNCTION public.audit_shop_status_change();

-- ----------------------------------------------------------------------------
-- 5. Row Level Security: Notifications & Audit Logs
-- ----------------------------------------------------------------------------
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Notifications: Recipients can select their own notifications
CREATE POLICY "recipient_select_notifications"
ON public.notifications FOR SELECT
TO authenticated
USING (recipient_id = auth.uid());

-- Notifications: Recipients can mark their own notifications as read
CREATE POLICY "recipient_update_notifications"
ON public.notifications FOR UPDATE
TO authenticated
USING (recipient_id = auth.uid())
WITH CHECK (recipient_id = auth.uid());

-- Audit Logs: Only Master Admin can select audit logs
CREATE POLICY "master_admin_select_audit_logs"
ON public.audit_logs FOR SELECT
TO authenticated
USING (public.is_master_admin(auth.uid()));

-- Audit Logs: Admins can select audit logs concerning entities they acted on
CREATE POLICY "admin_select_own_audit_logs"
ON public.audit_logs FOR SELECT
TO authenticated
USING (
    public.is_admin(auth.uid()) AND
    actor_id = auth.uid()
);

-- Audit Logs: Client insertion is strictly disallowed (only system functions/triggers can insert)
CREATE OR REPLACE FUNCTION public.prevent_client_audit_writes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF current_user IN ('postgres', 'service_role') THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    IF auth.role() = 'authenticated' THEN
        RAISE EXCEPTION 'Access denied: Audit logs cannot be modified directly from client applications.';
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_audit_logs ON public.audit_logs;
CREATE TRIGGER trg_protect_audit_logs
BEFORE INSERT OR UPDATE OR DELETE ON public.audit_logs
FOR EACH ROW
EXECUTE FUNCTION public.prevent_client_audit_writes();
