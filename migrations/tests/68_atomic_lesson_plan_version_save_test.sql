begin;

insert into public.schools(id, name, code, status, is_active) values
  ('68000000-0000-4000-8000-000000000001', 'AUDIT planificación A', 'AUDIT-PLAN-A', 'active', true),
  ('68000000-0000-4000-8000-000000000002', 'AUDIT planificación B', 'AUDIT-PLAN-B', 'active', true);
insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('68000000-0000-4000-8000-000000000010', 'plan-teacher@example.invalid', '{}', '{}');
insert into public.profiles(id, school_id, role, is_active) values
  ('68000000-0000-4000-8000-000000000010', '68000000-0000-4000-8000-000000000001', 'admin', true);
insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
select '68000000-0000-4000-8000-000000000010', '68000000-0000-4000-8000-000000000001', id, true
from public.tenant_roles where name = 'school_admin';
insert into public.courses(id, school_id, name, academic_year) values
  ('68000000-0000-4000-8000-000000000021', '68000000-0000-4000-8000-000000000001', 'Noveno A', '2096-2097'),
  ('68000000-0000-4000-8000-000000000022', '68000000-0000-4000-8000-000000000002', 'Noveno B', '2096-2097');
insert into public.lesson_plans(
  id, school_id, teacher_id, course_id, academic_year, title, level, grade_year,
  subject_name, unit_title, topic_title, version, status
) values
  ('68000000-0000-4000-8000-000000000031', '68000000-0000-4000-8000-000000000001',
    '68000000-0000-4000-8000-000000000010', '68000000-0000-4000-8000-000000000021',
    '2096-2097', 'Plan original', 'basica_superior', 'noveno', 'Matemática', 'Unidad 1', 'Fracciones', 1, 'borrador'),
  ('68000000-0000-4000-8000-000000000032', '68000000-0000-4000-8000-000000000002',
    '68000000-0000-4000-8000-000000000010', '68000000-0000-4000-8000-000000000022',
    '2096-2097', 'Plan ajeno', 'basica_superior', 'noveno', 'Matemática', 'Unidad 1', 'Fracciones', 1, 'borrador');

select set_config('request.jwt.claim.sub', '68000000-0000-4000-8000-000000000010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_result jsonb;
  v_stale boolean := false;
  v_denied boolean := false;
begin
  v_result := public.save_lesson_plan_version(
    '68000000-0000-4000-8000-000000000031',
    jsonb_build_object('title', 'Plan actualizado', 'status', 'lista'),
    1
  );
  if not (v_result->>'success')::boolean
    or (v_result->>'version')::integer <> 2
    or not (v_result->>'history_saved')::boolean
    or v_result->'plan'->>'title' <> 'Plan actualizado' then
    raise exception 'Lesson plan update was not fully confirmed';
  end if;
  if (select count(*) from public.lesson_plan_versions
      where lesson_plan_id = '68000000-0000-4000-8000-000000000031' and version_number = 2) <> 1 then
    raise exception 'Lesson plan history was not saved atomically';
  end if;

  begin
    perform public.save_lesson_plan_version(
      '68000000-0000-4000-8000-000000000031', jsonb_build_object('title', 'Escritura obsoleta'), 1
    );
  exception when serialization_failure then v_stale := true;
  end;
  if not v_stale then raise exception 'A stale lesson plan update was accepted'; end if;

  begin
    perform public.save_lesson_plan_version(
      '68000000-0000-4000-8000-000000000032', jsonb_build_object('title', 'Plan invadido'), 1
    );
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'Cross-tenant lesson plan update was accepted'; end if;
  if (select title from public.lesson_plans where id = '68000000-0000-4000-8000-000000000032') <> 'Plan ajeno' then
    raise exception 'Rejected cross-tenant update changed the lesson plan';
  end if;
end
$$;

reset role;
rollback;
select 'atomic_lesson_plan_version_save_tests_passed' as result;
