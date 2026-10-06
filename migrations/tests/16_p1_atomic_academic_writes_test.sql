-- Contract test for migrations/16_p1_atomic_academic_writes.sql
-- Safe on a live project: all fixtures and writes are rolled back.
begin;

do $$
begin
  if to_regprocedure('public.import_students_batch(uuid,jsonb)') is null then
    raise exception 'import_students_batch is missing';
  end if;
  if to_regprocedure('public.save_grade_batch(jsonb,jsonb)') is null then
    raise exception 'save_grade_batch is missing';
  end if;
  if to_regprocedure('public.save_qualitative_grade_batch(uuid,uuid,jsonb,jsonb)') is null then
    raise exception 'save_qualitative_grade_batch is missing';
  end if;
end
$$;

select set_config(
  'request.jwt.claim.sub',
  (select id::text from public.profiles order by created_at limit 1),
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

do $$
declare
  v_student_id uuid;
  v_definition_id uuid;
  v_course_id uuid;
  v_grade_count integer;
  v_student_count integer;
  v_failed boolean := false;
begin
  select g.student_id, g.grade_definition_id, st.course_id
    into v_student_id, v_definition_id, v_course_id
  from public.grades g
  join public.students st on st.id = g.student_id
  join public.grade_definitions gd on gd.id = g.grade_definition_id
  join public.course_subjects cs on cs.id = gd.course_subject_id
  where cs.course_id = st.course_id
  limit 1;

  if v_student_id is null then
    raise exception 'atomic grade test requires one existing grade fixture';
  end if;

  select count(*) into v_grade_count from public.grades;

  begin
    perform public.save_grade_batch(
      jsonb_build_array(
        jsonb_build_object(
          'student_id', v_student_id,
          'grade_definition_id', v_definition_id,
          'score', 9.25
        ),
        jsonb_build_object(
          'student_id', 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
          'grade_definition_id', v_definition_id,
          'score', 8.50
        )
      ),
      '[]'::jsonb
    );
  exception
    when others then v_failed := true;
  end;

  if not v_failed then
    raise exception 'invalid grade batch was accepted';
  end if;
  if (select count(*) from public.grades) <> v_grade_count then
    raise exception 'failed grade batch changed persisted rows';
  end if;

  select count(*) into v_student_count from public.students;
  v_failed := false;

  begin
    perform public.import_students_batch(
      v_course_id,
      jsonb_build_array(
        jsonb_build_object('full_name', 'P1 atomic fixture', 'student_cedula', 'P1-ATOMIC-1'),
        jsonb_build_object('full_name', '', 'student_cedula', 'P1-ATOMIC-2')
      )
    );
  exception
    when others then v_failed := true;
  end;

  if not v_failed then
    raise exception 'invalid student batch was accepted';
  end if;
  if (select count(*) from public.students) <> v_student_count then
    raise exception 'failed student batch changed persisted rows';
  end if;
end
$$;

rollback;
