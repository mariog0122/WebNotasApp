-- Ejecutar después de consolidate_policies_and_indexes. Todos los cambios se revierten.
begin;

select set_config(
  'audit.policy_school',
  (select school_id::text from public.profiles where school_id is not null order by created_at limit 1),
  true
);
select set_config(
  'audit.policy_actor',
  (select id::text from public.profiles
   where school_id::text = current_setting('audit.policy_school')
   order by created_at limit 1),
  true
);

delete from public.user_platform_roles
where user_id::text = current_setting('audit.policy_actor');
update public.profiles
set role = 'teacher', is_active = true
where id::text = current_setting('audit.policy_actor');
insert into public.tenant_memberships (user_id, school_id, tenant_role_id, is_active)
select current_setting('audit.policy_actor')::uuid,
       current_setting('audit.policy_school')::uuid,
       tr.id,
       true
from public.tenant_roles tr
where tr.name = 'teacher'
on conflict (user_id, school_id) do update
set tenant_role_id = excluded.tenant_role_id, is_active = true;

select set_config('request.jwt.claim.sub', current_setting('audit.policy_actor'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;

do $$
declare
  v_year text;
  v_blocked boolean := false;
begin
  select name into v_year
  from public.academic_years
  where school_id::text = current_setting('audit.policy_school')
  order by name limit 1;

  begin
    insert into public.courses (school_id, name, academic_year)
    values (
      current_setting('audit.policy_school')::uuid,
      '__AUDIT_UNAUTHORIZED_COURSE__',
      v_year
    );
  exception when insufficient_privilege then
    v_blocked := true;
  end;
  if not v_blocked then
    raise exception 'teacher inserted a course without settings.manage';
  end if;

  if not exists (
    select 1 from public.courses
    where school_id::text = current_setting('audit.policy_school')
  ) then
    raise exception 'teacher lost own-tenant course read access';
  end if;
end
$$;

reset role;

do $$
declare
  v_duplicate record;
begin
  select tablename, cmd, count(*) as policy_count
  into v_duplicate
  from pg_policies
  where schemaname = 'public'
    and tablename in (
      'courses',
      'institution_ai_settings',
      'schools',
      'tenant_features',
      'tenant_limits'
    )
    and 'authenticated' = any(roles)
  group by tablename, cmd
  having count(*) > 1
  limit 1;

  if v_duplicate.tablename is not null then
    raise exception 'duplicate policy remains on % for %', v_duplicate.tablename, v_duplicate.cmd;
  end if;

  if exists (
    select 1 from pg_indexes
    where schemaname = 'public'
      and indexname in (
        'idx_courses_school_id',
        'idx_grades_course_subject_id',
        'idx_grades_quarter_id',
        'idx_grades_composite',
        'idx_grades_student_definition',
        'idx_payments_school_id'
      )
  ) then
    raise exception 'a redundant index remains';
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'courses'
      and column_name = 'school_id'
      and is_nullable = 'YES'
  ) then
    raise exception 'courses.school_id remains nullable';
  end if;
end
$$;

rollback;

select 'policy_and_index_consolidation_tests_passed' as result;
