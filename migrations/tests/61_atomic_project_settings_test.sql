begin;

insert into public.schools(id, name, code, status, is_active) values
  ('61000000-0000-4000-8000-000000000001', 'AUDIT configuración proyecto A', 'AUDIT-PSET-A', 'active', true),
  ('61000000-0000-4000-8000-000000000002', 'AUDIT configuración proyecto B', 'AUDIT-PSET-B', 'active', true);
insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('61000000-0000-4000-8000-000000000010', 'project-settings-owner@example.invalid', '{}', '{}');
insert into public.profiles(id, role, is_active) values
  ('61000000-0000-4000-8000-000000000010', 'superadmin', true);
insert into public.user_platform_roles(user_id, platform_role_id)
select '61000000-0000-4000-8000-000000000010', id
from public.platform_roles where name = 'platform_owner';

insert into public.courses(id, school_id, name, academic_year) values
  ('61000000-0000-4000-8000-000000000021', '61000000-0000-4000-8000-000000000001', 'AUDIT curso A', '2094-2095'),
  ('61000000-0000-4000-8000-000000000022', '61000000-0000-4000-8000-000000000002', 'AUDIT curso B', '2094-2095');
insert into public.quarters(id, school_id, name, code, is_active, is_locked) values
  ('61000000-0000-4000-8000-000000000031', '61000000-0000-4000-8000-000000000001', 'Q1', 'Q1', true, false),
  ('61000000-0000-4000-8000-000000000032', '61000000-0000-4000-8000-000000000002', 'Q1', 'Q1', true, false);
insert into public.subjects(id, school_id, name) values
  ('61000000-0000-4000-8000-000000000041', '61000000-0000-4000-8000-000000000001', 'AUDIT materia A1'),
  ('61000000-0000-4000-8000-000000000042', '61000000-0000-4000-8000-000000000001', 'AUDIT materia A2'),
  ('61000000-0000-4000-8000-000000000043', '61000000-0000-4000-8000-000000000002', 'AUDIT materia B');
insert into public.course_subjects(id, school_id, course_id, subject_id) values
  ('61000000-0000-4000-8000-000000000051', '61000000-0000-4000-8000-000000000001', '61000000-0000-4000-8000-000000000021', '61000000-0000-4000-8000-000000000041'),
  ('61000000-0000-4000-8000-000000000052', '61000000-0000-4000-8000-000000000001', '61000000-0000-4000-8000-000000000021', '61000000-0000-4000-8000-000000000042'),
  ('61000000-0000-4000-8000-000000000053', '61000000-0000-4000-8000-000000000002', '61000000-0000-4000-8000-000000000022', '61000000-0000-4000-8000-000000000043');
insert into public.project_settings(course_id, quarter_id, subject_id) values
  ('61000000-0000-4000-8000-000000000021', '61000000-0000-4000-8000-000000000031', '61000000-0000-4000-8000-000000000041');
insert into public.students(id, school_id, course_id, full_name) values
  ('61000000-0000-4000-8000-000000000061', '61000000-0000-4000-8000-000000000001', '61000000-0000-4000-8000-000000000021', 'AUDIT estudiante');
insert into public.project_subject_grades(student_id, course_id, quarter_id, subject_id, score) values
  ('61000000-0000-4000-8000-000000000061', '61000000-0000-4000-8000-000000000021', '61000000-0000-4000-8000-000000000031', '61000000-0000-4000-8000-000000000042', 8.5);

select set_config('request.jwt.claim.sub', '61000000-0000-4000-8000-000000000010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_result jsonb;
  v_failed boolean := false;
begin
  v_result := public.save_project_settings_batch(
    '61000000-0000-4000-8000-000000000021',
    '61000000-0000-4000-8000-000000000031',
    array[
      '61000000-0000-4000-8000-000000000041',
      '61000000-0000-4000-8000-000000000042'
    ]::uuid[]
  );
  if not (v_result->>'success')::boolean or (v_result->>'selected_count')::integer <> 2 then
    raise exception 'Project settings replacement was not confirmed';
  end if;

  begin
    perform public.save_project_settings_batch(
      '61000000-0000-4000-8000-000000000021',
      '61000000-0000-4000-8000-000000000031',
      array['61000000-0000-4000-8000-000000000041']::uuid[]
    );
  exception when raise_exception then
    v_failed := true;
  end;
  if not v_failed then raise exception 'A subject with project grades was removed'; end if;
  if not exists (
    select 1 from public.project_settings
    where course_id = '61000000-0000-4000-8000-000000000021'
      and quarter_id = '61000000-0000-4000-8000-000000000031'
      and subject_id = '61000000-0000-4000-8000-000000000042'
  ) then
    raise exception 'Rejected removal partially changed project settings';
  end if;

  v_failed := false;
  begin
    perform public.save_project_settings_batch(
      '61000000-0000-4000-8000-000000000021',
      '61000000-0000-4000-8000-000000000031',
      array['61000000-0000-4000-8000-000000000043']::uuid[]
    );
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then raise exception 'Cross-tenant project subject was accepted'; end if;
  if (select count(*) from public.project_settings
      where course_id = '61000000-0000-4000-8000-000000000021'
        and quarter_id = '61000000-0000-4000-8000-000000000031') <> 2 then
    raise exception 'Rejected cross-tenant replacement changed project settings';
  end if;
end
$$;

reset role;
rollback;
select 'atomic_project_settings_tests_passed' as result;
