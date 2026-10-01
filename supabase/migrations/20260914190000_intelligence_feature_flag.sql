-- ==============================================================================
-- LOGREVA — CAPA DE INTELIGENCIA DEL APRENDIZAJE (FASE 5: FEATURE FLAGS & SEGURIDAD)
-- Migración aditiva para control granular por institución (Kill-switch / Rollout)
-- ==============================================================================

-- 1. RPC: CONSULTA DE ESTADO DE LA CAPA DE INTELIGENCIA POR TENANT
create or replace function public.is_intelligence_module_enabled(p_school_id uuid)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_val text;
begin
  if p_school_id is null then
    return true; -- Habilitado por defecto en modo demo/sandbox
  end if;

  select value into v_val
  from public.system_config
  where school_id = p_school_id and key = 'intelligence_enabled';

  if v_val is not null and lower(v_val) in ('false', '0', 'disabled', 'off') then
    return false;
  end if;

  return true;
end;
$$;

revoke all on function public.is_intelligence_module_enabled(uuid) from public, anon;
grant execute on function public.is_intelligence_module_enabled(uuid) to authenticated;

-- 2. REGISTRO INICIAL POR DEFECTO EN SYSTEM_CONFIG (SI NO EXISTE)
insert into public.system_config (school_id, key, value)
select id, 'intelligence_enabled', 'true'
from public.schools
where id is not null
on conflict (school_id, key) do nothing;
