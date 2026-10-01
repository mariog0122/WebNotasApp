-- Contract test for migrations/14_p1_commercial_catalog_limits.sql
-- Safe to run against a live project: every fixture is rolled back.
begin;

do $$
declare
  v_paid_plan_count integer;
begin
  if to_regclass('public.tenant_limits') is null then
    raise exception 'tenant_limits table is missing';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'plans'
      and column_name = 'monthly_price'
  ) then
    raise exception 'plans.monthly_price is missing';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'subscriptions'
      and column_name = 'agreed_price'
  ) then
    raise exception 'subscriptions.agreed_price is missing';
  end if;

  select count(*) into v_paid_plan_count
  from public.plans
  where active and code like 'institutional_%';

  if v_paid_plan_count <> 3 then
    raise exception 'expected 3 active institutional plans, found %', v_paid_plan_count;
  end if;

  if not exists (
    select 1 from public.plans
    where code = 'institutional_500'
      and monthly_price = 89
      and annual_price = 890
      and student_limit = 500
      and trial_days = 15
      and implementation_fee = 350
  ) then
    raise exception 'institutional_500 commercial contract mismatch';
  end if;

  if not exists (
    select 1 from public.plans
    where code = 'institutional_1000'
      and monthly_price = 129
      and annual_price = 1290
      and student_limit = 1000
  ) then
    raise exception 'institutional_1000 commercial contract mismatch';
  end if;

  if not exists (
    select 1 from public.plans
    where code = 'institutional_2000'
      and monthly_price = 179
      and annual_price = 1790
      and student_limit = 2000
  ) then
    raise exception 'institutional_2000 commercial contract mismatch';
  end if;
end
$$;

do $$
declare
  v_school_id uuid;
  v_course_id uuid;
  v_actor_id uuid;
  v_blocked boolean := false;
begin
  select s.id, c.id, p.id
    into v_school_id, v_course_id, v_actor_id
  from public.schools s
  join public.courses c on c.school_id = s.id
  join public.profiles p on p.school_id = s.id
  where exists (select 1 from public.students st where st.school_id = s.id)
  limit 1;

  if v_school_id is null then
    raise exception 'student-limit test requires one existing school/course fixture';
  end if;

  update public.tenant_limits
  set max_students = (select count(*) from public.students where school_id = v_school_id)
  where school_id = v_school_id;

  perform set_config('request.jwt.claim.sub', v_actor_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  begin
    insert into public.students (full_name, course_id, school_id)
    values ('P1 limit contract fixture', v_course_id, v_school_id);
  exception
    when raise_exception then
      v_blocked := position('STUDENT_LIMIT_REACHED' in sqlerrm) > 0;
  end;

  if not v_blocked then
    raise exception 'student insert was not blocked at the subscribed limit';
  end if;
end
$$;

rollback;
