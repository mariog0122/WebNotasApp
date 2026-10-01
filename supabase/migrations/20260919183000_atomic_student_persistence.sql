-- Persist one student through an authorized, tenant-safe transaction.

create or replace function public.save_student_record(
  p_school_id uuid,
  p_student_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_existing public.students;
  v_course public.courses;
  v_is_update boolean := false;
  v_full_name text;
  v_student_cedula text;
  v_birthdate date;
  v_current_count integer;
  v_limit integer;
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;
  if p_school_id is null or p_student_id is null or jsonb_typeof(p_payload) is distinct from 'object' then
    raise exception 'Datos del estudiante incompletos' using errcode = '22023';
  end if;

  v_full_name := nullif(trim(p_payload->>'full_name'), '');
  v_student_cedula := nullif(trim(p_payload->>'student_cedula'), '');
  v_birthdate := nullif(p_payload->>'student_birthdate', '')::date;

  if v_full_name is null or length(v_full_name) > 200
    or nullif(p_payload->>'course_id', '') is null
    or length(coalesce(v_student_cedula, '')) > 30
    or length(coalesce(trim(p_payload->>'student_phone'), '')) > 30
    or length(coalesce(trim(p_payload->>'student_address'), '')) > 500
    or length(coalesce(trim(p_payload->>'representative_name'), '')) > 200
    or length(coalesce(trim(p_payload->>'representative_cedula'), '')) > 30
    or length(coalesce(trim(p_payload->>'representative_phone'), '')) > 30
    or length(coalesce(trim(p_payload->>'representative_alt_phone'), '')) > 30
    or length(coalesce(p_payload->>'student_photo_url', '')) > 1000
    or length(coalesce(p_payload->>'representative_photo_url', '')) > 1000 then
    raise exception 'Los datos del estudiante no son válidos' using errcode = '22023';
  end if;
  if v_birthdate is not null and v_birthdate >= current_date then
    raise exception 'La fecha de nacimiento debe ser anterior a hoy' using errcode = '22023';
  end if;
  if coalesce((p_payload->>'has_adaptation')::boolean, false)
    and coalesce(nullif(p_payload->>'adaptation_grade', ''), '1') not in ('1', '2', '3') then
    raise exception 'El grado de adaptación no es válido' using errcode = '22023';
  end if;

  select * into v_course
  from public.courses
  where id = (p_payload->>'course_id')::uuid
    and school_id = p_school_id
  for share;
  if not found then
    raise exception 'El curso no existe o pertenece a otra institución' using errcode = '42501';
  end if;

  select * into v_existing
  from public.students
  where id = p_student_id
  for update;
  v_is_update := found;
  if v_is_update and v_existing.school_id is distinct from p_school_id then
    raise exception 'El estudiante pertenece a otra institución' using errcode = '42501';
  end if;

  if not public.is_platform_admin() and (
    p_school_id is distinct from public.get_user_school_id()
    or (v_is_update and not public.has_tenant_permission('students.update'))
    or (not v_is_update and not public.has_tenant_permission('students.create'))
  ) then
    raise exception 'No tienes permiso para guardar estudiantes en esta institución' using errcode = '42501';
  end if;

  if exists (
    select 1
    from public.academic_years ay
    where ay.school_id = p_school_id
      and ay.name = v_course.academic_year
      and ay.is_locked
  ) and not public.is_platform_admin()
    and not public.has_tenant_permission('academic_year.update') then
    raise exception 'El año lectivo está bloqueado' using errcode = '42501';
  end if;

  if v_student_cedula is not null and exists (
    select 1 from public.students s
    where s.school_id = p_school_id
      and s.student_cedula = v_student_cedula
      and s.id <> p_student_id
  ) then
    raise exception 'Ya existe un estudiante con esa identificación en la institución' using errcode = '23505';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_school_id::text, 0));
  if not v_is_update then
    select count(*) into v_current_count from public.students where school_id = p_school_id;
    select max_students into v_limit from public.tenant_limits where school_id = p_school_id;
    if v_limit is null then
      raise exception 'La institución no tiene un límite de estudiantes configurado' using errcode = 'P0001';
    end if;
    if v_current_count + 1 > v_limit then
      raise exception 'Límite de estudiantes alcanzado: actuales %, límite %', v_current_count, v_limit using errcode = 'P0001';
    end if;
  end if;

  if v_is_update then
    update public.students
    set full_name = v_full_name,
        course_id = v_course.id,
        student_cedula = v_student_cedula,
        student_birthdate = v_birthdate,
        student_phone = nullif(trim(p_payload->>'student_phone'), ''),
        student_address = nullif(trim(p_payload->>'student_address'), ''),
        representative_name = nullif(trim(p_payload->>'representative_name'), ''),
        representative_cedula = nullif(trim(p_payload->>'representative_cedula'), ''),
        representative_phone = nullif(trim(p_payload->>'representative_phone'), ''),
        representative_alt_phone = nullif(trim(p_payload->>'representative_alt_phone'), ''),
        student_photo_url = nullif(p_payload->>'student_photo_url', ''),
        representative_photo_url = nullif(p_payload->>'representative_photo_url', ''),
        has_adaptation = coalesce((p_payload->>'has_adaptation')::boolean, v_existing.has_adaptation, false),
        adaptation_grade = case
          when coalesce((p_payload->>'has_adaptation')::boolean, v_existing.has_adaptation, false)
            then coalesce(nullif(p_payload->>'adaptation_grade', ''), v_existing.adaptation_grade, '1')
          else '1'
        end,
        adaptation_details = case
          when coalesce((p_payload->>'has_adaptation')::boolean, v_existing.has_adaptation, false)
            then coalesce(p_payload->>'adaptation_details', v_existing.adaptation_details, '')
          else ''
        end
    where id = p_student_id and school_id = p_school_id;
  else
    insert into public.students(
      id, school_id, course_id, full_name, student_cedula, student_birthdate,
      student_phone, student_address, representative_name, representative_cedula,
      representative_phone, representative_alt_phone, student_photo_url,
      representative_photo_url, has_adaptation, adaptation_grade,
      adaptation_details, created_by
    ) values (
      p_student_id, p_school_id, v_course.id, v_full_name, v_student_cedula, v_birthdate,
      nullif(trim(p_payload->>'student_phone'), ''), nullif(trim(p_payload->>'student_address'), ''),
      nullif(trim(p_payload->>'representative_name'), ''), nullif(trim(p_payload->>'representative_cedula'), ''),
      nullif(trim(p_payload->>'representative_phone'), ''), nullif(trim(p_payload->>'representative_alt_phone'), ''),
      nullif(p_payload->>'student_photo_url', ''), nullif(p_payload->>'representative_photo_url', ''),
      coalesce((p_payload->>'has_adaptation')::boolean, false),
      case when coalesce((p_payload->>'has_adaptation')::boolean, false)
        then coalesce(nullif(p_payload->>'adaptation_grade', ''), '1') else '1' end,
      case when coalesce((p_payload->>'has_adaptation')::boolean, false)
        then coalesce(p_payload->>'adaptation_details', '') else '' end,
      auth.uid()
    );
  end if;

  if not exists (
    select 1 from public.students
    where id = p_student_id and school_id = p_school_id and course_id = v_course.id
  ) then
    raise exception 'La base de datos no confirmó el guardado del estudiante';
  end if;

  insert into public.audit_log(school_id, user_id, action, table_name, record_id, new_values)
  values (
    p_school_id,
    auth.uid(),
    case when v_is_update then 'STUDENT_UPDATED' else 'STUDENT_CREATED' end,
    'students',
    p_student_id::text,
    jsonb_build_object('course_id', v_course.id)
  );

  return jsonb_build_object(
    'success', true,
    'action', case when v_is_update then 'updated' else 'created' end,
    'student_id', p_student_id,
    'school_id', p_school_id,
    'course_id', v_course.id
  );
end;
$$;

revoke all on function public.save_student_record(uuid, uuid, jsonb) from public, anon;
grant execute on function public.save_student_record(uuid, uuid, jsonb) to authenticated, service_role;
