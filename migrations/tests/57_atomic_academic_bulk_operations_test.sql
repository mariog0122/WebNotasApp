begin;

insert into public.schools(id, name, code, status, is_active) values
  ('57000000-0000-4000-8000-000000000001', 'AUDIT lotes académicos A', 'AUDIT-BULK-A', 'active', true),
  ('57000000-0000-4000-8000-000000000002', 'AUDIT lotes académicos B', 'AUDIT-BULK-B', 'active', true);

insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('57000000-0000-4000-8000-000000000010', 'bulk-admin@example.invalid', '{}', '{}');

insert into public.profiles(id, school_id, role, is_active) values
  ('57000000-0000-4000-8000-000000000010', '57000000-0000-4000-8000-000000000001', 'admin', true);

insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
select '57000000-0000-4000-8000-000000000010', '57000000-0000-4000-8000-000000000001', id, true
from public.tenant_roles where name = 'school_admin';

insert into public.courses(id, school_id, name, academic_year) values
  ('57000000-0000-4000-8000-000000000021', '57000000-0000-4000-8000-000000000001', 'AUDIT curso propio 1', '2097-2098'),
  ('57000000-0000-4000-8000-000000000022', '57000000-0000-4000-8000-000000000001', 'AUDIT curso propio 2', '2097-2098'),
  ('57000000-0000-4000-8000-000000000023', '57000000-0000-4000-8000-000000000002', 'AUDIT curso ajeno', '2097-2098');

insert into public.students(id, school_id, course_id, full_name, student_cedula) values
  ('57000000-0000-4000-8000-000000000031', '57000000-0000-4000-8000-000000000001', '57000000-0000-4000-8000-000000000021', 'AUDIT estudiante propio 1', 'AUDIT-BULK-1'),
  ('57000000-0000-4000-8000-000000000032', '57000000-0000-4000-8000-000000000001', '57000000-0000-4000-8000-000000000021', 'AUDIT estudiante propio 2', 'AUDIT-BULK-2'),
  ('57000000-0000-4000-8000-000000000033', '57000000-0000-4000-8000-000000000002', '57000000-0000-4000-8000-000000000023', 'AUDIT estudiante ajeno', 'AUDIT-BULK-3');

select set_config('request.jwt.claim.sub', '57000000-0000-4000-8000-000000000010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_result jsonb;
  v_denied boolean := false;
begin
  v_result := public.delete_students_batch(
    '57000000-0000-4000-8000-000000000001',
    array['57000000-0000-4000-8000-000000000031']::uuid[],
    false
  );
  if not (v_result->>'success')::boolean or (v_result->>'deleted_count')::integer <> 1 then
    raise exception 'Student batch deletion was not confirmed';
  end if;
  if exists (select 1 from public.students where id = '57000000-0000-4000-8000-000000000031') then
    raise exception 'Selected own-tenant student was not deleted';
  end if;

  begin
    perform public.delete_students_batch(
      '57000000-0000-4000-8000-000000000001',
      array[
        '57000000-0000-4000-8000-000000000032',
        '57000000-0000-4000-8000-000000000033'
      ]::uuid[],
      false
    );
  exception when insufficient_privilege then
    v_denied := true;
  end;
  if not v_denied then
    raise exception 'SECURITY: cross-tenant student batch deletion was accepted';
  end if;
  if not exists (select 1 from public.students where id = '57000000-0000-4000-8000-000000000032') then
    raise exception 'Failed student batch changed an own-tenant row';
  end if;

  v_result := public.delete_courses_batch(
    '57000000-0000-4000-8000-000000000001',
    array['57000000-0000-4000-8000-000000000022']::uuid[]
  );
  if not (v_result->>'success')::boolean or (v_result->>'deleted_count')::integer <> 1 then
    raise exception 'Course batch deletion was not confirmed';
  end if;

  v_denied := false;
  begin
    perform public.delete_courses_batch(
      '57000000-0000-4000-8000-000000000001',
      array['57000000-0000-4000-8000-000000000023']::uuid[]
    );
  exception when insufficient_privilege then
    v_denied := true;
  end;
  if not v_denied then
    raise exception 'SECURITY: cross-tenant course deletion was accepted';
  end if;
  if not exists (select 1 from public.courses where id = '57000000-0000-4000-8000-000000000023') then
    raise exception 'Foreign course changed after rejected batch';
  end if;
end
$$;

reset role;
rollback;
select 'atomic_academic_bulk_operations_tests_passed' as result;
