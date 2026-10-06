begin;

insert into public.schools(id, name, code, status, is_active) values
  ('64000000-0000-4000-8000-000000000001', 'AUDIT materias A', 'AUDIT-SUBJECT-A', 'active', true),
  ('64000000-0000-4000-8000-000000000002', 'AUDIT materias B', 'AUDIT-SUBJECT-B', 'active', true);
insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('64000000-0000-4000-8000-000000000010', 'subject-admin@example.invalid', '{}', '{}');
insert into public.profiles(id, school_id, role, is_active) values
  ('64000000-0000-4000-8000-000000000010', '64000000-0000-4000-8000-000000000001', 'admin', true);
insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
select '64000000-0000-4000-8000-000000000010', '64000000-0000-4000-8000-000000000001', id, true
from public.tenant_roles where name = 'school_admin';
insert into public.courses(id, school_id, name, academic_year) values
  ('64000000-0000-4000-8000-000000000021', '64000000-0000-4000-8000-000000000001', 'AUDIT curso', '2091-2092');
insert into public.subjects(id, school_id, name) values
  ('64000000-0000-4000-8000-000000000031', '64000000-0000-4000-8000-000000000001', 'Materia vinculada'),
  ('64000000-0000-4000-8000-000000000032', '64000000-0000-4000-8000-000000000002', 'Materia ajena');
insert into public.course_subjects(id, school_id, course_id, subject_id) values
  ('64000000-0000-4000-8000-000000000041', '64000000-0000-4000-8000-000000000001', '64000000-0000-4000-8000-000000000021', '64000000-0000-4000-8000-000000000031');

select set_config('request.jwt.claim.sub', '64000000-0000-4000-8000-000000000010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_result jsonb;
  v_subject_id uuid;
  v_failed boolean := false;
begin
  v_result := public.save_subject_record(
    '64000000-0000-4000-8000-000000000001', null, 'Materia creada'
  );
  v_subject_id := (v_result->'subject'->>'id')::uuid;
  if not (v_result->>'success')::boolean or v_result->>'action' <> 'created' or v_subject_id is null then
    raise exception 'Subject creation was not confirmed';
  end if;

  v_result := public.save_subject_record(
    '64000000-0000-4000-8000-000000000001', v_subject_id, 'Materia actualizada'
  );
  if v_result->>'action' <> 'updated' or v_result->'subject'->>'name' <> 'Materia actualizada' then
    raise exception 'Subject update was not confirmed';
  end if;

  v_result := public.import_subjects_batch(
    '64000000-0000-4000-8000-000000000001', array['Materia importada 1', 'Materia importada 2']
  );
  if (v_result->>'inserted_count')::integer <> 2 then raise exception 'Subject import was not confirmed'; end if;

  v_result := public.delete_subject_record('64000000-0000-4000-8000-000000000001', v_subject_id);
  if (v_result->>'deleted_count')::integer <> 1 then raise exception 'Subject deletion was not confirmed'; end if;

  begin
    perform public.delete_subject_record(
      '64000000-0000-4000-8000-000000000001', '64000000-0000-4000-8000-000000000031'
    );
  exception when raise_exception then
    v_failed := true;
  end;
  if not v_failed then raise exception 'Linked subject deletion was accepted'; end if;
  if not exists (select 1 from public.subjects where id = '64000000-0000-4000-8000-000000000031') then
    raise exception 'Rejected linked deletion removed the subject';
  end if;

  v_failed := false;
  begin
    perform public.save_subject_record(
      '64000000-0000-4000-8000-000000000001',
      '64000000-0000-4000-8000-000000000032',
      'Intento ajeno'
    );
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then raise exception 'Cross-tenant subject update was accepted'; end if;
  if not exists (
    select 1 from public.subjects where id = '64000000-0000-4000-8000-000000000032' and name = 'Materia ajena'
  ) then
    raise exception 'Rejected cross-tenant update changed the subject';
  end if;
end
$$;

reset role;
rollback;
select 'secure_subject_catalog_tests_passed' as result;
