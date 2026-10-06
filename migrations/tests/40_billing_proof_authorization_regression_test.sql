-- Ejecutar después de harden_billing_proof_access. Todos los cambios se revierten.
begin;

select set_config(
  'audit.billing_school',
  (select school_id::text from public.tenant_billing_profiles order by updated_at limit 1),
  true
);
select set_config(
  'audit.billing_actor',
  (select id::text from public.profiles
   where school_id::text = current_setting('audit.billing_school')
   order by created_at limit 1),
  true
);
select set_config('request.jwt.claim.sub', current_setting('audit.billing_actor'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

delete from public.user_platform_roles
where user_id::text = current_setting('audit.billing_actor');
update public.profiles
set role = 'teacher', is_active = true
where id::text = current_setting('audit.billing_actor');
insert into public.tenant_memberships (user_id, school_id, tenant_role_id, is_active)
select current_setting('audit.billing_actor')::uuid,
       current_setting('audit.billing_school')::uuid,
       tr.id,
       true
from public.tenant_roles tr
where tr.name = 'teacher'
on conflict (user_id, school_id) do update
set tenant_role_id = excluded.tenant_role_id, is_active = true;

set local role authenticated;

do $$
declare
  v_updated integer := 0;
  v_result json;
  v_blocked boolean := false;
begin
  begin
    update public.tenant_billing_profiles
    set updated_at = updated_at
    where school_id::text = current_setting('audit.billing_school');
    get diagnostics v_updated = row_count;
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked and v_updated <> 0 then
    raise exception 'teacher updated tenant_billing_profiles directly';
  end if;

  begin
    v_result := public.upload_tenant_payment_proof(
      current_setting('audit.billing_school')::uuid,
      'receipts/' || current_setting('audit.billing_school') || '_11111111-1111-4111-8111-111111111111.pdf',
      'authorization regression test'
    );
    if coalesce((v_result->>'success')::boolean, false) then
      raise exception 'teacher uploaded a billing proof through the RPC';
    end if;
  exception when insufficient_privilege then
    null;
  end;
end
$$;

reset role;

do $$
begin
  if has_function_privilege('anon', 'public.upload_tenant_payment_proof(uuid,text,text)', 'EXECUTE') then
    raise exception 'billing proof RPC remains executable by anon/public';
  end if;
  if (select public from storage.buckets where id = 'billing-proofs') then
    raise exception 'billing-proofs bucket remains public';
  end if;
end
$$;

update public.tenant_memberships tm
set tenant_role_id = tr.id, is_active = true
from public.tenant_roles tr
where tm.user_id::text = current_setting('audit.billing_actor')
  and tm.school_id::text = current_setting('audit.billing_school')
  and tr.name = 'school_admin';

set local role authenticated;

do $$
declare
  v_path text := 'receipts/' || current_setting('audit.billing_school') || '_22222222-2222-4222-8222-222222222222.pdf';
  v_result json;
begin
  v_result := public.upload_tenant_payment_proof(
    current_setting('audit.billing_school')::uuid,
    v_path,
    'authorized regression test'
  );
  if not coalesce((v_result->>'success')::boolean, false) then
    raise exception 'school admin could not register a billing proof';
  end if;
  if not exists (
    select 1 from public.payments
    where school_id::text = current_setting('audit.billing_school')
      and receipt_url = v_path
      and recorded_by::text = current_setting('audit.billing_actor')
  ) then
    raise exception 'authorized billing proof did not create its auditable payment';
  end if;

  begin
    perform public.upload_tenant_payment_proof(
      current_setting('audit.billing_school')::uuid,
      'receipts/00000000-0000-4000-8000-000000000000_wrong.pdf',
      'invalid path regression test'
    );
    raise exception 'invalid cross-tenant receipt path was accepted';
  exception when sqlstate '22023' then
    null;
  end;
end
$$;

reset role;
rollback;

select 'billing_proof_authorization_regression_tests_passed' as result;
