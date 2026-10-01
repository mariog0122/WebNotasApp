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
