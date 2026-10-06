begin;

insert into public.schools(id, name, code, status, is_active) values
  ('65000000-0000-4000-8000-000000000001', 'AUDIT períodos predeterminados A', 'AUDIT-DEFAULT-Q-A', 'active', true),
  ('65000000-0000-4000-8000-000000000002', 'AUDIT períodos predeterminados B', 'AUDIT-DEFAULT-Q-B', 'active', true);
insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('65000000-0000-4000-8000-000000000010', 'default-quarter-admin@example.invalid', '{}', '{}');
insert into public.profiles(id, school_id, role, is_active) values
  ('65000000-0000-4000-8000-000000000010', '65000000-0000-4000-8000-000000000001', 'admin', true);
insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
select '65000000-0000-4000-8000-000000000010', '65000000-0000-4000-8000-000000000001', id, true
from public.tenant_roles where name = 'school_admin';

select set_config('request.jwt.claim.sub', '65000000-0000-4000-8000-000000000010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_result jsonb;
  v_denied boolean := false;
  v_duplicate boolean := false;
begin
  v_result := public.create_default_quarters(
    '65000000-0000-4000-8000-000000000001',
    'TRIMESTRE'
  );
  if not (v_result->>'success')::boolean
    or (v_result->>'created_count')::integer <> 3
    or jsonb_array_length(v_result->'periods') <> 3 then
    raise exception 'Default quarter creation was not fully confirmed';
  end if;
  if (select count(*) from public.quarters
      where school_id = '65000000-0000-4000-8000-000000000001') <> 3
    or (select count(*) from public.quarters
        where school_id = '65000000-0000-4000-8000-000000000001' and is_active) <> 1 then
    raise exception 'Default quarter creation left an invalid set';
  end if;

  begin
    perform public.create_default_quarters(
      '65000000-0000-4000-8000-000000000001',
      'QUIMESTRE'
    );
  exception when unique_violation then
    v_duplicate := true;
  end;
  if not v_duplicate then raise exception 'A second period set was accepted'; end if;
  if (select count(*) from public.quarters
      where school_id = '65000000-0000-4000-8000-000000000001') <> 3 then
    raise exception 'Rejected duplicate changed the existing period set';
  end if;

  begin
    perform public.create_default_quarters(
      '65000000-0000-4000-8000-000000000002',
      'QUIMESTRE'
    );
  exception when insufficient_privilege then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Cross-tenant period creation was accepted'; end if;
  if exists (select 1 from public.quarters where school_id = '65000000-0000-4000-8000-000000000002') then
    raise exception 'Rejected cross-tenant creation left partial periods';
  end if;
end
$$;

reset role;
rollback;
select 'secure_default_quarter_creation_tests_passed' as result;
