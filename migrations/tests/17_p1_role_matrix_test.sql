-- Role matrix for sellable academic operations. Safe: all changes roll back.
begin;

select set_config(
  'audit.test_actor',
  (select id::text from public.profiles order by created_at limit 1),
  true
);
select set_config(
  'audit.test_school',
  (select school_id::text from public.profiles where id::text = current_setting('audit.test_actor')),
  true
);
select set_config('request.jwt.claim.sub', current_setting('audit.test_actor'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

insert into public.schools (id, name, code, status, is_active)
values ('cccccccc-cccc-4ccc-8ccc-ccccccccccc1', 'P1 foreign role fixture', 'P1-ROLE-FOREIGN', 'active', true);
insert into public.subscriptions (school_id, plan_id, status, billing_cycle, agreed_price)
select 'cccccccc-cccc-4ccc-8ccc-ccccccccccc1', p.id, 'active', 'monthly', p.monthly_price
from public.plans p
where p.active = true
order by p.student_limit
limit 1;
insert into public.courses (id, name, academic_year, school_id)
values (
  'cccccccc-cccc-4ccc-8ccc-ccccccccccc2',
  'P1 foreign course',
  'P1',
  'cccccccc-cccc-4ccc-8ccc-ccccccccccc1'
);
insert into public.students (id, full_name, course_id, school_id, student_cedula)
values (
  'cccccccc-cccc-4ccc-8ccc-ccccccccccc3',
  'P1 foreign student fixture',
  'cccccccc-cccc-4ccc-8ccc-ccccccccccc2',
  'cccccccc-cccc-4ccc-8ccc-ccccccccccc1',
  'P1-ROLE-FOREIGN-STUDENT'
);

-- A platform owner must keep global access even without any tenant membership.
set local role authenticated;
delete from public.tenant_memberships
where user_id::text = current_setting('audit.test_actor');

do $$
begin
  if not public.is_platform_owner() or not public.is_platform_admin() then
    raise exception 'platform owner lost its global authorization';
  end if;
  if not exists (
    select 1 from public.students
    where id = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc3'
  ) then
    raise exception 'platform owner could not read a tenant without membership';
  end if;
end
$$;
reset role;

delete from public.user_platform_roles
where user_id::text = current_setting('audit.test_actor');
update public.profiles
set role = 'teacher', is_active = true
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

set local role authenticated;

do $$
declare
  v_student_id uuid;
  v_definition_id uuid;
  v_course_id uuid;
  v_failed boolean := false;
begin
  if not public.has_tenant_permission('grades.update') then
    raise exception 'teacher should have grades.update';
  end if;
  if public.has_tenant_permission('students.create') then
    raise exception 'teacher must not have students.create';
  end if;
  if exists (
    select 1 from public.students
    where id = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc3'
  ) then
    raise exception 'teacher read a student from a foreign tenant';
  end if;
  if exists (
    select 1 from public.courses
    where id = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc2'
  ) then
    raise exception 'teacher read a course from a foreign tenant';
  end if;

  select g.student_id, g.grade_definition_id, st.course_id
    into v_student_id, v_definition_id, v_course_id
  from public.grades g
  join public.students st on st.id = g.student_id
  join public.grade_definitions gd on gd.id = g.grade_definition_id
  join public.course_subjects cs on cs.id = gd.course_subject_id
  join public.quarters q on q.id = gd.quarter_id
  where st.school_id::text = current_setting('audit.test_school')
    and st.course_id = cs.course_id
    and not coalesce(q.is_locked, false)
  limit 1;

  if v_student_id is null then
    raise exception 'role test requires one unlocked existing grade';
  end if;

  perform public.save_grade_batch(
    jsonb_build_array(jsonb_build_object(
      'student_id', v_student_id,
      'grade_definition_id', v_definition_id,
      'score', 9.10
    )),
    '[]'::jsonb
  );

  begin
    perform public.import_students_batch(
      v_course_id,
      jsonb_build_array(jsonb_build_object(
        'full_name', 'P1 forbidden teacher import',
        'student_cedula', 'P1-ROLE-TEACHER'
      ))
    );
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'teacher imported students without permission';
  end if;

  v_failed := false;
  begin
    perform public.import_students_batch(
      'cccccccc-cccc-4ccc-8ccc-ccccccccccc2',
      jsonb_build_array(jsonb_build_object(
        'full_name', 'P1 forbidden foreign import',
        'student_cedula', 'P1-ROLE-FOREIGN'
      ))
    );
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'teacher wrote to a foreign tenant';
  end if;
end
$$;

reset role;

update public.tenant_memberships tm
set tenant_role_id = tr.id
from public.tenant_roles tr
where tm.user_id::text = current_setting('audit.test_actor')
  and tm.school_id::text = current_setting('audit.test_school')
  and tr.name = 'school_admin';
update public.profiles
set role = 'admin'
where id::text = current_setting('audit.test_actor');

set local role authenticated;

do $$
declare
  v_course_id uuid;
begin
  if not public.has_tenant_permission('students.create') then
    raise exception 'school_admin should have students.create';
  end if;
  if exists (
    select 1 from public.students
    where id = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc3'
  ) then
    raise exception 'school_admin read a student from a foreign tenant';
  end if;

  select id into v_course_id
  from public.courses
  where school_id::text = current_setting('audit.test_school')
  limit 1;

  perform public.import_students_batch(
    v_course_id,
    jsonb_build_array(jsonb_build_object(
      'full_name', 'P1 allowed admin import',
      'student_cedula', 'P1-ROLE-ADMIN'
    ))
  );

  if not exists (
    select 1 from public.students
    where school_id::text = current_setting('audit.test_school')
      and student_cedula = 'P1-ROLE-ADMIN'
  ) then
    raise exception 'school_admin import did not persist inside transaction';
  end if;
end
$$;

reset role;
rollback;
