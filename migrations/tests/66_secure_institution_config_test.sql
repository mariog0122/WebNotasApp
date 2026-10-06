begin;

insert into public.schools(id, name, code, status, is_active) values
  ('66000000-0000-4000-8000-000000000001', 'AUDIT configuración A', 'AUDIT-CONFIG-A', 'active', true),
  ('66000000-0000-4000-8000-000000000002', 'AUDIT configuración B', 'AUDIT-CONFIG-B', 'active', true);
insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data) values
  ('66000000-0000-4000-8000-000000000010', 'config-admin@example.invalid', '{}', '{}');
insert into public.profiles(id, school_id, role, is_active) values
  ('66000000-0000-4000-8000-000000000010', '66000000-0000-4000-8000-000000000001', 'admin', true);
insert into public.tenant_memberships(user_id, school_id, tenant_role_id, is_active)
select '66000000-0000-4000-8000-000000000010', '66000000-0000-4000-8000-000000000001', id, true
from public.tenant_roles where name = 'school_admin';

select set_config('request.jwt.claim.sub', '66000000-0000-4000-8000-000000000010', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_result jsonb;
  v_denied boolean := false;
  v_invalid boolean := false;
begin
  v_result := public.save_institution_identity(
    '66000000-0000-4000-8000-000000000001',
    jsonb_build_object(
      'institution_name', 'Unidad Educativa Andina',
      'institution_logo_url', '66000000-0000-4000-8000-000000000001/institution/logo.webp',
      'institution_tutor_name', 'María Andrade',
      'institution_rector_name', 'José Cedeño'
    )
  );
  if not (v_result->>'success')::boolean
    or v_result->>'school_id' <> '66000000-0000-4000-8000-000000000001'
    or v_result->'config'->>'institution_name' <> 'Unidad Educativa Andina'
    or (select count(*) from public.system_config
        where school_id = '66000000-0000-4000-8000-000000000001'
          and key like 'institution_%') <> 4 then
    raise exception 'Institution configuration was not fully confirmed';
  end if;

  begin
    perform public.save_institution_identity(
      '66000000-0000-4000-8000-000000000002',
      jsonb_build_object('institution_name', 'Institución ajena')
    );
  exception when insufficient_privilege then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Cross-tenant institution configuration was accepted'; end if;

  begin
    perform public.save_institution_identity(
      '66000000-0000-4000-8000-000000000001',
      jsonb_build_object(
        'institution_name', 'Unidad Educativa Andina',
        'institution_logo_url', '66000000-0000-4000-8000-000000000002/institution/foreign.webp'
      )
    );
  exception when invalid_parameter_value then
    v_invalid := true;
  end;
  if not v_invalid then raise exception 'A foreign tenant logo path was accepted'; end if;
  if (select value from public.system_config
      where school_id = '66000000-0000-4000-8000-000000000001'
        and key = 'institution_logo_url') <> '66000000-0000-4000-8000-000000000001/institution/logo.webp' then
    raise exception 'Rejected configuration changed the stored logo';
  end if;
end
$$;

reset role;
rollback;
select 'secure_institution_config_tests_passed' as result;
