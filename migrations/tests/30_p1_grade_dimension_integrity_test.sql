-- Las notas deben heredar siempre materia y periodo desde su definición.
-- Todas las escrituras se revierten al final de la prueba.
begin;

select set_config(
  'audit.test_actor',
  (
    select upr.user_id::text
    from public.user_platform_roles upr
    join public.platform_roles pr on pr.id = upr.platform_role_id
    where pr.name in ('platform_owner', 'platform_admin')
    order by upr.created_at
    limit 1
  ),
  true
);
select set_config('request.jwt.claim.sub', current_setting('audit.test_actor'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

set local role authenticated;

do $$
declare
  v_student_id uuid;
  v_definition_id uuid;
  v_expected_course_subject_id uuid;
  v_expected_quarter_id uuid;
  v_actual_course_subject_id uuid;
  v_actual_quarter_id uuid;
begin
  select st.id, gd.id, gd.course_subject_id, gd.quarter_id
  into v_student_id, v_definition_id, v_expected_course_subject_id, v_expected_quarter_id
  from public.students st
  join public.course_subjects cs on cs.course_id = st.course_id and cs.school_id = st.school_id
  join public.grade_definitions gd on gd.course_subject_id = cs.id and gd.school_id = st.school_id
  join public.quarters q on q.id = gd.quarter_id and q.school_id = st.school_id
  left join public.grades g on g.student_id = st.id and g.grade_definition_id = gd.id
  where g.id is null
    and not coalesce(q.is_locked, false)
  order by gd.sort_order, gd.id
  limit 1;

  if v_definition_id is null then
    raise exception 'grade integrity test requires one unused unlocked definition';
  end if;

  perform public.save_grade_batch(
    jsonb_build_array(jsonb_build_object(
      'student_id', v_student_id,
      'grade_definition_id', v_definition_id,
      'score', 9.25
    )),
    '[]'::jsonb
  );

  select g.course_subject_id, g.quarter_id
  into v_actual_course_subject_id, v_actual_quarter_id
  from public.grades g
  where g.student_id = v_student_id
    and g.grade_definition_id = v_definition_id;

  if v_actual_course_subject_id is distinct from v_expected_course_subject_id
     or v_actual_quarter_id is distinct from v_expected_quarter_id then
    raise exception 'save_grade_batch did not synchronize grade dimensions';
  end if;
end
$$;

do $$
declare
  v_mismatches bigint;
begin
  select count(*) into v_mismatches
  from public.grades g
  join public.grade_definitions gd on gd.id = g.grade_definition_id
  where g.course_subject_id is distinct from gd.course_subject_id
     or g.quarter_id is distinct from gd.quarter_id;

  if v_mismatches <> 0 then
    raise exception 'found % grades with inconsistent dimensions', v_mismatches;
  end if;
end
$$;

reset role;
rollback;
