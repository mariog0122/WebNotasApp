begin;
-- Localized corrections; no renames, deletions of business data or role changes.
drop policy if exists academic_years_insert on public.academic_years;
create policy academic_years_insert on public.academic_years for insert to authenticated
with check (public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('settings.manage')));
drop policy if exists academic_years_update on public.academic_years;
create policy academic_years_update on public.academic_years for update to authenticated
using (public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('settings.manage')))
with check (public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('settings.manage')));
drop policy if exists academic_years_delete on public.academic_years;
create policy academic_years_delete on public.academic_years for delete to authenticated
using (public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('settings.manage')));

-- Existing rows were checked for dimension, student/course and score consistency before preparing this migration.
create or replace function private.synchronize_grade_dimensions_from_definition()
returns trigger language plpgsql security definer set search_path=pg_catalog,public,private as $$
declare definition record; student record;
begin
  select gd.course_subject_id,gd.quarter_id,gd.school_id,cs.course_id,q.is_locked
    into definition from public.grade_definitions gd
    join public.course_subjects cs on cs.id=gd.course_subject_id and cs.school_id=gd.school_id
    join public.quarters q on q.id=gd.quarter_id and q.school_id=gd.school_id
    where gd.id=new.grade_definition_id;
  select school_id,course_id into student from public.students where id=new.student_id;
  if definition.school_id is null or student.school_id is distinct from definition.school_id
    or student.course_id is distinct from definition.course_id then
    raise exception 'INVALID_GRADE_DIMENSIONS' using errcode='23514';
  end if;
  if new.score is not null and (new.score<0 or new.score>10) then
    raise exception 'GRADE_SCORE_OUT_OF_RANGE' using errcode='23514';
  end if;
  if auth.uid() is not null and coalesce(definition.is_locked,false) then
    raise exception 'GRADE_PERIOD_LOCKED' using errcode='42501';
  end if;
  new.course_subject_id:=definition.course_subject_id;
  new.quarter_id:=definition.quarter_id;
  new.school_id:=definition.school_id;
  new.updated_at:=now();
  return new;
end $$;
drop policy if exists grades_select on public.grades;
create policy grades_select on public.grades for select to authenticated
using (public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('grades.read')));
drop policy if exists grades_insert on public.grades;
create policy grades_insert on public.grades for insert to authenticated
with check (public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('grades.update')));
drop policy if exists grades_update on public.grades;
create policy grades_update on public.grades for update to authenticated
using (public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('grades.update')))
with check (public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('grades.update')));
drop policy if exists grades_delete on public.grades;
create policy grades_delete on public.grades for delete to authenticated
using ((public.is_platform_admin() or (school_id=public.get_user_school_id() and public.has_tenant_permission('grades.update')))
  and exists(select 1 from public.quarters q where q.id=quarter_id and not coalesce(q.is_locked,false)));

-- Keep the existing receipts/<school UUID>_<filename> convention and historical links.
create or replace function private.can_access_billing_proof(object_name text)
returns boolean language sql stable security definer set search_path=pg_catalog,public as $$
  select public.is_platform_admin() or (
    public.has_tenant_permission('billing.read')
    and split_part(object_name,'/',1)='receipts'
    and split_part(split_part(object_name,'/',2),'_',1)=public.get_user_school_id()::text
    and array_length(string_to_array(object_name,'/'),1)=2
  )
$$;
revoke all on function private.can_access_billing_proof(text) from public,anon;
grant usage on schema private to authenticated;
grant execute on function private.can_access_billing_proof(text) to authenticated;
drop policy if exists "Public view for billing proofs" on storage.objects;
drop policy if exists "Allow upload billing proofs" on storage.objects;
drop policy if exists "Allow update billing proofs" on storage.objects;
create policy billing_proofs_select on storage.objects for select to authenticated
using (bucket_id='billing-proofs' and private.can_access_billing_proof(name));
create policy billing_proofs_insert on storage.objects for insert to authenticated
with check (bucket_id='billing-proofs' and private.can_access_billing_proof(name) and public.has_tenant_permission('billing.manage'));
create policy billing_proofs_update on storage.objects for update to authenticated
using (bucket_id='billing-proofs' and private.can_access_billing_proof(name) and public.has_tenant_permission('billing.manage'))
with check (bucket_id='billing-proofs' and private.can_access_billing_proof(name) and public.has_tenant_permission('billing.manage'));
update storage.buckets set public=false,file_size_limit=10485760,
  allowed_mime_types=array['image/jpeg','image/png','image/webp','application/pdf'] where id='billing-proofs';

-- Deploy with education-ai and the matching frontend; never run historical migrations wholesale.
alter table public.institution_ai_settings add column if not exists has_api_key boolean
  generated always as (nullif(btrim(encrypted_api_key),'') is not null) stored;

-- RLS cannot hide individual columns. Remove broad table privileges first.
revoke select, insert, update, delete on public.institution_ai_settings from public, anon, authenticated;
grant select (school_id,mode,provider,model_id,has_api_key,monthly_quota_generations,
  teacher_daily_limit,is_active,status,alert_thresholds,created_at,updated_at)
  on public.institution_ai_settings to authenticated;
grant all on public.institution_ai_settings to service_role;

-- Preserve this RPC's return contract while preventing tenant-id probing.
do $$ declare source text; begin
  select pg_get_functiondef('public.check_ai_planning_access(uuid)'::regprocedure) into source;
  if position('-- AUDIT tenant guard' in source)=0 then
    if position('-- Comprobar si el tenant' in source)=0 then
      raise exception 'Unexpected check_ai_planning_access definition; inspect before applying';
    end if;
    source := replace(source, '-- Comprobar si el tenant',
      E'-- AUDIT tenant guard\n  IF NOT public.is_platform_admin() AND v_school_id IS DISTINCT FROM public.get_user_school_id() THEN\n    RAISE EXCEPTION ''Institución no autorizada'' USING ERRCODE = ''42501'';\n  END IF;\n\n  -- Comprobar si el tenant');
    execute source;
  end if;
end $$;
revoke execute on function public.check_ai_planning_access(uuid) from public,anon;
grant execute on function public.check_ai_planning_access(uuid) to authenticated,service_role;

-- Only the authenticated server may reserve real usage. Serialize concurrent requests.
create or replace function public.reserve_education_ai_usage(
  p_school_id uuid, p_user_id uuid, p_task_type text, p_provider text, p_model_id text
) returns uuid language plpgsql security invoker set search_path=pg_catalog,public as $$
declare cfg public.institution_ai_settings; monthly_count integer; daily_count integer;
  reservation uuid; tz text; month_start timestamptz; day_start timestamptz;
begin
  perform pg_advisory_xact_lock(hashtextextended('ai:'||p_school_id::text,0));
  select * into cfg from public.institution_ai_settings where school_id=p_school_id;
  if not found or not cfg.is_active or cfg.mode='demo' or cfg.status not in ('active','demo') then
    raise exception 'AI_UNAVAILABLE' using errcode='42501';
  end if;
  if not exists(select 1 from public.schools where id=p_school_id and coalesce(is_active,true)
    and status::text in ('active','trial','past_due','grace_period'))
    or exists(select 1 from public.tenant_features where school_id=p_school_id and feature_key='ai_planning' and not enabled) then
    raise exception 'AI_UNAVAILABLE' using errcode='42501';
  end if;
  select timezone into tz from public.schools where id=p_school_id;
  if not exists(select 1 from pg_timezone_names where name=tz) then tz:='America/Guayaquil'; end if;
  month_start:=date_trunc('month',now() at time zone tz) at time zone tz;
  day_start:=date_trunc('day',now() at time zone tz) at time zone tz;
  select count(*),count(*) filter(where user_id=p_user_id and created_at>=day_start)
    into monthly_count,daily_count from public.ai_usage_ledger
    where school_id=p_school_id and created_at>=month_start
      and (status='success' or (status='pending' and created_at>now()-interval '5 minutes'));
  if monthly_count>=cfg.monthly_quota_generations or daily_count>=cfg.teacher_daily_limit then
    raise exception 'AI_LIMIT_REACHED' using errcode='42501';
  end if;
  insert into public.ai_usage_ledger(school_id,user_id,task_type,provider,model_id,status,is_demo)
    values(p_school_id,p_user_id,p_task_type,p_provider,p_model_id,'pending',false) returning id into reservation;
  return reservation;
end $$;
revoke all on function public.reserve_education_ai_usage(uuid,uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.reserve_education_ai_usage(uuid,uuid,text,text,text) to service_role;


-- Synthetic fixtures only; never commit this transaction. Requires a trusted database test connection.
create or replace function pg_temp.audit_id(n integer) returns uuid language sql immutable as $$
select ('d0600000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid $$;
create temporary table audit_checks(name text, passed boolean) on commit drop;
grant select,insert on audit_checks to authenticated,anon,service_role;
insert into public.schools(id,name,code,status,is_active)
select pg_temp.audit_id(n), 'AUDIT synthetic institution '||n, 'AUDIT-20260906-'||n,'active',true from generate_series(1,3) n;
insert into public.subscriptions(school_id,plan_id,status,billing_cycle,agreed_price)
select pg_temp.audit_id(n),p.id,'active','monthly',p.monthly_price from generate_series(1,3) n
cross join (select id,monthly_price from public.plans where active order by student_limit limit 1) p;
insert into auth.users(id,aud,role,email)
select pg_temp.audit_id(n),'authenticated','authenticated','audit-'||n||'@example.invalid' from generate_series(101,106) n;
insert into public.profiles(id,email,full_name,role,school_id)
select pg_temp.audit_id(n),'audit-'||n||'@example.invalid','Synthetic audit actor',
case when n=106 then 'superadmin' when n in (102,104,105) then 'admin' else 'teacher' end,
pg_temp.audit_id(case when n=104 then 2 when n=105 then 3 else 1 end)
from generate_series(101,106) n;
insert into public.tenant_memberships(user_id,school_id,tenant_role_id,is_active)
select p.id,p.school_id,tr.id,true from public.profiles p join public.tenant_roles tr
on tr.name::text=case when p.id=pg_temp.audit_id(101) then 'teacher' when p.id=pg_temp.audit_id(103) then 'student' else 'school_admin' end
where p.id in (select pg_temp.audit_id(n) from generate_series(101,105) n);
insert into public.courses(id,name,academic_year,school_id)
select pg_temp.audit_id(200+n),'Audit course '||n,'2098-2099',pg_temp.audit_id(n) from generate_series(1,3) n;
insert into public.academic_years(id,name,start_year,end_year,school_id)
select pg_temp.audit_id(300+n),'2098-2099',2098,2099,pg_temp.audit_id(n) from generate_series(1,3) n;
insert into public.students(id,full_name,course_id,school_id)
select pg_temp.audit_id(400+n),'Synthetic student '||n,pg_temp.audit_id(200+n),pg_temp.audit_id(n) from generate_series(1,3) n;
insert into public.subjects(id,name,school_id)
select pg_temp.audit_id(500+n),'Synthetic subject',pg_temp.audit_id(n) from generate_series(1,3) n;
insert into public.course_subjects(id,course_id,subject_id,teacher_id,school_id)
select pg_temp.audit_id(600+n),pg_temp.audit_id(200+n),pg_temp.audit_id(500+n),pg_temp.audit_id(case when n=1 then 101 when n=2 then 104 else 105 end),pg_temp.audit_id(n) from generate_series(1,3) n;
insert into public.quarters(id,name,school_id)
select pg_temp.audit_id(700+n),'Audit quarter',pg_temp.audit_id(n) from generate_series(1,3) n;
insert into public.grade_definitions(id,course_subject_id,quarter_id,name,category,sort_order,school_id)
select pg_temp.audit_id(800+n),pg_temp.audit_id(600+n),pg_temp.audit_id(700+n),'Audit lesson','INDIVIDUAL',1,pg_temp.audit_id(n) from generate_series(1,3) n;
insert into public.grades(id,student_id,grade_definition_id,score)
select pg_temp.audit_id(900+n),pg_temp.audit_id(400+n),pg_temp.audit_id(800+n),8 from generate_series(1,3) n;
-- Storage metadata only: no upload, download or deletion of real files.
insert into storage.objects(bucket_id,name)
select 'billing-proofs','receipts/'||pg_temp.audit_id(n)||'_audit.png' from generate_series(1,3) n;

select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub',pg_temp.audit_id(101)::text,true);
set local role authenticated;
insert into audit_checks select 'teacher reads own grade',exists(select 1 from public.grades where id=pg_temp.audit_id(901));
insert into audit_checks select 'teacher cannot read B/C grades',not exists(select 1 from public.grades where id in (pg_temp.audit_id(902),pg_temp.audit_id(903)));
insert into audit_checks select 'teacher cannot read B/C students',not exists(select 1 from public.students where id in (pg_temp.audit_id(402),pg_temp.audit_id(403)));
do $$ declare allowed boolean; affected integer; begin
  begin
    update public.academic_years set name='Audit teacher update' where id=pg_temp.audit_id(301);
    get diagnostics affected=row_count; allowed:=affected>0;
    raise sqlstate 'PZ001';
  exception when sqlstate 'PZ001' then null; when insufficient_privilege then allowed:=false; end;
  insert into audit_checks values('teacher cannot modify academic year',not allowed);
  begin
    update public.grades set score=11 where id=pg_temp.audit_id(901);
    get diagnostics affected=row_count; allowed:=affected>0;
    raise sqlstate 'PZ001';
  exception when sqlstate 'PZ001' then null; when check_violation or insufficient_privilege then allowed:=false; end;
  insert into audit_checks values('direct grade rejects score above 10',not allowed);
  begin
    update public.grades set student_id=pg_temp.audit_id(402) where id=pg_temp.audit_id(901);
    get diagnostics affected=row_count; allowed:=affected>0;
    raise sqlstate 'PZ001';
  exception when sqlstate 'PZ001' then null; when check_violation or insufficient_privilege then allowed:=false; end;
  insert into audit_checks values('direct grade rejects foreign student',not allowed);
  perform public.save_grade_batch(jsonb_build_array(jsonb_build_object('student_id',pg_temp.audit_id(401),'grade_definition_id',pg_temp.audit_id(801),'score',9)), '[]');
  insert into audit_checks select 'teacher RPC still saves own grade',score=9 from public.grades where id=pg_temp.audit_id(901);
end $$;
reset role;
select set_config('request.jwt.claim.sub',pg_temp.audit_id(103)::text,true);
set local role authenticated;
insert into audit_checks select 'role without grades.read cannot read grades',not exists(select 1 from public.grades where id=pg_temp.audit_id(901));
reset role;
select set_config('request.jwt.claim.sub',pg_temp.audit_id(102)::text,true);
set local role authenticated;
do $$ declare allowed boolean; affected integer; begin
  update public.academic_years set is_active=true where id=pg_temp.audit_id(301);
  get diagnostics affected=row_count;
  insert into audit_checks values('school admin still edits own year',affected=1);
  begin
    update public.academic_years set school_id=pg_temp.audit_id(2),name='Audit moved year' where id=pg_temp.audit_id(301);
    get diagnostics affected=row_count; allowed:=affected>0;
    raise sqlstate 'PZ001';
  exception when sqlstate 'PZ001' then null; when insufficient_privilege then allowed:=false; end;
  insert into audit_checks values('school admin cannot move year to B',not allowed);
end $$;
insert into audit_checks select 'billing admin reads own proof',exists(select 1 from storage.objects where bucket_id='billing-proofs' and name='receipts/'||pg_temp.audit_id(1)||'_audit.png');
insert into audit_checks select 'billing admin cannot read B/C proofs',not exists(select 1 from storage.objects where bucket_id='billing-proofs' and name in ('receipts/'||pg_temp.audit_id(2)||'_audit.png','receipts/'||pg_temp.audit_id(3)||'_audit.png'));
reset role;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claim.role','anon',true);
set local role anon;
insert into audit_checks select 'anonymous cannot list proofs',not exists(select 1 from storage.objects where bucket_id='billing-proofs' and name like '%_audit.png');
reset role;
select name,passed from audit_checks order by name;

reset role;
insert into public.institution_ai_settings(school_id,mode,provider,model_id,encrypted_api_key,monthly_quota_generations,teacher_daily_limit,status)
values(pg_temp.audit_id(1),'byok','gemini','test-model','synthetic-key-never-real',1,1,'active');
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub',pg_temp.audit_id(101)::text,true);
set local role authenticated;
do $$ declare denied boolean:=false; begin
  begin perform encrypted_api_key from public.institution_ai_settings where school_id=pg_temp.audit_id(1);
  exception when insufficient_privilege then denied:=true; end;
  insert into audit_checks values('AI key cannot be read by browser role',denied);
  insert into audit_checks select 'AI metadata remains readable',has_api_key from public.institution_ai_settings where school_id=pg_temp.audit_id(1);
  denied:=false;
  begin perform public.check_ai_planning_access(pg_temp.audit_id(2));
  exception when insufficient_privilege then denied:=true; end;
  insert into audit_checks values('AI context rejects foreign tenant ID',denied);
  denied:=false;
  begin perform public.reserve_education_ai_usage(pg_temp.audit_id(1),pg_temp.audit_id(101),'plan_generation','gemini','test-model');
  exception when insufficient_privilege then denied:=true; end;
  insert into audit_checks values('Browser cannot reserve privileged AI calls directly',denied);
end $$;
reset role;
set local role service_role;
do $$ declare reservation uuid; denied boolean:=false; begin
  reservation:=public.reserve_education_ai_usage(pg_temp.audit_id(1),pg_temp.audit_id(101),'plan_generation','gemini','test-model');
  insert into audit_checks values('AI server reserves first generation',reservation is not null);
  begin perform public.reserve_education_ai_usage(pg_temp.audit_id(1),pg_temp.audit_id(101),'plan_generation','gemini','test-model');
  exception when insufficient_privilege then denied:=true; end;
  insert into audit_checks values('AI pending generation counts against quota',denied);
end $$;
reset role;
select name,passed from audit_checks order by name;

rollback;
