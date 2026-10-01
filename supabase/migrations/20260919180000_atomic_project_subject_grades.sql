-- Persist project subject grades and removals in one authorized transaction.

create or replace function public.save_project_subject_grades_batch(
  p_course_id uuid,
  p_quarter_id uuid,
  p_upserts jsonb default '[]'::jsonb,
  p_deletes jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_school_id uuid;
  v_upsert_count integer;
  v_delete_count integer;
  v_valid_count integer;
  v_upserted integer := 0;
  v_deleted integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;
  if jsonb_typeof(p_upserts) is distinct from 'array'
    or jsonb_typeof(p_deletes) is distinct from 'array' then
    raise exception 'Lote de proyecto no válido' using errcode = '22023';
  end if;

  v_upsert_count := jsonb_array_length(p_upserts);
  v_delete_count := jsonb_array_length(p_deletes);
  if v_upsert_count + v_delete_count > 10000 then
    raise exception 'El lote de proyecto supera 10000 notas' using errcode = '22023';
  end if;
  if v_upsert_count + v_delete_count = 0 then
    return jsonb_build_object('success', true, 'upserted', 0, 'deleted', 0);
  end if;

  select c.school_id into v_school_id
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
    raise exception 'No tienes permiso para guardar notas de proyecto' using errcode = '42501';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_upserts) item(student_id uuid, subject_id uuid, score numeric)
    where item.student_id is null or item.subject_id is null
      or item.score is null or item.score < 0 or item.score > 10
  ) then
    raise exception 'Una nota de proyecto contiene datos inválidos' using errcode = '22003';
  end if;
  if exists (
    select 1 from jsonb_to_recordset(p_deletes) item(student_id uuid, subject_id uuid)
    where item.student_id is null or item.subject_id is null
  ) then
    raise exception 'Una eliminación de proyecto contiene datos inválidos' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_to_recordset(p_upserts) item(student_id uuid, subject_id uuid, score numeric)
    group by item.student_id, item.subject_id having count(*) > 1
  ) or exists (
    select 1 from jsonb_to_recordset(p_deletes) item(student_id uuid, subject_id uuid)
    group by item.student_id, item.subject_id having count(*) > 1
  ) or exists (
    select 1
    from jsonb_to_recordset(p_upserts) added(student_id uuid, subject_id uuid, score numeric)
    join jsonb_to_recordset(p_deletes) removed(student_id uuid, subject_id uuid)
      using (student_id, subject_id)
  ) then
    raise exception 'El lote repite una nota de proyecto' using errcode = '23505';
  end if;

  -- Serialize grade writes with project-subject configuration changes before
  -- validating project_settings, so a concurrent removal cannot race this save.
  perform pg_advisory_xact_lock(hashtextextended(
    v_school_id::text || ':project-grades:' || p_course_id::text || ':' || p_quarter_id::text, 0
  ));

  select count(*) into v_valid_count
  from jsonb_to_recordset(p_upserts) item(student_id uuid, subject_id uuid, score numeric)
  join public.students st on st.id = item.student_id
    and st.school_id = v_school_id and st.course_id = p_course_id
  join public.course_subjects cs on cs.course_id = p_course_id
    and cs.subject_id = item.subject_id and cs.school_id = v_school_id
  join public.project_settings ps on ps.course_id = p_course_id
    and ps.quarter_id = p_quarter_id and ps.subject_id = item.subject_id
  where public.is_platform_admin()
     or public.can_manage_project_score(
       item.student_id, p_course_id, item.subject_id, p_quarter_id, 'grades.update'
     );
  if v_valid_count <> v_upsert_count then
    raise exception 'El lote contiene una nota fuera del curso, proyecto o asignación autorizada' using errcode = '42501';
  end if;

  select count(*) into v_valid_count
  from jsonb_to_recordset(p_deletes) item(student_id uuid, subject_id uuid)
  join public.project_subject_grades pg on pg.student_id = item.student_id
    and pg.subject_id = item.subject_id and pg.course_id = p_course_id
    and pg.quarter_id = p_quarter_id
  join public.students st on st.id = item.student_id
    and st.school_id = v_school_id and st.course_id = p_course_id
  where public.is_platform_admin()
     or public.can_manage_project_score(
       item.student_id, p_course_id, item.subject_id, p_quarter_id, 'grades.update'
     );
  if v_valid_count <> v_delete_count then
    raise exception 'El lote contiene una eliminación inexistente o no autorizada' using errcode = '42501';
  end if;

  delete from public.project_subject_grades pg
  using jsonb_to_recordset(p_deletes) item(student_id uuid, subject_id uuid)
  where pg.student_id = item.student_id
    and pg.subject_id = item.subject_id
    and pg.course_id = p_course_id
    and pg.quarter_id = p_quarter_id;
  get diagnostics v_deleted = row_count;

  insert into public.project_subject_grades(
    student_id, course_id, quarter_id, subject_id, score, updated_at
  )
  select item.student_id, p_course_id, p_quarter_id, item.subject_id,
    item.score, timezone('utc'::text, now())
  from jsonb_to_recordset(p_upserts) item(student_id uuid, subject_id uuid, score numeric)
  on conflict (student_id, course_id, quarter_id, subject_id) do update
  set score = excluded.score,
      updated_at = timezone('utc'::text, now());
  get diagnostics v_upserted = row_count;

  if v_deleted <> v_delete_count or v_upserted <> v_upsert_count then
    raise exception 'La base de datos no confirmó el lote completo de proyecto';
  end if;

  return jsonb_build_object(
    'success', true, 'upserted', v_upserted, 'deleted', v_deleted,
    'course_id', p_course_id, 'quarter_id', p_quarter_id
  );
end;
$$;

revoke all on function public.save_project_subject_grades_batch(uuid, uuid, jsonb, jsonb) from public, anon;
grant execute on function public.save_project_subject_grades_batch(uuid, uuid, jsonb, jsonb) to authenticated;
