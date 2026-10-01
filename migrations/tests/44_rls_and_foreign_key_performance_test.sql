-- Ejecutar después de optimize_rls_and_foreign_keys. Solo realiza comprobaciones.
begin;

do $$
declare
  v_index text;
begin
  foreach v_index in array array[
    'idx_fk_attendance_records_justified_by',
    'idx_fk_attendance_records_quarter_id',
    'idx_fk_attendance_records_subject_id',
    'idx_fk_attendance_records_teacher_id',
    'idx_fk_curriculum_items_catalog_id',
    'idx_fk_lesson_plan_resources_teacher_id',
    'idx_fk_lesson_plan_versions_created_by',
    'idx_fk_lesson_plans_quarter_id',
    'idx_fk_lesson_plans_subject_id',
    'idx_fk_student_support_events_created_by',
    'idx_fk_student_support_events_support_plan_id',
    'idx_fk_student_support_plans_approved_by',
    'idx_fk_student_support_plans_course_id',
    'idx_fk_student_support_plans_lesson_plan_id',
    'idx_fk_student_support_plans_subject_id',
    'idx_fk_teacher_reports_quarter_id',
    'idx_fk_teacher_reports_subject_id'
  ]
  loop
    if to_regclass('public.' || v_index) is null then
      raise exception 'missing foreign-key index %', v_index;
    end if;
  end loop;

  if exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and (tablename, policyname) in (
        ('client_error_events', 'client_error_events_insert'),
        ('lesson_plan_versions', 'lesson_plan_versions_select'),
        ('lesson_plan_versions', 'lesson_plan_versions_insert'),
        ('student_support_events', 'student_support_events_select'),
        ('student_support_events', 'student_support_events_insert'),
        ('grade_definitions', 'grade_definitions_insert'),
        ('grade_definitions', 'grade_definitions_update'),
        ('teacher_reports', 'teacher_reports_select'),
        ('teacher_reports', 'teacher_reports_insert'),
        ('teacher_reports', 'teacher_reports_update'),
        ('teacher_reports', 'teacher_reports_delete'),
        ('attendance_records', 'attendance_records_select'),
        ('attendance_records', 'attendance_records_insert'),
        ('attendance_records', 'attendance_records_update'),
        ('lesson_plans', 'lesson_plans_select'),
        ('lesson_plans', 'lesson_plans_insert'),
        ('lesson_plans', 'lesson_plans_update'),
        ('lesson_plans', 'lesson_plans_delete'),
        ('lesson_plan_resources', 'lesson_plan_resources_all'),
        ('student_support_plans', 'student_support_plans_all'),
        ('ai_usage_ledger', 'ai_usage_ledger_select')
      )
      and regexp_replace(
        lower(coalesce(qual, '') || ' ' || coalesce(with_check, '')),
        '\\(\\s*select\\s+auth\\.uid\\(\\)(?:\\s+as\\s+uid)?\\s*\\)',
        '',
        'g'
      ) ~ 'auth\\.uid\\(\\)'
  ) then
    raise exception 'an RLS policy still evaluates auth.uid() per row';
  end if;
end
$$;

rollback;

select 'rls_and_foreign_key_performance_tests_passed' as result;
