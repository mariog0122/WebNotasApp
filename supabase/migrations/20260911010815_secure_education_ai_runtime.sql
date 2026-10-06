-- Deploy together with the education-ai Edge Function. This migration is
-- intentionally self-contained so production does not need historical files.

create extension if not exists pgcrypto with schema extensions;

update public.institution_ai_settings
set model_id = 'gemini-2.5-flash', updated_at = now()
where provider = 'gemini' and model_id in ('gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-2.0-flash');

update public.institution_ai_settings
set model_id = 'gpt-5-mini', updated_at = now()
where provider = 'openai' and model_id in ('gpt-5.6-luna', 'gpt-4o-mini', 'gpt-4o');

alter table public.institution_ai_settings
  add column if not exists has_api_key boolean
  generated always as (nullif(btrim(encrypted_api_key), '') is not null) stored;

alter table public.institution_ai_settings
  drop constraint if exists institution_ai_settings_supported_model;
alter table public.institution_ai_settings
  add constraint institution_ai_settings_supported_model check (
    (provider = 'gemini' and model_id in ('auto', 'gemini-3.7-flash', 'gemini-2.5-flash', 'gemini-2.5-flash-lite', 'gemini-2.5-pro'))
    or (provider = 'openai' and model_id in ('auto', 'gpt-5-nano', 'gpt-5-mini', 'gpt-5'))
    or (provider = 'demo' and model_id in ('auto', 'demo-pedagogico-ec'))
  );

revoke select, insert, update, delete on public.institution_ai_settings from public, anon, authenticated;
grant select (school_id, mode, provider, model_id, has_api_key, monthly_quota_generations,
  teacher_daily_limit, is_active, status, alert_thresholds, created_at, updated_at)
  on public.institution_ai_settings to authenticated;
grant all on public.institution_ai_settings to service_role;

create or replace function public.encrypt_ai_api_key(p_key text, p_passphrase text)
returns text language plpgsql security invoker
set search_path = pg_catalog, extensions, public as $$
begin
  if p_key is null or btrim(p_key) = '' or p_passphrase is null or length(p_passphrase) < 32 then
    return null;
  end if;
  return extensions.armor(extensions.pgp_sym_encrypt(p_key, p_passphrase, 'cipher-algo=aes256'));
end;
$$;

create or replace function public.decrypt_ai_api_key(p_armored_cipher text, p_passphrase text)
returns text language plpgsql security invoker
set search_path = pg_catalog, extensions, public as $$
begin
  if p_armored_cipher is null or btrim(p_armored_cipher) = '' or p_passphrase is null or length(p_passphrase) < 32 then
    return null;
  end if;
  return extensions.pgp_sym_decrypt(extensions.dearmor(p_armored_cipher), p_passphrase);
exception when others then
  return null;
end;
$$;

revoke all on function public.encrypt_ai_api_key(text, text) from public, anon, authenticated;
grant execute on function public.encrypt_ai_api_key(text, text) to service_role;
revoke all on function public.decrypt_ai_api_key(text, text) from public, anon, authenticated;
grant execute on function public.decrypt_ai_api_key(text, text) to service_role;

do $$
declare source text;
begin
  select pg_get_functiondef('public.check_ai_planning_access(uuid)'::regprocedure) into source;
  if position('-- AUDIT tenant guard' in source) = 0 then
    if position('-- Comprobar si el tenant' in source) = 0 then
      raise exception 'Unexpected check_ai_planning_access definition; inspect before applying';
    end if;
    source := replace(source, '-- Comprobar si el tenant',
      E'-- AUDIT tenant guard\n  IF NOT public.is_platform_admin() AND v_school_id IS DISTINCT FROM public.get_user_school_id() THEN\n    RAISE EXCEPTION ''Institución no autorizada'' USING ERRCODE = ''42501'';\n  END IF;\n\n  -- Comprobar si el tenant');
  end if;
  source := replace(source, '''gemini-1.5-flash''', '''gemini-2.5-flash''');
  execute source;
end;
$$;

revoke execute on function public.check_ai_planning_access(uuid) from public, anon;
grant execute on function public.check_ai_planning_access(uuid) to authenticated, service_role;

create or replace function public.reserve_education_ai_usage(
  p_school_id uuid, p_user_id uuid, p_task_type text, p_provider text, p_model_id text
) returns uuid language plpgsql security invoker set search_path = pg_catalog, public as $$
declare
  cfg public.institution_ai_settings;
  monthly_count integer;
  daily_count integer;
  reservation uuid;
  tz text;
  month_start timestamptz;
  day_start timestamptz;
begin
  if p_school_id is null or p_user_id is null then
    raise exception 'AI_UNAUTHORIZED' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('ai:' || p_school_id::text, 0));
  select * into cfg from public.institution_ai_settings where school_id = p_school_id;
  if not found or not cfg.is_active or cfg.mode = 'demo' or cfg.status not in ('active', 'demo') then
    raise exception 'AI_UNAVAILABLE' using errcode = '42501';
  end if;
  if not exists (
      select 1 from public.schools where id = p_school_id and coalesce(is_active, true)
        and status::text in ('active', 'trial', 'past_due', 'grace_period')
    ) or exists (
      select 1 from public.tenant_features where school_id = p_school_id
        and feature_key = 'ai_planning' and not enabled
    ) then
    raise exception 'AI_UNAVAILABLE' using errcode = '42501';
  end if;
  select timezone into tz from public.schools where id = p_school_id;
  if not exists (select 1 from pg_timezone_names where name = tz) then tz := 'America/Guayaquil'; end if;
  month_start := date_trunc('month', now() at time zone tz) at time zone tz;
  day_start := date_trunc('day', now() at time zone tz) at time zone tz;
  select count(*), count(*) filter (where user_id = p_user_id and created_at >= day_start)
    into monthly_count, daily_count
    from public.ai_usage_ledger
    where school_id = p_school_id and created_at >= month_start
      and (status = 'success' or (status = 'pending' and created_at > now() - interval '5 minutes'));
  if monthly_count >= cfg.monthly_quota_generations or daily_count >= cfg.teacher_daily_limit then
    raise exception 'AI_LIMIT_REACHED' using errcode = '42501';
  end if;
  insert into public.ai_usage_ledger (school_id, user_id, task_type, provider, model_id, status, is_demo)
  values (p_school_id, p_user_id, p_task_type, p_provider, p_model_id, 'pending', false)
  returning id into reservation;
  return reservation;
end;
$$;

revoke all on function public.reserve_education_ai_usage(uuid, uuid, text, text, text)
  from public, anon, authenticated;
grant execute on function public.reserve_education_ai_usage(uuid, uuid, text, text, text)
  to service_role;
