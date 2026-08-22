begin;

select set_config('request.jwt.claim.sub', (select id::text from public.profiles order by created_at limit 1), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

set local role authenticated;

do $$
declare
  v_course_id uuid;
  v_before integer;
  v_assignments jsonb;
  v_failed boolean := false;
begin
  select cs.course_id into v_course_id
  from public.course_subjects cs
  join public.grade_definitions gd on gd.course_subject_id = cs.id
  limit 1;

  if v_course_id is null then
    raise exception 'Assignment test requires a course with academic data';
  end if;

  select count(*), jsonb_agg(jsonb_build_object(
    'subject_id', cs.subject_id,
    'teacher_id', cs.teacher_id
  ) order by cs.subject_id)
  into v_before, v_assignments
  from public.course_subjects cs
  where cs.course_id = v_course_id;

  perform public.save_course_subject_assignments(v_course_id, v_assignments);

  begin
    perform public.save_course_subject_assignments(
      v_course_id,
      jsonb_build_array(jsonb_build_object(
        'subject_id', (v_assignments->0->>'subject_id')::uuid,
        'teacher_id', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
      ))
    );
  exception when sqlstate 'P0001' then
    if sqlerrm = 'INVALID_ASSIGNED_TEACHER' then v_failed := true; else raise; end if;
  end;
  if not v_failed then raise exception 'Invalid teacher assignment was accepted'; end if;

  v_failed := false;
  begin
    perform public.save_course_subject_assignments(v_course_id, '[]'::jsonb);
  exception when sqlstate 'P0001' then
    if sqlerrm = 'COURSE_SUBJECT_HAS_ACADEMIC_DATA' then v_failed := true; else raise; end if;
  end;
  if not v_failed then raise exception 'Academic course subject deletion was accepted'; end if;

  if (select count(*) from public.course_subjects where course_id = v_course_id) <> v_before then
    raise exception 'Assignment batch changed after rejected operation';
  end if;
end $$;

reset role;
rollback;
