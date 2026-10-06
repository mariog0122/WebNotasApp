-- ====================================================================
-- MIGRATION: 20260810200000_add_delete_tenant_function.sql (Updated)
-- PURPOSE: Función RPC para eliminación integral de instituciones (tenants),
-- eliminando en cascada todos los registros escolares y los usuarios
-- (profesores, administradores de escuela) en public.profiles y auth.users.
-- ====================================================================

CREATE OR REPLACE FUNCTION public.delete_tenant(p_school_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE
    v_school_name text;
    v_is_admin boolean;
    v_user_ids uuid[];
    v_deleted_users_count integer := 0;
BEGIN
    -- 1. Verificar si el usuario ejecutor es SuperAdmin / Platform Admin
    SELECT (
        public.is_platform_admin() OR public.is_platform_owner() OR
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'superadmin')
    ) INTO v_is_admin;

    IF NOT COALESCE(v_is_admin, false) THEN
        RAISE EXCEPTION 'Acceso denegado. Solo los administradores de la plataforma pueden eliminar instituciones.';
    END IF;

    -- 2. Obtener nombre de la institución
    SELECT name INTO v_school_name FROM public.schools WHERE id = p_school_id;
    IF v_school_name IS NULL THEN
        RAISE EXCEPTION 'Institución no encontrada.';
    END IF;

    -- 3. Identificar todos los usuarios no-superadmin vinculados a esta institución
    SELECT array_agg(id) INTO v_user_ids
    FROM public.profiles
    WHERE school_id = p_school_id AND role != 'superadmin';

    -- 4. Limpieza en cascada de registros académicos
    DELETE FROM public.supplementary_exams WHERE school_id = p_school_id 
        OR course_subject_id IN (SELECT id FROM public.course_subjects WHERE school_id = p_school_id);
        
    DELETE FROM public.project_subject_grades WHERE course_id IN (SELECT id FROM public.courses WHERE school_id = p_school_id);
    DELETE FROM public.project_settings WHERE course_id IN (SELECT id FROM public.courses WHERE school_id = p_school_id);
    
    DELETE FROM public.grades WHERE student_id IN (SELECT id FROM public.students WHERE school_id = p_school_id)
        OR grade_definition_id IN (SELECT id FROM public.grade_definitions WHERE school_id = p_school_id);
        
    DELETE FROM public.qualitative_grades WHERE student_id IN (SELECT id FROM public.students WHERE school_id = p_school_id);
    
    DELETE FROM public.grade_definitions WHERE school_id = p_school_id 
        OR course_subject_id IN (SELECT id FROM public.course_subjects WHERE school_id = p_school_id);
        
    DELETE FROM public.course_subjects WHERE school_id = p_school_id 
        OR course_id IN (SELECT id FROM public.courses WHERE school_id = p_school_id);
        
    DELETE FROM public.student_alerts WHERE school_id = p_school_id 
        OR student_id IN (SELECT id FROM public.students WHERE school_id = p_school_id);
        
    DELETE FROM public.students WHERE school_id = p_school_id;
    DELETE FROM public.courses WHERE school_id = p_school_id;
    DELETE FROM public.subjects WHERE school_id = p_school_id;
    DELETE FROM public.quarters WHERE school_id = p_school_id;
    DELETE FROM public.academic_years WHERE school_id = p_school_id;

    -- 5. Limpieza de facturación y logs
    DELETE FROM public.invoice_payment_allocations WHERE invoice_id IN (SELECT id FROM public.invoices WHERE school_id = p_school_id);
    DELETE FROM public.invoices WHERE school_id = p_school_id;
    DELETE FROM public.payments WHERE school_id = p_school_id;
    DELETE FROM public.subscriptions WHERE school_id = p_school_id;
    DELETE FROM public.tenant_billing_profiles WHERE school_id = p_school_id;
    DELETE FROM public.tenant_memberships WHERE school_id = p_school_id;
    DELETE FROM public.tenant_features WHERE school_id = p_school_id;
    DELETE FROM public.tenant_limits WHERE school_id = p_school_id;
    DELETE FROM public.system_config WHERE school_id = p_school_id;
    DELETE FROM public.client_error_events WHERE school_id = p_school_id;
    DELETE FROM public.audit_log WHERE school_id = p_school_id;
    DELETE FROM public.impersonation_logs WHERE school_id = p_school_id;

    -- 6. Eliminar perfiles y cuentas de usuario en auth.users
    IF v_user_ids IS NOT NULL AND array_length(v_user_ids, 1) > 0 THEN
        v_deleted_users_count := array_length(v_user_ids, 1);
        DELETE FROM public.profiles WHERE id = ANY(v_user_ids);
        DELETE FROM auth.users WHERE id = ANY(v_user_ids);
    END IF;

    -- Si algún superadmin tenía asociado este school_id, desvincularlo
    UPDATE public.profiles SET school_id = NULL WHERE school_id = p_school_id;

    -- 7. Eliminar la institución principal
    DELETE FROM public.schools WHERE id = p_school_id;

    RETURN jsonb_build_object(
        'success', true,
        'deleted_users', v_deleted_users_count,
        'message', format('La institución "%s" y %s usuarios asociados fueron eliminados correctamente.', v_school_name, v_deleted_users_count)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_tenant(uuid) TO authenticated;
