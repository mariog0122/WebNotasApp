-- ==============================================================================
-- LOGREVA — CAPA DE INTELIGENCIA DEL APRENDIZAJE: REAL DATA BRIDGE & SYNC
-- Migración para corrección de nombres reales de estudiantes (full_name) y
-- sincronización de brechas pedagógicas a partir de calificaciones oficiales.
-- ==============================================================================

-- 1. CORRECCIÓN DE RPC: get_student_longitudinal_passport CON NOMBRE REAL Y CURSO REAL
create or replace function public.get_student_longitudinal_passport(
  p_student_id uuid,
  p_school_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_user_school uuid;
  v_is_admin boolean;
  v_student_id uuid;
  v_student_name text;
  v_student_school uuid;
  v_student_course uuid;
  v_course_name text;
  v_mastery_records jsonb;
  v_resolved_gaps jsonb;
  v_active_gaps jsonb;
  v_result jsonb;
begin
  v_user_school := public.get_user_school_id();
  v_is_admin := public.is_platform_admin();

  if p_school_id is null then
    p_school_id := v_user_school;
  end if;

  -- Búsqueda del estudiante real en students
  select id, full_name, school_id, course_id
  into v_student_id, v_student_name, v_student_school, v_student_course
  from public.students
  where id = p_student_id;

  if not found then
    raise exception 'Estudiante no encontrado en la institución';
  end if;

  if p_school_id is null then
    p_school_id := v_student_school;
  end if;

  -- Validación de Tenancy: asegurar que el usuario pertenece a la escuela del estudiante o es admin
  if not v_is_admin and v_user_school is not null and v_user_school <> v_student_school then
    raise exception 'Acceso denegado: no pertenece a la institución del estudiante';
  end if;

  -- Nombre del curso real
  select name into v_course_name
  from public.courses
  where id = v_student_course;

  -- Competencias y estado de dominio real
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'competency_code', c.code,
        'competency_name', c.name,
        'subject_area', c.subject_area,
        'mastery_score', m.mastery_score,
        'state', m.state,
        'last_assessed_at', m.updated_at
      ) order by c.subject_area, c.code
    ),
    '[]'::jsonb
  ) into v_mastery_records
  from public.mastery_state m
  join public.competencies c on c.id = m.competency_id
  where m.student_id = p_student_id and m.school_id = v_student_school;

  -- Brechas resueltas (recuperaciones verificadas)
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'competency_name', c.name,
        'subject_area', c.subject_area,
        'resolved_at', g.closed_at
      )
    ),
    '[]'::jsonb
  ) into v_resolved_gaps
  from public.learning_gaps g
  join public.competencies c on c.id = g.competency_id
  where g.student_id = p_student_id and g.school_id = v_student_school and g.status = 'resolved';

  -- Brechas activas (requieren apoyo)
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'competency_name', c.name,
        'subject_area', c.subject_area,
        'severity', g.severity
      )
    ),
    '[]'::jsonb
  ) into v_active_gaps
  from public.learning_gaps g
  join public.competencies c on c.id = g.competency_id
  where g.student_id = p_student_id and g.school_id = v_student_school and g.status in ('open', 'in_recovery');

  v_result := jsonb_build_object(
    'student', jsonb_build_object(
      'id', p_student_id,
      'fullName', coalesce(v_student_name, 'Estudiante Sin Nombre'),
      'courseName', coalesce(v_course_name, 'Sin Curso Asignado'),
      'schoolId', v_student_school
    ),
    'mastery_records', v_mastery_records,
    'resolved_gaps', v_resolved_gaps,
    'active_gaps', v_active_gaps,
    'generated_at', now()
  );

  return v_result;
end;
$$;

-- 2. CORRECCIÓN DE RPC: get_school_learning_impact_analytics
create or replace function public.get_school_learning_impact_analytics(
  p_school_id uuid default null,
  p_course_id uuid default null,
  p_subject_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_user_school uuid;
  v_is_admin boolean;
  v_total_enrolled integer := 0;
  v_total_students_assessed integer := 0;
  v_total_gaps integer := 0;
  v_resolved_gaps integer := 0;
  v_closure_rate numeric(5,2) := 0.0;
  v_mastery_count integer := 0;
  v_in_progress_count integer := 0;
  v_critical_count integer := 0;
  v_top_bottlenecks jsonb;
  v_health_index numeric(5,2) := 100.0;
  v_result jsonb;
begin
  v_user_school := public.get_user_school_id();
  v_is_admin := public.is_platform_admin();

  if p_school_id is null then
    p_school_id := v_user_school;
  end if;

  if not v_is_admin and (v_user_school is not null and v_user_school <> p_school_id) then
    raise exception 'Acceso denegado: no pertenece a la institución solicitada';
  end if;

  -- 1. Total de estudiantes matriculados en la institución
  select count(*)
  into v_total_enrolled
  from public.students
  where school_id = p_school_id;

  -- 2. Estudiantes con al menos un estado de dominio
  select count(distinct student_id)
  into v_total_students_assessed
  from public.mastery_state
  where school_id = p_school_id;

  -- 3. Brechas totales y resueltas
  select 
    count(*),
    count(*) filter (where status = 'resolved')
  into v_total_gaps, v_resolved_gaps
  from public.learning_gaps
  where school_id = p_school_id;

  if v_total_gaps > 0 then
    v_closure_rate := round((v_resolved_gaps::numeric / v_total_gaps::numeric) * 100, 2);
  else
    v_closure_rate := 0.0;
  end if;

  -- 4. Distribución de estados
  select
    count(*) filter (where upper(state) in ('MASTERED', 'COMPETENT')),
    count(*) filter (where upper(state) in ('DEVELOPING', 'IN_PROGRESS')),
    count(*) filter (where upper(state) in ('NOT_EVIDENCED', 'AT_RISK_OF_FORGETTING', 'CRITICAL_GAP'))
  into v_mastery_count, v_in_progress_count, v_critical_count
  from public.mastery_state
  where school_id = p_school_id;

  -- Índice de salud curricular institucional real
  if (v_mastery_count + v_in_progress_count + v_critical_count) > 0 then
    v_health_index := round(
      ((v_mastery_count * 1.0 + v_in_progress_count * 0.6) / 
       (v_mastery_count + v_in_progress_count + v_critical_count)::numeric) * 100, 
      1
    );
  else
    v_health_index := 100.0;
  end if;

  -- 5. Cuellos de botella reales
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'competency_id', c.id,
        'code', c.code,
        'name', c.name,
        'subject_area', c.subject_area,
        'active_gaps_count', sub.active_gaps
      )
    ),
    '[]'::jsonb
  ) into v_top_bottlenecks
  from (
    select competency_id, count(*) as active_gaps
    from public.learning_gaps
    where school_id = p_school_id and status in ('open', 'in_recovery')
    group by competency_id
    order by active_gaps desc
    limit 5
  ) sub
  join public.competencies c on c.id = sub.competency_id;

  v_result := jsonb_build_object(
    'school_id', p_school_id,
    'total_enrolled', v_total_enrolled,
    'total_students_assessed', v_total_students_assessed,
    'total_gaps_identified', v_total_gaps,
    'total_gaps_resolved', v_resolved_gaps,
    'gap_closure_rate', v_closure_rate,
    'distribution', jsonb_build_object(
      'mastered', v_mastery_count,
      'in_progress', v_in_progress_count,
      'critical_gap', v_critical_count
    ),
    'bottlenecks', v_top_bottlenecks,
    'institutional_health_index', v_health_index,
    'generated_at', now()
  );

  return v_result;
end;
$$;

-- 3. NUEVO RPC: Sincronización de Brechas desde Calificaciones Oficiales
create or replace function public.sync_course_gaps_from_grades(
  p_school_id uuid,
  p_course_id uuid,
  p_course_subject_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_student record;
  v_comp record;
  v_score numeric;
  v_total_students integer := 0;
  v_gaps_created integer := 0;
  v_mastered_created integer := 0;
  v_subject_name text;
begin
  -- Identificar nombre de la materia si se especificó course_subject_id
  if p_course_subject_id is not null then
    select s.name into v_subject_name
    from public.course_subjects cs
    join public.subjects s on s.id = cs.subject_id
    where cs.id = p_course_subject_id;
  end if;

  -- Buscar competencias asociadas a esta área (o todas las de Matemática por defecto)
  for v_student in
    select id, full_name, school_id
    from public.students
    where course_id = p_course_id and school_id = p_school_id
  loop
    v_total_students := v_total_students + 1;

    -- Obtener promedio real de calificaciones en esta materia o curso
    select avg(score::numeric)
    into v_score
    from public.grades
    where student_id = v_student.id
      and (p_course_subject_id is null or course_subject_id = p_course_subject_id);

    -- Si el estudiante tiene notas reales:
    if v_score is not null then
      -- Buscar la competencia primaria del área curricular
      for v_comp in
        select id, code, name
        from public.competencies
        where (v_subject_name is null or subject_area ilike '%' || split_part(v_subject_name, ' ', 1) || '%')
        limit 2
      loop
        if v_score < 7.00 then
          -- Crear brecha activa
          insert into public.learning_gaps (
            school_id, student_id, course_id, competency_id, status, severity, priority, opened_at
          )
          values (
            p_school_id, v_student.id, p_course_id, v_comp.id, 'open', 
            case when v_score < 5.0 then 'critical' else 'high' end,
            round((10.0 - v_score)::numeric, 2),
            now()
          )
          on conflict do nothing;

          -- Registrar en mastery_state
          insert into public.mastery_state (
            school_id, student_id, competency_id, mastery_score, confidence, state, updated_at
          )
          values (
            p_school_id, v_student.id, v_comp.id, round((v_score / 10.0)::numeric, 2), 0.90,
            case when v_score < 5.0 then 'NOT_EVIDENCED' else 'DEVELOPING' end,
            now()
          )
          on conflict (school_id, student_id, competency_id) do update set
            mastery_score = EXCLUDED.mastery_score,
            state = EXCLUDED.state,
            updated_at = now();

          v_gaps_created := v_gaps_created + 1;
        else
          -- Marcar en dominio
          insert into public.mastery_state (
            school_id, student_id, competency_id, mastery_score, confidence, state, updated_at
          )
          values (
            p_school_id, v_student.id, v_comp.id, round((v_score / 10.0)::numeric, 2), 0.95,
            case when v_score >= 8.5 then 'MASTERED' else 'COMPETENT' end,
            now()
          )
          on conflict (school_id, student_id, competency_id) do update set
            mastery_score = EXCLUDED.mastery_score,
            state = EXCLUDED.state,
            updated_at = now();

          v_mastered_created := v_mastered_created + 1;
        end if;
      end loop;
    end if;
  end loop;

  return jsonb_build_object(
    'success', true,
    'total_students', v_total_students,
    'gaps_created', v_gaps_created,
    'mastered_created', v_mastered_created
  );
end;
$$;

-- Permisos de ejecución: nunca exponer datos educativos a sesiones anónimas.
revoke all on function public.get_student_longitudinal_passport(uuid, uuid) from public, anon;
revoke all on function public.get_school_learning_impact_analytics(uuid, uuid, text) from public, anon;
revoke all on function public.sync_course_gaps_from_grades(uuid, uuid, uuid) from public, anon;
grant execute on function public.get_student_longitudinal_passport(uuid, uuid) to authenticated;
grant execute on function public.get_school_learning_impact_analytics(uuid, uuid, text) to authenticated;
grant execute on function public.sync_course_gaps_from_grades(uuid, uuid, uuid) to authenticated;
