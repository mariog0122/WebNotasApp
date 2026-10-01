begin;

insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('58000000-0000-4000-8000-000000000001', 'restore-owner@example.invalid', '{}', '{}');
insert into public.profiles(id, role, is_active) values
  ('58000000-0000-4000-8000-000000000001', 'superadmin', true);
insert into public.user_platform_roles(user_id, platform_role_id)
select '58000000-0000-4000-8000-000000000001', id
from public.platform_roles where name = 'platform_owner';

insert into public.schools(id, name, code, status, is_active) values
  ('58000000-0000-4000-8000-000000000010', 'AUDIT destino ocupado', 'AUDIT-RESTORE-BUSY', 'active', true);
insert into public.courses(id, school_id, name, academic_year) values
  ('58000000-0000-4000-8000-000000000011', '58000000-0000-4000-8000-000000000010', 'Curso existente', '2096-2097');

select set_config('request.jwt.claim.sub', '58000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_backup jsonb;
  v_result jsonb;
  v_school_id uuid;
  v_denied boolean := false;
begin
  v_backup := jsonb_build_object(
    'system_config', jsonb_build_array(jsonb_build_object('key', 'institution_name', 'value', 'AUDIT restaurada')),
    'tenant_limits', jsonb_build_object('max_students', 900, 'max_users', 80, 'max_teachers', 30),
    'academic_years', jsonb_build_array(jsonb_build_object(
      'id', '58000000-0000-4000-8000-000000000020', 'name', '2096-2097',
      'start_year', 2096, 'end_year', 2097, 'is_active', true, 'is_current', true, 'is_locked', false
    )),
    'quarters', jsonb_build_array(jsonb_build_object(
      'id', '58000000-0000-4000-8000-000000000021', 'name', 'Primer Trimestre',
      'code', 'Q1', 'is_active', true, 'is_locked', false
    )),
    'subjects', jsonb_build_array(jsonb_build_object(
      'id', '58000000-0000-4000-8000-000000000022', 'name', 'Matemática'
    )),
    'courses', jsonb_build_array(jsonb_build_object(
      'id', '58000000-0000-4000-8000-000000000023', 'name', 'Octavo A',
      'academic_year', '2096-2097', 'level', 'Básica', 'track', 'General'
    )),
    'course_subjects', jsonb_build_array(jsonb_build_object(
      'id', '58000000-0000-4000-8000-000000000024',
      'course_id', '58000000-0000-4000-8000-000000000023',
      'subject_id', '58000000-0000-4000-8000-000000000022'
    )),
    'students', jsonb_build_array(jsonb_build_object(
      'id', '58000000-0000-4000-8000-000000000025',
      'course_id', '58000000-0000-4000-8000-000000000023',
      'full_name', 'Estudiante Restaurado', 'student_cedula', 'AUDIT-RESTORE-STUDENT'
    )),
    'grade_definitions', jsonb_build_array(jsonb_build_object(
      'id', '58000000-0000-4000-8000-000000000026',
      'course_subject_id', '58000000-0000-4000-8000-000000000024',
      'quarter_id', '58000000-0000-4000-8000-000000000021',
      'name', 'Tarea 1', 'category', 'INDIVIDUAL', 'sort_order', 1
    )),
    'grades_numeric', jsonb_build_array(jsonb_build_object(
      'student_id', '58000000-0000-4000-8000-000000000025',
      'grade_definition_id', '58000000-0000-4000-8000-000000000026', 'score', 9.5
    )),
    'grades_qualitative', jsonb_build_array(jsonb_build_object(
      'student_id', '58000000-0000-4000-8000-000000000025',
      'course_subject_id', '58000000-0000-4000-8000-000000000024',
      'quarter_id', '58000000-0000-4000-8000-000000000021', 'score_text', 'A+'
    )),
    'supplementary_exams', jsonb_build_array(jsonb_build_object(
      'student_id', '58000000-0000-4000-8000-000000000025',
      'course_subject_id', '58000000-0000-4000-8000-000000000024', 'score', 8.75
    ))
  );

  v_result := public.restore_tenant_academic_backup(
    v_backup, null, 'AUDIT institución restaurada', 'AUDIT-RESTORE-NEW'
  );
  if not (v_result->>'success')::boolean then raise exception 'Restore was not confirmed'; end if;
  v_school_id := (v_result->>'school_id')::uuid;
  if (v_result->>'courses')::integer <> 1
    or (v_result->>'students')::integer <> 1
    or (v_result->>'grades')::integer <> 2 then
    raise exception 'Restore counters do not match the backup';
  end if;
  if (select count(*) from public.courses where school_id = v_school_id) <> 1
    or (select count(*) from public.students where school_id = v_school_id) <> 1
    or (select max_students from public.tenant_limits where school_id = v_school_id) <> 900 then
    raise exception 'Restored tenant data or limits are incomplete';
  end if;
  if not exists (
    select 1
    from public.grades g
    join public.students st on st.id = g.student_id
    join public.grade_definitions gd on gd.id = g.grade_definition_id
    where st.school_id = v_school_id and gd.school_id = v_school_id and g.score = 9.5
  ) then
    raise exception 'Restored numeric grade lost its tenant relationships';
  end if;

  begin
    perform public.restore_tenant_academic_backup(
      jsonb_build_object(
        'courses', jsonb_build_array(jsonb_build_object(
          'id', '58000000-0000-4000-8000-000000000030',
          'name', 'Curso inválido', 'academic_year', '2096-2097'
        )),
        'course_subjects', jsonb_build_array(jsonb_build_object(
          'id', '58000000-0000-4000-8000-000000000031',
          'course_id', '58000000-0000-4000-8000-000000000030',
          'subject_id', '58000000-0000-4000-8000-000000000099'
        ))
      ),
      null, 'AUDIT restauración fallida', 'AUDIT-RESTORE-ROLLBACK'
    );
  exception when others then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Invalid relational backup was accepted'; end if;
  if exists (select 1 from public.schools where code = 'AUDIT-RESTORE-ROLLBACK') then
    raise exception 'Failed restore did not roll back its new school';
  end if;

  v_denied := false;
  begin
    perform public.restore_tenant_academic_backup(
      '{}'::jsonb, '58000000-0000-4000-8000-000000000010', null, null
    );
  exception when unique_violation then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Restore into non-empty tenant was accepted'; end if;
end
$$;

reset role;
rollback;
select 'atomic_tenant_academic_restore_tests_passed' as result;
