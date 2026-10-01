-- Targeted fix; preserve RPC signatures. No records are deleted or merged.
-- Abort on existing invalid/duplicate records rather than silently changing them.
alter table public.attendance_records alter column school_id set not null;
alter table public.attendance_records add constraint attendance_status_valid
 check (status in ('presente','atraso','falta_injustificada','falta_justificada','fuga'));
alter table public.attendance_records drop constraint unique_student_attendance_entry;
alter table public.attendance_records add constraint unique_student_attendance_entry
 unique nulls not distinct (student_id,attendance_date,course_id,subject_id,hour_block);

create or replace function private.assert_attendance_access(p_course_id uuid,p_subject_id uuid)
returns void language plpgsql security invoker set search_path=pg_catalog,public,auth as $$
declare c public.courses; y record; begin
  if auth.uid() is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  select * into c from public.courses where id=p_course_id for share;
  if c.id is null then raise exception 'ATTENDANCE_ACCESS_DENIED' using errcode='42501'; end if;
  if not public.is_platform_admin() then
    if c.school_id is distinct from public.get_user_school_id()
      or not public.has_tenant_permission('attendance.manage') then
      raise exception 'ATTENDANCE_ACCESS_DENIED' using errcode='42501';
    end if;
    if not public.has_tenant_permission('settings.manage') and not exists (
      select 1 from public.course_subjects cs where cs.school_id=c.school_id and cs.course_id=c.id
        and cs.teacher_id=auth.uid() and (p_subject_id is null or cs.subject_id=p_subject_id)
    ) then raise exception 'ATTENDANCE_ASSIGNMENT_REQUIRED' using errcode='42501'; end if;
  end if;
  if p_subject_id is not null and not exists (
    select 1 from public.course_subjects cs join public.subjects s on s.id=cs.subject_id
    where cs.course_id=c.id and cs.school_id=c.school_id and s.school_id=c.school_id and s.id=p_subject_id
  ) then raise exception 'ATTENDANCE_SUBJECT_MISMATCH' using errcode='42501'; end if;
  -- Keep a year lock stable for the duration of this write transaction.
  for y in select is_locked from public.academic_years where school_id=c.school_id and name=c.academic_year for share loop
    if y.is_locked then raise exception 'ACADEMIC_YEAR_LOCKED' using errcode='42501'; end if;
  end loop;
end $$;
revoke all on function private.assert_attendance_access(uuid,uuid) from public,anon,authenticated;

create or replace function public.save_attendance_batch(
 p_course_id uuid,p_subject_id uuid,p_date date,p_hour_block text,p_records jsonb
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,auth as $$
declare c public.courses; r record; q record; default_quarter uuid; target_quarter uuid; saved integer:=0; begin
  perform private.assert_attendance_access(p_course_id,p_subject_id);
  if p_date is null or jsonb_typeof(p_records) is distinct from 'array' then
    raise exception 'INVALID_ATTENDANCE_BATCH' using errcode='22023';
  end if;
  if jsonb_array_length(p_records)>1000 or coalesce(p_hour_block,'jornada_completa') not in ('jornada_completa','1','2','3','4','5','6','7') then
    raise exception 'INVALID_ATTENDANCE_BATCH' using errcode='22023';
  end if;
  if (select count(distinct x->>'student_id') from jsonb_array_elements(p_records) x) <> jsonb_array_length(p_records) then
    raise exception 'DUPLICATE_OR_MISSING_STUDENT' using errcode='22023';
  end if;
  select * into c from public.courses where id=p_course_id;
  select id into default_quarter from public.quarters where school_id=c.school_id and is_active=true order by id limit 1;
  for r in select * from jsonb_to_recordset(p_records) as x(student_id uuid,status text,observations text,quarter_id uuid) loop
    -- Lock the student against a simultaneous transfer to another course.
    perform 1 from public.students where id=r.student_id and course_id=c.id and school_id=c.school_id for share;
    if not found then raise exception 'ATTENDANCE_STUDENT_MISMATCH' using errcode='42501'; end if;
    if r.status is null or r.status not in ('presente','atraso','falta_injustificada','falta_justificada','fuga') or length(r.observations)>4000 then
      raise exception 'INVALID_ATTENDANCE_RECORD' using errcode='22023';
    end if;
    target_quarter:=coalesce(r.quarter_id,default_quarter);
    if target_quarter is not null then
      select * into q from public.quarters where id=target_quarter and school_id=c.school_id for share;
      if not found or coalesce(q.is_locked,false) then raise exception 'INVALID_OR_LOCKED_ATTENDANCE_QUARTER' using errcode='42501'; end if;
    end if;
    -- An old entry cannot be rewritten by supplying a different, unlocked quarter.
    if exists(select 1 from public.attendance_records a join public.quarters pq on pq.id=a.quarter_id
      where a.student_id=r.student_id and a.course_id=c.id and a.attendance_date=p_date
        and a.subject_id is not distinct from p_subject_id and a.hour_block=coalesce(p_hour_block,'jornada_completa') and pq.is_locked) then
      raise exception 'ATTENDANCE_QUARTER_LOCKED' using errcode='42501';
    end if;
    insert into public.attendance_records(school_id,course_id,subject_id,student_id,teacher_id,attendance_date,hour_block,status,observations,academic_year,quarter_id)
    values(c.school_id,c.id,p_subject_id,r.student_id,auth.uid(),p_date,coalesce(p_hour_block,'jornada_completa'),r.status,r.observations,c.academic_year,target_quarter)
    on conflict(student_id,attendance_date,course_id,subject_id,hour_block) do update
      set status=excluded.status,observations=excluded.observations,teacher_id=auth.uid(),updated_at=now();
    saved:=saved+1;
  end loop;
  return jsonb_build_object('success',true,'saved_count',saved,'date',p_date,'course_id',p_course_id);
end $$;

create or replace function public.justify_attendance_records(
 p_student_id uuid,p_dates date[],p_reason text,p_course_id uuid default null
) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,auth as $$
declare s public.students; r record; updated integer:=0; begin
  if auth.uid() is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  select * into s from public.students where id=p_student_id for share;
  if s.id is null or (p_course_id is not null and s.course_id is distinct from p_course_id) then
    raise exception 'ATTENDANCE_ACCESS_DENIED' using errcode='42501';
  end if;
  perform private.assert_attendance_access(s.course_id,null);
  if s.school_id is distinct from (select school_id from public.courses where id=s.course_id) then
    raise exception 'ATTENDANCE_STUDENT_MISMATCH' using errcode='42501';
  end if;
  if coalesce(cardinality(p_dates),0)=0 or cardinality(p_dates)>366 or nullif(btrim(p_reason),'') is null or length(p_reason)>4000 then
    raise exception 'INVALID_ATTENDANCE_JUSTIFICATION' using errcode='22023';
  end if;
  -- All selected rows must be authorized before the atomic update completes.
  for r in select * from public.attendance_records where student_id=s.id and school_id=s.school_id
    and course_id=s.course_id and attendance_date=any(p_dates) and status in ('falta_injustificada','atraso') for update loop
    perform private.assert_attendance_access(r.course_id,r.subject_id);
    if r.quarter_id is not null then
      perform 1 from public.quarters where id=r.quarter_id and school_id=s.school_id and not coalesce(is_locked,false) for share;
      if not found then raise exception 'ATTENDANCE_QUARTER_LOCKED' using errcode='42501'; end if;
    end if;
    update public.attendance_records set status='falta_justificada',justification_reason=btrim(p_reason),justified_by=auth.uid(),justified_at=now(),updated_at=now() where id=r.id;
    updated:=updated+1;
  end loop;
  return jsonb_build_object('success',true,'updated_count',updated,'student_id',p_student_id);
end $$;

-- Only validated RPCs perform client writes; RLS alone cannot validate all dimensions.
revoke insert,update,delete on public.attendance_records from public,anon,authenticated;
revoke all on function public.save_attendance_batch(uuid,uuid,date,text,jsonb) from public,anon;
revoke all on function public.justify_attendance_records(uuid,date[],text,uuid) from public,anon;
grant execute on function public.save_attendance_batch(uuid,uuid,date,text,jsonb) to authenticated,service_role;
grant execute on function public.justify_attendance_records(uuid,date[],text,uuid) to authenticated,service_role;
