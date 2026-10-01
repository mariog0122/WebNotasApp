-- Contract test for migrations/15_p1_subscription_lifecycle.sql
-- Safe on a live project: lifecycle fixtures are rolled back.
begin;

do $$
begin
  if to_regprocedure('public.reconcile_subscription_lifecycle()') is null then
    raise exception 'reconcile_subscription_lifecycle function is missing';
  end if;

  if to_regclass('cron.job') is null then
    raise exception 'pg_cron is not enabled';
  end if;

  if not exists (
    select 1 from cron.job where jobname = 'reconcile-subscription-lifecycle'
  ) then
    raise exception 'subscription lifecycle cron job is missing';
  end if;
end
$$;

insert into public.schools (id, name, code, status, is_active) values
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1', 'P1 expired trial', 'P1-TRIAL-EXPIRED', 'trial', true),
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2', 'P1 overdue active', 'P1-ACTIVE-OVERDUE', 'active', true),
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee3', 'P1 expired grace', 'P1-GRACE-EXPIRED', 'grace_period', true);

insert into public.subscriptions (
  school_id, plan_id, status, billing_cycle, agreed_price,
  trial_ends_at, next_billing_date, grace_period_until
)
select 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1'::uuid, id, 'trial'::public.tenant_status_type, 'monthly', monthly_price,
       now() - interval '1 minute', now() - interval '1 minute', null::timestamptz
from public.plans where code = 'institutional_500'
union all
select 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2'::uuid, id, 'active'::public.tenant_status_type, 'monthly', monthly_price,
       null::timestamptz, now() - interval '1 minute', null::timestamptz
from public.plans where code = 'institutional_500'
union all
select 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee3'::uuid, id, 'grace_period'::public.tenant_status_type, 'monthly', monthly_price,
       null::timestamptz, now() - interval '8 days', now() - interval '1 minute'
from public.plans where code = 'institutional_500';

select public.reconcile_subscription_lifecycle();

do $$
begin
  if not exists (
    select 1 from public.subscriptions
    where school_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1'
      and status::text = 'suspended'
  ) then
    raise exception 'expired trial was not suspended';
  end if;

  if not exists (
    select 1 from public.subscriptions
    where school_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2'
      and status::text = 'grace_period'
      and grace_period_until > now()
  ) then
    raise exception 'overdue active subscription did not enter grace period';
  end if;

  if not exists (
    select 1 from public.subscriptions
    where school_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee3'
      and status::text = 'suspended'
  ) then
    raise exception 'expired grace subscription was not suspended';
  end if;

  if public.is_school_entitled('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1') then
    raise exception 'expired trial still has entitlement';
  end if;

  if not public.is_school_entitled('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2') then
    raise exception 'tenant in valid grace period lost entitlement';
  end if;
end
$$;

rollback;
