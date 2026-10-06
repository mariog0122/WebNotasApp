-- Replace the project-subject configuration as one authorized transaction.

create or replace function public.save_project_settings_batch(
  p_course_id uuid,
  p_quarter_id uuid,
  p_subject_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_school_id uuid;
  v_academic_year text;
  v_requested integer := coalesce(cardinality(p_subject_ids), 0);
  v_valid integer := 0;
  v_previous integer := 0;
  v_inserted integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;
  if p_course_id is null or p_quarter_id is null or p_subject_ids is null or v_requested > 500 then
    raise exception 'Configuración de proyecto no válida' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(p_subject_ids) item(id) where item.id is null)
    or (select count(distinct item.id) from unnest(p_subject_ids) item(id)) <> v_requested then
    raise exception 'La configuración contiene materias repetidas o inválidas' using errcode = '23505';
  end if;

  select c.school_id, c.academic_year into v_school_id, v_academic_year
  from public.courses c
  join public.quarters q on q.id = p_quarter_id and q.school_id = c.school_id
  where c.id = p_course_id and not coalesce(q.is_locked, false)
  for share of c, q;
  if v_school_id is null then
    raise exception 'El curso o período no existe, pertenece a otra institución o está bloqueado' using errcode = '42501';
  end if;

  if not public.is_platform_admin() and (
    v_school_id is distinct from public.get_user_school_id()
    or not public.has_tenant_permission('grades.update')
  ) then
    raise exception 'No tienes permiso para configurar el proyecto' using errcode = '42501';
  end if;
  -- Use the same lock as project-grade writes before checking/removing subjects.
  perform pg_advisory_xact_lock(hashtextextended(
    v_school_id::text || ':project-grades:' || p_course_id::text || ':' || p_quarter_id::text, 0
  ));

  if exists (
    select 1 from public.academic_years ay
    where ay.school_id = v_school_id
      and ay.name = v_academic_year
      and ay.is_locked
  ) and not public.is_platform_admin()
    and not public.has_tenant_permission('academic_year.update') then
    raise exception 'El año lectivo está bloqueado' using errcode = '42501';
  end if;

  select count(*) into v_valid
  from public.course_subjects cs
  where cs.school_id = v_school_id
    and cs.course_id = p_course_id
    and cs.subject_id = any(p_subject_ids);
  if v_valid <> v_requested then
    raise exception 'La selección contiene una materia que no pertenece al curso' using errcode = '42501';
  end if;

  if not public.is_platform_admin()
    and not public.has_tenant_permission('settings.manage')
    and exists (
      select 1
      from (
        select ps.subject_id
        from public.project_settings ps
        where ps.course_id = p_course_id and ps.quarter_id = p_quarter_id
        union
        select item.id from unnest(p_subject_ids) item(id)
      ) affected
      where not exists (
        select 1 from public.course_subjects cs
        where cs.school_id = v_school_id
          and cs.course_id = p_course_id
          and cs.subject_id = affected.subject_id
          and cs.teacher_id = auth.uid()
      )
    ) then
    raise exception 'La configuración incluye una materia no asignada al docente' using errcode = '42501';
  end if;

  if exists (
    select 1
    from public.project_settings ps
    where ps.course_id = p_course_id
      and ps.quarter_id = p_quarter_id
      and not (ps.subject_id = any(p_subject_ids))
      and exists (
        select 1 from public.project_subject_grades pg
        where pg.course_id = p_course_id
          and pg.quarter_id = p_quarter_id
          and pg.subject_id = ps.subject_id
      )
  ) then
    raise exception 'Elimina primero las notas del proyecto antes de retirar la materia' using errcode = 'P0001';
  end if;

  select count(*) into v_previous
  from public.project_settings
  where course_id = p_course_id and quarter_id = p_quarter_id;

  delete from public.project_settings
  where course_id = p_course_id and quarter_id = p_quarter_id;

  insert into public.project_settings(course_id, quarter_id, subject_id)
  select p_course_id, p_quarter_id, item.id
  from unnest(p_subject_ids) item(id);
  get diagnostics v_inserted = row_count;
  if v_inserted <> v_requested then
    raise exception 'La base de datos no confirmó la configuración completa del proyecto';
  end if;

  insert into public.audit_log(school_id, user_id, action, table_name, record_id, new_values)
  values (
    v_school_id,
    auth.uid(),
    'PROJECT_SETTINGS_REPLACED',
    'project_settings',
    p_course_id::text,
    jsonb_build_object(
      'quarter_id', p_quarter_id,
      'previous_count', v_previous,
      'selected_count', v_inserted
    )
  );

  return jsonb_build_object(
    'success', true,
    'course_id', p_course_id,
    'quarter_id', p_quarter_id,
    'previous_count', v_previous,
    'selected_count', v_inserted
  );
end;
$$;

revoke all on function public.save_project_settings_batch(uuid, uuid, uuid[]) from public, anon;
grant execute on function public.save_project_settings_batch(uuid, uuid, uuid[]) to authenticated, service_role;
