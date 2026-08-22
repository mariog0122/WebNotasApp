-- The student cap is commercial data: it must always match the subscribed plan.
create or replace function public.enforce_plan_student_limit()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_plan_limit integer;
begin
  select p.student_limit
    into v_plan_limit
  from public.subscriptions s
  join public.plans p on p.id = s.plan_id
  where s.school_id = new.school_id
  order by s.created_at desc
  limit 1;

  if v_plan_limit is null then
    raise exception 'SUBSCRIPTION_LIMIT_REQUIRED' using errcode = 'P0001';
  end if;

  if new.max_students is distinct from v_plan_limit then
    raise exception 'PLAN_STUDENT_LIMIT_IMMUTABLE' using errcode = 'P0001';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_plan_student_limit() from public, anon, authenticated;

drop trigger if exists tenant_limits_enforce_plan_student_limit on public.tenant_limits;
create trigger tenant_limits_enforce_plan_student_limit
before insert or update of max_students on public.tenant_limits
for each row execute function public.enforce_plan_student_limit();

