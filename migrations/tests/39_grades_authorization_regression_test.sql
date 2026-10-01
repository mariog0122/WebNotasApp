-- Ejecutar después de harden_grades_authorization. Todos los cambios se revierten.
begin;

select set_config(
  'audit.grade_id',
  (select g.id::text
   from public.grades g
   join public.quarters q on q.id = g.quarter_id
   where not coalesce(q.is_locked, false)
   order by g.created_at
   limit 1),
  true
);
select set_config(
  'audit.test_school',
  (select g.school_id::text from public.grades g where g.id::text = current_setting('audit.grade_id')),
  true
);
select set_config(
  'audit.test_actor',
  (select p.id::text from public.profiles p
   where p.school_id::text = current_setting('audit.test_school')
   order by p.created_at limit 1),
  true
);
select set_config('request.jwt.claim.sub', current_setting('audit.test_actor'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

delete from public.user_platform_roles
where user_id::text = current_setting('audit.test_actor');
update public.profiles set role = 'teacher', is_active = true
where id::text = current_setting('audit.test_actor');
insert into public.tenant_memberships (user_id, school_id, tenant_role_id, is_active)
select current_setting('audit.test_actor')::uuid,
       current_setting('audit.test_school')::uuid,
       tr.id,
       true
from public.tenant_roles tr
where tr.name = 'teacher'
on conflict (user_id, school_id) do update
set tenant_role_id = excluded.tenant_role_id, is_active = true;

update public.course_subjects cs
set teacher_id = null
from public.grades g
where g.id::text = current_setting('audit.grade_id')
  and cs.id = g.course_subject_id;

set local role authenticated;

do $$
declare
  v_updated integer := 0;
  v_grade record;
  v_failed boolean := false;
begin
  update public.grades
  set score = score
  where id::text = current_setting('audit.grade_id');
  get diagnostics v_updated = row_count;
  if v_updated <> 0 then
    raise exception 'unassigned teacher updated a grade directly';
  end if;

  select g.student_id, g.grade_definition_id, g.score
    into v_grade
  from public.grades g
  where g.id::text = current_setting('audit.grade_id');

  -- La lectura del docente se conserva, pero la escritura requiere asignación.
  if v_grade.student_id is null then
    raise exception 'teacher lost own-tenant grade read access';
  end if;

  begin
    perform public.save_grade_batch(
      jsonb_build_array(jsonb_build_object(
        'student_id', v_grade.student_id,
        'grade_definition_id', v_grade.grade_definition_id,
        'score', v_grade.score
      )),
      '[]'::jsonb
    );
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'unassigned teacher wrote a grade through save_grade_batch';
  end if;
end
$$;

reset role;
update public.course_subjects cs
set teacher_id = current_setting('audit.test_actor')::uuid
from public.grades g
where g.id::text = current_setting('audit.grade_id')
  and cs.id = g.course_subject_id;
set local role authenticated;

do $$
declare
  v_grade record;
begin
  select student_id, grade_definition_id, score into v_grade
  from public.grades where id::text = current_setting('audit.grade_id');

  perform public.save_grade_batch(
    jsonb_build_array(jsonb_build_object(
      'student_id', v_grade.student_id,
      'grade_definition_id', v_grade.grade_definition_id,
      'score', v_grade.score
    )),
    '[]'::jsonb
  );
end
$$;

reset role;
rollback;

select 'grades_authorization_regression_tests_passed' as result;
