-- Endurece los RPC de la capa de inteligencia añadidos en las fases 1-5.
-- Toda autorización se evalúa contra la institución solicitada para soportar
-- cuentas con varias membresías sin confiar en profiles.school_id.

create or replace function private.has_intelligence_permission(
  p_school_id uuid,
  p_permission text
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private, auth
as $$
  select (select auth.uid()) is not null
    and p_school_id is not null
    and (
      public.has_platform_role(array['platform_owner', 'platform_admin'])
      or exists (
        select 1
        from public.tenant_memberships tm
        join public.tenant_roles tr on tr.id = tm.tenant_role_id
        join public.role_permissions rp on rp.tenant_role_id = tr.id
        join public.permissions p on p.id = rp.permission_id
        join public.schools s on s.id = tm.school_id
        join public.profiles profile on profile.id = tm.user_id
        where tm.user_id = (select auth.uid())
          and tm.school_id = p_school_id
          and tm.is_active
          and coalesce(profile.is_active, true)
          and coalesce(s.is_active, true)
          and s.status::text in ('trial', 'active', 'past_due', 'grace_period')
          and p.code = p_permission
      )
    );
$$;

revoke all on function private.has_intelligence_permission(uuid, text)
  from public, anon, authenticated;

create or replace function public.is_intelligence_module_enabled(p_school_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_value text;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if p_school_id is null then
    return false;
  end if;
  if not (
    public.has_platform_role(array['platform_owner', 'platform_admin'])
    or exists (
      select 1
      from public.tenant_memberships tm
      join public.schools s on s.id = tm.school_id
      join public.profiles profile on profile.id = tm.user_id
      where tm.user_id = auth.uid()
        and tm.school_id = p_school_id
        and tm.is_active
        and coalesce(profile.is_active, true)
        and coalesce(s.is_active, true)
        and s.status::text in ('trial', 'active', 'past_due', 'grace_period')
    )
  ) then
    raise exception 'TENANT_ACCESS_DENIED' using errcode = '42501';
  end if;

  select sc.value into v_value
  from public.system_config sc
  where sc.school_id = p_school_id
    and sc.key = 'intelligence_enabled';

  return lower(coalesce(v_value, 'false')) in ('true', '1', 'enabled', 'on');
end;
$$;

revoke all on function public.is_intelligence_module_enabled(uuid) from public, anon;
grant execute on function public.is_intelligence_module_enabled(uuid) to authenticated;

create or replace function public.get_socratic_rag_context(
  p_school_id uuid,
  p_subject_area text,
  p_grade_level text,
  p_competency_code text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_results jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if not (
    private.has_intelligence_permission(p_school_id, 'students.read')
    or private.has_intelligence_permission(p_school_id, 'grades.read')
  ) then
    raise exception 'INTELLIGENCE_READ_PERMISSION_REQUIRED' using errcode = '42501';
  end if;
  if not public.is_intelligence_module_enabled(p_school_id) then
    raise exception 'INTELLIGENCE_MODULE_DISABLED' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'title', selected.title,
    'content_type', selected.content_type,
    'content', selected.content,
    'competency_code', selected.competency_code
  ) order by selected.tenant_priority, selected.created_at desc), '[]'::jsonb)
  into v_results
  from (
    select corpus.title, corpus.content_type, corpus.content,
      corpus.competency_code, corpus.created_at,
      case when corpus.school_id = p_school_id then 0 else 1 end as tenant_priority
    from public.institutional_curriculum_corpus corpus
    where (corpus.school_id is null or corpus.school_id = p_school_id)
      and corpus.subject_area ilike coalesce(nullif(trim(p_subject_area), ''), 'Matemática')
      and corpus.grade_level ilike coalesce(nullif(trim(p_grade_level), ''), 'Media')
      and (
        p_competency_code is null
        or corpus.competency_code = p_competency_code
        or corpus.competency_code is null
      )
    order by tenant_priority, corpus.created_at desc
    limit 5
  ) selected;

  return v_results;
end;
$$;

revoke all on function public.get_socratic_rag_context(uuid, text, text, text)
  from public, anon;
grant execute on function public.get_socratic_rag_context(uuid, text, text, text)
  to authenticated;

create or replace function public.record_intelligence_ai_trace(
  p_school_id uuid,
  p_use_case text,
  p_model text,
  p_latency_ms integer,
  p_outcome text,
  p_safety_flags jsonb default '{}'::jsonb
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if not (
    private.has_intelligence_permission(p_school_id, 'students.read')
    or private.has_intelligence_permission(p_school_id, 'grades.read')
  ) then
    raise exception 'INTELLIGENCE_READ_PERMISSION_REQUIRED' using errcode = '42501';
  end if;
  if p_use_case not in ('socratic_tutor') then
    raise exception 'INVALID_AI_TRACE_USE_CASE' using errcode = '22023';
  end if;

  insert into public.ai_traces (
    school_id, actor_id, use_case, provider, model, prompt_version,
    latency_ms, outcome, safety_flags
  ) values (
    p_school_id, auth.uid(), p_use_case, 'local',
    left(coalesce(nullif(trim(p_model), ''), 'unknown'), 100), '1.0',
    greatest(coalesce(p_latency_ms, 0), 0),
    left(coalesce(nullif(trim(p_outcome), ''), 'success'), 50),
    coalesce(p_safety_flags, '{}'::jsonb)
  );

  return true;
end;
$$;

revoke all on function public.record_intelligence_ai_trace(uuid, text, text, integer, text, jsonb)
  from public, anon;
grant execute on function public.record_intelligence_ai_trace(uuid, text, text, integer, text, jsonb)
  to authenticated;

create or replace function public.get_school_learning_impact_analytics(
  p_school_id uuid default null,
  p_course_id uuid default null,
  p_subject_name text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_total_enrolled integer := 0;
  v_total_students_assessed integer := 0;
  v_total_gaps integer := 0;
  v_resolved_gaps integer := 0;
  v_closure_rate numeric(5,2) := 0;
  v_mastery_count integer := 0;
  v_in_progress_count integer := 0;
  v_critical_count integer := 0;
  v_bottlenecks jsonb := '[]'::jsonb;
  v_health_index numeric(5,2) := 0;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if not private.has_intelligence_permission(p_school_id, 'reports.read') then
    raise exception 'REPORTS_PERMISSION_REQUIRED' using errcode = '42501';
  end if;
  if p_course_id is not null and not exists (
    select 1 from public.courses c
    where c.id = p_course_id and c.school_id = p_school_id
  ) then
    raise exception 'COURSE_NOT_FOUND_IN_TENANT' using errcode = 'P0002';
  end if;

  select count(*) into v_total_enrolled
  from public.students st
  where st.school_id = p_school_id
    and (p_course_id is null or st.course_id = p_course_id);

  with student_summary as (
    select ms.student_id, avg(ms.mastery_score) as average_mastery
    from public.mastery_state ms
    join public.students st on st.id = ms.student_id and st.school_id = ms.school_id
    join public.competencies comp on comp.id = ms.competency_id
    where ms.school_id = p_school_id
      and (p_course_id is null or st.course_id = p_course_id)
      and (p_subject_name is null or comp.subject_area ilike '%' || split_part(p_subject_name, ' ', 1) || '%')
    group by ms.student_id
  )
  select
    count(*),
    count(*) filter (where average_mastery >= 0.70),
    count(*) filter (where average_mastery >= 0.50 and average_mastery < 0.70),
    count(*) filter (where average_mastery < 0.50)
  into v_total_students_assessed, v_mastery_count, v_in_progress_count, v_critical_count
  from student_summary;

  select
    count(*),
    count(*) filter (where lg.status = 'resolved')
  into v_total_gaps, v_resolved_gaps
  from public.learning_gaps lg
  join public.students st on st.id = lg.student_id and st.school_id = lg.school_id
  join public.competencies comp on comp.id = lg.competency_id
  where lg.school_id = p_school_id
    and (p_course_id is null or st.course_id = p_course_id)
    and (p_subject_name is null or comp.subject_area ilike '%' || split_part(p_subject_name, ' ', 1) || '%');

  if v_total_gaps > 0 then
    v_closure_rate := round((v_resolved_gaps::numeric / v_total_gaps::numeric) * 100, 2);
  end if;
  if (v_mastery_count + v_in_progress_count + v_critical_count) > 0 then
    v_health_index := round(
      ((v_mastery_count + v_in_progress_count * 0.6) /
        (v_mastery_count + v_in_progress_count + v_critical_count)::numeric) * 100,
      1
    );
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'competency_id', ranked.competency_id,
    'code', ranked.code,
    'name', ranked.name,
    'subject_area', ranked.subject_area,
    'active_gaps_count', ranked.active_gaps
  ) order by ranked.active_gaps desc), '[]'::jsonb)
  into v_bottlenecks
  from (
    select comp.id as competency_id, comp.code, comp.name, comp.subject_area,
      count(*) as active_gaps
    from public.learning_gaps lg
    join public.students st on st.id = lg.student_id and st.school_id = lg.school_id
    join public.competencies comp on comp.id = lg.competency_id
    where lg.school_id = p_school_id
      and lg.status in ('open', 'in_recovery')
      and (p_course_id is null or st.course_id = p_course_id)
      and (p_subject_name is null or comp.subject_area ilike '%' || split_part(p_subject_name, ' ', 1) || '%')
    group by comp.id, comp.code, comp.name, comp.subject_area
    order by count(*) desc
    limit 5
  ) ranked;

  return jsonb_build_object(
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
    'bottlenecks', v_bottlenecks,
    'institutional_health_index', v_health_index,
    'generated_at', now()
  );
end;
$$;

revoke all on function public.get_school_learning_impact_analytics(uuid, uuid, text)
  from public, anon;
grant execute on function public.get_school_learning_impact_analytics(uuid, uuid, text)
  to authenticated;

create or replace function public.get_student_longitudinal_passport(
  p_student_id uuid,
  p_school_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_student record;
  v_mastery_records jsonb := '[]'::jsonb;
  v_resolved_gaps jsonb := '[]'::jsonb;
  v_active_gaps jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if p_student_id is null or p_school_id is null then
    raise exception 'STUDENT_AND_SCHOOL_REQUIRED' using errcode = '22023';
  end if;
  if not private.has_intelligence_permission(p_school_id, 'students.read') then
    raise exception 'STUDENTS_PERMISSION_REQUIRED' using errcode = '42501';
  end if;

  select st.id, st.full_name, st.school_id, st.course_id, c.name as course_name
  into v_student
  from public.students st
  left join public.courses c on c.id = st.course_id and c.school_id = st.school_id
  where st.id = p_student_id and st.school_id = p_school_id;
  if not found then
    raise exception 'STUDENT_NOT_FOUND_IN_TENANT' using errcode = 'P0002';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'competency_code', comp.code,
    'competency_name', comp.name,
    'subject_area', comp.subject_area,
    'mastery_score', ms.mastery_score,
    'state', ms.state,
    'last_assessed_at', ms.updated_at
  ) order by comp.subject_area, comp.code), '[]'::jsonb)
  into v_mastery_records
  from public.mastery_state ms
  join public.competencies comp on comp.id = ms.competency_id
  where ms.student_id = p_student_id and ms.school_id = p_school_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'competency_name', comp.name,
    'subject_area', comp.subject_area,
    'resolved_at', lg.closed_at
  )), '[]'::jsonb)
  into v_resolved_gaps
  from public.learning_gaps lg
  join public.competencies comp on comp.id = lg.competency_id
  where lg.student_id = p_student_id
    and lg.school_id = p_school_id
    and lg.status = 'resolved';

  select coalesce(jsonb_agg(jsonb_build_object(
    'competency_name', comp.name,
    'subject_area', comp.subject_area,
    'severity', lg.severity
  )), '[]'::jsonb)
  into v_active_gaps
  from public.learning_gaps lg
  join public.competencies comp on comp.id = lg.competency_id
  where lg.student_id = p_student_id
    and lg.school_id = p_school_id
    and lg.status in ('open', 'in_recovery');

  return jsonb_build_object(
    'student', jsonb_build_object(
      'id', v_student.id,
      'fullName', v_student.full_name,
      'courseName', coalesce(v_student.course_name, 'Sin curso asignado'),
      'schoolId', v_student.school_id
    ),
    'mastery_records', v_mastery_records,
    'resolved_gaps', v_resolved_gaps,
    'active_gaps', v_active_gaps,
    'generated_at', now()
  );
end;
$$;

revoke all on function public.get_student_longitudinal_passport(uuid, uuid)
  from public, anon;
grant execute on function public.get_student_longitudinal_passport(uuid, uuid)
  to authenticated;

create or replace function public.sync_course_gaps_from_grades(
  p_school_id uuid,
  p_course_id uuid,
  p_course_subject_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_student record;
  v_comp record;
  v_score numeric;
  v_subject_name text;
  v_total_students integer := 0;
  v_gaps_created integer := 0;
  v_mastered_created integer := 0;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if not private.has_intelligence_permission(p_school_id, 'grades.update') then
    raise exception 'GRADES_UPDATE_REQUIRED' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.courses c
    where c.id = p_course_id and c.school_id = p_school_id
  ) then
    raise exception 'COURSE_NOT_FOUND_IN_TENANT' using errcode = 'P0002';
  end if;
  if p_course_subject_id is not null then
    select s.name into v_subject_name
    from public.course_subjects cs
    join public.subjects s on s.id = cs.subject_id and s.school_id = cs.school_id
    where cs.id = p_course_subject_id
      and cs.course_id = p_course_id
      and cs.school_id = p_school_id;
    if not found then
      raise exception 'COURSE_SUBJECT_NOT_FOUND_IN_TENANT' using errcode = 'P0002';
    end if;
  end if;
  if not private.has_intelligence_permission(p_school_id, 'settings.manage')
    and not exists (
      select 1 from public.course_subjects cs
      where cs.school_id = p_school_id
        and cs.course_id = p_course_id
        and cs.teacher_id = auth.uid()
        and (p_course_subject_id is null or cs.id = p_course_subject_id)
    ) then
    raise exception 'TEACHER_ASSIGNMENT_REQUIRED' using errcode = '42501';
  end if;

  for v_student in
    select st.id
    from public.students st
    where st.course_id = p_course_id and st.school_id = p_school_id
  loop
    v_total_students := v_total_students + 1;
    select avg(g.score::numeric) into v_score
    from public.grades g
    where g.student_id = v_student.id
      and (p_course_subject_id is null or g.course_subject_id = p_course_subject_id);

    if v_score is not null then
      for v_comp in
        select comp.id
        from public.competencies comp
        where (comp.school_id is null or comp.school_id = p_school_id)
          and (v_subject_name is null or comp.subject_area ilike '%' || split_part(v_subject_name, ' ', 1) || '%')
          and comp.status = 'active'
        order by comp.school_id nulls last, comp.code
        limit 2
      loop
        if v_score < 7 then
          if exists (
            select 1 from public.learning_gaps lg
            where lg.school_id = p_school_id
              and lg.student_id = v_student.id
              and lg.course_id = p_course_id
              and lg.competency_id = v_comp.id
              and lg.status in ('open', 'in_recovery')
          ) then
            update public.learning_gaps
            set severity = case when v_score < 5 then 'critical' else 'high' end,
                priority = round((10 - v_score)::numeric, 2),
                confidence = 0.90
            where school_id = p_school_id
              and student_id = v_student.id
              and course_id = p_course_id
              and competency_id = v_comp.id
              and status in ('open', 'in_recovery');
          else
            insert into public.learning_gaps (
              school_id, student_id, course_id, competency_id, status,
              severity, priority, confidence, opened_at
            ) values (
              p_school_id, v_student.id, p_course_id, v_comp.id, 'open',
              case when v_score < 5 then 'critical' else 'high' end,
              round((10 - v_score)::numeric, 2), 0.90, now()
            );
            v_gaps_created := v_gaps_created + 1;
          end if;
        else
          update public.learning_gaps
          set status = 'resolved', closed_at = coalesce(closed_at, now())
          where school_id = p_school_id
            and student_id = v_student.id
            and course_id = p_course_id
            and competency_id = v_comp.id
            and status in ('open', 'in_recovery');
          v_mastered_created := v_mastered_created + 1;
        end if;

        insert into public.mastery_state (
          school_id, student_id, competency_id, mastery_score, confidence,
          state, last_evidence_at, updated_at
        ) values (
          p_school_id, v_student.id, v_comp.id,
          least(1, greatest(0, round((v_score / 10)::numeric, 2))), 0.90,
          case
            when v_score >= 8.5 then 'MASTERED'
            when v_score >= 7 then 'COMPETENT'
            when v_score >= 5 then 'DEVELOPING'
            else 'NOT_EVIDENCED'
          end,
          now(), now()
        )
        on conflict (school_id, student_id, competency_id) do update set
          mastery_score = excluded.mastery_score,
          confidence = excluded.confidence,
          state = excluded.state,
          last_evidence_at = excluded.last_evidence_at,
          updated_at = excluded.updated_at;
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

revoke all on function public.sync_course_gaps_from_grades(uuid, uuid, uuid)
  from public, anon;
grant execute on function public.sync_course_gaps_from_grades(uuid, uuid, uuid)
  to authenticated;

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
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_student_id uuid;
  v_run_id uuid;
  v_assigned_count integer := 0;
  v_assigned_runs jsonb := '[]'::jsonb;
  v_competency_id uuid;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if not private.has_intelligence_permission(p_school_id, 'grades.update') then
    raise exception 'GRADES_UPDATE_REQUIRED' using errcode = '42501';
  end if;
  if p_student_ids is null or cardinality(p_student_ids) = 0 then
    raise exception 'STUDENTS_REQUIRED' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.courses c
    where c.id = p_course_id and c.school_id = p_school_id
  ) then
    raise exception 'COURSE_NOT_FOUND_IN_TENANT' using errcode = 'P0002';
  end if;
  if not private.has_intelligence_permission(p_school_id, 'settings.manage')
    and not exists (
      select 1 from public.course_subjects cs
      where cs.school_id = p_school_id
        and cs.course_id = p_course_id
        and cs.teacher_id = auth.uid()
    ) then
    raise exception 'TEACHER_ASSIGNMENT_REQUIRED' using errcode = '42501';
  end if;

  select intervention.competency_id into v_competency_id
  from public.interventions intervention
  where intervention.id = p_intervention_id
    and intervention.status = 'active'
    and (intervention.school_id is null or intervention.school_id = p_school_id);
  if not found then
    raise exception 'INTERVENTION_NOT_FOUND_IN_TENANT' using errcode = 'P0002';
  end if;

  if exists (
    select 1
    from unnest(p_student_ids) requested(student_id)
    left join public.students st
      on st.id = requested.student_id
      and st.school_id = p_school_id
      and st.course_id = p_course_id
    where st.id is null
  ) then
    raise exception 'STUDENT_NOT_FOUND_IN_COURSE' using errcode = '42501';
  end if;

  foreach v_student_id in array p_student_ids loop
    v_run_id := null;
    select run.id into v_run_id
    from public.intervention_runs run
    where run.school_id = p_school_id
      and run.intervention_id = p_intervention_id
      and run.teacher_id = auth.uid()
      and run.course_id = p_course_id
      and run.student_id = v_student_id
      and run.outcome = 'in_progress'
    order by run.created_at desc
    limit 1;

    if v_run_id is null then
      insert into public.intervention_runs (
        school_id, intervention_id, teacher_id, course_id, student_id,
        started_at, outcome, notes
      ) values (
        p_school_id, p_intervention_id, auth.uid(), p_course_id, v_student_id,
        now(), 'in_progress', left(nullif(trim(p_notes), ''), 2000)
      )
      returning id into v_run_id;
    end if;

    v_assigned_runs := v_assigned_runs || jsonb_build_array(jsonb_build_object(
      'student_id', v_student_id,
      'run_id', v_run_id
    ));

    update public.learning_gaps
    set status = 'in_recovery'
    where school_id = p_school_id
      and student_id = v_student_id
      and course_id = p_course_id
      and (competency_id = v_competency_id or cause_competency_id = v_competency_id)
      and status = 'open';
    v_assigned_count := v_assigned_count + 1;
  end loop;

  return jsonb_build_object(
    'success', true,
    'assigned_students', v_assigned_count,
    'assigned_runs', v_assigned_runs,
    'competency_id', v_competency_id
  );
end;
$$;

revoke all on function public.assign_pedagogical_intervention(uuid, uuid, uuid, uuid[], text)
  from public, anon;
grant execute on function public.assign_pedagogical_intervention(uuid, uuid, uuid, uuid[], text)
  to authenticated;

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
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_course_id uuid;
  v_resolved boolean := false;
  v_outcome text;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if not private.has_intelligence_permission(p_school_id, 'grades.update') then
    raise exception 'GRADES_UPDATE_REQUIRED' using errcode = '42501';
  end if;
  if p_score is null or p_score < 0 or p_score > 1 then
    raise exception 'INVALID_SCORE_RANGE' using errcode = '22023';
  end if;
  if p_run_id is null then
    raise exception 'INTERVENTION_RUN_REQUIRED' using errcode = '22023';
  end if;

  select st.course_id into v_course_id
  from public.students st
  where st.id = p_student_id and st.school_id = p_school_id;
  if not found then
    raise exception 'STUDENT_NOT_FOUND_IN_TENANT' using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from public.competencies comp
    where comp.id = p_competency_id
      and (comp.school_id is null or comp.school_id = p_school_id)
  ) then
    raise exception 'COMPETENCY_NOT_FOUND_IN_TENANT' using errcode = 'P0002';
  end if;
  if not private.has_intelligence_permission(p_school_id, 'settings.manage')
    and not exists (
      select 1 from public.course_subjects cs
      where cs.school_id = p_school_id
        and cs.course_id = v_course_id
        and cs.teacher_id = auth.uid()
    ) then
    raise exception 'TEACHER_ASSIGNMENT_REQUIRED' using errcode = '42501';
  end if;
  if not exists (
    select 1
    from public.intervention_runs run
    join public.interventions assigned_intervention
      on assigned_intervention.id = run.intervention_id
    where run.id = p_run_id
      and run.school_id = p_school_id
      and run.student_id = p_student_id
      and run.outcome = 'in_progress'
      and assigned_intervention.competency_id = p_competency_id
      and (
        run.teacher_id = auth.uid()
        or private.has_intelligence_permission(p_school_id, 'settings.manage')
      )
  ) then
    raise exception 'INTERVENTION_RUN_ACCESS_DENIED' using errcode = '42501';
  end if;

  insert into public.student_evidence (
    school_id, student_id, competency_id, source, score,
    raw_response, confidence, occurred_at
  ) values (
    p_school_id, p_student_id, p_competency_id, 'observation', p_score,
    p_raw_response, 0.90, now()
  );

  v_resolved := p_score >= 0.70;
  v_outcome := case when v_resolved then 'verified_mastery' else 'needs_further_support' end;

  update public.learning_gaps
  set status = case when v_resolved then 'resolved' else 'in_recovery' end,
      closed_at = case when v_resolved then now() else null end
  where school_id = p_school_id
    and student_id = p_student_id
    and (competency_id = p_competency_id or cause_competency_id = p_competency_id)
    and status in ('open', 'in_recovery');

  insert into public.mastery_state (
    school_id, student_id, competency_id, mastery_score, confidence,
    attempt_count, state, last_evidence_at, updated_at
  ) values (
    p_school_id, p_student_id, p_competency_id, p_score, 0.90, 1,
    case
      when p_score >= 0.85 then 'MASTERED'
      when p_score >= 0.70 then 'COMPETENT'
      when p_score >= 0.50 then 'DEVELOPING'
      else 'NOT_EVIDENCED'
    end,
    now(), now()
  )
  on conflict (school_id, student_id, competency_id) do update set
    mastery_score = excluded.mastery_score,
    confidence = excluded.confidence,
    attempt_count = mastery_state.attempt_count + 1,
    state = excluded.state,
    last_evidence_at = excluded.last_evidence_at,
    updated_at = excluded.updated_at;

  update public.intervention_runs
  set completed_at = now(), outcome = v_outcome
  where id = p_run_id and school_id = p_school_id and student_id = p_student_id;

  return jsonb_build_object(
    'success', true,
    'resolved', v_resolved,
    'outcome', v_outcome,
    'score', p_score
  );
end;
$$;

revoke all on function public.complete_intervention_with_reevaluation(uuid, uuid, uuid, uuid, numeric, text)
  from public, anon;
grant execute on function public.complete_intervention_with_reevaluation(uuid, uuid, uuid, uuid, numeric, text)
  to authenticated;

create or replace function public.get_intelligence_diagnostic_items(
  p_school_id uuid,
  p_subject_area text,
  p_grade_level text default 'Media'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_items jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if not private.has_intelligence_permission(p_school_id, 'students.read') then
    raise exception 'STUDENTS_PERMISSION_REQUIRED' using errcode = '42501';
  end if;
  if not public.is_intelligence_module_enabled(p_school_id) then
    raise exception 'INTELLIGENCE_MODULE_DISABLED' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', selected.id,
    'subject_area', selected.subject_area,
    'grade_level', selected.grade_level,
    'item_type', selected.item_type,
    'stem', selected.stem,
    'options', selected.options,
    'hints', selected.hints,
    'difficulty', selected.difficulty,
    'version', selected.version,
    'competency_id', selected.competency_id
  ) order by selected.difficulty, selected.id), '[]'::jsonb)
  into v_items
  from (
    select ai.id, ai.subject_area, ai.grade_level, ai.item_type, ai.stem,
      ai.options, ai.hints, ai.difficulty, ai.version, mapping.competency_id
    from public.assessment_items ai
    left join lateral (
      select aic.competency_id
      from public.assessment_item_competencies aic
      where aic.assessment_item_id = ai.id
      order by aic.is_primary desc, aic.weight desc, aic.id
      limit 1
    ) mapping on true
    where ai.status = 'active'
      and (ai.school_id is null or ai.school_id = p_school_id)
      and ai.subject_area ilike '%' || split_part(coalesce(nullif(trim(p_subject_area), ''), 'Matemática'), ' ', 1) || '%'
      and (p_grade_level is null or ai.grade_level ilike p_grade_level)
      and mapping.competency_id is not null
    order by ai.difficulty, ai.id
    limit 20
  ) selected;

  return v_items;
end;
$$;

revoke all on function public.get_intelligence_diagnostic_items(uuid, text, text)
  from public, anon;
grant execute on function public.get_intelligence_diagnostic_items(uuid, text, text)
  to authenticated;

create or replace function public.submit_intelligence_diagnostic_answer(
  p_school_id uuid,
  p_student_id uuid,
  p_assessment_item_id uuid,
  p_answer text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_course_id uuid;
  v_correct_answer text;
  v_competency_id uuid;
  v_explanation text;
  v_is_correct boolean;
  v_score numeric;
  v_mastery_score numeric;
  v_confidence numeric;
  v_attempt_count integer;
  v_state text;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if not private.has_intelligence_permission(p_school_id, 'grades.update') then
    raise exception 'GRADES_UPDATE_REQUIRED' using errcode = '42501';
  end if;
  if p_answer is null or trim(p_answer) = '' then
    raise exception 'ANSWER_REQUIRED' using errcode = '22023';
  end if;

  select st.course_id into v_course_id
  from public.students st
  where st.id = p_student_id and st.school_id = p_school_id;
  if not found then
    raise exception 'STUDENT_NOT_FOUND_IN_TENANT' using errcode = 'P0002';
  end if;
  if not private.has_intelligence_permission(p_school_id, 'settings.manage')
    and not exists (
      select 1 from public.course_subjects cs
      where cs.school_id = p_school_id
        and cs.course_id = v_course_id
        and cs.teacher_id = auth.uid()
    ) then
    raise exception 'TEACHER_ASSIGNMENT_REQUIRED' using errcode = '42501';
  end if;

  select ai.correct_answer, ai.explanation, mapping.competency_id
  into v_correct_answer, v_explanation, v_competency_id
  from public.assessment_items ai
  join lateral (
    select aic.competency_id
    from public.assessment_item_competencies aic
    where aic.assessment_item_id = ai.id
    order by aic.is_primary desc, aic.weight desc, aic.id
    limit 1
  ) mapping on true
  where ai.id = p_assessment_item_id
    and ai.status = 'active'
    and (ai.school_id is null or ai.school_id = p_school_id);
  if not found or v_competency_id is null then
    raise exception 'ASSESSMENT_ITEM_NOT_FOUND_IN_TENANT' using errcode = 'P0002';
  end if;

  v_is_correct := lower(trim(p_answer)) = lower(trim(v_correct_answer));
  v_score := case when v_is_correct then 1 else 0 end;

  insert into public.student_evidence (
    school_id, student_id, assessment_item_id, competency_id, source,
    score, raw_response, confidence, occurred_at
  ) values (
    p_school_id, p_student_id, p_assessment_item_id, v_competency_id,
    'diagnostic', v_score, p_answer, 0.85, now()
  );

  select coalesce(avg(se.score), 0), coalesce(avg(se.confidence), 0), count(*)
  into v_mastery_score, v_confidence, v_attempt_count
  from public.student_evidence se
  where se.school_id = p_school_id
    and se.student_id = p_student_id
    and se.competency_id = v_competency_id;

  v_state := case
    when v_mastery_score >= 0.85 then 'MASTERED'
    when v_mastery_score >= 0.70 then 'COMPETENT'
    when v_mastery_score >= 0.50 then 'DEVELOPING'
    else 'NOT_EVIDENCED'
  end;

  insert into public.mastery_state (
    school_id, student_id, competency_id, mastery_score, confidence,
    attempt_count, state, last_evidence_at, updated_at
  ) values (
    p_school_id, p_student_id, v_competency_id, v_mastery_score,
    v_confidence, v_attempt_count, v_state, now(), now()
  )
  on conflict (school_id, student_id, competency_id) do update set
    mastery_score = excluded.mastery_score,
    confidence = excluded.confidence,
    attempt_count = excluded.attempt_count,
    state = excluded.state,
    last_evidence_at = excluded.last_evidence_at,
    updated_at = excluded.updated_at;

  return jsonb_build_object(
    'success', true,
    'is_correct', v_is_correct,
    'score', v_score,
    'explanation', v_explanation,
    'competency_id', v_competency_id
  );
end;
$$;

revoke all on function public.submit_intelligence_diagnostic_answer(uuid, uuid, uuid, text)
  from public, anon;
grant execute on function public.submit_intelligence_diagnostic_answer(uuid, uuid, uuid, text)
  to authenticated;

-- La respuesta correcta nunca debe viajar por PostgREST al navegador.
revoke select on public.assessment_items from anon, authenticated;
grant select (
  id, school_id, subject_area, grade_level, item_type, stem, options,
  explanation, hints, difficulty, status, version, metadata, created_at
) on public.assessment_items to authenticated;

-- Las escrituras de inteligencia se realizan exclusivamente mediante RPC atómicos.
revoke insert, update, delete on public.student_evidence from anon, authenticated;
revoke insert, update, delete on public.mastery_state from anon, authenticated;
revoke insert, update, delete on public.learning_gaps from anon, authenticated;
revoke insert, update, delete on public.intervention_runs from anon, authenticated;
revoke insert, update, delete on public.ai_traces from anon, authenticated;

notify pgrst, 'reload schema';
