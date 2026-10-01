-- Cache auth.uid() once per statement in the policies reported by the advisor.
do $$
declare
  v_policy record;
  v_using text;
  v_check text;
  v_sql text;
begin
  for v_policy in
    select p.*
    from pg_policies p
    join (
      values
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
    ) target(tablename, policyname)
      on target.tablename = p.tablename
     and target.policyname = p.policyname
    where p.schemaname = 'public'
  loop
    v_using := replace(v_policy.qual, 'auth.uid()', '(SELECT auth.uid())');
    v_check := replace(v_policy.with_check, 'auth.uid()', '(SELECT auth.uid())');

    execute format(
      'drop policy if exists %I on public.%I',
      v_policy.policyname,
      v_policy.tablename
    );

    v_sql := format(
      'create policy %I on public.%I for %s to authenticated',
      v_policy.policyname,
      v_policy.tablename,
      v_policy.cmd
    );
    if v_using is not null then
      v_sql := v_sql || ' using (' || v_using || ')';
    end if;
    if v_check is not null then
      v_sql := v_sql || ' with check (' || v_check || ')';
    end if;
    execute v_sql;
  end loop;
end
$$;

create index if not exists idx_fk_attendance_records_justified_by
on public.attendance_records (justified_by);
create index if not exists idx_fk_attendance_records_quarter_id
on public.attendance_records (quarter_id);
create index if not exists idx_fk_attendance_records_subject_id
on public.attendance_records (subject_id);
create index if not exists idx_fk_attendance_records_teacher_id
on public.attendance_records (teacher_id);
create index if not exists idx_fk_curriculum_items_catalog_id
on public.curriculum_items (catalog_id);
create index if not exists idx_fk_lesson_plan_resources_teacher_id
on public.lesson_plan_resources (teacher_id);
create index if not exists idx_fk_lesson_plan_versions_created_by
on public.lesson_plan_versions (created_by);
create index if not exists idx_fk_lesson_plans_quarter_id
on public.lesson_plans (quarter_id);
create index if not exists idx_fk_lesson_plans_subject_id
on public.lesson_plans (subject_id);
create index if not exists idx_fk_student_support_events_created_by
on public.student_support_events (created_by);
create index if not exists idx_fk_student_support_events_support_plan_id
on public.student_support_events (support_plan_id);
create index if not exists idx_fk_student_support_plans_approved_by
on public.student_support_plans (approved_by);
create index if not exists idx_fk_student_support_plans_course_id
on public.student_support_plans (course_id);
create index if not exists idx_fk_student_support_plans_lesson_plan_id
on public.student_support_plans (lesson_plan_id);
create index if not exists idx_fk_student_support_plans_subject_id
on public.student_support_plans (subject_id);
create index if not exists idx_fk_teacher_reports_quarter_id
on public.teacher_reports (quarter_id);
create index if not exists idx_fk_teacher_reports_subject_id
on public.teacher_reports (subject_id);
