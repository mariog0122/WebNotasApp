begin;

insert into public.schools(id, name, code, status, is_active) values
  ('54000000-0000-4000-8000-000000000001', 'AUDIT roles A', 'AUDIT-ROLE-A', 'active', true),
  ('54000000-0000-4000-8000-000000000002', 'AUDIT roles B', 'AUDIT-ROLE-B', 'active', true);

insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('54000000-0000-4000-8000-000000000010', 'role-admin@example.invalid', '{}', '{}'),
  ('54000000-0000-4000-8000-000000000011', 'role-target@example.invalid', '{}', '{}');

insert into public.profiles(id, school_id, role, is_active) values
  ('54000000-0000-4000-8000-000000000010', '54000000-0000-4000-8000-000000000001', 'admin', true),
  ('54000000-0000-4000-8000-000000000011', '54000000-0000-4000-8000-000000000001', 'teacher', true);

insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
select '54000000-0000-4000-8000-000000000010', '54000000-0000-4000-8000-000000000001', id, true
from public.tenant_roles where name = 'school_admin';
insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
select '54000000-0000-4000-8000-000000000011', '54000000-0000-4000-8000-000000000001', id, true
from public.tenant_roles where name = 'teacher';

select set_config('request.jwt.claim.sub', '54000000-0000-4000-8000-000000000010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_result jsonb;
  v_denied boolean := false;
begin
  v_result := public.update_tenant_user_role(
    '54000000-0000-4000-8000-000000000011',
    '54000000-0000-4000-8000-000000000001',
    'inspector'
  );
  if v_result->>'tenant_role' <> 'inspector' then
    raise exception 'Authorized role update did not return the institutional role';
  end if;
  if (select role from public.profiles where id = '54000000-0000-4000-8000-000000000011') <> 'admin' then
    raise exception 'Legacy profile role was not kept compatible';
  end if;
  if (select tr.name from public.tenant_memberships tm join public.tenant_roles tr on tr.id = tm.tenant_role_id
      where tm.user_id = '54000000-0000-4000-8000-000000000011'
        and tm.school_id = '54000000-0000-4000-8000-000000000001') <> 'inspector' then
    raise exception 'Tenant membership role was not updated';
  end if;

  begin
    perform public.update_tenant_user_role(
      '54000000-0000-4000-8000-000000000011',
      '54000000-0000-4000-8000-000000000002',
      'teacher'
    );
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'SECURITY: cross-tenant role update accepted'; end if;
end
$$;

reset role;
rollback;
select 'tenant_user_role_management_tests_passed' as result;

