-- Synthetic fixtures only. All changes roll back, including auth.users.
begin;
insert into public.schools(id,name,code,status,is_active) values
 ('45000000-0000-4000-8000-000000000001','AUDIT attendance A','AUDIT-ATT-A','active',true),
 ('45000000-0000-4000-8000-000000000002','AUDIT attendance B','AUDIT-ATT-B','active',true);
insert into public.subscriptions(school_id,plan_id,status,billing_cycle,agreed_price)
 select s.id,p.id,'active','monthly',p.monthly_price
 from public.schools s cross join lateral (
   select id,monthly_price from public.plans where active=true and student_limit>0 order by student_limit limit 1
 ) p where s.code in ('AUDIT-ATT-A','AUDIT-ATT-B');
insert into auth.users(id,email,raw_user_meta_data,raw_app_meta_data) values
 ('45000000-0000-4000-8000-000000000010','attendance-a@example.invalid','{}','{}');
insert into public.profiles(id,school_id,role,is_active) values
 ('45000000-0000-4000-8000-000000000010','45000000-0000-4000-8000-000000000001','teacher',true)
 on conflict(id) do update set school_id=excluded.school_id,role=excluded.role,is_active=true;
delete from public.user_platform_roles where user_id='45000000-0000-4000-8000-000000000010';
delete from public.tenant_memberships where user_id='45000000-0000-4000-8000-000000000010';
insert into public.tenant_memberships(user_id,school_id,tenant_role_id,is_active)
 select '45000000-0000-4000-8000-000000000010','45000000-0000-4000-8000-000000000001',id,true
 from public.tenant_roles where name='teacher';
insert into public.academic_years(school_id,name,start_year,end_year,is_active,is_current,is_locked)
 select id,'2098-2099',2098,2099,true,true,false from public.schools where code in ('AUDIT-ATT-A','AUDIT-ATT-B');
insert into public.courses(id,school_id,name,academic_year) values
 ('45000000-0000-4000-8000-000000000021','45000000-0000-4000-8000-000000000001','AUDIT A','2098-2099'),
 ('45000000-0000-4000-8000-000000000022','45000000-0000-4000-8000-000000000002','AUDIT B','2098-2099');
insert into public.students(id,school_id,course_id,full_name) values
 ('45000000-0000-4000-8000-000000000031','45000000-0000-4000-8000-000000000001','45000000-0000-4000-8000-000000000021','AUDIT alumno A'),
 ('45000000-0000-4000-8000-000000000032','45000000-0000-4000-8000-000000000002','45000000-0000-4000-8000-000000000022','AUDIT alumno B');
insert into public.subjects(id,name,school_id) values
 ('45000000-0000-4000-8000-000000000040','AUDIT materia','45000000-0000-4000-8000-000000000001');
insert into public.course_subjects(course_id,subject_id,school_id,teacher_id) values
 ('45000000-0000-4000-8000-000000000021','45000000-0000-4000-8000-000000000040','45000000-0000-4000-8000-000000000001','45000000-0000-4000-8000-000000000010');
insert into public.attendance_records(school_id,course_id,student_id,teacher_id,attendance_date,status,academic_year) values
 ('45000000-0000-4000-8000-000000000002','45000000-0000-4000-8000-000000000022','45000000-0000-4000-8000-000000000032','45000000-0000-4000-8000-000000000010','2098-10-10','falta_injustificada','2098-2099');
select set_config('request.jwt.claim.sub','45000000-0000-4000-8000-000000000010',true);
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
do $$ declare result jsonb; denied boolean; begin
  denied := false;
  begin
    perform public.justify_attendance_records('45000000-0000-4000-8000-000000000032',array['2098-10-10'::date],'AUDIT');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'SECURITY: foreign institution justification accepted'; end if;

  denied := false;
  begin
    perform public.save_attendance_batch('45000000-0000-4000-8000-000000000021',null,'2098-10-10','jornada_completa',
      '[{"student_id":"45000000-0000-4000-8000-000000000032","status":"presente"}]');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'SECURITY: foreign student accepted in own course'; end if;

  denied := false;
  begin
    perform public.save_attendance_batch('45000000-0000-4000-8000-000000000022',null,'2098-10-10','jornada_completa','[]');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'SECURITY: foreign course accepted'; end if;

  denied := false;
  begin
    perform public.save_attendance_batch('45000000-0000-4000-8000-000000000021',null,'2098-10-10','jornada_completa',
      '[{"student_id":"45000000-0000-4000-8000-000000000031","status":"inventado"}]');
  exception when invalid_parameter_value then denied := true; end;
  if not denied then raise exception 'Invalid attendance status accepted'; end if;

  result := public.save_attendance_batch('45000000-0000-4000-8000-000000000021',null,'2098-10-10','jornada_completa',
    '[{"student_id":"45000000-0000-4000-8000-000000000031","status":"falta_injustificada"}]');
  if (result->>'saved_count')::int <> 1 then raise exception 'Assigned teacher could not save attendance'; end if;
  perform public.save_attendance_batch('45000000-0000-4000-8000-000000000021',null,'2098-10-10','jornada_completa',
    '[{"student_id":"45000000-0000-4000-8000-000000000031","status":"atraso"}]');
  if (select count(*) from public.attendance_records where student_id='45000000-0000-4000-8000-000000000031') <> 1 then
    raise exception 'Duplicate attendance with NULL subject';
  end if;
  result := public.justify_attendance_records('45000000-0000-4000-8000-000000000031',array['2098-10-10'::date],'AUDIT autorizado');
  if (result->>'updated_count')::int <> 1 then raise exception 'Assigned teacher could not justify attendance'; end if;
  denied := false;
  begin
    update public.attendance_records set school_id='45000000-0000-4000-8000-000000000002'
      where student_id='45000000-0000-4000-8000-000000000031';
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Direct client update unexpectedly allowed'; end if;
end $$;
reset role;
update public.course_subjects set teacher_id=null where course_id='45000000-0000-4000-8000-000000000021';
set local role authenticated;
do $$ declare denied boolean:=false; begin
  begin
    perform public.save_attendance_batch('45000000-0000-4000-8000-000000000021',null,'2098-10-10','jornada_completa','[]');
  exception when insufficient_privilege then denied:=true; end;
  if not denied then raise exception 'Unassigned teacher accepted'; end if;
end $$;
reset role;
update public.course_subjects set teacher_id='45000000-0000-4000-8000-000000000010' where course_id='45000000-0000-4000-8000-000000000021';
update public.academic_years set is_locked=true where school_id='45000000-0000-4000-8000-000000000001';
set local role authenticated;
do $$ declare denied boolean := false; begin
  begin
    perform public.save_attendance_batch('45000000-0000-4000-8000-000000000021',null,'2098-10-10','jornada_completa',
      '[{"student_id":"45000000-0000-4000-8000-000000000031","status":"presente"}]');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Locked academic year accepted attendance write'; end if;
end $$;
reset role;
rollback;
select 'attendance_authorization_tests_passed' as result;
