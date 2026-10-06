-- Restablece autorización por permiso, asignación docente y periodo desbloqueado.

alter table public.grades alter column school_id set not null;
alter table public.grades enable row level security;

drop policy if exists grades_select on public.grades;
drop policy if exists grades_insert on public.grades;
drop policy if exists grades_update on public.grades;
drop policy if exists grades_delete on public.grades;
drop policy if exists grades_all_auth on public.grades;
drop policy if exists grades_cud on public.grades;
drop policy if exists grades_teacher_cud on public.grades;
drop policy if exists "Admin or Assigned Teacher write" on public.grades;
drop policy if exists "Grades multi tenant isolate" on public.grades;

create policy grades_select on public.grades for select to authenticated
using (public.can_access_student(student_id, 'grades.read'));

create policy grades_insert on public.grades for insert to authenticated
with check (
  public.can_manage_grade(
    student_id, course_subject_id, grade_definition_id, quarter_id, 'grades.create'
  )
);

create policy grades_update on public.grades for update to authenticated
using (
  public.can_manage_grade(
    student_id, course_subject_id, grade_definition_id, quarter_id, 'grades.update'
  )
)
with check (
  public.can_manage_grade(
    student_id, course_subject_id, grade_definition_id, quarter_id, 'grades.update'
  )
);

create policy grades_delete on public.grades for delete to authenticated
using (
  public.can_manage_grade(
    student_id, course_subject_id, grade_definition_id, quarter_id, 'grades.update'
  )
);

create or replace function public.save_grade_batch(
  p_upserts jsonb default '[]'::jsonb,
  p_deletes jsonb default '[]'::jsonb
)
returns json
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
  v_first_student_id uuid;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if jsonb_typeof(p_upserts) is distinct from 'array'
     or jsonb_typeof(p_deletes) is distinct from 'array' then
    raise exception 'INVALID_GRADE_BATCH' using errcode = '22023';
  end if;

  v_upsert_count := jsonb_array_length(p_upserts);
  v_delete_count := jsonb_array_length(p_deletes);
  if v_upsert_count + v_delete_count > 10000 then
    raise exception 'GRADE_BATCH_TOO_LARGE' using errcode = '22023';
  end if;
  if v_upsert_count + v_delete_count = 0 then
    return json_build_object('success', true, 'upserted', 0, 'deleted', 0);
  end if;

  v_first_student_id := coalesce(
    (p_upserts->0->>'student_id')::uuid,
    (p_deletes->0->>'student_id')::uuid
  );
  select school_id into v_school_id from public.students where id = v_first_student_id;

  if v_school_id is null then
    raise exception 'GRADE_STUDENT_NOT_FOUND' using errcode = 'P0002';
  end if;
  if not public.is_platform_admin() and (
    v_school_id is distinct from public.get_user_school_id()
    or not public.has_tenant_permission('grades.update')
  ) then
    raise exception 'GRADE_WRITE_FORBIDDEN' using errcode = '42501';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_upserts)
      as x(student_id uuid, grade_definition_id uuid, score numeric)
    where x.score is null or x.score < 0 or x.score > 10
  ) then
    raise exception 'GRADE_SCORE_OUT_OF_RANGE' using errcode = '22003';
  end if;

  select count(*) into v_valid_count
  from jsonb_to_recordset(p_upserts)
    as x(student_id uuid, grade_definition_id uuid, score numeric)
  join public.students st on st.id = x.student_id
  join public.grade_definitions gd on gd.id = x.grade_definition_id
  join public.course_subjects cs on cs.id = gd.course_subject_id
  join public.quarters q on q.id = gd.quarter_id
  where st.school_id = v_school_id
    and gd.school_id = v_school_id
    and cs.school_id = v_school_id
    and q.school_id = v_school_id
    and st.course_id = cs.course_id
    and not coalesce(q.is_locked, false)
    and public.can_manage_grade(
      x.student_id, gd.course_subject_id, gd.id, gd.quarter_id, 'grades.update'
    );

  if v_valid_count <> v_upsert_count then
    raise exception 'INVALID_OR_LOCKED_GRADE_TARGET' using errcode = '42501';
  end if;

  select count(*) into v_valid_count
  from jsonb_to_recordset(p_deletes)
    as x(student_id uuid, grade_definition_id uuid)
  join public.students st on st.id = x.student_id
  join public.grade_definitions gd on gd.id = x.grade_definition_id
  join public.course_subjects cs on cs.id = gd.course_subject_id
  join public.quarters q on q.id = gd.quarter_id
  where st.school_id = v_school_id
    and gd.school_id = v_school_id
    and cs.school_id = v_school_id
    and q.school_id = v_school_id
    and st.course_id = cs.course_id
    and not coalesce(q.is_locked, false)
    and public.can_manage_grade(
      x.student_id, gd.course_subject_id, gd.id, gd.quarter_id, 'grades.update'
    );

  if v_valid_count <> v_delete_count then
    raise exception 'INVALID_OR_LOCKED_GRADE_TARGET' using errcode = '42501';
  end if;

  delete from public.grades g
  using jsonb_to_recordset(p_deletes)
    as x(student_id uuid, grade_definition_id uuid)
  where g.student_id = x.student_id
    and g.grade_definition_id = x.grade_definition_id;
  get diagnostics v_deleted = row_count;

  insert into public.grades (student_id, grade_definition_id, score, updated_at)
  select x.student_id, x.grade_definition_id, x.score, timezone('utc'::text, now())
  from jsonb_to_recordset(p_upserts)
    as x(student_id uuid, grade_definition_id uuid, score numeric)
  on conflict (student_id, grade_definition_id) do update
  set score = excluded.score,
      updated_at = timezone('utc'::text, now());
  get diagnostics v_upserted = row_count;

  return json_build_object(
    'success', true,
    'upserted', v_upserted,
    'deleted', v_deleted
  );
end;
$$;

revoke all on function public.save_grade_batch(jsonb, jsonb) from public, anon;
grant execute on function public.save_grade_batch(jsonb, jsonb) to authenticated, service_role;
