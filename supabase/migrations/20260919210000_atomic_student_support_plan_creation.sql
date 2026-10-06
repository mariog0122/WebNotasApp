-- Create a pedagogical support plan with validated tenant relationships.

create or replace function public.create_student_support_plan(
  p_school_id uuid,
  p_student_id uuid,
  p_course_id uuid,
  p_subject_id uuid,
  p_lesson_plan_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_teacher_id uuid := auth.uid();
  v_plan public.student_support_plans;
  v_support_type text := lower(trim(coalesce(p_payload->>'support_type', '')));
  v_observed_difficulty text := nullif(trim(p_payload->>'observed_difficulty'), '');
  v_evidence_type text := lower(trim(coalesce(p_payload->>'evidence_type', '')));
  v_intensity text := lower(trim(coalesce(p_payload->>'intensity', 'moderada')));
  v_duration_weeks integer := coalesce((p_payload->>'duration_weeks')::integer, 2);
  v_status text := lower(trim(coalesce(p_payload->>'status', 'propuesta')));
  v_actions jsonb := p_payload->'proposed_actions';
  v_target_date date := nullif(p_payload->>'target_date', '')::date;
begin
  if v_teacher_id is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;
  if p_school_id is null or p_student_id is null or jsonb_typeof(p_payload) is distinct from 'object' then
    raise exception 'Los datos del plan de apoyo están incompletos' using errcode = '22023';
  end if;
  if not public.can_access_lesson_plan(p_school_id, v_teacher_id) then
    raise exception 'No tienes permiso para crear planes de apoyo en esta institución' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.students s
    where s.id = p_student_id and s.school_id = p_school_id
      and (p_course_id is null or s.course_id = p_course_id)
  ) then
    raise exception 'El estudiante no pertenece al curso y la institución indicados' using errcode = '42501';
  end if;
  if p_course_id is not null and not exists (
    select 1 from public.courses c where c.id = p_course_id and c.school_id = p_school_id
  ) then
    raise exception 'El curso no pertenece a la institución' using errcode = '42501';
  end if;
  if p_subject_id is not null and not exists (
    select 1 from public.subjects subject
    where subject.id = p_subject_id and subject.school_id = p_school_id
  ) then
    raise exception 'La asignatura no pertenece a la institución' using errcode = '42501';
  end if;
  if p_course_id is not null and p_subject_id is not null and not exists (
    select 1 from public.course_subjects cs
    where cs.school_id = p_school_id and cs.course_id = p_course_id and cs.subject_id = p_subject_id
  ) then
    raise exception 'La asignatura no está vinculada al curso' using errcode = '42501';
  end if;
  if p_lesson_plan_id is not null and not exists (
    select 1 from public.lesson_plans lp
    where lp.id = p_lesson_plan_id and lp.school_id = p_school_id
      and (p_course_id is null or lp.course_id = p_course_id)
      and (p_subject_id is null or lp.subject_id = p_subject_id)
  ) then
    raise exception 'La planificación no pertenece al contexto indicado' using errcode = '42501';
  end if;

  if v_support_type not in ('refuerzo', 'recuperacion', 'adecuacion', 'diferenciada', 'profundizacion', 'retroalimentacion', 'comunicacion_familia')
    or v_evidence_type not in ('calificacion', 'rubrica', 'tarea', 'observacion', 'inasistencia')
    or v_intensity not in ('leve', 'moderada', 'intensiva')
    or v_status not in ('propuesta', 'aprobado_docente')
    or v_observed_difficulty is null
    or length(v_observed_difficulty) > 2000
    or v_duration_weeks not between 1 and 52
    or jsonb_typeof(v_actions) is distinct from 'object' then
    raise exception 'El contenido del plan de apoyo no es válido' using errcode = '22023';
  end if;

  insert into public.student_support_plans(
    school_id, lesson_plan_id, student_id, teacher_id, course_id, subject_id,
    support_type, observed_difficulty, evidence_type, intensity, duration_weeks,
    proposed_actions, status, target_date, approved_at, approved_by, observations
  ) values (
    p_school_id, p_lesson_plan_id, p_student_id, v_teacher_id, p_course_id, p_subject_id,
    v_support_type, v_observed_difficulty, v_evidence_type, v_intensity, v_duration_weeks,
    v_actions, v_status, v_target_date,
    case when v_status = 'aprobado_docente' then now() else null end,
    case when v_status = 'aprobado_docente' then v_teacher_id else null end,
    nullif(trim(p_payload->>'observations'), '')
  ) returning * into v_plan;

  if v_plan.id is null or v_plan.school_id is distinct from p_school_id
    or v_plan.student_id is distinct from p_student_id
    or v_plan.teacher_id is distinct from v_teacher_id
    or v_plan.status is distinct from v_status then
    raise exception 'La base de datos no confirmó el plan de apoyo';
  end if;

  insert into public.audit_log(school_id, user_id, action, table_name, record_id, new_values)
  values (
    p_school_id, v_teacher_id, 'STUDENT_SUPPORT_PLAN_CREATED', 'student_support_plans', v_plan.id::text,
    jsonb_build_object('student_id', p_student_id, 'course_id', p_course_id, 'subject_id', p_subject_id,
      'support_type', v_support_type, 'status', v_status)
  );

  return jsonb_build_object('success', true, 'plan', to_jsonb(v_plan));
end;
$$;

revoke all on function public.create_student_support_plan(uuid, uuid, uuid, uuid, uuid, jsonb) from public, anon;
grant execute on function public.create_student_support_plan(uuid, uuid, uuid, uuid, uuid, jsonb) to authenticated, service_role;
revoke insert on public.student_support_plans from authenticated;
