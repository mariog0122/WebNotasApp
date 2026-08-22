-- Contract test for migrations/25_p3_kushki_event_processing.sql
-- Safe on a live project: all fixtures are rolled back.
begin;

do $$
begin
  if to_regprocedure('public.process_kushki_payment_event(uuid)') is null then
    raise exception 'process_kushki_payment_event is missing';
  end if;
end
$$;

insert into public.schools (id, name, code, status, is_active)
values ('dddddddd-dddd-4ddd-8ddd-ddddddddddd1', 'P3 Kushki fixture', 'P3-KUSHKI', 'trial', true);

insert into public.subscriptions (
  school_id, plan_id, status, billing_cycle, agreed_price,
  trial_ends_at, next_billing_date
)
select 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1', id, 'trial', 'monthly', monthly_price,
       now() + interval '5 days', now() + interval '5 days'
from public.plans where code = 'institutional_500';

do $$
declare
  v_event json;
  v_result json;
  v_duplicate json;
begin
  v_event := public.ingest_payment_event(
    'kushki',
    'P3-KUSHKI-TX-1:sale:APPROVAL',
    'sale.approval',
    repeat('c', 64),
    jsonb_build_object(
      'transaction_id', 'P3-KUSHKI-TX-1',
      'transaction_type', 'sale',
      'transaction_status', 'APPROVAL',
      'currency', 'USD',
      'created', extract(epoch from now()),
      'amount', jsonb_build_object('total', 439),
      'metadata', jsonb_build_object(
        'school_id', 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1',
        'invoice_number', 'P3-KUSHKI-INV-1'
      )
    )
  );

  v_result := public.process_kushki_payment_event((v_event->>'event_id')::uuid);
  v_duplicate := public.process_kushki_payment_event((v_event->>'event_id')::uuid);

  if (v_result->>'status') <> 'processed'
     or (v_result->>'duplicate')::boolean
     or not (v_duplicate->>'duplicate')::boolean
     or v_result->>'payment_id' <> v_duplicate->>'payment_id' then
    raise exception 'approved event was not processed idempotently';
  end if;
end
$$;

do $$
begin
  if (select count(*) from public.payments where provider = 'kushki' and provider_reference = 'P3-KUSHKI-TX-1') <> 1 then
    raise exception 'approved event created an incorrect payment count';
  end if;

  if not exists (
    select 1
    from public.invoices i
    join public.invoice_payment_allocations a on a.invoice_id = i.id
    join public.payments p on p.id = a.payment_id
    where i.invoice_number = 'P3-KUSHKI-INV-1'
      and i.status = 'paid'
      and i.total = 439
      and p.provider_reference = 'P3-KUSHKI-TX-1'
  ) then
    raise exception 'approved event did not reconcile its invoice';
  end if;

  if not exists (
    select 1 from public.schools sc
    join public.subscriptions su on su.school_id = sc.id
    where sc.id = 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1'
      and sc.status::text = 'active'
      and su.status::text = 'active'
      and su.next_billing_date > now() + interval '1 month'
  ) then
    raise exception 'approved event did not activate and extend the subscription';
  end if;
end
$$;

do $$
declare
  v_event json;
  v_result json;
begin
  v_event := public.ingest_payment_event(
    'kushki', 'P3-KUSHKI-TX-2:sale:DECLINED', 'sale.declined', repeat('d', 64),
    '{"transaction_id":"P3-KUSHKI-TX-2","transaction_type":"sale","transaction_status":"DECLINED"}'::jsonb
  );
  v_result := public.process_kushki_payment_event((v_event->>'event_id')::uuid);
  if (v_result->>'status') <> 'ignored' then
    raise exception 'declined event was not safely ignored';
  end if;
  if exists (select 1 from public.payments where provider_reference = 'P3-KUSHKI-TX-2') then
    raise exception 'declined event created a payment';
  end if;
end
$$;

rollback;
