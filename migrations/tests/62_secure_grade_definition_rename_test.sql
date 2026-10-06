begin;

insert into public.schools(id, name, code, status, is_active) values
  ('62000000-0000-4000-8000-000000000001', 'AUDIT definición A', 'AUDIT-GDEF-A', 'active', true),
  ('62000000-0000-4000-8000-000000000002', 'AUDIT definición B', 'AUDIT-GDEF-B', 'active', true);
insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('62000000-0000-4000-8000-000000000010', 'definition-teacher@example.invalid', '{}', '{}');
insert into public.profiles(id, school_id, role, is_active) values
  ('62000000-0000-4000-8000-000000000010', '62000000-0000-4000-8000-000000000001', 'teacher', true);
insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
select '62000000-0000-4000-8000-000000000010', '62000000-0000-4000-8000-000000000001', id, true
from public.tenant_roles where name = 'teacher';

insert into public.courses(id, school_id, name, academic_year) values
  ('62000000-0000-4000-8000-000000000021', '62000000-0000-4000-8000-000000000001', 'AUDIT curso A', '2093-2094'),
  ('62000000-0000-4000-8000-000000000022', '62000000-0000-4000-8000-000000000002', 'AUDIT curso B', '2093-2094');
insert into public.quarters(id, school_id, name, code, is_active, is_locked) values
  ('62000000-0000-4000-8000-000000000031', '62000000-0000-4000-8000-000000000001', 'Q1', 'Q1', true, false),
  ('62000000-0000-4000-8000-000000000032', '62000000-0000-4000-8000-000000000002', 'Q1', 'Q1', true, false);
insert into public.subjects(id, school_id, name) values
  ('62000000-0000-4000-8000-000000000041', '62000000-0000-4000-8000-000000000001', 'AUDIT materia A'),
  ('62000000-0000-4000-8000-000000000042', '62000000-0000-4000-8000-000000000002', 'AUDIT materia B');
insert into public.course_subjects(id, school_id, course_id, subject_id, teacher_id) values
  ('62000000-0000-4000-8000-000000000051', '62000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000021', '62000000-0000-4000-8000-000000000041', '62000000-0000-4000-8000-000000000010'),
  ('62000000-0000-4000-8000-000000000052', '62000000-0000-4000-8000-000000000002', '62000000-0000-4000-8000-000000000022', '62000000-0000-4000-8000-000000000042', null);
insert into public.grade_definitions(id, school_id, course_subject_id, quarter_id, name, category, sort_order) values
  ('62000000-0000-4000-8000-000000000061', '62000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000051', '62000000-0000-4000-8000-000000000031', 'Lección', 'INDIVIDUAL', 1),
  ('62000000-0000-4000-8000-000000000062', '62000000-0000-4000-8000-000000000002', '62000000-0000-4000-8000-000000000052', '62000000-0000-4000-8000-000000000032', 'Lección ajena', 'INDIVIDUAL', 1);

select set_config('request.jwt.claim.sub', '62000000-0000-4000-8000-000000000010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_result jsonb;
  v_denied boolean := false;
begin
  v_result := public.rename_grade_definition(
    '62000000-0000-4000-8000-000000000061',
    'Evaluación corta'
  );
  if not (v_result->>'success')::boolean
    or v_result->>'name' <> 'Evaluación corta' then
    raise exception 'Grade definition rename was not confirmed';
  end if;

  begin
    perform public.rename_grade_definition(
      '62000000-0000-4000-8000-000000000062',
      'Intento ajeno'
    );
  exception when insufficient_privilege then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Cross-tenant definition rename was accepted'; end if;
  if not exists (
    select 1 from public.grade_definitions
    where id = '62000000-0000-4000-8000-000000000062' and name = 'Lección ajena'
  ) then
    raise exception 'Rejected rename changed the foreign definition';
  end if;
end
$$;

reset role;
update public.quarters set is_locked = true where id = '62000000-0000-4000-8000-000000000031';
set local role authenticated;

do $$
declare
  v_denied boolean := false;
begin
  begin
    perform public.rename_grade_definition(
      '62000000-0000-4000-8000-000000000061',
      'Cambio bloqueado'
    );
  exception when insufficient_privilege then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Locked-quarter definition rename was accepted'; end if;
  if not exists (
    select 1 from public.grade_definitions
    where id = '62000000-0000-4000-8000-000000000061' and name = 'Evaluación corta'
  ) then
    raise exception 'Rejected locked-quarter rename changed the definition';
  end if;
end
$$;

reset role;
rollback;
select 'secure_grade_definition_rename_tests_passed' as result;
