-- Atomic course-subject and teacher assignments. Prevents partial writes and
-- protects academic history from accidental cascading deletes.
create or replace function public.save_course_subject_assignments(
  p_course_id uuid,
  p_assignments jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_school_id uuid;
  v_item jsonb;
  v_subject_id uuid;
  v_teacher_id uuid;
begin
  if jsonb_typeof(p_assignments) is distinct from 'array' then
    raise exception 'INVALID_ASSIGNMENT_BATCH' using errcode = 'P0001';
  end if;

  select c.school_id into v_school_id
  from public.courses c
  where c.id = p_course_id;

  if v_school_id is null then
    raise exception 'COURSE_NOT_FOUND' using errcode = 'P0001';
  end if;

  if not public.is_admin()
     or (not public.is_platform_admin() and v_school_id is distinct from public.get_user_school_id()) then
    raise exception 'COURSE_ASSIGNMENT_FORBIDDEN' using errcode = '42501';
  end if;

  if exists (
    select 1
    from (
      select value->>'subject_id' subject_id, count(*) amount
      from jsonb_array_elements(p_assignments)
      group by value->>'subject_id'
      having count(*) > 1
    ) duplicates
  ) then
    raise exception 'DUPLICATE_SUBJECT_ASSIGNMENT' using errcode = 'P0001';
  end if;

  for v_item in select value from jsonb_array_elements(p_assignments)
  loop
    begin
      v_subject_id := (v_item->>'subject_id')::uuid;
      v_teacher_id := nullif(v_item->>'teacher_id', '')::uuid;
    exception when invalid_text_representation then
      raise exception 'INVALID_ASSIGNMENT_ID' using errcode = 'P0001';
    end;

    if not exists (
      select 1 from public.subjects s
      where s.id = v_subject_id and s.school_id = v_school_id
    ) then
      raise exception 'INVALID_ASSIGNED_SUBJECT' using errcode = 'P0001';
    end if;

    if v_teacher_id is not null and not exists (
      select 1 from public.profiles p
      where p.id = v_teacher_id
        and p.school_id = v_school_id
        and p.role = 'teacher'
        and coalesce(p.is_active, true)
    ) then
      raise exception 'INVALID_ASSIGNED_TEACHER' using errcode = 'P0001';
    end if;
  end loop;

  if exists (
    select 1
    from public.course_subjects cs
    where cs.course_id = p_course_id
      and not exists (
        select 1 from jsonb_array_elements(p_assignments) item
        where (item->>'subject_id')::uuid = cs.subject_id
      )
      and (
        exists (select 1 from public.grade_definitions gd where gd.course_subject_id = cs.id)
        or exists (select 1 from public.grades g where g.course_subject_id = cs.id)
        or exists (select 1 from public.qualitative_grades qg where qg.course_subject_id = cs.id)
        or exists (select 1 from public.supplementary_exams se where se.course_subject_id = cs.id)
      )
  ) then
    raise exception 'COURSE_SUBJECT_HAS_ACADEMIC_DATA' using errcode = 'P0001';
  end if;

  delete from public.course_subjects cs
  where cs.course_id = p_course_id
    and not exists (
      select 1 from jsonb_array_elements(p_assignments) item
      where (item->>'subject_id')::uuid = cs.subject_id
    );

  insert into public.course_subjects (course_id, subject_id, teacher_id, school_id)
  select
    p_course_id,
    (item->>'subject_id')::uuid,
    nullif(item->>'teacher_id', '')::uuid,
    v_school_id
  from jsonb_array_elements(p_assignments) item
  on conflict (course_id, subject_id) do update
  set teacher_id = excluded.teacher_id,
      school_id = excluded.school_id;

  return jsonb_build_object(
    'course_id', p_course_id,
    'assignment_count', jsonb_array_length(p_assignments),
    'teacher_assignment_count', (
      select count(*) from jsonb_array_elements(p_assignments) item
      where nullif(item->>'teacher_id', '') is not null
    )
  );
end;
$$;

revoke all on function public.save_course_subject_assignments(uuid, jsonb) from public, anon;
grant execute on function public.save_course_subject_assignments(uuid, jsonb) to authenticated;

