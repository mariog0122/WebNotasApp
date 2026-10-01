-- Datos sintéticos: toda la prueba se revierte, incluidas las cuentas Auth.
begin;

insert into public.schools(id, name, code, status, is_active) values
  ('52000000-0000-4000-8000-000000000001', 'AUDIT bienestar A', 'AUDIT-WELL-A', 'active', true),
  ('52000000-0000-4000-8000-000000000002', 'AUDIT bienestar B', 'AUDIT-WELL-B', 'active', true);

insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('52000000-0000-4000-8000-000000000010', 'wellbeing-a@example.invalid', '{}', '{}');

insert into public.profiles(id, school_id, role, is_active) values
  ('52000000-0000-4000-8000-000000000010', '52000000-0000-4000-8000-000000000001', 'teacher', true)
on conflict(id) do update
set school_id = excluded.school_id, role = excluded.role, is_active = true;

delete from public.user_platform_roles where user_id = '52000000-0000-4000-8000-000000000010';
delete from public.tenant_memberships where user_id = '52000000-0000-4000-8000-000000000010';
insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
select '52000000-0000-4000-8000-000000000010', '52000000-0000-4000-8000-000000000001', id, true
from public.tenant_roles where name = 'teacher';

insert into public.courses(id, school_id, name, academic_year) values
  ('52000000-0000-4000-8000-000000000021', '52000000-0000-4000-8000-000000000001', 'AUDIT curso A', '2098-2099'),
  ('52000000-0000-4000-8000-000000000022', '52000000-0000-4000-8000-000000000002', 'AUDIT curso B', '2098-2099');

insert into public.students(id, school_id, course_id, full_name) values
  ('52000000-0000-4000-8000-000000000031', '52000000-0000-4000-8000-000000000001', '52000000-0000-4000-8000-000000000021', 'AUDIT estudiante A'),
  ('52000000-0000-4000-8000-000000000032', '52000000-0000-4000-8000-000000000002', '52000000-0000-4000-8000-000000000022', 'AUDIT estudiante B');

insert into public.subjects(id, school_id, name) values
  ('52000000-0000-4000-8000-000000000041', '52000000-0000-4000-8000-000000000001', 'AUDIT materia A');

insert into public.course_subjects(course_id, subject_id, school_id, teacher_id) values
  ('52000000-0000-4000-8000-000000000021', '52000000-0000-4000-8000-000000000041', '52000000-0000-4000-8000-000000000001', '52000000-0000-4000-8000-000000000010');

insert into public.quarters(id, school_id, name, is_active) values
  ('52000000-0000-4000-8000-000000000051', '52000000-0000-4000-8000-000000000001', 'AUDIT período A', true),
  ('52000000-0000-4000-8000-000000000052', '52000000-0000-4000-8000-000000000002', 'AUDIT período B', true);

insert into public.student_alerts(
  school_id, student_id, course_id, quarter_id, alert_type, severity,
  description, date_occurred, status
) values (
  '52000000-0000-4000-8000-000000000002',
  '52000000-0000-4000-8000-000000000032',
  '52000000-0000-4000-8000-000000000022',
  '52000000-0000-4000-8000-000000000052',
  'ATRASO', 'LEVE', 'Caso extranjero que nunca debe ser visible.', now(), 'PENDIENTE'
);

select set_config('request.jwt.claim.sub', '52000000-0000-4000-8000-000000000010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_case jsonb;
  v_case_id uuid;
  v_denied boolean;
begin
  v_case := public.create_student_wellbeing_case(jsonb_build_object(
    'school_id', '52000000-0000-4000-8000-000000000001',
    'student_id', '52000000-0000-4000-8000-000000000031',
    'course_id', '52000000-0000-4000-8000-000000000021',
    'quarter_id', '52000000-0000-4000-8000-000000000051',
    'alert_type', 'ATRASO',
    'severity', 'LEVE',
    'description', 'Novedad sintética autorizada para comprobar el aislamiento.',
    'date_occurred', now()
  ));
  v_case_id := (v_case->>'id')::uuid;
  if v_case_id is null then raise exception 'Assigned teacher could not create a wellbeing case'; end if;

  v_denied := false;
  begin
    perform public.create_student_wellbeing_case(jsonb_build_object(
      'school_id', '52000000-0000-4000-8000-000000000002',
      'student_id', '52000000-0000-4000-8000-000000000032',
      'course_id', '52000000-0000-4000-8000-000000000022',
      'quarter_id', '52000000-0000-4000-8000-000000000052',
      'alert_type', 'ATRASO', 'severity', 'LEVE',
      'description', 'Intento cruzado entre instituciones.',
      'date_occurred', now()
    ));
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'SECURITY: foreign institution case accepted'; end if;

  v_denied := false;
  begin
    perform public.update_student_wellbeing_case(v_case_id, 'EN_REVISION', 'Nota no autorizada', null);
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'SECURITY: teacher managed DECE notes'; end if;

  v_denied := false;
  begin
    perform public.register_student_wellbeing_signature(v_case_id, '{}'::jsonb);
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'SECURITY: teacher registered DECE signature'; end if;

  v_denied := false;
  begin
    update public.student_alerts set status = 'ARCHIVADO' where id = v_case_id;
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'SECURITY: direct wellbeing update accepted'; end if;

  if (select count(*) from public.student_alerts where school_id = '52000000-0000-4000-8000-000000000002') <> 0 then
    raise exception 'SECURITY: foreign wellbeing cases visible';
  end if;
end;
$$;

reset role;
update public.tenant_memberships
set tenant_role_id = (select id from public.tenant_roles where name = 'counselor')
where user_id = '52000000-0000-4000-8000-000000000010'
  and school_id = '52000000-0000-4000-8000-000000000001';
set local role authenticated;

do $$
declare
  v_case public.student_alerts%rowtype;
  v_result jsonb;
begin
  select * into v_case
  from public.student_alerts
  where school_id = '52000000-0000-4000-8000-000000000001'
  limit 1;

  v_result := public.update_student_wellbeing_case(
    v_case.id, 'EN_REVISION', 'Seguimiento DECE sintético', 'Compromiso sintético'
  );
  if v_result->>'status' <> 'EN_REVISION' then
    raise exception 'Counselor could not manage wellbeing case';
  end if;

  v_result := public.register_student_wellbeing_signature(
    v_case.id,
    jsonb_build_object(
      'algorithm', 'SHA256withRSA',
      'document_digest', repeat('a', 64),
      'signature_hex', repeat('ab', 128),
      'signed_at', now(),
      'signer_name', 'AUDIT Consejería Estudiantil',
      'canonical_payload', jsonb_build_object(
        'alert_id', v_case.id,
        'student_id', v_case.student_id,
        'alert_type', v_case.alert_type,
        'severity', v_case.severity,
        'description', v_case.description,
        'dece_notes', 'Seguimiento DECE sintético',
        'resolution', 'Compromiso sintético'
      )
    )
  );
  if (v_result->'signature_data'->>'is_valid')::boolean
    or v_result->'signature_data'->>'verification_status' <> 'pending_server_verification' then
    raise exception 'SECURITY: unverified local signature presented as verified';
  end if;
end;
$$;

reset role;
rollback;
select 'student_wellbeing_authorization_tests_passed' as result;
