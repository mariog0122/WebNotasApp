-- Restrict irreversible, provisioning and financial operations to their intended
-- platform roles. Keep support access only where it is explicitly allowed.

alter function public.provision_tenant_wizard(
  text,text,text,text,text,text,text,text,text,text,uuid,text,numeric
) rename to provision_tenant_wizard_unchecked_20260911;
revoke all on function public.provision_tenant_wizard_unchecked_20260911(
  text,text,text,text,text,text,text,text,text,text,uuid,text,numeric
) from public, anon, authenticated;

create function public.provision_tenant_wizard(
  p_name text,
  p_trade_name text,
  p_code text,
  p_country text,
  p_province text,
  p_city text,
  p_timezone text,
  p_admin_name text,
  p_admin_email text,
  p_admin_phone text,
  p_plan_id uuid,
  p_billing_cycle text,
  p_price numeric
) returns json
language plpgsql security definer
set search_path = pg_catalog, public, auth
as $$
begin
  if not public.has_platform_role(array['platform_owner', 'platform_admin']) then
    return json_build_object('success', false, 'message', 'Acceso denegado.');
  end if;
  return public.provision_tenant_wizard_unchecked_20260911(
    p_name, p_trade_name, p_code, p_country, p_province, p_city, p_timezone,
    p_admin_name, p_admin_email, p_admin_phone, p_plan_id, p_billing_cycle, p_price
  );
end;
$$;
revoke all on function public.provision_tenant_wizard(
  text,text,text,text,text,text,text,text,text,text,uuid,text,numeric
) from public, anon;
grant execute on function public.provision_tenant_wizard(
  text,text,text,text,text,text,text,text,text,text,uuid,text,numeric
) to authenticated, service_role;

alter function public.record_manual_payment(
  uuid,numeric,text,text,timestamp with time zone,text,text
) rename to record_manual_payment_unchecked_20260911;
revoke all on function public.record_manual_payment_unchecked_20260911(
  uuid,numeric,text,text,timestamp with time zone,text,text
) from public, anon, authenticated;

create function public.record_manual_payment(
  p_school_id uuid,
  p_amount numeric,
  p_provider_reference text,
  p_external_invoice_number text,
  p_paid_at timestamp with time zone,
  p_notes text,
  p_receipt_url text default null
) returns json
language plpgsql security definer
set search_path = pg_catalog, public, auth
as $$
begin
  if not public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance']) then
    raise exception 'PLATFORM_FINANCE_REQUIRED' using errcode = '42501';
  end if;
  return public.record_manual_payment_unchecked_20260911(
    p_school_id, p_amount, p_provider_reference, p_external_invoice_number,
    p_paid_at, p_notes, p_receipt_url
  );
end;
$$;
revoke all on function public.record_manual_payment(
  uuid,numeric,text,text,timestamp with time zone,text,text
) from public, anon;
grant execute on function public.record_manual_payment(
  uuid,numeric,text,text,timestamp with time zone,text,text
) to authenticated, service_role;

alter function public.set_tenant_status(uuid,text,text,text)
  rename to set_tenant_status_unchecked_20260911;
revoke all on function public.set_tenant_status_unchecked_20260911(uuid,text,text,text)
  from public, anon, authenticated;

create function public.set_tenant_status(
  p_school_id uuid,
  p_new_status text,
  p_reason text default 'Modificación por administración de plataforma',
  p_observation text default null
) returns json
language plpgsql security definer
set search_path = pg_catalog, public, auth
as $$
begin
  if not public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_support']) then
    raise exception 'PLATFORM_STATUS_ROLE_REQUIRED' using errcode = '42501';
  end if;
  return public.set_tenant_status_unchecked_20260911(
    p_school_id, p_new_status, p_reason, p_observation
  );
end;
$$;
revoke all on function public.set_tenant_status(uuid,text,text,text)
  from public, anon;
grant execute on function public.set_tenant_status(uuid,text,text,text)
  to authenticated, service_role;

create or replace function public.delete_tenant(p_school_id uuid)
returns json
language plpgsql security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_school_name text;
begin
  if not public.has_platform_role(array['platform_owner']) then
    return json_build_object(
      'success', false,
      'message', 'Acceso denegado. Se requiere rol de propietario de plataforma.'
    );
  end if;
  if p_school_id is null then
    return json_build_object('success', false, 'message', 'Institución requerida.');
  end if;

  select name into v_school_name
  from public.schools
  where id = p_school_id
  for update;
  if not found then
    return json_build_object('success', false, 'message', 'Institución no encontrada.');
  end if;

  delete from public.invoice_payment_allocations allocation
  using public.invoices invoice
  where allocation.invoice_id = invoice.id
    and invoice.school_id = p_school_id;
  delete from public.invoices where school_id = p_school_id;
  delete from public.schools where id = p_school_id;

  insert into public.audit_log (
    school_id, user_id, action, table_name, record_id, old_values, new_values
  ) values (
    null, null, 'TENANT_DELETED', 'schools', p_school_id::text,
    jsonb_build_object('school_id', p_school_id, 'name', v_school_name, 'actor_id', auth.uid()),
    jsonb_build_object('result', 'success')
  );

  return json_build_object(
    'success', true,
    'message', 'Institución y datos institucionales eliminados correctamente.'
  );
end;
$$;
revoke all on function public.delete_tenant(uuid) from public, anon;
grant execute on function public.delete_tenant(uuid) to authenticated, service_role;

notify pgrst, 'reload schema';
