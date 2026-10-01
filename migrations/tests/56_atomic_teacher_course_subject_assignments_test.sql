begin;

insert into public.schools(id, name, code, status, is_active) values
  ('56000000-0000-4000-8000-000000000001', 'AUDIT asignaciones A', 'AUDIT-ASG-A', 'active', true),
  ('56000000-0000-4000-8000-000000000002', 'AUDIT asignaciones B', 'AUDIT-ASG-B', 'active', true);
insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('56000000-0000-4000-8000-000000000010', 'assignment-admin@example.invalid', '{}', '{}'),
  ('56000000-0000-4000-8000-000000000011', 'assignment-teacher@example.invalid', '{}', '{}');
insert into public.profiles(id, school_id, role, is_active) values
  ('56000000-0000-4000-8000-000000000010', '56000000-0000-4000-8000-000000000001', 'admin', true),
  ('56000000-0000-4000-8000-000000000011', '56000000-0000-4000-8000-000000000001', 'teacher', true);
insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
select '56000000-0000-4000-8000-000000000010', '56000000-0000-4000-8000-000000000001', id, true
from public.tenant_roles where name = 'school_admin';
insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
select '56000000-0000-4000-8000-000000000011', '56000000-0000-4000-8000-000000000001', id, true
from public.tenant_roles where name = 'teacher';
insert into public.courses(id, school_id, name, academic_year) values
  ('56000000-0000-4000-8000-000000000021', '56000000-0000-4000-8000-000000000001', 'AUDIT curso A', '2098-2099'),
  ('56000000-0000-4000-8000-000000000022', '56000000-0000-4000-8000-000000000002', 'AUDIT curso B', '2098-2099');
insert into public.subjects(id, school_id, name) values
  ('56000000-0000-4000-8000-000000000031', '56000000-0000-4000-8000-000000000001', 'AUDIT materia A'),
  ('56000000-0000-4000-8000-000000000032', '56000000-0000-4000-8000-000000000002', 'AUDIT materia B');
insert into public.course_subjects(id, school_id, course_id, subject_id) values
  ('56000000-0000-4000-8000-000000000041', '56000000-0000-4000-8000-000000000001', '56000000-0000-4000-8000-000000000021', '56000000-0000-4000-8000-000000000031'),
  ('56000000-0000-4000-8000-000000000042', '56000000-0000-4000-8000-000000000002', '56000000-0000-4000-8000-000000000022', '56000000-0000-4000-8000-000000000032');

select set_config('request.jwt.claim.sub', '56000000-0000-4000-8000-000000000010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_result jsonb;
  v_denied boolean := false;
begin
  v_result := public.set_teacher_course_subject_assignments(
    '56000000-0000-4000-8000-000000000011',
    '56000000-0000-4000-8000-000000000001',
    array['56000000-0000-4000-8000-000000000041']::uuid[],
    array['56000000-0000-4000-8000-000000000041']::uuid[]
  );
  if not (v_result->>'success')::boolean then raise exception 'Assignment was not confirmed'; end if;
  if (select teacher_id from public.course_subjects where id = '56000000-0000-4000-8000-000000000041')
     is distinct from '56000000-0000-4000-8000-000000000011'::uuid then
    raise exception 'Teacher assignment was not persisted';
  end if;

  begin
    perform public.set_teacher_course_subject_assignments(
      '56000000-0000-4000-8000-000000000011',
      '56000000-0000-4000-8000-000000000001',
      array['56000000-0000-4000-8000-000000000042']::uuid[],
      array['56000000-0000-4000-8000-000000000042']::uuid[]
    );
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'SECURITY: foreign course subject assignment accepted'; end if;
end
$$;

reset role;
rollback;
select 'atomic_teacher_course_subject_assignments_tests_passed' as result;

