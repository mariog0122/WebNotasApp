-- Create or update one course through an authorized tenant transaction.

create or replace function public.save_course_record(
  p_school_id uuid,
  p_course_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_existing public.courses;
  v_course public.courses;
  v_is_update boolean := false;
  v_name text;
  v_academic_year text;
  v_level text;
  v_track text;
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;
  if p_school_id is null or jsonb_typeof(p_payload) is distinct from 'object' then
    raise exception 'Datos del curso incompletos' using errcode = '22023';
  end if;

  v_name := nullif(trim(p_payload->>'name'), '');
  v_academic_year := nullif(trim(p_payload->>'academic_year'), '');
  v_level := nullif(trim(p_payload->>'level'), '');
  v_track := nullif(trim(p_payload->>'track'), '');
  if v_name is null or v_academic_year is null
    or length(v_name) > 150 or length(v_academic_year) > 30
    or length(coalesce(v_level, '')) > 50 or length(coalesce(v_track, '')) > 50 then
    raise exception 'Los datos del curso no son válidos' using errcode = '22023';
  end if;

  if p_course_id is not null then
    select * into v_existing from public.courses where id = p_course_id for update;
    v_is_update := found;
    if not v_is_update then
      raise exception 'Curso no encontrado' using errcode = 'P0002';
    end if;
    if v_existing.school_id is distinct from p_school_id then
      raise exception 'El curso pertenece a otra institución' using errcode = '42501';
    end if;
  end if;

  if not public.is_platform_admin() and (
    p_school_id is distinct from public.get_user_school_id()
    or (
      v_is_update
      and not public.has_tenant_permission('courses.update')
      and not public.has_tenant_permission('settings.manage')
    )
    or (
      not v_is_update
      and not public.has_tenant_permission('courses.create')
      and not public.has_tenant_permission('settings.manage')
    )
  ) then
    raise exception 'No tienes permiso para guardar cursos en esta institución' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.academic_years ay
    where ay.school_id = p_school_id and ay.name = v_academic_year
  ) then
    raise exception 'El año lectivo no pertenece a la institución' using errcode = '42501';
  end if;
  if not public.is_platform_admin()
    and not public.has_tenant_permission('academic_year.update')
    and exists (
      select 1 from public.academic_years ay
      where ay.school_id = p_school_id
        and ay.is_locked
        and (
          ay.name = v_academic_year
          or (v_is_update and ay.name = v_existing.academic_year)
        )
    ) then
    raise exception 'No se puede modificar un curso de un año lectivo bloqueado' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_school_id::text || ':courses', 0));
  if exists (
    select 1 from public.courses c
    where c.school_id = p_school_id
      and c.academic_year = v_academic_year
      and lower(trim(c.name)) = lower(v_name)
      and (not v_is_update or c.id <> p_course_id)
  ) then
    raise exception 'DUPLICATE_COURSE_NAME: Ya existe un curso con ese nombre en el año lectivo' using errcode = '23505';
  end if;

  if v_is_update then
    update public.courses
    set name = v_name,
        academic_year = v_academic_year,
        level = v_level,
        track = v_track
    where id = p_course_id and school_id = p_school_id
    returning * into v_course;
  else
    insert into public.courses(school_id, name, academic_year, level, track)
    values (p_school_id, v_name, v_academic_year, v_level, v_track)
    returning * into v_course;
  end if;

  if v_course.id is null or v_course.school_id is distinct from p_school_id
    or v_course.name is distinct from v_name or v_course.academic_year is distinct from v_academic_year then
    raise exception 'La base de datos no confirmó el guardado del curso';
  end if;

  insert into public.audit_log(school_id, user_id, action, table_name, record_id, new_values)
  values (
    p_school_id,
    auth.uid(),
    case when v_is_update then 'COURSE_UPDATED' else 'COURSE_CREATED' end,
    'courses',
    v_course.id::text,
    jsonb_build_object('name', v_name, 'academic_year', v_academic_year)
  );

  return jsonb_build_object(
    'success', true,
    'action', case when v_is_update then 'updated' else 'created' end,
    'course', to_jsonb(v_course)
  );
end;
$$;

revoke all on function public.save_course_record(uuid, uuid, jsonb) from public, anon;
grant execute on function public.save_course_record(uuid, uuid, jsonb) to authenticated, service_role;
revoke insert, update on public.courses from authenticated;
