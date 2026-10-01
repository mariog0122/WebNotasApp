-- Datos sintéticos. La transacción completa se revierte.
begin;

insert into public.schools(id, name, code, status, is_active) values
  ('51000000-0000-4000-8000-000000000001', 'AUDIT planning A', 'AUDIT-PLAN-A', 'active', true),
  ('51000000-0000-4000-8000-000000000002', 'AUDIT planning B', 'AUDIT-PLAN-B', 'active', true);

insert into public.subscriptions(school_id, plan_id, status, billing_cycle, agreed_price)
select school.id, plan.id, 'active', 'monthly', plan.monthly_price
from public.schools school
cross join lateral (
  select id, monthly_price from public.plans
  where active = true and student_limit > 0
  order by student_limit limit 1
) plan
where school.code in ('AUDIT-PLAN-A', 'AUDIT-PLAN-B');

insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('51000000-0000-4000-8000-000000000010', 'planning-a@example.invalid', '{}', '{}');
insert into public.profiles(id, school_id, role, is_active) values
  ('51000000-0000-4000-8000-000000000010', '51000000-0000-4000-8000-000000000001', 'teacher', true)
on conflict(id) do update
set school_id = excluded.school_id, role = excluded.role, is_active = true;
delete from public.user_platform_roles where user_id = '51000000-0000-4000-8000-000000000010';
delete from public.tenant_memberships where user_id = '51000000-0000-4000-8000-000000000010';
insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
select '51000000-0000-4000-8000-000000000010', '51000000-0000-4000-8000-000000000001', id, true
from public.tenant_roles where name = 'teacher';

insert into public.tenant_features(school_id, feature_key, enabled) values
  ('51000000-0000-4000-8000-000000000001', 'ai_planning', true),
  ('51000000-0000-4000-8000-000000000002', 'ai_planning', true)
on conflict(school_id, feature_key) do update set enabled = excluded.enabled;
insert into public.institution_ai_settings(
  school_id, mode, provider, model_id, status, is_active,
  monthly_quota_generations, teacher_daily_limit
) values
  ('51000000-0000-4000-8000-000000000001', 'demo', 'demo', 'demo-pedagogico-ec', 'demo', true, 20, 5),
  ('51000000-0000-4000-8000-000000000002', 'demo', 'demo', 'demo-pedagogico-ec', 'demo', true, 20, 5)
on conflict(school_id) do update
set mode = excluded.mode, provider = excluded.provider, model_id = excluded.model_id,
    status = excluded.status, is_active = true;

insert into public.courses(id, school_id, name, academic_year) values
  ('51000000-0000-4000-8000-000000000021', '51000000-0000-4000-8000-000000000001', 'AUDIT curso A', '2098-2099'),
  ('51000000-0000-4000-8000-000000000022', '51000000-0000-4000-8000-000000000002', 'AUDIT curso B', '2098-2099');
insert into public.students(id, school_id, course_id, full_name) values
  ('51000000-0000-4000-8000-000000000031', '51000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000021', 'AUDIT estudiante A'),
  ('51000000-0000-4000-8000-000000000032', '51000000-0000-4000-8000-000000000002', '51000000-0000-4000-8000-000000000022', 'AUDIT estudiante B');
insert into public.subjects(id, school_id, name) values
  ('51000000-0000-4000-8000-000000000041', '51000000-0000-4000-8000-000000000001', 'AUDIT materia A'),
  ('51000000-0000-4000-8000-000000000042', '51000000-0000-4000-8000-000000000002', 'AUDIT materia B');
insert into public.course_subjects(course_id, subject_id, school_id, teacher_id) values
  ('51000000-0000-4000-8000-000000000021', '51000000-0000-4000-8000-000000000041', '51000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000010'),
  ('51000000-0000-4000-8000-000000000022', '51000000-0000-4000-8000-000000000042', '51000000-0000-4000-8000-000000000002', null);

select set_config('request.jwt.claim.sub', '51000000-0000-4000-8000-000000000010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_access jsonb;
  v_plan_id uuid;
  v_denied boolean;
begin
  v_access := public.check_ai_planning_access('51000000-0000-4000-8000-000000000001');
  if not (v_access->>'module_enabled')::boolean or not (v_access->>'is_demo')::boolean then
    raise exception 'Authorized demo planning access was not reported correctly';
  end if;

  v_denied := false;
  begin
    perform public.check_ai_planning_access('51000000-0000-4000-8000-000000000002');
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'SECURITY: foreign planning access accepted'; end if;

  insert into public.lesson_plans(
    school_id, teacher_id, course_id, subject_id, academic_year, title,
    level, grade_year, subject_name, unit_title, topic_title
  ) values (
    '51000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000010',
    '51000000-0000-4000-8000-000000000021', '51000000-0000-4000-8000-000000000041',
    '2098-2099', 'AUDIT plan válido', 'basica_media', '6to_egb',
    'Matemáticas', 'Unidad auditada', 'Tema auditado'
  ) returning id into v_plan_id;

  v_denied := false;
  begin
    insert into public.lesson_plans(
      school_id, teacher_id, course_id, academic_year, title,
      level, grade_year, subject_name, unit_title, topic_title
    ) values (
      '51000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000010',
      '51000000-0000-4000-8000-000000000022', '2098-2099', 'AUDIT cruce',
      'basica_media', '6to_egb', 'Matemáticas', 'Unidad', 'Tema'
    );
  exception when check_violation then v_denied := true;
  end;
  if not v_denied then raise exception 'SECURITY: foreign course linked to plan'; end if;

  v_denied := false;
  begin
    insert into public.lesson_plan_resources(
      school_id, lesson_plan_id, teacher_id, resource_type, title, content, target_students
    ) values (
      '51000000-0000-4000-8000-000000000001', v_plan_id,
      '51000000-0000-4000-8000-000000000010', 'ficha_trabajo', 'AUDIT recurso', '{}',
      array['51000000-0000-4000-8000-000000000032'::uuid]
    );
  exception when check_violation then v_denied := true;
  end;
  if not v_denied then raise exception 'SECURITY: foreign resource student accepted'; end if;

  v_denied := false;
  begin
    insert into public.student_support_plans(
      school_id, lesson_plan_id, student_id, teacher_id, course_id, subject_id,
      support_type, observed_difficulty, evidence_type, proposed_actions
    ) values (
      '51000000-0000-4000-8000-000000000001', v_plan_id,
      '51000000-0000-4000-8000-000000000032', '51000000-0000-4000-8000-000000000010',
      '51000000-0000-4000-8000-000000000021', '51000000-0000-4000-8000-000000000041',
      'refuerzo', 'AUDIT dificultad', 'observacion', '{}'
    );
  exception when check_violation then v_denied := true;
  end;
  if not v_denied then raise exception 'SECURITY: foreign support student accepted'; end if;
end;
$$;

reset role;
rollback;
select 'ai_planning_authorization_tests_passed' as result;
