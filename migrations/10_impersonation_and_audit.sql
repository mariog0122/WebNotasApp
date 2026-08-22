-- ====================================================================
-- MIGRATION: 10_impersonation_and_audit.sql
-- PURPOSE: FASE 11 (Impersonación Segura) y FASE 12 (Logs de Auditoría Inmutables)
-- ====================================================================

-- 1. IMPERSONATION LOGS TABLE
CREATE TABLE IF NOT EXISTS public.impersonation_logs (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    actor_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    impersonated_user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    reason text NOT NULL,
    started_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
    ended_at timestamptz,
    ip_address text,
    user_agent text
);

ALTER TABLE public.impersonation_logs ENABLE ROW LEVEL SECURITY;

-- Solo Platform Admins pueden ver impersonation logs
DROP POLICY IF EXISTS "Platform admins view impersonation logs" ON public.impersonation_logs;
CREATE POLICY "Platform admins view impersonation logs" ON public.impersonation_logs
    FOR SELECT USING (public.is_platform_admin());

-- Nadie inserta directo desde REST client, sólo mediante RPC
DROP POLICY IF EXISTS "No direct insert impersonation" ON public.impersonation_logs;

-- RPC INICIAR IMPERSONACIÓN
CREATE OR REPLACE FUNCTION public.start_impersonation_session(
    p_target_user_id uuid,
    p_reason text
)
RETURNS json AS $$
DECLARE
    v_target_profile record;
    v_log_id uuid;
BEGIN
    -- Validar permiso
    IF NOT public.is_platform_admin() THEN
        RETURN json_build_object('success', false, 'message', 'Acceso denegado: Requiere rol de soporte/administrador de plataforma.');
    END IF;

    IF p_reason IS NULL OR length(trim(p_reason)) < 5 THEN
        RETURN json_build_object('success', false, 'message', 'Debe proporcionar un motivo válido para la impersonación (mínimo 5 caracteres).');
    END IF;

    -- Obtener datos del usuario a impersonar
    SELECT * INTO v_target_profile FROM public.profiles WHERE id = p_target_user_id;
    IF v_target_profile IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Usuario destino no encontrado.');
    END IF;

    -- Registrar log
    INSERT INTO public.impersonation_logs (
        actor_id,
        impersonated_user_id,
        school_id,
        reason,
        started_at
    ) VALUES (
        auth.uid(),
        p_target_user_id,
        v_target_profile.school_id,
        p_reason,
        now()
    )
    RETURNING id INTO v_log_id;

    -- Registrar en audit log global
    INSERT INTO public.audit_log (user_id, action, table_name, record_id, new_values)
    VALUES (
        auth.uid(),
        'IMPERSONATION_START',
        'profiles',
        p_target_user_id,
        jsonb_build_object('reason', p_reason, 'impersonation_log_id', v_log_id, 'target_email', v_target_profile.email)
    );

    RETURN json_build_object(
        'success', true,
        'impersonation_id', v_log_id,
        'target_user', json_build_object(
            'id', v_target_profile.id,
            'email', v_target_profile.email,
            'full_name', v_target_profile.full_name,
            'role', v_target_profile.role,
            'school_id', v_target_profile.school_id
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC FINALIZAR IMPERSONACIÓN
CREATE OR REPLACE FUNCTION public.stop_impersonation_session(p_log_id uuid)
RETURNS json AS $$
BEGIN
    UPDATE public.impersonation_logs
    SET ended_at = now()
    WHERE id = p_log_id AND actor_id = auth.uid() AND ended_at IS NULL;

    INSERT INTO public.audit_log (user_id, action, table_name, record_id, new_values)
    VALUES (
        auth.uid(),
        'IMPERSONATION_END',
        'impersonation_logs',
        p_log_id,
        jsonb_build_object('ended_at', now())
    );

    RETURN json_build_object('success', true, 'message', 'Sesión de impersonación finalizada.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. REFORZAR AUDIT_LOGS PARA EVITAR EDICIÓN O ELIMINACIÓN
CREATE TABLE IF NOT EXISTS public.audit_log (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE,
    user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    action text NOT NULL,
    table_name text,
    record_id text,
    old_values jsonb,
    new_values jsonb,
    ip_address text,
    created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view audit logs" ON public.audit_log;
CREATE POLICY "Platform admins and tenant admins can view audit logs" ON public.audit_log
    FOR SELECT USING (
        public.is_platform_admin() 
        OR (public.has_tenant_permission('settings.read') AND user_id = auth.uid())
    );

-- Bloquear INSERT, UPDATE y DELETE directos en audit_log deshabilitando políticas de modificación
DROP POLICY IF EXISTS "No direct insert audit" ON public.audit_log;
DROP POLICY IF EXISTS "No update audit" ON public.audit_log;
DROP POLICY IF EXISTS "No delete audit" ON public.audit_log;
