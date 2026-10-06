begin;

insert into public.schools(id, name, code, status, is_active) values
  ('67000000-0000-4000-8000-000000000001', 'AUDIT apoyo pedagógico A', 'AUDIT-SUPPORT-A', 'active', true),
  ('67000000-0000-4000-8000-000000000002', 'AUDIT apoyo pedagógico B', 'AUDIT-SUPPORT-B', 'active', true);
insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('67000000-0000-4000-8000-000000000010', 'support-teacher@example.invalid', '{}', '{}');
insert into public.profiles(id, school_id, role, is_active) values
  ('67000000-0000-4000-8000-000000000010', '67000000-0000-4000-8000-000000000001', 'admin', true);
insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
select '67000000-0000-4000-8000-000000000010', '67000000-0000-4000-8000-000000000001', id, true
from public.tenant_roles where name = 'school_admin';
insert into public.courses(id, school_id, name, academic_year) values
  ('67000000-0000-4000-8000-000000000021', '67000000-0000-4000-8000-000000000001', 'Octavo A', '2095-2096'),
  ('67000000-0000-4000-8000-000000000022', '67000000-0000-4000-8000-000000000002', 'Octavo B', '2095-2096');
insert into public.students(id, school_id, course_id, full_name) values
  ('67000000-0000-4000-8000-000000000031', '67000000-0000-4000-8000-000000000001', '67000000-0000-4000-8000-000000000021', 'Estudiante propio'),
  ('67000000-0000-4000-8000-000000000032', '67000000-0000-4000-8000-000000000002', '67000000-0000-4000-8000-000000000022', 'Estudiante ajeno');

select set_config('request.jwt.claim.sub', '67000000-0000-4000-8000-000000000010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_result jsonb;
  v_denied boolean := false;
  v_invalid boolean := false;
begin
  v_result := public.create_student_support_plan(
    '67000000-0000-4000-8000-000000000001', '67000000-0000-4000-8000-000000000031',
    '67000000-0000-4000-8000-000000000021', null, null,
    jsonb_build_object('support_type', 'refuerzo', 'observed_difficulty', 'Necesita consolidar destrezas matemáticas.',
      'evidence_type', 'calificacion', 'intensity', 'moderada', 'duration_weeks', 2,
      'proposed_actions', jsonb_build_object('diagnostic', 'Diagnóstico confirmado'), 'status', 'propuesta')
  );
  if not (v_result->>'success')::boolean
    or v_result->'plan'->>'student_id' <> '67000000-0000-4000-8000-000000000031'
    or v_result->'plan'->>'teacher_id' <> '67000000-0000-4000-8000-000000000010'
    or v_result->'plan'->>'status' <> 'propuesta' then
    raise exception 'Student support plan creation was not confirmed';
  end if;

  begin
    perform public.create_student_support_plan(
      '67000000-0000-4000-8000-000000000002', '67000000-0000-4000-8000-000000000032',
      '67000000-0000-4000-8000-000000000022', null, null,
      jsonb_build_object('support_type', 'refuerzo', 'observed_difficulty', 'Intento ajeno',
        'evidence_type', 'calificacion', 'proposed_actions', jsonb_build_object('diagnostic', 'No debe guardarse'))
    );
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'Cross-tenant support plan was accepted'; end if;

  begin
    perform public.create_student_support_plan(
      '67000000-0000-4000-8000-000000000001', '67000000-0000-4000-8000-000000000031',
      '67000000-0000-4000-8000-000000000021', null, null,
      jsonb_build_object('support_type', 'tipo_inexistente', 'observed_difficulty', 'Contenido inválido',
        'evidence_type', 'calificacion', 'proposed_actions', jsonb_build_object('diagnostic', 'No debe guardarse'))
    );
  exception when invalid_parameter_value then v_invalid := true;
  end;
  if not v_invalid then raise exception 'Invalid support type was accepted'; end if;
  if (select count(*) from public.student_support_plans
      where school_id = '67000000-0000-4000-8000-000000000001') <> 1 then
    raise exception 'Rejected support plan left partial data';
  end if;
end
$$;

reset role;
rollback;
select 'atomic_student_support_plan_creation_tests_passed' as result;
