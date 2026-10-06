-- Restore the academic portion of a tenant backup in one transaction.

create or replace function public.restore_tenant_academic_backup(
  p_backup jsonb,
  p_target_school_id uuid default null,
  p_new_school_name text default null,
  p_new_school_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_data jsonb;
  v_target_school_id uuid := p_target_school_id;
  v_created_school boolean := false;
  v_key text;
  v_item jsonb;
  v_new_id uuid;
  v_ref_id uuid;
  v_name text;
  v_total integer := 0;
  v_courses integer := 0;
  v_subjects integer := 0;
  v_students integer := 0;
  v_grades integer := 0;
  v_quarter_map jsonb := '{}'::jsonb;
  v_subject_map jsonb := '{}'::jsonb;
  v_course_map jsonb := '{}'::jsonb;
  v_course_subject_map jsonb := '{}'::jsonb;
  v_student_map jsonb := '{}'::jsonb;
  v_definition_map jsonb := '{}'::jsonb;
begin
  if auth.uid() is null or not public.has_platform_role(array['platform_owner']) then
    raise exception 'Se requiere el rol propietario de plataforma para restaurar respaldos' using errcode = '42501';
  end if;
  if p_backup is null or jsonb_typeof(p_backup) <> 'object' then
    raise exception 'El respaldo debe ser un objeto JSON' using errcode = '22023';
  end if;

  v_data := case
    when jsonb_typeof(p_backup->'data') = 'object' then p_backup->'data'
    else p_backup
  end;

  foreach v_key in array array[
    'system_config', 'academic_years', 'quarters', 'subjects', 'courses',
    'course_subjects', 'students', 'grade_definitions', 'grades_numeric',
    'grades_qualitative', 'supplementary_exams'
  ] loop
    if jsonb_typeof(coalesce(v_data->v_key, '[]'::jsonb)) <> 'array' then
      raise exception 'La sección % del respaldo no es una lista', v_key using errcode = '22023';
    end if;
    v_total := v_total + jsonb_array_length(coalesce(v_data->v_key, '[]'::jsonb));
  end loop;
  if v_total > 100000 then
    raise exception 'El respaldo supera el límite de 100000 registros académicos' using errcode = '22023';
  end if;

  if v_target_school_id is null then
    if nullif(trim(p_new_school_name), '') is null or nullif(trim(p_new_school_code), '') is null then
      raise exception 'Nombre y código son obligatorios para crear la institución destino' using errcode = '22023';
    end if;
    perform pg_advisory_xact_lock(hashtextextended('tenant-restore-code:' || lower(trim(p_new_school_code)), 0));
    insert into public.schools(name, code, status, is_active)
    values (trim(p_new_school_name), trim(p_new_school_code), 'active', true)
    returning id into v_target_school_id;
    v_created_school := true;
  else
    select id into v_target_school_id
    from public.schools
    where id = p_target_school_id
    for update;
    if not found then
      raise exception 'La institución destino no existe' using errcode = 'P0002';
    end if;
    perform pg_advisory_xact_lock(hashtextextended('tenant-restore:' || v_target_school_id::text, 0));
    if exists (select 1 from public.courses where school_id = v_target_school_id)
      or exists (select 1 from public.subjects where school_id = v_target_school_id)
      or exists (select 1 from public.students where school_id = v_target_school_id)
      or exists (select 1 from public.quarters where school_id = v_target_school_id)
      or exists (select 1 from public.grade_definitions where school_id = v_target_school_id)
      or exists (select 1 from public.academic_years where school_id = v_target_school_id) then
      raise exception 'La institución destino debe estar vacía para evitar mezclar o duplicar datos' using errcode = '23505';
    end if;
  end if;

  for v_item in select value from jsonb_array_elements(coalesce(v_data->'system_config', '[]'::jsonb)) loop
    if nullif(trim(v_item->>'key'), '') is null then
      raise exception 'La configuración contiene una clave vacía' using errcode = '22023';
    end if;
    insert into public.system_config(school_id, key, value)
    values (v_target_school_id, trim(v_item->>'key'), coalesce(v_item->>'value', ''))
    on conflict (school_id, key) do update set value = excluded.value;
  end loop;

  v_item := case
    when jsonb_typeof(v_data->'tenant_limits') = 'object' then v_data->'tenant_limits'
    else '{}'::jsonb
  end;
  insert into public.tenant_limits(
    school_id, max_users, max_teachers, max_students, storage_mb,
    max_documents, max_emails_month, max_api_requests
  ) values (
    v_target_school_id,
    greatest(1, coalesce((v_item->>'max_users')::integer, 50)),
    greatest(1, coalesce((v_item->>'max_teachers')::integer, 20)),
    greatest(
      jsonb_array_length(coalesce(v_data->'students', '[]'::jsonb)),
      coalesce((v_item->>'max_students')::integer, 500),
      1
    ),
    greatest(1, coalesce((v_item->>'storage_mb')::integer, 5120)),
    greatest(1, coalesce((v_item->>'max_documents')::integer, 1000)),
    greatest(1, coalesce((v_item->>'max_emails_month')::integer, 5000)),
    greatest(1, coalesce((v_item->>'max_api_requests')::integer, 100000))
  )
  on conflict (school_id) do update set
    max_users = excluded.max_users,
    max_teachers = excluded.max_teachers,
    max_students = excluded.max_students,
    storage_mb = excluded.storage_mb,
    max_documents = excluded.max_documents,
    max_emails_month = excluded.max_emails_month,
    max_api_requests = excluded.max_api_requests,
    updated_at = timezone('utc'::text, now());

  for v_item in select value from jsonb_array_elements(coalesce(v_data->'academic_years', '[]'::jsonb)) loop
    insert into public.academic_years(
      school_id, name, start_year, end_year, is_active, is_current, is_locked
    ) values (
      v_target_school_id,
      trim(v_item->>'name'),
      (v_item->>'start_year')::integer,
      (v_item->>'end_year')::integer,
      coalesce((v_item->>'is_active')::boolean, false),
      coalesce((v_item->>'is_current')::boolean, false),
      coalesce((v_item->>'is_locked')::boolean, false)
    );
  end loop;

  if jsonb_array_length(coalesce(v_data->'academic_years', '[]'::jsonb)) = 0 then
    for v_name in
      select distinct trim(value->>'academic_year')
      from jsonb_array_elements(coalesce(v_data->'courses', '[]'::jsonb))
      where trim(coalesce(value->>'academic_year', '')) ~ '^[0-9]{4}-[0-9]{4}$'
    loop
      insert into public.academic_years(
        school_id, name, start_year, end_year, is_active, is_current, is_locked
      ) values (
        v_target_school_id,
        v_name,
        split_part(v_name, '-', 1)::integer,
        split_part(v_name, '-', 2)::integer,
        false, false, false
      );
    end loop;
  end if;

  for v_item in select value from jsonb_array_elements(coalesce(v_data->'quarters', '[]'::jsonb)) loop
    if nullif(v_item->>'id', '') is null or nullif(trim(v_item->>'name'), '') is null then
      raise exception 'Un período no contiene identificador o nombre' using errcode = '22023';
    end if;
    insert into public.quarters(school_id, name, code, is_active, is_locked)
    values (
      v_target_school_id,
      trim(v_item->>'name'),
      coalesce(nullif(trim(v_item->>'code'), ''), trim(v_item->>'name')),
      coalesce((v_item->>'is_active')::boolean, false),
      coalesce((v_item->>'is_locked')::boolean, false)
    ) returning id into v_new_id;
    v_quarter_map := v_quarter_map || jsonb_build_object(v_item->>'id', v_new_id::text);
  end loop;

  for v_item in select value from jsonb_array_elements(coalesce(v_data->'subjects', '[]'::jsonb)) loop
    if nullif(v_item->>'id', '') is null or nullif(trim(v_item->>'name'), '') is null then
      raise exception 'Una materia no contiene identificador o nombre' using errcode = '22023';
    end if;
    insert into public.subjects(school_id, name)
    values (v_target_school_id, trim(v_item->>'name'))
    returning id into v_new_id;
    v_subject_map := v_subject_map || jsonb_build_object(v_item->>'id', v_new_id::text);
    v_subjects := v_subjects + 1;
  end loop;

  for v_item in select value from jsonb_array_elements(coalesce(v_data->'courses', '[]'::jsonb)) loop
    if nullif(v_item->>'id', '') is null or nullif(trim(v_item->>'name'), '') is null
      or nullif(trim(v_item->>'academic_year'), '') is null then
      raise exception 'Un curso no contiene identificador, nombre o año lectivo' using errcode = '22023';
    end if;
    insert into public.courses(school_id, name, academic_year, level, track)
    values (
      v_target_school_id,
      trim(v_item->>'name'),
      trim(v_item->>'academic_year'),
      nullif(trim(v_item->>'level'), ''),
      nullif(trim(v_item->>'track'), '')
    ) returning id into v_new_id;
    v_course_map := v_course_map || jsonb_build_object(v_item->>'id', v_new_id::text);
    v_courses := v_courses + 1;
  end loop;

  for v_item in select value from jsonb_array_elements(coalesce(v_data->'course_subjects', '[]'::jsonb)) loop
    v_ref_id := nullif(v_course_map ->> (v_item->>'course_id'), '')::uuid;
    v_new_id := nullif(v_subject_map ->> (v_item->>'subject_id'), '')::uuid;
    if nullif(v_item->>'id', '') is null or v_ref_id is null or v_new_id is null then
      raise exception 'Una asignación referencia un curso o materia ausente' using errcode = '22023';
    end if;
    insert into public.course_subjects(school_id, course_id, subject_id)
    values (v_target_school_id, v_ref_id, v_new_id)
    returning id into v_new_id;
    v_course_subject_map := v_course_subject_map || jsonb_build_object(v_item->>'id', v_new_id::text);
  end loop;

  for v_item in select value from jsonb_array_elements(coalesce(v_data->'students', '[]'::jsonb)) loop
    v_ref_id := nullif(v_course_map ->> (v_item->>'course_id'), '')::uuid;
    if nullif(v_item->>'id', '') is null or nullif(trim(v_item->>'full_name'), '') is null then
      raise exception 'Un estudiante no contiene identificador o nombre' using errcode = '22023';
    end if;
    if nullif(v_item->>'course_id', '') is not null and v_ref_id is null then
      raise exception 'Un estudiante referencia un curso ausente' using errcode = '22023';
    end if;
    insert into public.students(
      school_id, course_id, full_name, student_cedula, student_birthdate,
      student_phone, student_address, representative_name, representative_cedula,
      representative_phone, representative_alt_phone, has_adaptation,
      adaptation_grade, adaptation_type, adaptation_details, created_by
    ) values (
      v_target_school_id, v_ref_id, trim(v_item->>'full_name'),
      nullif(trim(v_item->>'student_cedula'), ''), nullif(v_item->>'student_birthdate', '')::date,
      nullif(trim(v_item->>'student_phone'), ''), nullif(trim(v_item->>'student_address'), ''),
      nullif(trim(v_item->>'representative_name'), ''), nullif(trim(v_item->>'representative_cedula'), ''),
      nullif(trim(v_item->>'representative_phone'), ''), nullif(trim(v_item->>'representative_alt_phone'), ''),
      coalesce((v_item->>'has_adaptation')::boolean, false),
      coalesce(nullif(v_item->>'adaptation_grade', ''), '1'),
      coalesce(v_item->>'adaptation_type', ''), coalesce(v_item->>'adaptation_details', ''), auth.uid()
    ) returning id into v_new_id;
    v_student_map := v_student_map || jsonb_build_object(v_item->>'id', v_new_id::text);
    v_students := v_students + 1;
  end loop;

  for v_item in select value from jsonb_array_elements(coalesce(v_data->'grade_definitions', '[]'::jsonb)) loop
    v_ref_id := nullif(v_course_subject_map ->> (v_item->>'course_subject_id'), '')::uuid;
    v_new_id := nullif(v_quarter_map ->> (v_item->>'quarter_id'), '')::uuid;
    if nullif(v_item->>'id', '') is null or v_ref_id is null or v_new_id is null then
      raise exception 'Una definición de calificación referencia datos ausentes' using errcode = '22023';
    end if;
    insert into public.grade_definitions(
      school_id, course_subject_id, quarter_id, name, category, sort_order
    ) values (
      v_target_school_id, v_ref_id, v_new_id, trim(v_item->>'name'),
      trim(v_item->>'category'), coalesce((v_item->>'sort_order')::integer, 1)
    ) returning id into v_new_id;
    v_definition_map := v_definition_map || jsonb_build_object(v_item->>'id', v_new_id::text);
  end loop;

  for v_item in select value from jsonb_array_elements(coalesce(v_data->'grades_numeric', '[]'::jsonb)) loop
    v_ref_id := nullif(v_student_map ->> (v_item->>'student_id'), '')::uuid;
    v_new_id := nullif(v_definition_map ->> (v_item->>'grade_definition_id'), '')::uuid;
    if v_ref_id is null or v_new_id is null then
      raise exception 'Una calificación numérica referencia datos ausentes' using errcode = '22023';
    end if;
    insert into public.grades(student_id, grade_definition_id, score)
    values (v_ref_id, v_new_id, (v_item->>'score')::numeric);
    v_grades := v_grades + 1;
  end loop;

  for v_item in select value from jsonb_array_elements(coalesce(v_data->'grades_qualitative', '[]'::jsonb)) loop
    v_ref_id := nullif(v_student_map ->> (v_item->>'student_id'), '')::uuid;
    v_new_id := nullif(v_course_subject_map ->> (v_item->>'course_subject_id'), '')::uuid;
    if v_ref_id is null or v_new_id is null
      or nullif(v_quarter_map ->> (v_item->>'quarter_id'), '') is null then
      raise exception 'Una calificación cualitativa referencia datos ausentes' using errcode = '22023';
    end if;
    insert into public.qualitative_grades(student_id, course_subject_id, quarter_id, score_text)
    values (
      v_ref_id, v_new_id,
      (v_quarter_map ->> (v_item->>'quarter_id'))::uuid,
      v_item->>'score_text'
    );
    v_grades := v_grades + 1;
  end loop;

  for v_item in select value from jsonb_array_elements(coalesce(v_data->'supplementary_exams', '[]'::jsonb)) loop
    v_ref_id := nullif(v_student_map ->> (v_item->>'student_id'), '')::uuid;
    v_new_id := nullif(v_course_subject_map ->> (v_item->>'course_subject_id'), '')::uuid;
    if v_ref_id is null or v_new_id is null then
      raise exception 'Un examen supletorio referencia datos ausentes' using errcode = '22023';
    end if;
    insert into public.supplementary_exams(student_id, course_subject_id, score)
    values (v_ref_id, v_new_id, (v_item->>'score')::numeric);
  end loop;

  insert into public.audit_log(school_id, user_id, action, table_name, record_id, new_values)
  values (
    v_target_school_id, auth.uid(), 'TENANT_ACADEMIC_BACKUP_RESTORED', 'schools',
    v_target_school_id::text,
    jsonb_build_object(
      'created_school', v_created_school, 'records_received', v_total,
      'courses', v_courses, 'subjects', v_subjects,
      'students', v_students, 'grades', v_grades
    )
  );

  return jsonb_build_object(
    'success', true,
    'school_id', v_target_school_id,
    'created_school', v_created_school,
    'records_received', v_total,
    'courses', v_courses,
    'subjects', v_subjects,
    'students', v_students,
    'grades', v_grades
  );
end;
$$;

revoke all on function public.restore_tenant_academic_backup(jsonb, uuid, text, text) from public, anon;
grant execute on function public.restore_tenant_academic_backup(jsonb, uuid, text, text) to authenticated;
