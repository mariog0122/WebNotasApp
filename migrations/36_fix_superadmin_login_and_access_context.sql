-- ==============================================================================
-- MIGRACIÓN 36: Corrección Integral de Acceso Superadmin y Contexto de Autorización
-- ==============================================================================
-- Esta migración resuelve el error "permission denied for function get_my_access_context"
-- y el bloqueo del trigger "protect_profile_authorization_fields" al ejecutar desde el editor SQL.

BEGIN;

-- 1. Actualizar triggers para permitir migraciones y operaciones administrativas directas (auth.uid() IS NULL)
CREATE OR REPLACE FUNCTION public.protect_profile_authorization_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
BEGIN
  -- Permitir ejecuciones directas por SQL Editor, migraciones o cuando el actor es un administrador de plataforma
  IF (SELECT auth.uid()) IS NULL OR public.is_platform_admin() THEN
    RETURN NEW;
  END IF;

  IF OLD.school_id = public.get_user_school_id()
     AND public.has_tenant_permission('users.manage') THEN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.email IS DISTINCT FROM OLD.email
       OR NEW.school_id IS DISTINCT FROM OLD.school_id
       OR NEW.role = 'superadmin' THEN
      RAISE EXCEPTION 'Campos de autorización protegidos' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  IF OLD.id = (SELECT auth.uid()) THEN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.email IS DISTINCT FROM OLD.email
       OR NEW.role IS DISTINCT FROM OLD.role
       OR NEW.school_id IS DISTINCT FROM OLD.school_id
       OR NEW.is_active IS DISTINCT FROM OLD.is_active THEN
      RAISE EXCEPTION 'Campos de autorización protegidos' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Perfil no autorizado' USING ERRCODE = '42501';
END;
$$;

CREATE OR REPLACE FUNCTION public.set_school_id_from_auth()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  actor_school_id uuid := public.get_user_school_id();
BEGIN
  IF (SELECT auth.uid()) IS NULL OR public.is_platform_admin() THEN
    RETURN NEW;
  END IF;

  IF NEW.school_id IS NULL THEN
    NEW.school_id := actor_school_id;
  END IF;
  IF actor_school_id IS NULL OR NEW.school_id IS DISTINCT FROM actor_school_id THEN
    RAISE EXCEPTION 'Tenant no autorizado' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

-- 2. Asegurar roles de plataforma globales en platform_roles
INSERT INTO public.platform_roles (name, description)
VALUES 
  ('platform_owner', 'Propietario y creador de la plataforma'),
  ('platform_admin', 'Administrador global del sistema SaaS'),
  ('platform_support', 'Soporte técnico de la plataforma'),
  ('platform_finance', 'Gestión financiera y facturación de la plataforma'),
  ('platform_readonly', 'Auditor de plataforma')
ON CONFLICT (name) DO NOTHING;

-- 3. Aprovisionar y sincronizar superadministradores en user_platform_roles y profiles
DO $$
DECLARE
  v_owner_role_id uuid;
  v_admin_role_id uuid;
  v_superadmin_rec record;
BEGIN
  SELECT id INTO v_owner_role_id FROM public.platform_roles WHERE name = 'platform_owner';
  SELECT id INTO v_admin_role_id FROM public.platform_roles WHERE name = 'platform_admin';

  -- Asignar roles a todos los usuarios con rol superadmin en profiles
  IF v_owner_role_id IS NOT NULL THEN
    FOR v_superadmin_rec IN 
      SELECT id FROM public.profiles WHERE role = 'superadmin'
    LOOP
      INSERT INTO public.user_platform_roles (user_id, platform_role_id)
      VALUES (v_superadmin_rec.id, v_owner_role_id)
      ON CONFLICT DO NOTHING;

      IF v_admin_role_id IS NOT NULL THEN
        INSERT INTO public.user_platform_roles (user_id, platform_role_id)
        VALUES (v_superadmin_rec.id, v_admin_role_id)
        ON CONFLICT DO NOTHING;
      END IF;
    END LOOP;
  END IF;

  -- Promover específicamente a admin@webnotas.com si existe
  FOR v_superadmin_rec IN 
    SELECT id FROM public.profiles WHERE lower(email) = 'admin@webnotas.com'
  LOOP
    UPDATE public.profiles SET role = 'superadmin', is_active = true WHERE id = v_superadmin_rec.id;
    
    IF v_owner_role_id IS NOT NULL THEN
      INSERT INTO public.user_platform_roles (user_id, platform_role_id)
      VALUES (v_superadmin_rec.id, v_owner_role_id)
      ON CONFLICT DO NOTHING;
    END IF;

    IF v_admin_role_id IS NOT NULL THEN
      INSERT INTO public.user_platform_roles (user_id, platform_role_id)
      VALUES (v_superadmin_rec.id, v_admin_role_id)
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
END $$;

-- 4. Definición canónica y resiliente de is_platform_admin() (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.is_platform_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
  SELECT (SELECT auth.uid()) IS NOT NULL AND (
    EXISTS (
      SELECT 1
      FROM public.user_platform_roles upr
      JOIN public.platform_roles pr ON pr.id = upr.platform_role_id
      WHERE upr.user_id = (SELECT auth.uid())
        AND pr.name::text IN ('platform_owner', 'platform_admin', 'platform_support')
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role = 'superadmin'
        AND COALESCE(p.is_active, true)
    )
  );
$$;

-- 5. Definición canónica y resiliente de is_platform_owner() (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.is_platform_owner()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
  SELECT (SELECT auth.uid()) IS NOT NULL AND (
    EXISTS (
      SELECT 1
      FROM public.user_platform_roles upr
      JOIN public.platform_roles pr ON pr.id = upr.platform_role_id
      WHERE upr.user_id = (SELECT auth.uid())
        AND pr.name::text = 'platform_owner'
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role = 'superadmin'
        AND COALESCE(p.is_active, true)
    )
  );
$$;

-- 6. Definición canónica de get_user_school_id() (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
  SELECT COALESCE(
    (
      SELECT tm.school_id
      FROM public.tenant_memberships tm
      JOIN public.schools s ON s.id = tm.school_id
      WHERE tm.user_id = (SELECT auth.uid())
        AND tm.is_active
        AND COALESCE(s.is_active, true)
        AND s.status::text IN ('trial', 'active', 'past_due', 'grace_period')
      ORDER BY tm.created_at
      LIMIT 1
    ),
    (
      SELECT p.school_id
      FROM public.profiles p
      JOIN public.schools s ON s.id = p.school_id
      WHERE p.id = (SELECT auth.uid())
        AND COALESCE(p.is_active, true)
        AND COALESCE(s.is_active, true)
        AND s.status::text IN ('trial', 'active', 'past_due', 'grace_period')
      LIMIT 1
    )
  );
$$;

-- 7. Definición canónica de get_my_access_context() (SECURITY DEFINER)
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

-- 8. Concesión de permisos de ejecución sin restricciones de rol para funciones RPC básicas
GRANT EXECUTE ON FUNCTION public.get_my_access_context() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_platform_admin() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_platform_owner() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_user_school_id() TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.get_my_access_context() IS
  'Returns the authenticated user platform roles, active tenant memberships and granted permission codes.';

-- 9. Recargar caché de PostgREST
NOTIFY pgrst, 'reload schema';

COMMIT;
