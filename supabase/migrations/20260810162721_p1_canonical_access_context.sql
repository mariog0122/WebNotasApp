-- Canonical, RLS-aware authorization context for the browser.
-- SECURITY DEFINER ensures reliable execution for authenticated and platform admin users.
CREATE OR REPLACE FUNCTION public.get_my_access_context()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_is_platform_admin boolean := false;
  v_is_platform_owner boolean := false;
  v_platform_roles jsonb := '[]'::jsonb;
  v_default_school_id uuid;
  v_memberships jsonb := '[]'::jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object(
      'user_id', null,
      'is_platform_admin', false,
      'is_platform_owner', false,
      'platform_roles', '[]'::jsonb,
      'default_school_id', null,
      'memberships', '[]'::jsonb
    );
  END IF;

  v_is_platform_admin := public.is_platform_admin();
  v_is_platform_owner := public.is_platform_owner();

  -- Respaldo directo si el perfil es superadmin
  IF NOT coalesce(v_is_platform_admin, false) THEN
    SELECT EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = v_uid AND role = 'superadmin' AND coalesce(is_active, true)
    ) INTO v_is_platform_admin;
  END IF;

  SELECT coalesce(
    jsonb_agg(pr.name::text ORDER BY pr.name::text),
    '[]'::jsonb
  ) INTO v_platform_roles
  FROM public.user_platform_roles upr
  JOIN public.platform_roles pr ON pr.id = upr.platform_role_id
  WHERE upr.user_id = v_uid;

  IF v_is_platform_admin AND (v_platform_roles = '[]'::jsonb OR v_platform_roles IS NULL) THEN
    v_platform_roles := '["platform_admin", "platform_owner"]'::jsonb;
    v_is_platform_owner := true;
  END IF;

  v_default_school_id := public.get_user_school_id();

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'school_id', tm.school_id,
        'role', tr.name::text,
        'permissions', coalesce(
          (
            SELECT jsonb_agg(p.code ORDER BY p.code)
            FROM public.role_permissions rp
            JOIN public.permissions p ON p.id = rp.permission_id
            WHERE rp.tenant_role_id = tm.tenant_role_id
          ),
          '[]'::jsonb
        )
      )
      ORDER BY tm.created_at, tm.school_id
    ),
    '[]'::jsonb
  ) INTO v_memberships
  FROM public.tenant_memberships tm
  JOIN public.tenant_roles tr ON tr.id = tm.tenant_role_id
  WHERE tm.user_id = v_uid
    AND tm.is_active = true;

  RETURN jsonb_build_object(
    'user_id', v_uid,
    'is_platform_admin', coalesce(v_is_platform_admin, false),
    'is_platform_owner', coalesce(v_is_platform_owner, false),
    'platform_roles', coalesce(v_platform_roles, '[]'::jsonb),
    'default_school_id', v_default_school_id,
    'memberships', coalesce(v_memberships, '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_access_context() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_platform_admin() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_platform_owner() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_user_school_id() TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.get_my_access_context() IS
  'Returns the authenticated user platform roles, active tenant memberships and granted permission codes.';

