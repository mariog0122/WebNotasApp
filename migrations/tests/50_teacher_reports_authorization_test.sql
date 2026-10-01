-- Datos sintéticos. Toda la prueba, incluidas las cuentas Auth, se revierte.
begin;

insert into public.schools(id, name, code, status, is_active) values
  ('50000000-0000-4000-8000-000000000001', 'AUDIT reports A', 'AUDIT-REP-A', 'active', true),
  ('50000000-0000-4000-8000-000000000002', 'AUDIT reports B', 'AUDIT-REP-B', 'active', true);

insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('50000000-0000-4000-8000-000000000010', 'reports-a@example.invalid', '{}', '{}');

insert into public.profiles(id, school_id, role, is_active) values
  ('50000000-0000-4000-8000-000000000010', '50000000-0000-4000-8000-000000000001', 'teacher', true)
on conflict(id) do update
set school_id = excluded.school_id, role = excluded.role, is_active = true;

delete from public.user_platform_roles where user_id = '50000000-0000-4000-8000-000000000010';
delete from public.tenant_memberships where user_id = '50000000-0000-4000-8000-000000000010';
insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
select '50000000-0000-4000-8000-000000000010', '50000000-0000-4000-8000-000000000001', id, true
from public.tenant_roles where name = 'teacher';

insert into public.courses(id, school_id, name, academic_year) values
  ('50000000-0000-4000-8000-000000000021', '50000000-0000-4000-8000-000000000001', 'AUDIT curso A', '2098-2099'),
  ('50000000-0000-4000-8000-000000000022', '50000000-0000-4000-8000-000000000002', 'AUDIT curso B', '2098-2099');

insert into public.students(id, school_id, course_id, full_name) values
  ('50000000-0000-4000-8000-000000000031', '50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000021', 'AUDIT estudiante A'),
  ('50000000-0000-4000-8000-000000000032', '50000000-0000-4000-8000-000000000002', '50000000-0000-4000-8000-000000000022', 'AUDIT estudiante B');

insert into public.subjects(id, school_id, name) values
  ('50000000-0000-4000-8000-000000000041', '50000000-0000-4000-8000-000000000001', 'AUDIT materia A'),
  ('50000000-0000-4000-8000-000000000042', '50000000-0000-4000-8000-000000000002', 'AUDIT materia B');

insert into public.course_subjects(course_id, subject_id, school_id, teacher_id) values
  ('50000000-0000-4000-8000-000000000021', '50000000-0000-4000-8000-000000000041', '50000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000010'),
  ('50000000-0000-4000-8000-000000000022', '50000000-0000-4000-8000-000000000042', '50000000-0000-4000-8000-000000000002', null);

select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_report_id uuid;
  v_denied boolean;
begin
  select id into v_report_id
  from public.save_teacher_report(jsonb_build_object(
    'course_id', '50000000-0000-4000-8000-000000000021',
    'subject_id', '50000000-0000-4000-8000-000000000041',
    'student_id', '50000000-0000-4000-8000-000000000031',
    'template_type', 'citacion_representante',
    'title', 'AUDIT informe válido',
    'recipient_role', 'representante_legal',
    'status', 'borrador',
    'priority', 'normal',
    'reason', 'Validación sintética autorizada'
  ));
  if v_report_id is null then
    raise exception 'Assigned teacher could not create a report';
  end if;

  v_denied := false;
  begin
    perform public.save_teacher_report(jsonb_build_object(
      'course_id', '50000000-0000-4000-8000-000000000021',
      'student_id', '50000000-0000-4000-8000-000000000032',
      'reason', 'Intento cruzado entre instituciones'
    ));
  exception when check_violation then v_denied := true;
  end;
  if not v_denied then raise exception 'SECURITY: foreign student accepted'; end if;

  v_denied := false;
  begin
    perform public.save_teacher_report(jsonb_build_object(
      'course_id', '50000000-0000-4000-8000-000000000022',
      'student_id', '50000000-0000-4000-8000-000000000032',
      'reason', 'Intento en curso de otra institución'
    ));
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'SECURITY: foreign course accepted'; end if;

  v_denied := false;
  begin
    update public.teacher_reports set status = 'archivado' where id = v_report_id;
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'SECURITY: direct report update accepted'; end if;

  perform public.set_teacher_report_status(v_report_id, 'enviado');
  v_denied := false;
  begin
    perform public.delete_teacher_report(v_report_id);
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'SECURITY: teacher deleted a sent report'; end if;

  perform public.set_teacher_report_status(v_report_id, 'borrador');
  if not public.delete_teacher_report(v_report_id) then
    raise exception 'Teacher could not delete own draft';
  end if;
end;
$$;

reset role;
rollback;
select 'teacher_reports_authorization_tests_passed' as result;
