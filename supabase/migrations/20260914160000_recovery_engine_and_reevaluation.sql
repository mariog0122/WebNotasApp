-- ==============================================================================
-- LOGREVA — CAPA DE INTELIGENCIA DEL APRENDIZAJE (FASE 2: RECOVERY ENGINE & REEVALUACIÓN)
-- Migración aditiva para asignación, ejecución y verificación de cierre de brechas
-- ==============================================================================

-- 1. RPC: ASIGNACIÓN DE GRUPO PEDAGÓGICO E INTERVENCIÓN
create or replace function public.assign_pedagogical_intervention(
  p_school_id uuid,
  p_intervention_id uuid,
  p_course_id uuid,
  p_student_ids uuid[],
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_caller_school_id uuid;
  v_student_id uuid;
  v_assigned_count integer := 0;
  v_run_id uuid;
  v_competency_id uuid;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;

  v_caller_school_id := public.get_user_school_id();
  if not public.is_platform_admin() and (p_school_id is distinct from v_caller_school_id) then
    raise exception 'CROSS_TENANT_ACCESS_DENIED' using errcode = '42501';
  end if;

  -- Obtener la competencia asociada a la intervención
  select competency_id into v_competency_id
  from public.interventions
  where id = p_intervention_id;

  if v_competency_id is null then
    raise exception 'INTERVENTION_NOT_FOUND' using errcode = 'P0002';
  end if;

  -- Registrar ejecución para cada estudiante del grupo
  foreach v_student_id in array p_student_ids loop
    insert into public.intervention_runs (
      school_id,
      intervention_id,
      teacher_id,
      course_id,
      student_id,
      started_at,
      outcome,
      notes
    )
    values (
      p_school_id,
      p_intervention_id,
      auth.uid(),
      p_course_id,
      v_student_id,
      now(),
      'in_progress',
      p_notes
    )
    returning id into v_run_id;

    -- Actualizar estado de la brecha a 'in_recovery'
    update public.learning_gaps
    set status = 'in_recovery'
    where school_id = p_school_id
      and student_id = v_student_id
      and (competency_id = v_competency_id or cause_competency_id = v_competency_id)
      and status = 'open';

    v_assigned_count := v_assigned_count + 1;
  end loop;

  return jsonb_build_object(
    'success', true,
    'assigned_students', v_assigned_count,
    'competency_id', v_competency_id
  );
end;
$$;

revoke all on function public.assign_pedagogical_intervention(uuid, uuid, uuid, uuid[], text) from public, anon;
grant execute on function public.assign_pedagogical_intervention(uuid, uuid, uuid, uuid[], text) to authenticated;

-- 2. RPC: REGISTRO DE REEVALUACIÓN Y VERIFICACIÓN DE CIERRE DE BRECHA
create or replace function public.complete_intervention_with_reevaluation(
  p_school_id uuid,
  p_run_id uuid,
  p_student_id uuid,
  p_competency_id uuid,
  p_score numeric,
  p_raw_response text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_caller_school_id uuid;
  v_is_resolved boolean := false;
  v_outcome text;
  v_new_mastery numeric;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;

  v_caller_school_id := public.get_user_school_id();
  if not public.is_platform_admin() and (p_school_id is distinct from v_caller_school_id) then
    raise exception 'CROSS_TENANT_ACCESS_DENIED' using errcode = '42501';
  end if;

  if p_score < 0 or p_score > 1 then
    raise exception 'INVALID_SCORE_RANGE' using errcode = '22023';
  end if;

  -- 1. Guardar evidencia de reevaluación post-intervención
  insert into public.student_evidence (
    school_id,
    student_id,
    competency_id,
    source,
    score,
    raw_response,
    confidence,
    occurred_at
  )
  values (
    p_school_id,
    p_student_id,
    p_competency_id,
    'observation',
    p_score,
    p_raw_response,
    0.90,
    now()
  );

  -- 2. Evaluar si la brecha fue superada (umbral de dominio >= 0.70)
  if p_score >= 0.70 then
    v_is_resolved := true;
    v_outcome := 'verified_mastery';

    -- Cerrar la brecha
    update public.learning_gaps
    set status = 'resolved',
        closed_at = now()
    where school_id = p_school_id
      and student_id = p_student_id
      and (competency_id = p_competency_id or cause_competency_id = p_competency_id)
      and status in ('open', 'in_recovery');

    -- Actualizar estado a COMPETENT o MASTERED
    update public.mastery_state
    set mastery_score = greatest(mastery_score, p_score),
        state = case when p_score >= 0.85 then 'MASTERED' else 'COMPETENT' end,
        last_evidence_at = now(),
        updated_at = now()
    where school_id = p_school_id
      and student_id = p_student_id
      and competency_id = p_competency_id;
  else
    v_is_resolved := false;
    v_outcome := 'needs_further_support';

    -- Mantener en recuperación
    update public.learning_gaps
    set status = 'in_recovery'
    where school_id = p_school_id
      and student_id = p_student_id
      and (competency_id = p_competency_id or cause_competency_id = p_competency_id);
  end if;

  -- 3. Marcar completada la intervención en intervention_runs
  if p_run_id is not null then
    update public.intervention_runs
    set completed_at = now(),
        outcome = v_outcome
    where id = p_run_id
      and school_id = p_school_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'resolved', v_is_resolved,
    'outcome', v_outcome,
    'score', p_score
  );
end;
$$;

revoke all on function public.complete_intervention_with_reevaluation(uuid, uuid, uuid, uuid, numeric, text) from public, anon;
grant execute on function public.complete_intervention_with_reevaluation(uuid, uuid, uuid, uuid, numeric, text) to authenticated;
