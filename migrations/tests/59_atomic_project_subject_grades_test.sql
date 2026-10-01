begin;

insert into public.schools(id, name, code, status, is_active) values
  ('59000000-0000-4000-8000-000000000001', 'AUDIT proyecto A', 'AUDIT-PROJECT-A', 'active', true),
  ('59000000-0000-4000-8000-000000000002', 'AUDIT proyecto B', 'AUDIT-PROJECT-B', 'active', true);
insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('59000000-0000-4000-8000-000000000010', 'project-owner@example.invalid', '{}', '{}');
insert into public.profiles(id, role, is_active) values
  ('59000000-0000-4000-8000-000000000010', 'superadmin', true);
insert into public.user_platform_roles(user_id, platform_role_id)
select '59000000-0000-4000-8000-000000000010', id
from public.platform_roles where name = 'platform_owner';

insert into public.courses(id, school_id, name, academic_year) values
  ('59000000-0000-4000-8000-000000000021', '59000000-0000-4000-8000-000000000001', 'AUDIT curso A', '2095-2096'),
  ('59000000-0000-4000-8000-000000000022', '59000000-0000-4000-8000-000000000002', 'AUDIT curso B', '2095-2096');
insert into public.quarters(id, school_id, name, code, is_active, is_locked) values
  ('59000000-0000-4000-8000-000000000031', '59000000-0000-4000-8000-000000000001', 'Q1', 'Q1', true, false),
  ('59000000-0000-4000-8000-000000000032', '59000000-0000-4000-8000-000000000002', 'Q1', 'Q1', true, false);
insert into public.subjects(id, school_id, name) values
  ('59000000-0000-4000-8000-000000000041', '59000000-0000-4000-8000-000000000001', 'AUDIT materia A'),
  ('59000000-0000-4000-8000-000000000042', '59000000-0000-4000-8000-000000000002', 'AUDIT materia B');
insert into public.course_subjects(id, school_id, course_id, subject_id) values
  ('59000000-0000-4000-8000-000000000051', '59000000-0000-4000-8000-000000000001', '59000000-0000-4000-8000-000000000021', '59000000-0000-4000-8000-000000000041'),
  ('59000000-0000-4000-8000-000000000052', '59000000-0000-4000-8000-000000000002', '59000000-0000-4000-8000-000000000022', '59000000-0000-4000-8000-000000000042');
insert into public.project_settings(course_id, quarter_id, subject_id) values
  ('59000000-0000-4000-8000-000000000021', '59000000-0000-4000-8000-000000000031', '59000000-0000-4000-8000-000000000041'),
  ('59000000-0000-4000-8000-000000000022', '59000000-0000-4000-8000-000000000032', '59000000-0000-4000-8000-000000000042');
insert into public.students(id, school_id, course_id, full_name) values
  ('59000000-0000-4000-8000-000000000061', '59000000-0000-4000-8000-000000000001', '59000000-0000-4000-8000-000000000021', 'AUDIT estudiante A1'),
  ('59000000-0000-4000-8000-000000000062', '59000000-0000-4000-8000-000000000001', '59000000-0000-4000-8000-000000000021', 'AUDIT estudiante A2'),
  ('59000000-0000-4000-8000-000000000063', '59000000-0000-4000-8000-000000000002', '59000000-0000-4000-8000-000000000022', 'AUDIT estudiante B');
insert into public.project_subject_grades(student_id, course_id, quarter_id, subject_id, score) values
  ('59000000-0000-4000-8000-000000000061', '59000000-0000-4000-8000-000000000021', '59000000-0000-4000-8000-000000000031', '59000000-0000-4000-8000-000000000041', 7.5);

select set_config('request.jwt.claim.sub', '59000000-0000-4000-8000-000000000010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_result jsonb;
  v_failed boolean := false;
begin
  v_result := public.save_project_subject_grades_batch(
    '59000000-0000-4000-8000-000000000021',
    '59000000-0000-4000-8000-000000000031',
    jsonb_build_array(jsonb_build_object(
      'student_id', '59000000-0000-4000-8000-000000000062',
      'subject_id', '59000000-0000-4000-8000-000000000041', 'score', 9.25
    )),
    jsonb_build_array(jsonb_build_object(
      'student_id', '59000000-0000-4000-8000-000000000061',
      'subject_id', '59000000-0000-4000-8000-000000000041'
    ))
  );
  if (v_result->>'upserted')::integer <> 1 or (v_result->>'deleted')::integer <> 1 then
    raise exception 'Project batch result was not confirmed';
  end if;

  begin
    perform public.save_project_subject_grades_batch(
      '59000000-0000-4000-8000-000000000021',
      '59000000-0000-4000-8000-000000000031',
      jsonb_build_array(
        jsonb_build_object('student_id', '59000000-0000-4000-8000-000000000061', 'subject_id', '59000000-0000-4000-8000-000000000041', 'score', 8),
        jsonb_build_object('student_id', '59000000-0000-4000-8000-000000000063', 'subject_id', '59000000-0000-4000-8000-000000000041', 'score', 8)
      ),
      '[]'::jsonb
    );
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then raise exception 'Cross-tenant project batch was accepted'; end if;
  if exists (
    select 1 from public.project_subject_grades
    where student_id = '59000000-0000-4000-8000-000000000061'
      and course_id = '59000000-0000-4000-8000-000000000021'
  ) then
    raise exception 'Failed project batch partially inserted an own-tenant row';
  end if;
end
$$;

reset role;
rollback;
select 'atomic_project_subject_grades_tests_passed' as result;
