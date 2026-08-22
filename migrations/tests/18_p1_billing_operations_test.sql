-- Contract test for migrations/18_p1_billing_operations.sql
-- Safe on a live project: all billing fixtures are rolled back.
begin;

do $$
begin
  if to_regprocedure('public.record_manual_payment(uuid,numeric,text,text,timestamptz,text)') is null then
    raise exception 'record_manual_payment is missing';
  end if;
  if to_regprocedure('public.set_tenant_status(uuid,public.tenant_status_type,text,text)') is null then
    raise exception 'set_tenant_status is missing';
  end if;
end
$$;

select set_config(
  'request.jwt.claim.sub',
  (select id::text from public.profiles order by created_at limit 1),
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

insert into public.schools (id, name, code, status, is_active)
values ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'P1 billing fixture', 'P1-BILLING', 'trial', true);

insert into public.subscriptions (
  school_id, plan_id, status, billing_cycle, agreed_price,
  trial_ends_at, next_billing_date
)
select 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', id, 'trial', 'monthly', monthly_price,
       now() + interval '5 days', now() + interval '5 days'
from public.plans where code = 'institutional_500';

do $$
declare
  v_failed boolean := false;
begin
  begin
    perform public.record_manual_payment(
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
      1,
      'P1-BANK-INVALID',
      'P1-INV-INVALID',
      now(),
      'Monto inválido'
    );
  exception when others then
    v_failed := true;
  end;

  if not v_failed then
    raise exception 'underpayment activated the subscription';
  end if;
  if exists (
    select 1 from public.payments where school_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1'
  ) then
    raise exception 'failed payment left a persisted row';
  end if;
end
$$;

select public.record_manual_payment(
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
  439,
  'P1-BANK-VALID',
  'P1-INV-VALID',
  now(),
  'Transferencia verificada'
);

do $$
begin
  if not exists (
    select 1 from public.payments
    where school_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1'
      and amount = 439
      and provider_reference = 'P1-BANK-VALID'
      and external_invoice_number = 'P1-INV-VALID'
      and recorded_by = auth.uid()
  ) then
    raise exception 'auditable payment row was not created';
  end if;

  if not exists (
    select 1 from public.subscriptions
    where school_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1'
      and status::text = 'active'
      and next_billing_date > now() + interval '1 month'
  ) then
    raise exception 'subscription was not activated and extended from trial end';
  end if;

  if not exists (
    select 1 from public.schools
    where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1'
      and status::text = 'active'
      and is_active
  ) then
    raise exception 'school was not activated after payment';
  end if;
end
$$;

select public.set_tenant_status(
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
  'suspended',
  'Incumplimiento de términos',
  'Fixture de auditoría'
);

do $$
begin
  if not exists (
    select 1 from public.schools sc
    join public.subscriptions su on su.school_id = sc.id
    where sc.id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1'
      and sc.status::text = 'suspended'
      and su.status::text = 'suspended'
      and not sc.is_active
  ) then
    raise exception 'status change did not update school and subscription atomically';
  end if;

  if not exists (
    select 1 from public.tenant_status_logs
    where school_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1'
      and new_status::text = 'suspended'
      and actor_id = auth.uid()
  ) then
    raise exception 'status change was not audited';
  end if;
end
$$;

rollback;
