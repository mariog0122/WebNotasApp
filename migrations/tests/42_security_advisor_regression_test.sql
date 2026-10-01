-- Ejecutar después de resolve_security_advisor_warnings. Solo realiza comprobaciones.
begin;

do $$
declare
  v_table text;
  v_signature text;
  v_function regprocedure;
begin
  foreach v_table in array array[
    'client_error_events',
    'invoice_payment_allocations',
    'invoices',
    'lesson_plan_versions',
    'payment_events',
    'payment_refunds',
    'student_support_events'
  ]
  loop
    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = v_table
    ) then
      raise exception 'RLS table % has no policy', v_table;
    end if;
    if has_table_privilege('anon', format('public.%I', v_table), 'SELECT')
       or has_table_privilege('anon', format('public.%I', v_table), 'INSERT')
       or has_table_privilege('anon', format('public.%I', v_table), 'UPDATE')
       or has_table_privilege('anon', format('public.%I', v_table), 'DELETE') then
      raise exception 'anon retains DML on %', v_table;
    end if;
  end loop;

  foreach v_signature in array array[
    'public.auto_fill_academic_year_fields()',
    'public.check_ai_planning_access(uuid)',
    'public.check_duplicate_course_name()',
    'public.ensure_default_grade_definitions(uuid,uuid)',
    'public.get_my_access_context()',
    'public.get_tenant_usage_stats(uuid)',
    'public.get_user_school_id()',
    'public.has_platform_role(text[])',
    'public.is_platform_admin()',
    'public.is_platform_owner()',
    'public.justify_attendance_records(uuid,date[],text,uuid)',
    'public.save_attendance_batch(uuid,uuid,date,text,jsonb)',
    'public.save_teacher_report(jsonb)'
  ]
  loop
    v_function := to_regprocedure(v_signature);
    if v_function is not null and has_function_privilege('anon', v_function, 'EXECUTE') then
      raise exception 'anon executes %', v_signature;
    end if;
  end loop;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private'
      and p.proname in (
        'touch_teacher_reports_updated_at',
        'touch_attendance_records_updated_at',
        'touch_lesson_plans_updated_at'
      )
      and not coalesce(p.proconfig, '{}'::text[]) @> array['search_path=pg_catalog, public, private']
  ) then
    raise exception 'private timestamp trigger has a mutable search_path';
  end if;
end
$$;

rollback;

select 'security_advisor_regression_tests_passed' as result;
