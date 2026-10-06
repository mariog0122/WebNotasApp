-- Keep the legacy profile role and the tenant RBAC membership synchronized.
-- The operation runs in one database transaction and never accepts a tenant
-- selected only by the browser as proof of authorization.

create or replace function public.update_tenant_user_role(
  p_user_id uuid,
  p_school_id uuid,
  p_role text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_actor_id uuid := (select auth.uid());
  v_role_name text := lower(btrim(coalesce(p_role, '')));
  v_profile public.profiles%rowtype;
  v_tenant_role_id uuid;
  v_legacy_role text;
begin
  if v_actor_id is null then
    raise exception 'Autenticación requerida' using errcode = '42501';
  end if;
  if p_user_id is null or p_school_id is null then
    raise exception 'Usuario e institución son obligatorios' using errcode = '22023';
  end if;
  if p_user_id = v_actor_id then
    raise exception 'No puedes cambiar tu propio rol desde este módulo' using errcode = '42501';
  end if;

  if v_role_name = 'admin' then
    v_role_name := 'school_admin';
  end if;
  if v_role_name not in ('school_admin', 'rector', 'vicerrector', 'secretary', 'inspector', 'counselor', 'teacher') then
    raise exception 'Rol institucional no permitido' using errcode = '22023';
  end if;

  if not public.is_platform_admin() and (
    p_school_id is distinct from public.get_user_school_id()
    or not public.has_tenant_permission('users.manage')
  ) then
    raise exception 'No tienes permiso para administrar usuarios de esta institución' using errcode = '42501';
  end if;

  select p.* into v_profile
  from public.profiles p
  where p.id = p_user_id
    and p.school_id = p_school_id
  for update;

  if not found then
    raise exception 'Usuario institucional no encontrado' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.user_platform_roles upr where upr.user_id = p_user_id) then
    raise exception 'Las cuentas de plataforma no se administran desde este módulo' using errcode = '42501';
  end if;

  select tr.id into v_tenant_role_id
  from public.tenant_roles tr
  where tr.name = v_role_name;
  if v_tenant_role_id is null then
    raise exception 'El rol institucional no está configurado' using errcode = '22023';
  end if;

  insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
  values (p_user_id, p_school_id, v_tenant_role_id, true)
  on conflict (user_id, school_id) do update
  set tenant_role_id = excluded.tenant_role_id,
      is_active = true;

  v_legacy_role := case when v_role_name = 'teacher' then 'teacher' else 'admin' end;
  update public.profiles
  set role = v_legacy_role
  where id = p_user_id and school_id = p_school_id;

  insert into public.audit_log(
    school_id, user_id, action, table_name, record_id, old_values, new_values
  ) values (
    p_school_id,
    v_actor_id,
    'TENANT_USER_ROLE_UPDATED',
    'tenant_memberships',
    p_user_id::text,
    jsonb_build_object('legacy_profile_role', v_profile.role),
    jsonb_build_object('tenant_role', v_role_name, 'legacy_profile_role', v_legacy_role)
  );

  return jsonb_build_object(
    'success', true,
    'user_id', p_user_id,
    'school_id', p_school_id,
    'tenant_role', v_role_name,
    'legacy_profile_role', v_legacy_role
  );
end;
$$;

revoke all on function public.update_tenant_user_role(uuid, uuid, text) from public, anon;
grant execute on function public.update_tenant_user_role(uuid, uuid, text) to authenticated, service_role;

