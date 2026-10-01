begin;

insert into public.schools(id, name, code, status, is_active) values
  ('60000000-0000-4000-8000-000000000001', 'AUDIT estudiante A', 'AUDIT-STUDENT-A', 'active', true),
  ('60000000-0000-4000-8000-000000000002', 'AUDIT estudiante B', 'AUDIT-STUDENT-B', 'active', true);

insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('60000000-0000-4000-8000-000000000010', 'student-admin@example.invalid', '{}', '{}');

insert into public.profiles(id, school_id, role, is_active) values
  ('60000000-0000-4000-8000-000000000010', '60000000-0000-4000-8000-000000000001', 'admin', true);

insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
select '60000000-0000-4000-8000-000000000010', '60000000-0000-4000-8000-000000000001', id, true
from public.tenant_roles where name = 'school_admin';

insert into public.tenant_limits(school_id, max_students) values
  ('60000000-0000-4000-8000-000000000001', 10),
  ('60000000-0000-4000-8000-000000000002', 10);

insert into public.courses(id, school_id, name, academic_year) values
  ('60000000-0000-4000-8000-000000000021', '60000000-0000-4000-8000-000000000001', 'AUDIT curso propio', '2098-2099'),
  ('60000000-0000-4000-8000-000000000022', '60000000-0000-4000-8000-000000000002', 'AUDIT curso ajeno', '2098-2099');

insert into public.students(id, school_id, course_id, full_name, student_cedula) values
  ('60000000-0000-4000-8000-000000000031', '60000000-0000-4000-8000-000000000002', '60000000-0000-4000-8000-000000000022', 'Estudiante ajeno', 'AUDIT-STUDENT-FOREIGN');

select set_config('request.jwt.claim.sub', '60000000-0000-4000-8000-000000000010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_result jsonb;
  v_denied boolean := false;
begin
  v_result := public.save_student_record(
    '60000000-0000-4000-8000-000000000001',
    '60000000-0000-4000-8000-000000000032',
    jsonb_build_object(
      'course_id', '60000000-0000-4000-8000-000000000021',
      'full_name', 'Estudiante creado',
      'student_cedula', 'AUDIT-STUDENT-OWN',
      'student_phone', '0999999999',
      'has_adaptation', false
    )
  );
  if not (v_result->>'success')::boolean
    or v_result->>'action' <> 'created'
    or v_result->>'student_id' <> '60000000-0000-4000-8000-000000000032' then
    raise exception 'Student creation was not confirmed';
  end if;

  v_result := public.save_student_record(
    '60000000-0000-4000-8000-000000000001',
    '60000000-0000-4000-8000-000000000032',
    jsonb_build_object(
      'course_id', '60000000-0000-4000-8000-000000000021',
      'full_name', 'Estudiante actualizado',
      'student_cedula', 'AUDIT-STUDENT-OWN',
      'has_adaptation', true,
      'adaptation_grade', '2',
      'adaptation_details', 'Ajuste sintético'
    )
  );
  if v_result->>'action' <> 'updated'
    or not exists (
      select 1 from public.students
      where id = '60000000-0000-4000-8000-000000000032'
        and school_id = '60000000-0000-4000-8000-000000000001'
        and full_name = 'Estudiante actualizado'
        and adaptation_grade = '2'
    ) then
    raise exception 'Student update was not confirmed';
  end if;

  begin
    perform public.save_student_record(
      '60000000-0000-4000-8000-000000000001',
      '60000000-0000-4000-8000-000000000033',
      jsonb_build_object(
        'course_id', '60000000-0000-4000-8000-000000000022',
        'full_name', 'Cruce prohibido'
      )
    );
  exception when insufficient_privilege then
    v_denied := true;
  end;
  if not v_denied then
    raise exception 'SECURITY: cross-tenant course was accepted';
  end if;
  if exists (select 1 from public.students where id = '60000000-0000-4000-8000-000000000033') then
    raise exception 'Rejected creation left a partial student';
  end if;

  v_denied := false;
  begin
    perform public.save_student_record(
      '60000000-0000-4000-8000-000000000001',
      '60000000-0000-4000-8000-000000000031',
      jsonb_build_object(
        'course_id', '60000000-0000-4000-8000-000000000021',
        'full_name', 'Intento de mover estudiante ajeno'
      )
    );
  exception when insufficient_privilege then
    v_denied := true;
  end;
  if not v_denied then
    raise exception 'SECURITY: foreign student update was accepted';
  end if;
  if not exists (
    select 1 from public.students
    where id = '60000000-0000-4000-8000-000000000031'
      and school_id = '60000000-0000-4000-8000-000000000002'
      and full_name = 'Estudiante ajeno'
  ) then
    raise exception 'Rejected update changed the foreign student';
  end if;
end
$$;

reset role;
rollback;
select 'atomic_student_persistence_tests_passed' as result;
