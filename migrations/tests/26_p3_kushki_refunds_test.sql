-- Contract test for migrations/26_p3_kushki_refunds.sql
-- Safe on a live project: all fixtures are rolled back.
begin;

insert into public.schools (id, name, code, status, is_active)
values ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1', 'P3 refund fixture', 'P3-REFUND', 'trial', true);

insert into public.subscriptions (
  school_id, plan_id, status, billing_cycle, agreed_price,
  trial_ends_at, next_billing_date
)
select 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1', id, 'trial', 'monthly', monthly_price,
       now() + interval '5 days', now() + interval '5 days'
from public.plans where code = 'institutional_500';

do $$
declare
  v_sale json;
  v_refund json;
  v_result json;
  v_duplicate json;
begin
  v_sale := public.ingest_payment_event(
    'kushki', 'P3-SALE-1:sale:APPROVAL', 'sale.approval', repeat('e', 64),
    jsonb_build_object(
      'transaction_id', 'P3-SALE-1',
      'transaction_reference', 'P3-SALE-REFERENCE-1',
      'ticket_number', 'P3-SALE-TICKET-1',
      'transaction_type', 'sale', 'transaction_status', 'APPROVAL',
      'currency', 'USD', 'created', extract(epoch from now()),
      'amount', jsonb_build_object('total', 439),
      'metadata', jsonb_build_object(
        'school_id', 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1',
        'invoice_number', 'P3-REFUND-INV-1'
      )
    )
  );
  perform public.process_kushki_payment_event((v_sale->>'event_id')::uuid);

  v_refund := public.ingest_payment_event(
    'kushki', 'P3-REFUND-1:refund:APPROVAL', 'refund.approval', repeat('f', 64),
    jsonb_build_object(
      'transaction_id', 'P3-REFUND-1',
      'transaction_type', 'refund', 'transaction_status', 'APPROVAL',
      'sale_transaction_reference', 'P3-SALE-REFERENCE-1',
      'sale_ticket_number', 'P3-SALE-TICKET-1',
      'currency', 'USD', 'created', extract(epoch from now()),
      'amount', jsonb_build_object('total', 439),
      'metadata', jsonb_build_object('invoice_number', 'P3-REFUND-INV-1')
    )
  );
  v_result := public.process_kushki_refund_event((v_refund->>'event_id')::uuid);
  v_duplicate := public.process_kushki_refund_event((v_refund->>'event_id')::uuid);

  if (v_result->>'status') <> 'processed'
     or (v_result->>'duplicate')::boolean
     or not (v_duplicate->>'duplicate')::boolean then
    raise exception 'refund was not processed idempotently';
  end if;
end
$$;

do $$
begin
  if (select count(*) from public.payment_refunds where provider_reference = 'P3-REFUND-1') <> 1 then
    raise exception 'refund count is not idempotent';
  end if;
  if not exists (
    select 1 from public.payments p
    join public.invoice_payment_allocations a on a.payment_id = p.id
    join public.invoices i on i.id = a.invoice_id
    where p.provider_reference = 'P3-SALE-1'
      and p.status = 'refunded'
      and i.status = 'refunded'
  ) then
    raise exception 'original payment and invoice were not marked refunded';
  end if;
  if not exists (
    select 1 from public.schools sc
    join public.subscriptions su on su.school_id = sc.id
    where sc.id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1'
      and sc.status::text = 'grace_period'
      and sc.is_active
      and su.status::text = 'grace_period'
      and su.grace_period_until > now() + interval '6 days'
  ) then
    raise exception 'full current-period refund did not enter financial grace';
  end if;
end
$$;

do $$
declare
  v_event json;
  v_result json;
begin
  v_event := public.ingest_payment_event(
    'kushki', 'P3-VOID-DECLINED:void:DECLINED', 'void.declined', repeat('1', 64),
    '{"transaction_id":"P3-VOID-DECLINED","transaction_type":"void","transaction_status":"DECLINED"}'::jsonb
  );
  v_result := public.process_kushki_refund_event((v_event->>'event_id')::uuid);
  if (v_result->>'status') <> 'ignored' then
    raise exception 'declined void was not safely ignored';
  end if;
end
$$;

rollback;

