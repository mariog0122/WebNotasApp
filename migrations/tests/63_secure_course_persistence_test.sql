begin;

insert into public.schools(id, name, code, status, is_active) values
  ('63000000-0000-4000-8000-000000000001', 'AUDIT curso seguro A', 'AUDIT-COURSE-A', 'active', true),
  ('63000000-0000-4000-8000-000000000002', 'AUDIT curso seguro B', 'AUDIT-COURSE-B', 'active', true);
insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('63000000-0000-4000-8000-000000000010', 'course-admin@example.invalid', '{}', '{}');
insert into public.profiles(id, school_id, role, is_active) values
  ('63000000-0000-4000-8000-000000000010', '63000000-0000-4000-8000-000000000001', 'admin', true);
insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
select '63000000-0000-4000-8000-000000000010', '63000000-0000-4000-8000-000000000001', id, true
from public.tenant_roles where name = 'school_admin';
insert into public.academic_years(id, school_id, name, start_year, end_year, is_current, is_active, is_locked) values
  ('63000000-0000-4000-8000-000000000021', '63000000-0000-4000-8000-000000000001', '2092-2093', 2092, 2093, true, true, false),
  ('63000000-0000-4000-8000-000000000022', '63000000-0000-4000-8000-000000000002', '2092-2093', 2092, 2093, true, true, false);
insert into public.courses(id, school_id, name, academic_year, level, track) values
  ('63000000-0000-4000-8000-000000000031', '63000000-0000-4000-8000-000000000002', 'Curso ajeno', '2092-2093', 'MEDIA', 'BASICA');

select set_config('request.jwt.claim.sub', '63000000-0000-4000-8000-000000000010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_result jsonb;
  v_course_id uuid;
  v_denied boolean := false;
  v_duplicate boolean := false;
begin
  v_result := public.save_course_record(
    '63000000-0000-4000-8000-000000000001',
    null,
    jsonb_build_object('name', 'Octavo A', 'academic_year', '2092-2093', 'level', 'MEDIA', 'track', 'BASICA')
  );
  v_course_id := (v_result->'course'->>'id')::uuid;
  if not (v_result->>'success')::boolean or v_result->>'action' <> 'created' or v_course_id is null then
    raise exception 'Course creation was not confirmed';
  end if;

  v_result := public.save_course_record(
    '63000000-0000-4000-8000-000000000001',
    v_course_id,
    jsonb_build_object('name', 'Octavo A actualizado', 'academic_year', '2092-2093', 'level', 'MEDIA', 'track', 'BASICA')
  );
  if v_result->>'action' <> 'updated'
    or v_result->'course'->>'name' <> 'Octavo A actualizado' then
    raise exception 'Course update was not confirmed';
  end if;

  begin
    perform public.save_course_record(
      '63000000-0000-4000-8000-000000000001',
      '63000000-0000-4000-8000-000000000031',
      jsonb_build_object('name', 'Curso movido', 'academic_year', '2092-2093', 'level', 'MEDIA', 'track', 'BASICA')
    );
  exception when insufficient_privilege then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Cross-tenant course update was accepted'; end if;

  begin
    perform public.save_course_record(
      '63000000-0000-4000-8000-000000000001',
      null,
      jsonb_build_object('name', 'Octavo A actualizado', 'academic_year', '2092-2093', 'level', 'MEDIA', 'track', 'BASICA')
    );
  exception when unique_violation then
    v_duplicate := true;
  end;
  if not v_duplicate then raise exception 'Duplicate course name was accepted'; end if;
  if (select count(*) from public.courses
      where school_id = '63000000-0000-4000-8000-000000000001'
        and academic_year = '2092-2093') <> 1 then
    raise exception 'Rejected duplicate left a partial course';
  end if;
end
$$;

reset role;
rollback;
select 'secure_course_persistence_tests_passed' as result;
