-- Create the complete default academic-period set in one authorized transaction.

create or replace function public.create_default_quarters(
  p_school_id uuid,
  p_period_type text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_period_type text := upper(trim(coalesce(p_period_type, '')));
  v_expected_count integer;
  v_created_count integer;
  v_periods jsonb;
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;
  if p_school_id is null or v_period_type not in ('TRIMESTRE', 'QUIMESTRE') then
    raise exception 'El tipo de período no es válido' using errcode = '22023';
  end if;
  if not exists (select 1 from public.schools where id = p_school_id) then
    raise exception 'Institución no encontrada' using errcode = 'P0002';
  end if;
  if not public.is_platform_admin() and (
    p_school_id is distinct from public.get_user_school_id()
    or not public.has_tenant_permission('settings.manage')
  ) then
    raise exception 'No tienes permiso para configurar períodos en esta institución' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_school_id::text || ':quarters', 0));
  if exists (select 1 from public.quarters where school_id = p_school_id) then
    raise exception 'La institución ya tiene períodos configurados' using errcode = '23505';
  end if;

  if v_period_type = 'QUIMESTRE' then
    insert into public.quarters(school_id, name, is_active, is_locked)
    values
      (p_school_id, 'Primer Quimestre', true, false),
      (p_school_id, 'Segundo Quimestre', false, false);
    v_expected_count := 2;
  else
    insert into public.quarters(school_id, name, is_active, is_locked)
    values
      (p_school_id, 'Primer Trimestre', true, false),
      (p_school_id, 'Segundo Trimestre', false, false),
      (p_school_id, 'Tercer Trimestre', false, false);
    v_expected_count := 3;
  end if;

  select count(*), jsonb_agg(to_jsonb(q) order by q.created_at, q.id)
  into v_created_count, v_periods
  from public.quarters q
  where q.school_id = p_school_id;

  if v_created_count <> v_expected_count
    or (select count(*) from public.quarters where school_id = p_school_id and is_active) <> 1 then
    raise exception 'La base de datos no confirmó todos los períodos creados';
  end if;

  insert into public.audit_log(school_id, user_id, action, table_name, record_id, new_values)
  values (
    p_school_id,
    auth.uid(),
    'DEFAULT_QUARTERS_CREATED',
    'quarters',
    p_school_id::text,
    jsonb_build_object('period_type', v_period_type, 'count', v_created_count)
  );

  return jsonb_build_object(
    'success', true,
    'school_id', p_school_id,
    'period_type', v_period_type,
    'created_count', v_created_count,
    'periods', coalesce(v_periods, '[]'::jsonb)
  );
end;
$$;

revoke all on function public.create_default_quarters(uuid, text) from public, anon;
grant execute on function public.create_default_quarters(uuid, text) to authenticated, service_role;
revoke insert, update, delete on public.quarters from authenticated;
