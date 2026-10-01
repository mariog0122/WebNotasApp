-- Keep billing evidence private and require explicit billing permissions.

alter table public.tenant_billing_profiles enable row level security;

do $$
declare
  v_policy record;
begin
  for v_policy in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'tenant_billing_profiles'
  loop
    execute format(
      'drop policy if exists %I on public.tenant_billing_profiles',
      v_policy.policyname
    );
  end loop;
end
$$;

create policy billing_profiles_select
on public.tenant_billing_profiles
for select to authenticated
using (
  public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance'])
  or (
    school_id = public.get_user_school_id()
    and public.has_tenant_permission('billing.read')
  )
);

revoke all on table public.tenant_billing_profiles from anon, authenticated;
grant select on table public.tenant_billing_profiles to authenticated;

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.can_access_billing_proof(
  object_name text,
  required_permission text
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
  select auth.uid() is not null
    and required_permission in ('billing.read', 'billing.manage')
    and object_name ~* '^receipts/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}_[^/]+\.(jpg|jpeg|png|webp|pdf)$'
    and (
      public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance'])
      or (
        split_part(split_part(object_name, '/', 2), '_', 1) = public.get_user_school_id()::text
        and public.has_tenant_permission(required_permission)
      )
    )
$$;

revoke all on function private.can_access_billing_proof(text, text) from public, anon;
grant execute on function private.can_access_billing_proof(text, text) to authenticated;

drop policy if exists "Public view for billing proofs" on storage.objects;
drop policy if exists "Allow upload billing proofs" on storage.objects;
drop policy if exists "Allow update billing proofs" on storage.objects;
drop policy if exists "Authenticated users can upload billing proofs" on storage.objects;
drop policy if exists "Authenticated users can view billing proofs" on storage.objects;
drop policy if exists billing_proofs_select on storage.objects;
drop policy if exists billing_proofs_insert on storage.objects;
drop policy if exists billing_proofs_update on storage.objects;

create policy billing_proofs_select
on storage.objects
for select to authenticated
using (
  bucket_id = 'billing-proofs'
  and private.can_access_billing_proof(name, 'billing.read')
);

create policy billing_proofs_insert
on storage.objects
for insert to authenticated
with check (
  bucket_id = 'billing-proofs'
  and private.can_access_billing_proof(name, 'billing.manage')
);

update storage.buckets
set public = false,
    file_size_limit = 10485760,
    allowed_mime_types = array[
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/pdf'
    ]
where id = 'billing-proofs';

create unique index if not exists payments_billing_proof_unique
on public.payments (school_id, receipt_url)
where receipt_url is not null
  and provider = 'transfer'
  and amount = 0;

create or replace function public.upload_tenant_payment_proof(
  p_school_id uuid,
  p_receipt_url text,
  p_notes text default null
)
returns json
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_clean_path text := nullif(trim(p_receipt_url), '');
  v_payment_id uuid;
  v_is_platform boolean;
begin
  if auth.uid() is null then
    raise exception 'BILLING_PROOF_AUTH_REQUIRED' using errcode = '42501';
  end if;

  v_is_platform := public.has_platform_role(
    array['platform_owner', 'platform_admin', 'platform_finance']
  );

  if not v_is_platform and (
    public.get_user_school_id() is distinct from p_school_id
    or not public.has_tenant_permission('billing.manage')
  ) then
    raise exception 'BILLING_PROOF_WRITE_FORBIDDEN' using errcode = '42501';
  end if;

  if not exists (select 1 from public.schools where id = p_school_id) then
    raise exception 'SCHOOL_NOT_FOUND' using errcode = 'P0002';
  end if;

  if v_clean_path is null
     or length(v_clean_path) > 500
     or v_clean_path !~* (
       '^receipts/' || p_school_id::text ||
       '_[^/]+\.(jpg|jpeg|png|webp|pdf)$'
     ) then
    raise exception 'BILLING_PROOF_PATH_INVALID' using errcode = '22023';
  end if;

  insert into public.tenant_billing_profiles (
    school_id,
    latest_receipt_url,
    updated_at
  ) values (
    p_school_id,
    v_clean_path,
    timezone('utc'::text, now())
  )
  on conflict (school_id) do update
  set latest_receipt_url = excluded.latest_receipt_url,
      updated_at = timezone('utc'::text, now());

  insert into public.payments (
    school_id,
    amount,
    currency,
    provider,
    status,
    paid_at,
    payment_type,
    notes,
    receipt_url,
    recorded_by
  ) values (
    p_school_id,
    0,
    'USD',
    'transfer',
    'pending',
    timezone('utc'::text, now()),
    'subscription',
    coalesce(nullif(left(trim(p_notes), 1000), ''), 'Comprobante subido por la institución'),
    v_clean_path,
    auth.uid()
  )
  on conflict do nothing
  returning id into v_payment_id;

  if v_payment_id is null then
    select id into v_payment_id
    from public.payments
    where school_id = p_school_id
      and receipt_url = v_clean_path
      and provider = 'transfer'
      and amount = 0
    order by created_at desc
    limit 1;
  end if;

  return json_build_object(
    'success', true,
    'message', 'Comprobante de pago registrado exitosamente.',
    'payment_id', v_payment_id,
    'receipt_url', v_clean_path
  );
end;
$$;

revoke all on function public.upload_tenant_payment_proof(uuid, text, text)
from public, anon;
grant execute on function public.upload_tenant_payment_proof(uuid, text, text)
to authenticated, service_role;
