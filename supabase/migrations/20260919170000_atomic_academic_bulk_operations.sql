-- Make student imports and destructive academic bulk operations transactional.

create or replace function public.import_students_batch(
  p_course_id uuid,
  p_entries jsonb
)
returns json
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_course public.courses;
  v_school_id uuid;
  v_entry_count integer;
  v_new_count integer;
  v_current_count integer;
  v_limit integer;
  v_inserted integer := 0;
  v_updated integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;
  if jsonb_typeof(p_entries) is distinct from 'array' then
    raise exception 'Lote de estudiantes no válido' using errcode = '22023';
  end if;

  v_entry_count := jsonb_array_length(p_entries);
  if v_entry_count < 1 or v_entry_count > 5000 then
    raise exception 'El lote debe contener entre 1 y 5000 estudiantes' using errcode = '22023';
  end if;

  select c.* into v_course
  from public.courses c
  where c.id = p_course_id
  for share;
  if not found then
    raise exception 'Curso no encontrado' using errcode = 'P0002';
  end if;
  v_school_id := v_course.school_id;

  if not public.is_platform_admin() and (
    v_school_id is distinct from public.get_user_school_id()
    or not public.has_tenant_permission('students.create')
    or not public.has_tenant_permission('students.update')
  ) then
    raise exception 'No tienes permiso para importar estudiantes en este curso' using errcode = '42501';
  end if;

  if exists (
    select 1
    from public.academic_years ay
    where ay.school_id = v_school_id
      and ay.name = v_course.academic_year
      and ay.is_locked
  ) and not public.is_platform_admin()
    and not public.has_tenant_permission('academic_year.update') then
    raise exception 'El año lectivo está bloqueado' using errcode = '42501';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_entries) as x(
      full_name text,
      student_cedula text,
      student_birthdate date,
      student_phone text,
      student_address text,
      representative_name text,
      representative_cedula text,
      representative_phone text,
      representative_alt_phone text
    )
    where nullif(trim(x.full_name), '') is null
      or length(trim(x.full_name)) > 200
      or length(coalesce(trim(x.student_cedula), '')) > 30
      or length(coalesce(trim(x.student_phone), '')) > 30
      or length(coalesce(trim(x.student_address), '')) > 500
      or length(coalesce(trim(x.representative_name), '')) > 200
      or length(coalesce(trim(x.representative_cedula), '')) > 30
      or length(coalesce(trim(x.representative_phone), '')) > 30
      or length(coalesce(trim(x.representative_alt_phone), '')) > 30
  ) then
    raise exception 'Una fila contiene datos faltantes o demasiado extensos' using errcode = '22023';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_entries) as x(full_name text, student_cedula text)
    where nullif(trim(x.student_cedula), '') is not null
    group by trim(x.student_cedula)
    having count(*) > 1
  ) then
    raise exception 'El archivo contiene cédulas de estudiante repetidas' using errcode = '23505';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_school_id::text, 0));

  select count(*) into v_new_count
  from jsonb_to_recordset(p_entries) as x(full_name text, student_cedula text)
  where nullif(trim(x.student_cedula), '') is null
     or not exists (
       select 1
       from public.students s
       where s.school_id = v_school_id
         and s.course_id = p_course_id
         and s.student_cedula = trim(x.student_cedula)
     );

  select count(*) into v_current_count
  from public.students
  where school_id = v_school_id;

  select max_students into v_limit
  from public.tenant_limits
  where school_id = v_school_id;
  if v_limit is null then
    raise exception 'La institución no tiene un límite de estudiantes configurado' using errcode = 'P0001';
  end if;
  if v_current_count + v_new_count > v_limit then
    raise exception 'Límite de estudiantes alcanzado: actuales %, nuevos %, límite %',
      v_current_count, v_new_count, v_limit using errcode = 'P0001';
  end if;

  with input as (
    select
      trim(x.full_name) as full_name,
      nullif(trim(x.student_cedula), '') as student_cedula,
      x.student_birthdate,
      nullif(trim(x.student_phone), '') as student_phone,
      nullif(trim(x.student_address), '') as student_address,
      nullif(trim(x.representative_name), '') as representative_name,
      nullif(trim(x.representative_cedula), '') as representative_cedula,
      nullif(trim(x.representative_phone), '') as representative_phone,
      nullif(trim(x.representative_alt_phone), '') as representative_alt_phone
    from jsonb_to_recordset(p_entries) as x(
      full_name text,
      student_cedula text,
      student_birthdate date,
      student_phone text,
      student_address text,
      representative_name text,
      representative_cedula text,
      representative_phone text,
      representative_alt_phone text
    )
  )
  update public.students s
  set full_name = i.full_name,
      student_birthdate = i.student_birthdate,
      student_phone = i.student_phone,
      student_address = i.student_address,
      representative_name = i.representative_name,
      representative_cedula = i.representative_cedula,
      representative_phone = i.representative_phone,
      representative_alt_phone = i.representative_alt_phone
  from input i
  where s.school_id = v_school_id
    and s.course_id = p_course_id
    and i.student_cedula is not null
    and s.student_cedula = i.student_cedula;
  get diagnostics v_updated = row_count;

  with input as (
    select
      trim(x.full_name) as full_name,
      nullif(trim(x.student_cedula), '') as student_cedula,
      x.student_birthdate,
      nullif(trim(x.student_phone), '') as student_phone,
      nullif(trim(x.student_address), '') as student_address,
      nullif(trim(x.representative_name), '') as representative_name,
      nullif(trim(x.representative_cedula), '') as representative_cedula,
      nullif(trim(x.representative_phone), '') as representative_phone,
      nullif(trim(x.representative_alt_phone), '') as representative_alt_phone
    from jsonb_to_recordset(p_entries) as x(
      full_name text,
      student_cedula text,
      student_birthdate date,
      student_phone text,
      student_address text,
      representative_name text,
      representative_cedula text,
      representative_phone text,
      representative_alt_phone text
    )
  )
  insert into public.students (
    full_name,
    student_cedula,
    student_birthdate,
    student_phone,
    student_address,
    representative_name,
    representative_cedula,
    representative_phone,
    representative_alt_phone,
    course_id,
    school_id,
    created_by
  )
  select
    i.full_name,
    i.student_cedula,
    i.student_birthdate,
    i.student_phone,
    i.student_address,
    i.representative_name,
    i.representative_cedula,
    i.representative_phone,
    i.representative_alt_phone,
    p_course_id,
    v_school_id,
    auth.uid()
  from input i
  where i.student_cedula is null
     or not exists (
       select 1
       from public.students s
       where s.school_id = v_school_id
         and s.course_id = p_course_id
         and s.student_cedula = i.student_cedula
     );
  get diagnostics v_inserted = row_count;

  insert into public.audit_log(school_id, user_id, action, table_name, record_id, new_values)
  values (
    v_school_id,
    auth.uid(),
    'STUDENTS_IMPORTED',
    'students',
    p_course_id::text,
    jsonb_build_object('inserted', v_inserted, 'updated', v_updated, 'total', v_entry_count)
  );

  return json_build_object(
    'success', true,
    'inserted', v_inserted,
    'updated', v_updated,
    'total', v_entry_count
  );
end;
$$;

create or replace function public.delete_students_batch(
  p_school_id uuid,
  p_student_ids uuid[],
  p_delete_all boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_requested integer := coalesce(cardinality(p_student_ids), 0);
  v_target_count integer := 0;
  v_deleted integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;
  if p_school_id is null or p_delete_all is null then
    raise exception 'Datos de eliminación incompletos' using errcode = '22023';
  end if;
  if not p_delete_all and (p_student_ids is null or v_requested < 1) then
    raise exception 'Selecciona al menos un estudiante' using errcode = '22023';
  end if;
  if v_requested > 5000 then
    raise exception 'El lote supera 5000 estudiantes' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(coalesce(p_student_ids, '{}'::uuid[])) item(id) where item.id is null) then
    raise exception 'Identificador de estudiante no válido' using errcode = '22023';
  end if;

  if not public.is_platform_admin() and (
    p_school_id is distinct from public.get_user_school_id()
    or not public.has_tenant_permission('students.delete')
  ) then
    raise exception 'No tienes permiso para eliminar estudiantes de esta institución' using errcode = '42501';
  end if;

  if not p_delete_all and (
    select count(distinct s.id)
    from public.students s
    where s.school_id = p_school_id and s.id = any(p_student_ids)
  ) <> (
    select count(distinct item.id)
    from unnest(p_student_ids) item(id)
  ) then
    raise exception 'La selección contiene estudiantes inexistentes o de otra institución' using errcode = '42501';
  end if;

  if not public.is_platform_admin()
    and not public.has_tenant_permission('academic_year.update')
    and exists (
      select 1
      from public.students s
      join public.courses c on c.id = s.course_id and c.school_id = s.school_id
      join public.academic_years ay on ay.school_id = c.school_id and ay.name = c.academic_year
      where s.school_id = p_school_id
        and (p_delete_all or s.id = any(p_student_ids))
        and ay.is_locked
    ) then
    raise exception 'La selección incluye estudiantes de un año lectivo bloqueado' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_school_id::text || ':students-delete', 0));

  select count(*) into v_target_count
  from public.students s
  where s.school_id = p_school_id
    and (p_delete_all or s.id = any(p_student_ids));

  delete from public.students s
  where s.school_id = p_school_id
    and (p_delete_all or s.id = any(p_student_ids));
  get diagnostics v_deleted = row_count;

  if v_deleted <> v_target_count then
    raise exception 'La base de datos no eliminó todos los estudiantes solicitados';
  end if;

  insert into public.audit_log(school_id, user_id, action, table_name, new_values)
  values (
    p_school_id,
    auth.uid(),
    case when p_delete_all then 'ALL_STUDENTS_DELETED' else 'STUDENTS_BATCH_DELETED' end,
    'students',
    jsonb_build_object('requested', v_requested, 'deleted', v_deleted, 'delete_all', p_delete_all)
  );

  return jsonb_build_object('success', true, 'deleted_count', v_deleted, 'school_id', p_school_id);
end;
$$;

create or replace function public.delete_courses_batch(
  p_school_id uuid,
  p_course_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_requested integer := coalesce(cardinality(p_course_ids), 0);
  v_target_count integer := 0;
  v_deleted integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;
  if p_school_id is null or p_course_ids is null or v_requested < 1 then
    raise exception 'Selecciona al menos un curso' using errcode = '22023';
  end if;
  if v_requested > 5000 then
    raise exception 'El lote supera 5000 cursos' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(p_course_ids) item(id) where item.id is null) then
    raise exception 'Identificador de curso no válido' using errcode = '22023';
  end if;

  if not public.is_platform_admin() and (
    p_school_id is distinct from public.get_user_school_id()
    or not public.has_tenant_permission('settings.manage')
  ) then
    raise exception 'No tienes permiso para eliminar cursos de esta institución' using errcode = '42501';
  end if;

  if (
    select count(distinct c.id)
    from public.courses c
    where c.school_id = p_school_id and c.id = any(p_course_ids)
  ) <> (
    select count(distinct item.id)
    from unnest(p_course_ids) item(id)
  ) then
    raise exception 'La selección contiene cursos inexistentes o de otra institución' using errcode = '42501';
  end if;

  if not public.is_platform_admin()
    and not public.has_tenant_permission('academic_year.update')
    and exists (
      select 1
      from public.courses c
      join public.academic_years ay on ay.school_id = c.school_id and ay.name = c.academic_year
      where c.school_id = p_school_id
        and c.id = any(p_course_ids)
        and ay.is_locked
    ) then
    raise exception 'La selección incluye cursos de un año lectivo bloqueado' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_school_id::text || ':courses-delete', 0));

  select count(*) into v_target_count
  from public.courses c
  where c.school_id = p_school_id and c.id = any(p_course_ids);

  delete from public.courses c
  where c.school_id = p_school_id and c.id = any(p_course_ids);
  get diagnostics v_deleted = row_count;

  if v_deleted <> v_target_count then
    raise exception 'La base de datos no eliminó todos los cursos solicitados';
  end if;

  insert into public.audit_log(school_id, user_id, action, table_name, new_values)
  values (
    p_school_id,
    auth.uid(),
    'COURSES_BATCH_DELETED',
    'courses',
    jsonb_build_object('requested', v_requested, 'deleted', v_deleted)
  );

  return jsonb_build_object('success', true, 'deleted_count', v_deleted, 'school_id', p_school_id);
end;
$$;

revoke all on function public.import_students_batch(uuid, jsonb) from public, anon;
revoke all on function public.delete_students_batch(uuid, uuid[], boolean) from public, anon;
revoke all on function public.delete_courses_batch(uuid, uuid[]) from public, anon;
grant execute on function public.import_students_batch(uuid, jsonb) to authenticated, service_role;
grant execute on function public.delete_students_batch(uuid, uuid[], boolean) to authenticated, service_role;
grant execute on function public.delete_courses_batch(uuid, uuid[]) to authenticated, service_role;
