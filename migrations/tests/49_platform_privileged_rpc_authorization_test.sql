-- Critical platform-role boundaries. Safe: all role changes and calls roll back.
begin;

select set_config(
  'audit.platform_actor',
  (
    select upr.user_id::text
    from public.user_platform_roles upr
    join public.platform_roles pr on pr.id = upr.platform_role_id
    where pr.name::text in ('platform_owner', 'platform_admin')
    order by case pr.name::text when 'platform_owner' then 0 else 1 end
    limit 1
  ),
  true
);

do $$
begin
  if nullif(current_setting('audit.platform_actor', true), '') is null then
    raise exception 'AUTHORIZATION TEST: a platform actor is required';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', current_setting('audit.platform_actor'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
delete from public.user_platform_roles
where user_id::text = current_setting('audit.platform_actor');
insert into public.user_platform_roles (user_id, platform_role_id)
select current_setting('audit.platform_actor')::uuid, id
from public.platform_roles
where name::text = 'platform_support';
update public.profiles
set role = 'teacher', is_active = true
where id::text = current_setting('audit.platform_actor');
set local role authenticated;

do $$
declare
  response json;
begin
  if not public.is_platform_admin() then
    raise exception 'AUTHORIZATION TEST: fixture must exercise platform_support compatibility';
  end if;

  response := public.delete_tenant('f4900000-0000-4000-8000-000000000001');
  if coalesce((response->>'success')::boolean, true) then
    raise exception 'SECURITY: platform_support deleted a tenant';
  end if;

  response := public.provision_tenant_wizard(
    'Blocked support tenant', 'Blocked', 'BLOCKED-SUPPORT', 'Ecuador', null, null,
    'America/Guayaquil', 'Blocked Admin', 'blocked-support@example.invalid',
    '0999999999', null, 'monthly', 0
  );
  if response->>'message' is distinct from 'Acceso denegado.' then
    raise exception 'SECURITY: platform_support passed tenant provisioning authorization';
  end if;

  begin
    perform public.record_manual_payment(
      'f4900000-0000-4000-8000-000000000001', 10, 'blocked', 'blocked', now(), null, null
    );
    raise exception 'SECURITY: platform_support registered a manual payment';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;

reset role;
update public.profiles
set role = 'superadmin', is_active = false
where id::text = current_setting('audit.platform_actor');
delete from public.user_platform_roles
where user_id::text = current_setting('audit.platform_actor');
set local role authenticated;

do $$
declare
  response json;
begin
  response := public.delete_tenant('f4900000-0000-4000-8000-000000000001');
  if coalesce((response->>'success')::boolean, true) then
    raise exception 'SECURITY: inactive legacy superadmin deleted a tenant';
  end if;

  begin
    perform public.record_manual_payment(
      'f4900000-0000-4000-8000-000000000001', 10, 'blocked', 'blocked', now(), null, null
    );
    raise exception 'SECURITY: inactive legacy superadmin registered a payment';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform public.set_tenant_status(
      'f4900000-0000-4000-8000-000000000001', 'suspended', 'blocked', null
    );
    raise exception 'SECURITY: inactive legacy superadmin changed tenant status';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;

reset role;
insert into public.user_platform_roles (user_id, platform_role_id)
select current_setting('audit.platform_actor')::uuid, id
from public.platform_roles
where name::text = 'platform_owner';
update public.profiles
set role = 'teacher', is_active = true
where id::text = current_setting('audit.platform_actor');
insert into public.schools (id, name, code, status, is_active)
values ('f4900000-0000-4000-8000-000000000010', 'Disposable authorization test', 'AUTH-DELETE-TEST', 'active', true);
insert into public.courses (id, name, academic_year, school_id)
values (
  'f4900000-0000-4000-8000-000000000011', 'Disposable child row', 'TEST',
  'f4900000-0000-4000-8000-000000000010'
);
set local role authenticated;

do $$
declare
  response json;
begin
  response := public.delete_tenant('f4900000-0000-4000-8000-000000000010');
  if coalesce((response->>'success')::boolean, false) is not true then
    raise exception 'FUNCTIONAL: platform owner could not delete the disposable tenant';
  end if;
  if exists (select 1 from public.schools where id = 'f4900000-0000-4000-8000-000000000010')
     or exists (select 1 from public.courses where id = 'f4900000-0000-4000-8000-000000000011') then
    raise exception 'FUNCTIONAL: tenant deletion did not cascade';
  end if;
end;
$$;

rollback;
select 'platform_privileged_rpc_authorization_tests_passed' as result;
