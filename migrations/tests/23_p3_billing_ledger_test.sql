-- Contract test for migrations/23_p3_billing_ledger.sql
-- Safe on a live project: all fixtures are rolled back.
begin;

do $$
begin
  if to_regclass('public.invoices') is null
     or to_regclass('public.invoice_payment_allocations') is null
     or to_regclass('public.payment_events') is null then
    raise exception 'P3 billing ledger tables are missing';
  end if;
  if to_regprocedure('public.ingest_payment_event(text,text,text,text,jsonb)') is null then
    raise exception 'ingest_payment_event is missing';
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
values ('cccccccc-cccc-4ccc-8ccc-ccccccccccc1', 'P3 billing fixture', 'P3-BILLING', 'trial', true);

insert into public.subscriptions (
  school_id, plan_id, status, billing_cycle, agreed_price,
  trial_ends_at, next_billing_date
)
select 'cccccccc-cccc-4ccc-8ccc-ccccccccccc1', id, 'trial', 'monthly', monthly_price,
       now() + interval '5 days', now() + interval '5 days'
from public.plans where code = 'institutional_500';

select public.record_manual_payment(
  'cccccccc-cccc-4ccc-8ccc-ccccccccccc1',
  439,
  'P3-BANK-VALID',
  'P3-INV-VALID',
  now(),
  'Pago con factura conciliada'
);

do $$
begin
  if not exists (
    select 1
    from public.invoices i
    join public.invoice_payment_allocations a on a.invoice_id = i.id
    join public.payments p on p.id = a.payment_id
    where i.school_id = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc1'
      and i.invoice_number = 'P3-INV-VALID'
      and i.status = 'paid'
      and i.total = 439
      and a.amount = 439
      and p.provider_reference = 'P3-BANK-VALID'
  ) then
    raise exception 'manual payment was not invoiced and allocated atomically';
  end if;
end
$$;

do $$
declare
  v_first json;
  v_duplicate json;
  v_failed boolean := false;
begin
  v_first := public.ingest_payment_event(
    'kushki', 'P3-EVENT-1', 'payment.approved', repeat('a', 64), '{"ticket":"redacted"}'::jsonb
  );
  v_duplicate := public.ingest_payment_event(
    'KUSHKI', 'P3-EVENT-1', 'payment.approved', repeat('a', 64), '{"ticket":"redacted"}'::jsonb
  );

  if (v_first->>'duplicate')::boolean or not (v_duplicate->>'duplicate')::boolean
     or v_first->>'event_id' <> v_duplicate->>'event_id' then
    raise exception 'provider event idempotency failed';
  end if;

  begin
    perform public.ingest_payment_event(
      'kushki', 'P3-EVENT-1', 'payment.approved', repeat('b', 64), '{}'::jsonb
    );
  exception when others then
    v_failed := sqlerrm like '%PAYMENT_EVENT_REPLAY_MISMATCH%';
  end;

  if not v_failed then
    raise exception 'mismatched provider event replay was accepted';
  end if;

  perform public.complete_payment_event(
    (v_first->>'event_id')::uuid,
    'processed',
    'cccccccc-cccc-4ccc-8ccc-ccccccccccc1',
    null,
    null
  );
end
$$;

do $$
begin
  if not exists (
    select 1 from public.payment_events
    where provider = 'kushki'
      and provider_event_id = 'P3-EVENT-1'
      and status = 'processed'
      and attempt_count = 1
      and school_id = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc1'
  ) then
    raise exception 'provider event completion was not persisted';
  end if;
end
$$;

rollback;
