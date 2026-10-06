begin;

do $$
declare
  uncovered_fks integer;
  duplicate_select_policies integer;
begin
  select count(*) into uncovered_fks
  from pg_constraint con
  join pg_class c on c.oid = con.conrelid
  join pg_namespace n on n.oid = c.relnamespace
  where con.contype = 'f'
    and n.nspname = 'public'
    and not exists (
      select 1
      from pg_index i
      where i.indrelid = con.conrelid
        and i.indisvalid
        and (i.indkey::smallint[])[0:cardinality(con.conkey)-1] = con.conkey
    );

  if uncovered_fks <> 0 then
    raise exception 'Expected all public foreign keys covered, found %', uncovered_fks;
  end if;

  if to_regclass('public.grades_definition_id_idx') is not null
     or to_regclass('public.grades_student_id_idx') is not null
     or to_regclass('public.students_course_id_idx') is not null then
    raise exception 'Redundant legacy indexes still exist';
  end if;

  select count(*) into duplicate_select_policies
  from pg_policies
  where schemaname = 'public'
    and tablename in ('tenant_billing_profiles', 'tenant_limits')
    and cmd in ('SELECT', 'ALL');

  if duplicate_select_policies <> 2 then
    raise exception 'Expected one SELECT-capable policy per hardened table, found %', duplicate_select_policies;
  end if;

  if exists (
    select 1 from pg_extension e
    join pg_namespace n on n.oid = e.extnamespace
    where e.extname = 'pg_trgm' and n.nspname = 'public'
  ) then
    raise exception 'pg_trgm remains in public schema';
  end if;

  if has_function_privilege('authenticated', 'public.reconcile_subscription_lifecycle()', 'EXECUTE') then
    raise exception 'Lifecycle reconciliation remains exposed to authenticated users';
  end if;
end $$;

rollback;
