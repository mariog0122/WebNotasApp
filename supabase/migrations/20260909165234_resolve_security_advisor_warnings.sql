-- Restore intended access to RLS tables and remove anonymous definer execution.

drop policy if exists client_error_events_insert on public.client_error_events;
drop policy if exists client_error_events_select on public.client_error_events;
create policy client_error_events_insert
on public.client_error_events for insert to authenticated
with check (
  user_id = auth.uid()
  and school_id is not distinct from public.get_user_school_id()
);
create policy client_error_events_select
on public.client_error_events for select to authenticated
using (public.is_platform_admin());
revoke all on table public.client_error_events from public, anon, authenticated;
grant select, insert on table public.client_error_events to authenticated;

drop policy if exists invoices_select on public.invoices;
create policy invoices_select
on public.invoices for select to authenticated
using (
  public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance'])
  or (
    school_id = public.get_user_school_id()
    and public.has_tenant_permission('billing.read')
  )
);
revoke all on table public.invoices from public, anon, authenticated;
grant select on table public.invoices to authenticated;

drop policy if exists invoice_payment_allocations_select on public.invoice_payment_allocations;
create policy invoice_payment_allocations_select
on public.invoice_payment_allocations for select to authenticated
using (
  exists (
    select 1
    from public.invoices i
    where i.id = invoice_id
      and (
        public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance'])
        or (
          i.school_id = public.get_user_school_id()
          and public.has_tenant_permission('billing.read')
        )
      )
  )
);
revoke all on table public.invoice_payment_allocations from public, anon, authenticated;
grant select on table public.invoice_payment_allocations to authenticated;

drop policy if exists payment_events_select on public.payment_events;
create policy payment_events_select
on public.payment_events for select to authenticated
using (
  public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance'])
);
revoke all on table public.payment_events from public, anon, authenticated;
grant select on table public.payment_events to authenticated;

drop policy if exists payment_refunds_select on public.payment_refunds;
create policy payment_refunds_select
on public.payment_refunds for select to authenticated
using (
  exists (
    select 1
    from public.payments p
    where p.id = payment_id
      and (
        public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance'])
        or (
          p.school_id = public.get_user_school_id()
          and public.has_tenant_permission('billing.read')
        )
      )
  )
);
revoke all on table public.payment_refunds from public, anon, authenticated;
grant select on table public.payment_refunds to authenticated;

drop policy if exists lesson_plan_versions_select on public.lesson_plan_versions;
drop policy if exists lesson_plan_versions_insert on public.lesson_plan_versions;
create policy lesson_plan_versions_select
on public.lesson_plan_versions for select to authenticated
using (
  exists (
    select 1
    from public.lesson_plans lp
    where lp.id = lesson_plan_id
      and (
        public.is_platform_admin()
        or (
          lp.school_id = public.get_user_school_id()
          and (
            public.is_admin()
            or lp.teacher_id = auth.uid()
            or public.has_tenant_permission('grades.read')
          )
        )
      )
  )
);
create policy lesson_plan_versions_insert
on public.lesson_plan_versions for insert to authenticated
with check (
  (created_by is null or created_by = auth.uid())
  and exists (
    select 1
    from public.lesson_plans lp
    where lp.id = lesson_plan_id
      and (
        public.is_platform_admin()
        or (
          lp.school_id = public.get_user_school_id()
          and (public.is_admin() or lp.teacher_id = auth.uid())
        )
      )
  )
);
revoke all on table public.lesson_plan_versions from public, anon, authenticated;
grant select, insert on table public.lesson_plan_versions to authenticated;

drop policy if exists student_support_events_select on public.student_support_events;
drop policy if exists student_support_events_insert on public.student_support_events;
create policy student_support_events_select
on public.student_support_events for select to authenticated
using (
  exists (
    select 1
    from public.student_support_plans sp
    where sp.id = support_plan_id
      and (
        public.is_platform_admin()
        or (
          sp.school_id = public.get_user_school_id()
          and (
            public.is_admin()
            or sp.teacher_id = auth.uid()
            or public.has_tenant_permission('attendance.read')
          )
        )
      )
  )
);
create policy student_support_events_insert
on public.student_support_events for insert to authenticated
with check (
  (created_by is null or created_by = auth.uid())
  and exists (
    select 1
    from public.student_support_plans sp
    where sp.id = support_plan_id
      and (
        public.is_platform_admin()
        or (
          sp.school_id = public.get_user_school_id()
          and (public.is_admin() or sp.teacher_id = auth.uid())
        )
      )
  )
);
revoke all on table public.student_support_events from public, anon, authenticated;
grant select, insert on table public.student_support_events to authenticated;

alter function private.touch_teacher_reports_updated_at()
set search_path = pg_catalog, public, private;
alter function private.touch_attendance_records_updated_at()
set search_path = pg_catalog, public, private;
alter function private.touch_lesson_plans_updated_at()
set search_path = pg_catalog, public, private;

revoke all on function public.auto_fill_academic_year_fields()
from public, anon, authenticated;
revoke all on function public.check_duplicate_course_name()
from public, anon, authenticated;

revoke all on function public.check_ai_planning_access(uuid) from public, anon;
revoke all on function public.ensure_default_grade_definitions(uuid, uuid) from public, anon;
revoke all on function public.get_my_access_context() from public, anon;
revoke all on function public.get_tenant_usage_stats(uuid) from public, anon;
revoke all on function public.get_user_school_id() from public, anon;
revoke all on function public.has_platform_role(text[]) from public, anon;
revoke all on function public.is_platform_admin() from public, anon;
revoke all on function public.is_platform_owner() from public, anon;
revoke all on function public.justify_attendance_records(uuid, date[], text, uuid) from public, anon;
revoke all on function public.save_attendance_batch(uuid, uuid, date, text, jsonb) from public, anon;
revoke all on function public.save_teacher_report(jsonb) from public, anon;
