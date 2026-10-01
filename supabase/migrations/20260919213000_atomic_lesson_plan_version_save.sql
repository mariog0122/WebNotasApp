-- Save a lesson plan and its immutable version snapshot atomically.

create or replace function public.save_lesson_plan_version(
  p_plan_id uuid,
  p_payload jsonb,
  p_expected_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_existing public.lesson_plans;
  v_requested public.lesson_plans;
  v_updated public.lesson_plans;
  v_clean_payload jsonb;
  v_next_version integer;
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;
  if p_plan_id is null or p_expected_version is null or p_expected_version < 1
    or jsonb_typeof(p_payload) is distinct from 'object' then
    raise exception 'Los datos de la planificación están incompletos' using errcode = '22023';
  end if;

  select * into v_existing from public.lesson_plans where id = p_plan_id for update;
  if not found then
    raise exception 'Planificación no encontrada' using errcode = 'P0002';
  end if;
  if not public.can_access_lesson_plan(v_existing.school_id, v_existing.teacher_id) then
    raise exception 'No tienes permiso para actualizar esta planificación' using errcode = '42501';
  end if;
  if v_existing.version is distinct from p_expected_version then
    raise exception 'La planificación fue modificada en otra sesión; recarga antes de guardar' using errcode = '40001';
  end if;

  v_clean_payload := p_payload - array[
    'id', 'school_id', 'teacher_id', 'created_at', 'updated_at', 'version', 'deleted_at'
  ];
  select * into v_requested from jsonb_populate_record(v_existing, v_clean_payload);
  v_next_version := v_existing.version + 1;

  update public.lesson_plans
  set course_id = v_requested.course_id,
      subject_id = v_requested.subject_id,
      academic_year = v_requested.academic_year,
      quarter_id = v_requested.quarter_id,
      title = v_requested.title,
      regime = v_requested.regime,
      level = v_requested.level,
      grade_year = v_requested.grade_year,
      parallel = v_requested.parallel,
      target_age_min = v_requested.target_age_min,
      target_age_max = v_requested.target_age_max,
      students_count = v_requested.students_count,
      duration_minutes = v_requested.duration_minutes,
      session_count = v_requested.session_count,
      estimated_date = v_requested.estimated_date,
      subject_name = v_requested.subject_name,
      unit_title = v_requested.unit_title,
      topic_title = v_requested.topic_title,
      competencies = v_requested.competencies,
      dcd_codes = v_requested.dcd_codes,
      dcd_descriptions = v_requested.dcd_descriptions,
      evaluation_criteria_codes = v_requested.evaluation_criteria_codes,
      evaluation_criteria_descriptions = v_requested.evaluation_criteria_descriptions,
      evaluation_indicators = v_requested.evaluation_indicators,
      learning_objectives = v_requested.learning_objectives,
      bloom_level = v_requested.bloom_level,
      evidence_type = v_requested.evidence_type,
      methodology_primary = v_requested.methodology_primary,
      methodology_secondary = v_requested.methodology_secondary,
      modality = v_requested.modality,
      group_organization = v_requested.group_organization,
      available_resources = v_requested.available_resources,
      context_type = v_requested.context_type,
      evaluation_focus = v_requested.evaluation_focus,
      dua_principles = v_requested.dua_principles,
      pacing_type = v_requested.pacing_type,
      learning_barriers = v_requested.learning_barriers,
      adaptations_needed = v_requested.adaptations_needed,
      adaptations_degree = v_requested.adaptations_degree,
      support_strategies = v_requested.support_strategies,
      content_summary = v_requested.content_summary,
      didactic_sequence = v_requested.didactic_sequence,
      evaluation_plan = v_requested.evaluation_plan,
      inclusion_dua_plan = v_requested.inclusion_dua_plan,
      resources_plan = v_requested.resources_plan,
      status = v_requested.status,
      is_demo = v_requested.is_demo,
      ai_metadata = v_requested.ai_metadata,
      version = v_next_version,
      updated_at = now()
  where id = p_plan_id and version = p_expected_version
  returning * into v_updated;

  if v_updated.id is null or v_updated.version <> v_next_version then
    raise exception 'La base de datos no confirmó la planificación actualizada';
  end if;

  insert into public.lesson_plan_versions(
    lesson_plan_id, version_number, snapshot_content, change_summary, created_by
  ) values (
    p_plan_id,
    v_next_version,
    to_jsonb(v_updated),
    format('Actualización manual de bloques pedagógicos (v%s)', v_next_version),
    auth.uid()
  );

  insert into public.audit_log(school_id, user_id, action, table_name, record_id, new_values)
  values (
    v_updated.school_id, auth.uid(), 'LESSON_PLAN_VERSION_SAVED', 'lesson_plans', p_plan_id::text,
    jsonb_build_object('version', v_next_version, 'status', v_updated.status)
  );

  return jsonb_build_object(
    'success', true,
    'plan', to_jsonb(v_updated),
    'version', v_next_version,
    'history_saved', true
  );
end;
$$;

revoke all on function public.save_lesson_plan_version(uuid, jsonb, integer) from public, anon;
grant execute on function public.save_lesson_plan_version(uuid, jsonb, integer) to authenticated, service_role;
revoke update on public.lesson_plans from authenticated;
revoke insert on public.lesson_plan_versions from authenticated;
