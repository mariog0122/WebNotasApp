begin;

insert into public.schools(id, name, code, status, is_active) values
  ('55000000-0000-4000-8000-000000000001', 'AUDIT períodos A', 'AUDIT-Q-A', 'active', true),
  ('55000000-0000-4000-8000-000000000002', 'AUDIT períodos B', 'AUDIT-Q-B', 'active', true);
insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('55000000-0000-4000-8000-000000000010', 'quarter-admin@example.invalid', '{}', '{}');
insert into public.profiles(id, school_id, role, is_active) values
  ('55000000-0000-4000-8000-000000000010', '55000000-0000-4000-8000-000000000001', 'admin', true);
insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
select '55000000-0000-4000-8000-000000000010', '55000000-0000-4000-8000-000000000001', id, true
from public.tenant_roles where name = 'school_admin';
insert into public.quarters(id, school_id, name, is_active, is_locked) values
  ('55000000-0000-4000-8000-000000000021', '55000000-0000-4000-8000-000000000001', 'AUDIT Q1', true, false),
  ('55000000-0000-4000-8000-000000000022', '55000000-0000-4000-8000-000000000001', 'AUDIT Q2', false, false),
  ('55000000-0000-4000-8000-000000000023', '55000000-0000-4000-8000-000000000002', 'AUDIT Q externo', true, false);

select set_config('request.jwt.claim.sub', '55000000-0000-4000-8000-000000000010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_denied boolean := false;
begin
  perform public.set_active_quarter('55000000-0000-4000-8000-000000000022');
  if (select count(*) from public.quarters where school_id = '55000000-0000-4000-8000-000000000001' and is_active) <> 1 then
    raise exception 'Atomic activation did not leave exactly one active period';
  end if;
  if not (select is_active from public.quarters where id = '55000000-0000-4000-8000-000000000022') then
    raise exception 'Requested period was not activated';
  end if;

  perform public.set_quarter_lock('55000000-0000-4000-8000-000000000022', true);
  if not (select is_locked from public.quarters where id = '55000000-0000-4000-8000-000000000022') then
    raise exception 'Period lock was not persisted';
  end if;

  begin
    perform public.set_active_quarter('55000000-0000-4000-8000-000000000023');
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'SECURITY: foreign period activation accepted'; end if;
end
$$;

reset role;
rollback;
select 'atomic_quarter_management_tests_passed' as result;

