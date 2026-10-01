-- Save the editable institution identity as one validated tenant transaction.

create or replace function public.save_institution_identity(
  p_school_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_name text;
  v_logo_path text;
  v_tutor_name text;
  v_rector_name text;
  v_config jsonb;
begin
  if auth.uid() is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;
  if p_school_id is null or jsonb_typeof(p_payload) is distinct from 'object' then
    raise exception 'La configuración institucional está incompleta' using errcode = '22023';
  end if;
  if not exists (select 1 from public.schools where id = p_school_id) then
    raise exception 'Institución no encontrada' using errcode = 'P0002';
  end if;
  if not public.is_platform_admin() and (
    p_school_id is distinct from public.get_user_school_id()
    or not public.has_tenant_permission('settings.manage')
  ) then
    raise exception 'No tienes permiso para configurar esta institución' using errcode = '42501';
  end if;

  v_name := nullif(trim(p_payload->>'institution_name'), '');
  v_logo_path := trim(coalesce(p_payload->>'institution_logo_url', ''));
  v_tutor_name := trim(coalesce(p_payload->>'institution_tutor_name', ''));
  v_rector_name := trim(coalesce(p_payload->>'institution_rector_name', ''));

  if v_name is null or length(v_name) > 200
    or length(v_logo_path) > 500
    or length(v_tutor_name) > 150
    or length(v_rector_name) > 150 then
    raise exception 'La configuración institucional contiene valores no válidos' using errcode = '22023';
  end if;
  if v_logo_path <> ''
    and v_logo_path not like p_school_id::text || '/%'
    and v_logo_path !~ '^https://[^[:space:]]+$' then
    raise exception 'La ruta del logo no es válida para esta institución' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_school_id::text || ':institution-config', 0));
  insert into public.system_config(school_id, key, value, description)
  values
    (p_school_id, 'institution_name', v_name, 'Nombre de la institución'),
    (p_school_id, 'institution_logo_url', v_logo_path, 'Logo de la institución'),
    (p_school_id, 'institution_tutor_name', v_tutor_name, 'Nombre del tutor'),
    (p_school_id, 'institution_rector_name', v_rector_name, 'Nombre del rector')
  on conflict (school_id, key) do update
  set value = excluded.value,
      description = excluded.description;

  select jsonb_object_agg(sc.key, sc.value)
  into v_config
  from public.system_config sc
  where sc.school_id = p_school_id
    and sc.key in (
      'institution_name',
      'institution_logo_url',
      'institution_tutor_name',
      'institution_rector_name'
    );

  if coalesce(v_config->>'institution_name', '') is distinct from v_name
    or coalesce(v_config->>'institution_logo_url', '') is distinct from v_logo_path
    or coalesce(v_config->>'institution_tutor_name', '') is distinct from v_tutor_name
    or coalesce(v_config->>'institution_rector_name', '') is distinct from v_rector_name then
    raise exception 'La base de datos no confirmó la configuración institucional';
  end if;

  insert into public.audit_log(school_id, user_id, action, table_name, record_id, new_values)
  values (
    p_school_id,
    auth.uid(),
    'INSTITUTION_IDENTITY_UPDATED',
    'system_config',
    p_school_id::text,
    v_config
  );

  return jsonb_build_object(
    'success', true,
    'school_id', p_school_id,
    'config', v_config
  );
end;
$$;

revoke all on function public.save_institution_identity(uuid, jsonb) from public, anon;
grant execute on function public.save_institution_identity(uuid, jsonb) to authenticated, service_role;
revoke insert, update, delete on public.system_config from authenticated;
