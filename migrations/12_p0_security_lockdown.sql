-- P0: cierre de exposición anónima, aislamiento multi-tenant y mínimo privilegio.
-- Esta migración está diseñada para el esquema activo del 2026-08-08.

BEGIN;

-- Una política permisiva antigua se combina con OR. Se eliminan todas antes de
-- crear la matriz autorizada para evitar que sobreviva una vía de acceso pública.
DO $$
DECLARE
  policy_row record;
  table_row record;
BEGIN
  FOR table_row IN
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_row.table_name);
  END LOOP;

  FOR policy_row IN
    SELECT tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', policy_row.policyname, policy_row.tablename);
  END LOOP;
END
$$;

CREATE OR REPLACE FUNCTION public.is_platform_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT (SELECT auth.uid()) IS NOT NULL AND (
    EXISTS (
      SELECT 1
      FROM public.user_platform_roles upr
      JOIN public.platform_roles pr ON pr.id = upr.platform_role_id
      WHERE upr.user_id = (SELECT auth.uid())
        AND pr.name::text IN ('platform_owner', 'platform_admin')
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.role = 'superadmin'
        AND COALESCE(p.is_active, true)
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.is_platform_owner()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_platform_roles upr
    JOIN public.platform_roles pr ON pr.id = upr.platform_role_id
    WHERE upr.user_id = (SELECT auth.uid())
      AND pr.name::text = 'platform_owner'
  );
$$;

CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
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

CREATE OR REPLACE FUNCTION public.is_active_tenant_member(target_school_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT public.is_platform_admin()
    OR (target_school_id IS NOT NULL AND target_school_id = public.get_user_school_id());
$$;

CREATE OR REPLACE FUNCTION public.has_tenant_permission(perm_code text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT public.is_platform_admin() OR EXISTS (
    SELECT 1
    FROM public.tenant_memberships tm
    JOIN public.schools s ON s.id = tm.school_id
    JOIN public.role_permissions rp ON rp.tenant_role_id = tm.tenant_role_id
    JOIN public.permissions p ON p.id = rp.permission_id
    WHERE tm.user_id = (SELECT auth.uid())
      AND tm.school_id = public.get_user_school_id()
      AND tm.is_active
      AND COALESCE(s.is_active, true)
      AND s.status::text IN ('trial', 'active', 'past_due', 'grace_period')
      AND p.code = perm_code
  );
$$;

CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT p.role FROM public.profiles p WHERE p.id = (SELECT auth.uid());
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT public.is_platform_admin() OR public.has_tenant_permission('users.manage');
$$;

CREATE OR REPLACE FUNCTION public.is_superadmin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$ SELECT public.is_platform_admin(); $$;

CREATE OR REPLACE FUNCTION public.is_teacher()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT public.has_tenant_permission('grades.create');
$$;

CREATE OR REPLACE FUNCTION public.can_access_student(target_student_id uuid, permission_code text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT public.is_platform_admin() OR (
    public.has_tenant_permission(permission_code)
    AND EXISTS (
      SELECT 1 FROM public.students s
      WHERE s.id = target_student_id
        AND s.school_id = public.get_user_school_id()
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.can_access_course(target_course_id uuid, permission_code text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT public.is_platform_admin() OR (
    public.has_tenant_permission(permission_code)
    AND EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = target_course_id
        AND c.school_id = public.get_user_school_id()
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.can_manage_academic_score(
  target_student_id uuid,
  target_course_subject_id uuid,
  target_quarter_id uuid,
  permission_code text DEFAULT 'grades.update'
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT public.is_platform_admin() OR (
    public.has_tenant_permission(permission_code)
    AND EXISTS (
      SELECT 1
      FROM public.students st
      JOIN public.course_subjects cs
        ON cs.id = target_course_subject_id
       AND cs.course_id = st.course_id
       AND cs.school_id = st.school_id
      JOIN public.quarters q
        ON q.id = target_quarter_id
       AND q.school_id = st.school_id
      WHERE st.id = target_student_id
        AND st.school_id = public.get_user_school_id()
        AND COALESCE(q.is_locked, false) = false
        AND (
          public.has_tenant_permission('settings.manage')
          OR cs.teacher_id = (SELECT auth.uid())
        )
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.can_manage_grade(
  target_student_id uuid,
  target_course_subject_id uuid,
  target_grade_definition_id uuid,
  target_quarter_id uuid,
  permission_code text DEFAULT 'grades.update'
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT public.is_platform_admin() OR EXISTS (
    SELECT 1
    FROM public.grade_definitions gd
    WHERE gd.id = target_grade_definition_id
      AND gd.course_subject_id = target_course_subject_id
      AND gd.quarter_id = target_quarter_id
      AND gd.school_id = public.get_user_school_id()
      AND public.can_manage_academic_score(
        target_student_id,
        target_course_subject_id,
        target_quarter_id,
        permission_code
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.can_manage_project_score(
  target_student_id uuid,
  target_course_id uuid,
  target_subject_id uuid,
  target_quarter_id uuid,
  permission_code text DEFAULT 'grades.update'
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT public.is_platform_admin() OR (
    public.has_tenant_permission(permission_code)
    AND EXISTS (
      SELECT 1
      FROM public.students st
      JOIN public.courses c ON c.id = target_course_id AND c.id = st.course_id
      JOIN public.quarters q ON q.id = target_quarter_id AND q.school_id = c.school_id
      WHERE st.id = target_student_id
        AND c.school_id = public.get_user_school_id()
        AND COALESCE(q.is_locked, false) = false
        AND (
          public.has_tenant_permission('settings.manage')
          OR EXISTS (
            SELECT 1 FROM public.course_subjects cs
            WHERE cs.course_id = c.id
              AND cs.subject_id = target_subject_id
              AND cs.teacher_id = (SELECT auth.uid())
              AND cs.school_id = c.school_id
          )
        )
    )
  );
$$;

-- El trigger completa el tenant, pero jamás puede sustituir un school_id explícito
-- de una operación de plataforma ni aceptar un tenant ajeno.
CREATE OR REPLACE FUNCTION public.set_school_id_from_auth()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  actor_school_id uuid := public.get_user_school_id();
BEGIN
  IF NEW.school_id IS NULL THEN
    NEW.school_id := actor_school_id;
  END IF;
  IF NOT public.is_platform_admin()
     AND (actor_school_id IS NULL OR NEW.school_id IS DISTINCT FROM actor_school_id) THEN
    RAISE EXCEPTION 'Tenant no autorizado' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.protect_profile_authorization_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
BEGIN
  IF public.is_platform_admin() THEN
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

DROP TRIGGER IF EXISTS protect_profile_authorization_fields ON public.profiles;
CREATE TRIGGER protect_profile_authorization_fields
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.protect_profile_authorization_fields();

-- Copia de cursos limitada al tenant del actor y con school_id explícito.
CREATE OR REPLACE FUNCTION public.copy_courses_to_academic_year(
  source_year_id uuid,
  target_year_id uuid,
  include_subjects boolean DEFAULT true
)
RETURNS TABLE(new_course_id uuid, original_course_id uuid, course_name text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  source_year public.academic_years;
  target_year public.academic_years;
  source_course record;
  created_course_id uuid;
  actor_school_id uuid := public.get_user_school_id();
BEGIN
  IF actor_school_id IS NULL OR NOT public.has_tenant_permission('settings.manage') THEN
    RAISE EXCEPTION 'Acceso denegado' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO source_year FROM public.academic_years WHERE id = source_year_id;
  SELECT * INTO target_year FROM public.academic_years WHERE id = target_year_id;
  IF source_year.id IS NULL OR target_year.id IS NULL THEN
    RAISE EXCEPTION 'Año lectivo no encontrado';
  END IF;

  FOR source_course IN
    SELECT c.* FROM public.courses c
    WHERE c.academic_year = source_year.name AND c.school_id = actor_school_id
  LOOP
    INSERT INTO public.courses (name, academic_year, level, track, school_id)
    VALUES (source_course.name, target_year.name, source_course.level, source_course.track, actor_school_id)
    RETURNING id INTO created_course_id;

    IF include_subjects THEN
      INSERT INTO public.course_subjects (course_id, subject_id, teacher_id, school_id)
      SELECT created_course_id, cs.subject_id, NULL, actor_school_id
      FROM public.course_subjects cs
      WHERE cs.course_id = source_course.id AND cs.school_id = actor_school_id;
    END IF;

    new_course_id := created_course_id;
    original_course_id := source_course.id;
    course_name := source_course.name;
    RETURN NEXT;
  END LOOP;
END;
$$;

-- Fija search_path en las funciones de privilegio que se mantienen disponibles.
ALTER FUNCTION public.provision_tenant_wizard(text,text,text,text,text,text,text,text,text,text,uuid,text,numeric)
  SET search_path = pg_catalog, public, auth;
ALTER FUNCTION public.invite_teacher_by_email(text)
  SET search_path = pg_catalog, public, auth;
ALTER FUNCTION public.get_academic_years_list()
  SET search_path = pg_catalog, public, auth;
ALTER FUNCTION public.get_current_academic_year()
  SET search_path = pg_catalog, public, auth;
ALTER FUNCTION public.start_impersonation_session(uuid,text)
  SET search_path = pg_catalog, public, auth;
ALTER FUNCTION public.stop_impersonation_session(uuid)
  SET search_path = pg_catalog, public, auth;

-- Matriz de políticas. Una sola política por tabla/operación evita OR inesperados.
CREATE POLICY schools_select ON public.schools FOR SELECT TO authenticated
USING (public.is_platform_admin() OR id = public.get_user_school_id());
CREATE POLICY schools_insert ON public.schools FOR INSERT TO authenticated
WITH CHECK (public.is_platform_admin());
CREATE POLICY schools_update ON public.schools FOR UPDATE TO authenticated
USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());
CREATE POLICY schools_delete ON public.schools FOR DELETE TO authenticated
USING (public.is_platform_owner());

CREATE POLICY profiles_select ON public.profiles FOR SELECT TO authenticated
USING (
  public.is_platform_admin()
  OR id = (SELECT auth.uid())
  OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('users.read'))
);
CREATE POLICY profiles_update ON public.profiles FOR UPDATE TO authenticated
USING (
  public.is_platform_admin()
  OR id = (SELECT auth.uid())
  OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('users.manage'))
)
WITH CHECK (
  public.is_platform_admin()
  OR (id = (SELECT auth.uid()) AND school_id = public.get_user_school_id())
  OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('users.manage') AND role <> 'superadmin')
);

DO $$
DECLARE
  target_table text;
BEGIN
  FOREACH target_table IN ARRAY ARRAY['platform_roles','tenant_roles','permissions','role_permissions','plans']
  LOOP
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING ((SELECT auth.uid()) IS NOT NULL)',
      target_table || '_select', target_table
    );
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR INSERT TO authenticated WITH CHECK (public.is_platform_admin())',
      target_table || '_insert', target_table
    );
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR UPDATE TO authenticated USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin())',
      target_table || '_update', target_table
    );
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR DELETE TO authenticated USING (public.is_platform_owner())',
      target_table || '_delete', target_table
    );
  END LOOP;
END
$$;

CREATE POLICY user_platform_roles_select ON public.user_platform_roles FOR SELECT TO authenticated
USING (public.is_platform_admin() OR user_id = (SELECT auth.uid()));
CREATE POLICY user_platform_roles_insert ON public.user_platform_roles FOR INSERT TO authenticated
WITH CHECK (public.is_platform_owner());
CREATE POLICY user_platform_roles_update ON public.user_platform_roles FOR UPDATE TO authenticated
USING (public.is_platform_owner()) WITH CHECK (public.is_platform_owner());
CREATE POLICY user_platform_roles_delete ON public.user_platform_roles FOR DELETE TO authenticated
USING (public.is_platform_owner());

CREATE POLICY tenant_memberships_select ON public.tenant_memberships FOR SELECT TO authenticated
USING (
  public.is_platform_admin()
  OR user_id = (SELECT auth.uid())
  OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('users.read'))
);
CREATE POLICY tenant_memberships_insert ON public.tenant_memberships FOR INSERT TO authenticated
WITH CHECK (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('users.manage')));
CREATE POLICY tenant_memberships_update ON public.tenant_memberships FOR UPDATE TO authenticated
USING (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('users.manage')))
WITH CHECK (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('users.manage')));
CREATE POLICY tenant_memberships_delete ON public.tenant_memberships FOR DELETE TO authenticated
USING (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('users.manage')));

DO $$
DECLARE
  target_table text;
BEGIN
  FOREACH target_table IN ARRAY ARRAY['tenant_status_logs','subscriptions','payments']
  LOOP
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission(''billing.read'')))',
      target_table || '_select', target_table
    );
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR INSERT TO authenticated WITH CHECK (public.is_platform_admin())',
      target_table || '_insert', target_table
    );
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR UPDATE TO authenticated USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin())',
      target_table || '_update', target_table
    );
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR DELETE TO authenticated USING (public.is_platform_owner())',
      target_table || '_delete', target_table
    );
  END LOOP;
END
$$;

CREATE POLICY audit_log_select ON public.audit_log FOR SELECT TO authenticated
USING (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('settings.read')));
CREATE POLICY impersonation_logs_select ON public.impersonation_logs FOR SELECT TO authenticated
USING (public.is_platform_admin());

CREATE POLICY academic_years_select ON public.academic_years FOR SELECT TO authenticated
USING ((SELECT auth.uid()) IS NOT NULL);
CREATE POLICY academic_years_insert ON public.academic_years FOR INSERT TO authenticated
WITH CHECK (public.is_platform_admin());
CREATE POLICY academic_years_update ON public.academic_years FOR UPDATE TO authenticated
USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());
CREATE POLICY academic_years_delete ON public.academic_years FOR DELETE TO authenticated
USING (public.is_platform_owner());

DO $$
DECLARE
  target_table text;
BEGIN
  FOREACH target_table IN ARRAY ARRAY['courses','subjects','quarters','course_subjects','grade_definitions','system_config']
  LOOP
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (public.is_active_tenant_member(school_id))',
      target_table || '_select', target_table
    );
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR INSERT TO authenticated WITH CHECK (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission(''settings.manage'')))',
      target_table || '_insert', target_table
    );
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR UPDATE TO authenticated USING (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission(''settings.manage''))) WITH CHECK (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission(''settings.manage'')))',
      target_table || '_update', target_table
    );
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR DELETE TO authenticated USING (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission(''settings.manage'')))',
      target_table || '_delete', target_table
    );
  END LOOP;
END
$$;

CREATE POLICY students_select ON public.students FOR SELECT TO authenticated
USING (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('students.read')));
CREATE POLICY students_insert ON public.students FOR INSERT TO authenticated
WITH CHECK (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('students.create')));
CREATE POLICY students_update ON public.students FOR UPDATE TO authenticated
USING (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('students.update')))
WITH CHECK (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('students.update')));
CREATE POLICY students_delete ON public.students FOR DELETE TO authenticated
USING (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('students.delete')));

CREATE POLICY grades_select ON public.grades FOR SELECT TO authenticated
USING (public.can_access_student(student_id, 'grades.read'));
CREATE POLICY grades_insert ON public.grades FOR INSERT TO authenticated
WITH CHECK (public.can_manage_grade(student_id, course_subject_id, grade_definition_id, quarter_id, 'grades.create'));
CREATE POLICY grades_update ON public.grades FOR UPDATE TO authenticated
USING (public.can_manage_grade(student_id, course_subject_id, grade_definition_id, quarter_id, 'grades.update'))
WITH CHECK (public.can_manage_grade(student_id, course_subject_id, grade_definition_id, quarter_id, 'grades.update'));
CREATE POLICY grades_delete ON public.grades FOR DELETE TO authenticated
USING (public.can_manage_grade(student_id, course_subject_id, grade_definition_id, quarter_id, 'grades.update'));

CREATE POLICY qualitative_grades_select ON public.qualitative_grades FOR SELECT TO authenticated
USING (public.can_access_student(student_id, 'grades.read'));
CREATE POLICY qualitative_grades_insert ON public.qualitative_grades FOR INSERT TO authenticated
WITH CHECK (public.can_manage_academic_score(student_id, course_subject_id, quarter_id, 'grades.create'));
CREATE POLICY qualitative_grades_update ON public.qualitative_grades FOR UPDATE TO authenticated
USING (public.can_manage_academic_score(student_id, course_subject_id, quarter_id, 'grades.update'))
WITH CHECK (public.can_manage_academic_score(student_id, course_subject_id, quarter_id, 'grades.update'));
CREATE POLICY qualitative_grades_delete ON public.qualitative_grades FOR DELETE TO authenticated
USING (public.can_manage_academic_score(student_id, course_subject_id, quarter_id, 'grades.update'));

CREATE POLICY supplementary_exams_select ON public.supplementary_exams FOR SELECT TO authenticated
USING (public.can_access_student(student_id, 'grades.read'));
CREATE POLICY supplementary_exams_insert ON public.supplementary_exams FOR INSERT TO authenticated
WITH CHECK (public.can_manage_academic_score(student_id, course_subject_id, (SELECT q.id FROM public.quarters q WHERE q.school_id = public.get_user_school_id() AND q.is_active LIMIT 1), 'grades.create'));
CREATE POLICY supplementary_exams_update ON public.supplementary_exams FOR UPDATE TO authenticated
USING (public.is_platform_admin() OR (public.can_access_student(student_id, 'grades.update') AND public.has_tenant_permission('settings.manage')))
WITH CHECK (public.is_platform_admin() OR (public.can_access_student(student_id, 'grades.update') AND public.has_tenant_permission('settings.manage')));
CREATE POLICY supplementary_exams_delete ON public.supplementary_exams FOR DELETE TO authenticated
USING (public.is_platform_admin() OR (public.can_access_student(student_id, 'grades.update') AND public.has_tenant_permission('settings.manage')));

CREATE POLICY project_settings_select ON public.project_settings FOR SELECT TO authenticated
USING (public.can_access_course(course_id, 'grades.read'));
CREATE POLICY project_settings_insert ON public.project_settings FOR INSERT TO authenticated
WITH CHECK (public.can_access_course(course_id, 'settings.manage'));
CREATE POLICY project_settings_update ON public.project_settings FOR UPDATE TO authenticated
USING (public.can_access_course(course_id, 'settings.manage')) WITH CHECK (public.can_access_course(course_id, 'settings.manage'));
CREATE POLICY project_settings_delete ON public.project_settings FOR DELETE TO authenticated
USING (public.can_access_course(course_id, 'settings.manage'));

CREATE POLICY project_subject_grades_select ON public.project_subject_grades FOR SELECT TO authenticated
USING (public.can_access_student(student_id, 'grades.read'));
CREATE POLICY project_subject_grades_insert ON public.project_subject_grades FOR INSERT TO authenticated
WITH CHECK (public.can_manage_project_score(student_id, course_id, subject_id, quarter_id, 'grades.create'));
CREATE POLICY project_subject_grades_update ON public.project_subject_grades FOR UPDATE TO authenticated
USING (public.can_manage_project_score(student_id, course_id, subject_id, quarter_id, 'grades.update'))
WITH CHECK (public.can_manage_project_score(student_id, course_id, subject_id, quarter_id, 'grades.update'));
CREATE POLICY project_subject_grades_delete ON public.project_subject_grades FOR DELETE TO authenticated
USING (public.can_manage_project_score(student_id, course_id, subject_id, quarter_id, 'grades.update'));

CREATE POLICY project_grades_select ON public.project_grades FOR SELECT TO authenticated
USING (public.can_access_student(student_id, 'grades.read'));
CREATE POLICY project_grades_insert ON public.project_grades FOR INSERT TO authenticated
WITH CHECK (public.can_manage_project_score(student_id, course_id, NULL, quarter_id, 'grades.create'));
CREATE POLICY project_grades_update ON public.project_grades FOR UPDATE TO authenticated
USING (public.can_manage_project_score(student_id, course_id, NULL, quarter_id, 'grades.update'))
WITH CHECK (public.can_manage_project_score(student_id, course_id, NULL, quarter_id, 'grades.update'));
CREATE POLICY project_grades_delete ON public.project_grades FOR DELETE TO authenticated
USING (public.can_manage_project_score(student_id, course_id, NULL, quarter_id, 'grades.update'));

CREATE POLICY student_alerts_select ON public.student_alerts FOR SELECT TO authenticated
USING (public.is_active_tenant_member(school_id));
CREATE POLICY student_alerts_insert ON public.student_alerts FOR INSERT TO authenticated
WITH CHECK (
  public.is_active_tenant_member(school_id)
  AND student_id IS NOT NULL
  AND public.can_access_student(student_id, 'students.read')
  AND (reported_by IS NULL OR reported_by = (SELECT auth.uid()) OR public.is_platform_admin())
);
CREATE POLICY student_alerts_update ON public.student_alerts FOR UPDATE TO authenticated
USING (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('users.manage')))
WITH CHECK (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('users.manage')));
CREATE POLICY student_alerts_delete ON public.student_alerts FOR DELETE TO authenticated
USING (public.is_platform_admin() OR (school_id = public.get_user_school_id() AND public.has_tenant_permission('settings.manage')));

-- Storage privado. Se admiten rutas nuevas con prefijo de tenant y rutas antiguas
-- únicamente cuando ya están referenciadas por una fila del tenant actual.
CREATE OR REPLACE FUNCTION public.can_access_private_object(object_bucket text, object_name text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, storage
AS $$
  SELECT public.is_platform_admin() OR CASE
    WHEN object_bucket = 'profile-photos' THEN
      (storage.foldername(object_name))[1] = (SELECT auth.uid())::text
    WHEN object_bucket = 'student-photos' THEN
      (storage.foldername(object_name))[1] = public.get_user_school_id()::text
      OR EXISTS (
        SELECT 1 FROM public.students st
        WHERE st.school_id = public.get_user_school_id()
          AND (
            right(COALESCE(st.student_photo_url, ''), length(object_name)) = object_name
            OR right(COALESCE(st.representative_photo_url, ''), length(object_name)) = object_name
          )
      )
    WHEN object_bucket = 'institution-assets' THEN
      (storage.foldername(object_name))[1] = public.get_user_school_id()::text
      OR EXISTS (
        SELECT 1 FROM public.system_config cfg
        WHERE cfg.school_id = public.get_user_school_id()
          AND cfg.key = 'institution_logo_url'
          AND right(COALESCE(cfg.value, ''), length(object_name)) = object_name
      )
    ELSE false
  END;
$$;

UPDATE storage.buckets
SET public = false
WHERE id IN ('institution-assets', 'student-photos', 'profile-photos');

DO $$
DECLARE
  policy_row record;
BEGIN
  FOR policy_row IN
    SELECT policyname FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', policy_row.policyname);
  END LOOP;
END
$$;

CREATE POLICY private_objects_select ON storage.objects FOR SELECT TO authenticated
USING (public.can_access_private_object(bucket_id, name));
CREATE POLICY private_objects_insert ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  (bucket_id = 'profile-photos' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text)
  OR (
    bucket_id = 'student-photos'
    AND (storage.foldername(name))[1] = public.get_user_school_id()::text
    AND public.has_tenant_permission('students.update')
  )
  OR (
    bucket_id = 'institution-assets'
    AND (storage.foldername(name))[1] = public.get_user_school_id()::text
    AND public.has_tenant_permission('settings.manage')
  )
);
CREATE POLICY private_objects_update ON storage.objects FOR UPDATE TO authenticated
USING (public.can_access_private_object(bucket_id, name))
WITH CHECK (
  (bucket_id = 'profile-photos' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text)
  OR (
    bucket_id = 'student-photos'
    AND (storage.foldername(name))[1] = public.get_user_school_id()::text
    AND public.has_tenant_permission('students.update')
  )
  OR (
    bucket_id = 'institution-assets'
    AND (storage.foldername(name))[1] = public.get_user_school_id()::text
    AND public.has_tenant_permission('settings.manage')
  )
);
CREATE POLICY private_objects_delete ON storage.objects FOR DELETE TO authenticated
USING (
  (bucket_id = 'profile-photos' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text)
  OR (
    bucket_id = 'student-photos'
    AND public.can_access_private_object(bucket_id, name)
    AND public.has_tenant_permission('students.update')
  )
  OR (
    bucket_id = 'institution-assets'
    AND public.can_access_private_object(bucket_id, name)
    AND public.has_tenant_permission('settings.manage')
  )
);

-- Ninguna función pública se hereda por PUBLIC o anon. Se reabren sólo helpers/RPC
-- indispensables para usuarios autenticados; las funciones de suplantación quedan cerradas.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_platform_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_platform_owner() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_school_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_active_tenant_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_tenant_permission(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_superadmin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_teacher() TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_access_student(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_access_course(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_manage_academic_score(uuid,uuid,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_manage_grade(uuid,uuid,uuid,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_manage_project_score(uuid,uuid,uuid,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_access_private_object(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_academic_years_list() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_academic_year() TO authenticated;
GRANT EXECUTE ON FUNCTION public.invite_teacher_by_email(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.provision_tenant_wizard(text,text,text,text,text,text,text,text,text,text,uuid,text,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.copy_courses_to_academic_year(uuid,uuid,boolean) TO authenticated;

COMMIT;
