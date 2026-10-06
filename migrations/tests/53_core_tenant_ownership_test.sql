begin;

do $$
declare
  v_table text;
  v_allows_null boolean;
begin
  foreach v_table in array array[
    'academic_years',
    'courses',
    'quarters',
    'subjects',
    'students',
    'system_config',
    'grade_definitions',
    'course_subjects',
    'grades',
    'attendance_records',
    'student_alerts',
    'teacher_reports'
  ]
  loop
    select not a.attnotnull
      and not exists (
        select 1
        from pg_catalog.pg_constraint c
        where c.conrelid = a.attrelid
          and c.contype = 'c'
          and pg_catalog.pg_get_constraintdef(c.oid) ~* 'school_id IS NOT NULL'
      )
    into v_allows_null
    from pg_catalog.pg_attribute a
    where a.attrelid = format('public.%I', v_table)::regclass
      and a.attname = 'school_id'
      and not a.attisdropped;

    if coalesce(v_allows_null, true) then
      raise exception 'SECURITY: public.% still permits new rows without school_id', v_table;
    end if;
  end loop;
end
$$;

rollback;
select 'core_tenant_ownership_tests_passed' as result;

