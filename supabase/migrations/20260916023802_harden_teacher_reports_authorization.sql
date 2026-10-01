-- Endurece Informes Docentes para que todas las mutaciones se validen en el
-- servidor y cada relación pertenezca a una sola institución.

update public.teacher_reports tr
set school_id = c.school_id
from public.courses c
where tr.course_id = c.id
  and tr.school_id is null
  and c.school_id is not null;

alter table public.teacher_reports
  drop constraint if exists teacher_reports_school_required;
alter table public.teacher_reports
  add constraint teacher_reports_school_required
  check (school_id is not null) not valid;

do $$
begin
  if not exists (
    select 1 from public.teacher_reports where school_id is null
  ) then
    alter table public.teacher_reports
      validate constraint teacher_reports_school_required;
  end if;
end;
$$;

create or replace function private.can_manage_teacher_report_target(
  p_school_id uuid,
  p_course_id uuid,
  p_subject_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private, auth
as $$
  select private.has_intelligence_permission(p_school_id, 'reports.read')
    and (
      private.has_intelligence_permission(p_school_id, 'settings.manage')
      or exists (
        select 1
        from public.course_subjects cs
        where cs.school_id = p_school_id
          and cs.course_id = p_course_id
          and cs.teacher_id = (select auth.uid())
          and (p_subject_id is null or cs.subject_id = p_subject_id)
      )
    );
$$;

revoke all on function private.can_manage_teacher_report_target(uuid, uuid, uuid)
  from public, anon, authenticated;

create or replace function public.can_read_teacher_report(
  p_school_id uuid,
  p_teacher_id uuid,
  p_course_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private, auth
as $$
  select private.has_intelligence_permission(p_school_id, 'reports.read')
    and (
      private.has_intelligence_permission(p_school_id, 'settings.manage')
      or p_teacher_id = (select auth.uid())
      or exists (
        select 1
        from public.course_subjects cs
        where cs.school_id = p_school_id
          and cs.course_id = p_course_id
          and cs.teacher_id = (select auth.uid())
      )
    );
$$;

revoke all on function public.can_read_teacher_report(uuid, uuid, uuid)
  from public, anon;
grant execute on function public.can_read_teacher_report(uuid, uuid, uuid)
  to authenticated;

create or replace function public.save_teacher_report(p_report jsonb)
returns public.teacher_reports
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_caller_id uuid := auth.uid();
  v_report_id uuid := nullif(p_report->>'id', '')::uuid;
  v_course_id uuid := nullif(p_report->>'course_id', '')::uuid;
  v_subject_id uuid := nullif(p_report->>'subject_id', '')::uuid;
  v_student_id uuid := nullif(p_report->>'student_id', '')::uuid;
  v_quarter_id uuid := nullif(p_report->>'quarter_id', '')::uuid;
  v_school_id uuid;
  v_academic_year text;
  v_existing public.teacher_reports;
  v_result public.teacher_reports;
  v_template_type text := coalesce(nullif(trim(p_report->>'template_type'), ''), 'citacion_representante');
  v_recipient_role text := coalesce(nullif(trim(p_report->>'recipient_role'), ''), 'representante_legal');
  v_status text := coalesce(nullif(trim(p_report->>'status'), ''), 'borrador');
  v_priority text := coalesce(nullif(trim(p_report->>'priority'), ''), 'normal');
  v_reason text := trim(coalesce(p_report->>'reason', ''));
  v_score numeric := nullif(p_report->>'academic_score', '')::numeric;
begin
  if v_caller_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if v_course_id is null or v_student_id is null then
    raise exception 'COURSE_AND_STUDENT_REQUIRED' using errcode = '22023';
  end if;
  if jsonb_typeof(coalesce(p_report->'custom_payload', '{}'::jsonb)) <> 'object' then
    raise exception 'INVALID_CUSTOM_PAYLOAD' using errcode = '22023';
  end if;
  if octet_length(p_report::text) > 65536 then
    raise exception 'REPORT_PAYLOAD_TOO_LARGE' using errcode = '22023';
  end if;

  select c.school_id, c.academic_year
    into v_school_id, v_academic_year
  from public.courses c
  where c.id = v_course_id
    and c.school_id is not null;

  if v_school_id is null then
    raise exception 'COURSE_NOT_FOUND' using errcode = 'P0002';
  end if;
  if not private.has_intelligence_permission(v_school_id, 'reports.read')
     or not private.can_manage_teacher_report_target(v_school_id, v_course_id, v_subject_id) then
    raise exception 'TEACHER_REPORT_ACCESS_DENIED' using errcode = '42501';
  end if;
  if not exists (
    select 1
    from public.students s
    where s.id = v_student_id
      and s.course_id = v_course_id
      and s.school_id = v_school_id
  ) then
    raise exception 'STUDENT_COURSE_MISMATCH' using errcode = '23514';
  end if;
  if v_subject_id is not null and not exists (
    select 1
    from public.course_subjects cs
    where cs.school_id = v_school_id
      and cs.course_id = v_course_id
      and cs.subject_id = v_subject_id
  ) then
    raise exception 'SUBJECT_COURSE_MISMATCH' using errcode = '23514';
  end if;
  if v_quarter_id is not null and not exists (
    select 1
    from public.quarters q
    where q.id = v_quarter_id
      and q.school_id = v_school_id
  ) then
    raise exception 'QUARTER_TENANT_MISMATCH' using errcode = '23514';
  end if;
  if v_template_type <> all (array[
    'citacion_representante', 'informe_rendimiento', 'informe_comportamiento',
    'informe_dece_vicerrectorado', 'acta_compromiso'
  ]) then
    raise exception 'INVALID_REPORT_TEMPLATE' using errcode = '22023';
  end if;
  if v_recipient_role <> all (array[
    'representante_legal', 'dece', 'vicerrectorado', 'inspeccion', 'rectorado', 'tutor'
  ]) then
    raise exception 'INVALID_RECIPIENT_ROLE' using errcode = '22023';
  end if;
  if v_status <> all (array['borrador', 'enviado', 'en_revision', 'atendido', 'archivado']) then
    raise exception 'INVALID_REPORT_STATUS' using errcode = '22023';
  end if;
  if v_priority <> all (array['baja', 'normal', 'alta', 'urgente']) then
    raise exception 'INVALID_REPORT_PRIORITY' using errcode = '22023';
  end if;
  if length(v_reason) < 3 or length(v_reason) > 5000 then
    raise exception 'INVALID_REPORT_REASON' using errcode = '22023';
  end if;
  if v_score is not null and (v_score < 0 or v_score > 10) then
    raise exception 'INVALID_ACADEMIC_SCORE' using errcode = '22023';
  end if;

  if v_report_id is not null then
    select * into v_existing
    from public.teacher_reports tr
    where tr.id = v_report_id;

    if v_existing.id is null then
      raise exception 'REPORT_NOT_FOUND' using errcode = 'P0002';
    end if;
    if v_existing.school_id <> v_school_id then
      raise exception 'REPORT_TENANT_IMMUTABLE' using errcode = '23514';
    end if;
    if not (
      public.has_platform_role(array['platform_owner', 'platform_admin'])
      or private.has_intelligence_permission(v_school_id, 'settings.manage')
      or v_existing.teacher_id = v_caller_id
    ) then
      raise exception 'REPORT_UPDATE_DENIED' using errcode = '42501';
    end if;

    update public.teacher_reports
    set course_id = v_course_id,
        subject_id = v_subject_id,
        student_id = v_student_id,
        academic_year = v_academic_year,
        quarter_id = v_quarter_id,
        template_type = v_template_type,
        title = left(coalesce(nullif(trim(p_report->>'title'), ''), 'Informe Docente'), 200),
        recipient_role = v_recipient_role,
        recipient_name = nullif(left(trim(p_report->>'recipient_name'), 200), ''),
        status = v_status,
        priority = v_priority,
        citation_date = nullif(p_report->>'citation_date', '')::date,
        citation_time = nullif(left(trim(p_report->>'citation_time'), 20), ''),
        citation_location = nullif(left(trim(p_report->>'citation_location'), 300), ''),
        reason = v_reason,
        academic_score = v_score,
        observations = nullif(left(p_report->>'observations', 10000), ''),
        agreements_commitments = nullif(left(p_report->>'agreements_commitments', 10000), ''),
        recommendations = nullif(left(p_report->>'recommendations', 10000), ''),
        custom_payload = coalesce(p_report->'custom_payload', '{}'::jsonb)
    where id = v_report_id
    returning * into v_result;
  else
    insert into public.teacher_reports (
      school_id, course_id, subject_id, student_id, teacher_id, academic_year,
      quarter_id, template_type, title, recipient_role, recipient_name, status,
      priority, citation_date, citation_time, citation_location, reason,
      academic_score, observations, agreements_commitments, recommendations,
      custom_payload
    ) values (
      v_school_id, v_course_id, v_subject_id, v_student_id, v_caller_id, v_academic_year,
      v_quarter_id, v_template_type,
      left(coalesce(nullif(trim(p_report->>'title'), ''), 'Informe Docente'), 200),
      v_recipient_role, nullif(left(trim(p_report->>'recipient_name'), 200), ''),
      v_status, v_priority, nullif(p_report->>'citation_date', '')::date,
      nullif(left(trim(p_report->>'citation_time'), 20), ''),
      nullif(left(trim(p_report->>'citation_location'), 300), ''), v_reason, v_score,
      nullif(left(p_report->>'observations', 10000), ''),
      nullif(left(p_report->>'agreements_commitments', 10000), ''),
      nullif(left(p_report->>'recommendations', 10000), ''),
      coalesce(p_report->'custom_payload', '{}'::jsonb)
    ) returning * into v_result;
  end if;

  return v_result;
end;
$$;

create or replace function public.set_teacher_report_status(
  p_report_id uuid,
  p_status text
)
returns public.teacher_reports
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_report public.teacher_reports;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if p_status <> all (array['borrador', 'enviado', 'en_revision', 'atendido', 'archivado']) then
    raise exception 'INVALID_REPORT_STATUS' using errcode = '22023';
  end if;

  select * into v_report from public.teacher_reports where id = p_report_id;
  if v_report.id is null then
    raise exception 'REPORT_NOT_FOUND' using errcode = 'P0002';
  end if;
  if not private.has_intelligence_permission(v_report.school_id, 'reports.read')
     or not (
       public.has_platform_role(array['platform_owner', 'platform_admin'])
       or private.has_intelligence_permission(v_report.school_id, 'settings.manage')
       or v_report.teacher_id = auth.uid()
     ) then
    raise exception 'REPORT_STATUS_DENIED' using errcode = '42501';
  end if;

  update public.teacher_reports
  set status = p_status
  where id = p_report_id
  returning * into v_report;
  return v_report;
end;
$$;

create or replace function public.delete_teacher_report(p_report_id uuid)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_report public.teacher_reports;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;

  select * into v_report from public.teacher_reports where id = p_report_id;
  if v_report.id is null then
    raise exception 'REPORT_NOT_FOUND' using errcode = 'P0002';
  end if;
  if not private.has_intelligence_permission(v_report.school_id, 'reports.read')
     or not (
       public.has_platform_role(array['platform_owner', 'platform_admin'])
       or private.has_intelligence_permission(v_report.school_id, 'settings.manage')
       or (v_report.teacher_id = auth.uid() and v_report.status = 'borrador')
     ) then
    raise exception 'REPORT_DELETE_DENIED' using errcode = '42501';
  end if;

  delete from public.teacher_reports where id = p_report_id;
  return true;
end;
$$;

revoke all on function public.save_teacher_report(jsonb) from public, anon;
revoke all on function public.set_teacher_report_status(uuid, text) from public, anon;
revoke all on function public.delete_teacher_report(uuid) from public, anon;
grant execute on function public.save_teacher_report(jsonb) to authenticated, service_role;
grant execute on function public.set_teacher_report_status(uuid, text) to authenticated, service_role;
grant execute on function public.delete_teacher_report(uuid) to authenticated, service_role;

drop policy if exists teacher_reports_select on public.teacher_reports;
drop policy if exists teacher_reports_insert on public.teacher_reports;
drop policy if exists teacher_reports_update on public.teacher_reports;
drop policy if exists teacher_reports_delete on public.teacher_reports;

create policy teacher_reports_select on public.teacher_reports
for select to authenticated
using (public.can_read_teacher_report(school_id, teacher_id, course_id));

revoke insert, update, delete on table public.teacher_reports from authenticated;
grant select on table public.teacher_reports to authenticated;
