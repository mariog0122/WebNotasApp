-- Rename grade-definition headers through the same server-side dimensions used by grading.

create or replace function public.rename_grade_definition(
  p_definition_id uuid,
  p_name text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_definition public.grade_definitions;
  v_course_subject public.course_subjects;
  v_course public.courses;
  v_name text := trim(p_name);
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;
  if p_definition_id is null or v_name is null or length(v_name) < 1 or length(v_name) > 100 then
    raise exception 'El nombre de la columna debe tener entre 1 y 100 caracteres' using errcode = '22023';
  end if;

  select gd.* into v_definition
  from public.grade_definitions gd
  join public.course_subjects cs
    on cs.id = gd.course_subject_id and cs.school_id = gd.school_id
  join public.courses c
    on c.id = cs.course_id and c.school_id = gd.school_id
  join public.quarters q
    on q.id = gd.quarter_id and q.school_id = gd.school_id
  where gd.id = p_definition_id
    and not coalesce(q.is_locked, false)
  for update of gd;
  if not found then
    raise exception 'La definición no existe, sus relaciones no son válidas o el período está bloqueado' using errcode = '42501';
  end if;

  select * into v_course_subject
  from public.course_subjects
  where id = v_definition.course_subject_id;
  select * into v_course
  from public.courses
  where id = v_course_subject.course_id;

  if not public.is_platform_admin() and (
    v_definition.school_id is distinct from public.get_user_school_id()
    or not public.has_tenant_permission('grades.update')
    or (
      not public.has_tenant_permission('settings.manage')
      and v_course_subject.teacher_id is distinct from auth.uid()
    )
  ) then
    raise exception 'No tienes permiso para renombrar esta columna' using errcode = '42501';
  end if;

  if exists (
    select 1 from public.academic_years ay
    where ay.school_id = v_definition.school_id
      and ay.name = v_course.academic_year
      and ay.is_locked
  ) and not public.is_platform_admin()
    and not public.has_tenant_permission('academic_year.update') then
    raise exception 'El año lectivo está bloqueado' using errcode = '42501';
  end if;

  update public.grade_definitions
  set name = v_name
  where id = p_definition_id and school_id = v_definition.school_id
  returning * into v_definition;

  if v_definition.id is distinct from p_definition_id or v_definition.name is distinct from v_name then
    raise exception 'La base de datos no confirmó el cambio de nombre';
  end if;

  insert into public.audit_log(school_id, user_id, action, table_name, record_id, new_values)
  values (
    v_definition.school_id,
    auth.uid(),
    'GRADE_DEFINITION_RENAMED',
    'grade_definitions',
    p_definition_id::text,
    jsonb_build_object('name', v_name, 'quarter_id', v_definition.quarter_id)
  );

  return jsonb_build_object(
    'success', true,
    'definition_id', v_definition.id,
    'name', v_definition.name,
    'school_id', v_definition.school_id
  );
end;
$$;

revoke all on function public.rename_grade_definition(uuid, text) from public, anon;
grant execute on function public.rename_grade_definition(uuid, text) to authenticated, service_role;
revoke update on public.grade_definitions from authenticated;
