-- Period activation and locking must be atomic and institution-scoped.

create or replace function public.set_active_quarter(p_quarter_id uuid)
returns public.quarters
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_quarter public.quarters;
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;

  select q.* into v_quarter from public.quarters q where q.id = p_quarter_id for update;
  if not found then raise exception 'Período no encontrado' using errcode = 'P0002'; end if;
  if not public.is_platform_admin() and (
    v_quarter.school_id is distinct from public.get_user_school_id()
    or not public.has_tenant_permission('settings.manage')
  ) then
    raise exception 'No tienes permiso para activar este período' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_quarter.school_id::text || ':active-quarter', 0));
  update public.quarters set is_active = false
  where school_id = v_quarter.school_id and is_active and id <> p_quarter_id;
  update public.quarters set is_active = true
  where id = p_quarter_id returning * into v_quarter;

  insert into public.audit_log(school_id, user_id, action, table_name, record_id, new_values)
  values (v_quarter.school_id, auth.uid(), 'QUARTER_ACTIVATED', 'quarters', v_quarter.id::text,
    jsonb_build_object('is_active', true));
  return v_quarter;
end;
$$;

create or replace function public.set_quarter_lock(p_quarter_id uuid, p_is_locked boolean)
returns public.quarters
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_quarter public.quarters;
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;
  if p_is_locked is null then
    raise exception 'El estado del bloqueo es obligatorio' using errcode = '22023';
  end if;

  select q.* into v_quarter from public.quarters q where q.id = p_quarter_id for update;
  if not found then raise exception 'Período no encontrado' using errcode = 'P0002'; end if;
  if not public.is_platform_admin() and (
    v_quarter.school_id is distinct from public.get_user_school_id()
    or not public.has_tenant_permission('settings.manage')
  ) then
    raise exception 'No tienes permiso para bloquear este período' using errcode = '42501';
  end if;

  update public.quarters set is_locked = p_is_locked
  where id = p_quarter_id returning * into v_quarter;
  insert into public.audit_log(school_id, user_id, action, table_name, record_id, new_values)
  values (v_quarter.school_id, auth.uid(),
    case when p_is_locked then 'QUARTER_LOCKED' else 'QUARTER_UNLOCKED' end,
    'quarters', v_quarter.id::text, jsonb_build_object('is_locked', p_is_locked));
  return v_quarter;
end;
$$;

revoke all on function public.set_active_quarter(uuid) from public, anon;
revoke all on function public.set_quarter_lock(uuid, boolean) from public, anon;
grant execute on function public.set_active_quarter(uuid) to authenticated, service_role;
grant execute on function public.set_quarter_lock(uuid, boolean) to authenticated, service_role;
