-- P2: remove avoidable database-advisor findings without changing tenant data.

create schema if not exists extensions;
alter extension pg_trgm set schema extensions;

-- Lifecycle reconciliation is an internal pg_cron operation, never a public RPC.
revoke execute on function public.reconcile_subscription_lifecycle() from public, anon, authenticated;

-- Remove redundant physical indexes while retaining the consistently named copies.
drop index if exists public.grades_definition_id_idx;
drop index if exists public.grades_student_id_idx;
drop index if exists public.students_course_id_idx;

-- Cover every remaining foreign-key prefix to keep deletes, joins and tenant filters predictable.
create index if not exists idx_fk_audit_log_school_id on public.audit_log (school_id);
create index if not exists idx_fk_audit_log_user_id on public.audit_log (user_id);
create index if not exists idx_fk_course_subjects_school_id on public.course_subjects (school_id);
create index if not exists idx_fk_course_subjects_teacher_id on public.course_subjects (teacher_id);
create index if not exists idx_fk_courses_school_id on public.courses (school_id);
create index if not exists idx_fk_grade_definitions_quarter_id on public.grade_definitions (quarter_id);
create index if not exists idx_fk_grade_definitions_school_id on public.grade_definitions (school_id);
create index if not exists idx_fk_grades_course_subject_id on public.grades (course_subject_id);
create index if not exists idx_fk_grades_quarter_id on public.grades (quarter_id);
create index if not exists idx_fk_impersonation_logs_actor_id on public.impersonation_logs (actor_id);
create index if not exists idx_fk_impersonation_logs_impersonated_user_id on public.impersonation_logs (impersonated_user_id);
create index if not exists idx_fk_impersonation_logs_school_id on public.impersonation_logs (school_id);
create index if not exists idx_fk_payments_recorded_by on public.payments (recorded_by);
create index if not exists idx_fk_payments_school_id on public.payments (school_id);
create index if not exists idx_fk_payments_subscription_id on public.payments (subscription_id);
create index if not exists idx_fk_profiles_school_id on public.profiles (school_id);
create index if not exists idx_fk_project_grades_course_id on public.project_grades (course_id);
create index if not exists idx_fk_project_grades_quarter_id on public.project_grades (quarter_id);
create index if not exists idx_fk_project_settings_quarter_id on public.project_settings (quarter_id);
create index if not exists idx_fk_project_settings_subject_id on public.project_settings (subject_id);
create index if not exists idx_fk_project_subject_grades_quarter_id on public.project_subject_grades (quarter_id);
create index if not exists idx_fk_project_subject_grades_subject_id on public.project_subject_grades (subject_id);
create index if not exists idx_fk_qualitative_grades_quarter_id on public.qualitative_grades (quarter_id);
create index if not exists idx_fk_quarters_school_id on public.quarters (school_id);
create index if not exists idx_fk_role_permissions_permission_id on public.role_permissions (permission_id);
create index if not exists idx_fk_schools_suspended_by on public.schools (suspended_by);
create index if not exists idx_fk_student_alerts_quarter_id on public.student_alerts (quarter_id);
create index if not exists idx_fk_student_alerts_reported_by on public.student_alerts (reported_by);
create index if not exists idx_fk_student_alerts_school_id on public.student_alerts (school_id);
create index if not exists idx_fk_students_created_by on public.students (created_by);
create index if not exists idx_fk_students_school_id on public.students (school_id);
create index if not exists idx_fk_subjects_school_id on public.subjects (school_id);
create index if not exists idx_fk_subscriptions_plan_id on public.subscriptions (plan_id);
create index if not exists idx_fk_supplementary_exams_course_subject_id on public.supplementary_exams (course_subject_id);
create index if not exists idx_fk_tenant_billing_profiles_implementation_fee_payment_id on public.tenant_billing_profiles (implementation_fee_payment_id);
create index if not exists idx_fk_tenant_memberships_school_id on public.tenant_memberships (school_id);
create index if not exists idx_fk_tenant_memberships_tenant_role_id on public.tenant_memberships (tenant_role_id);
create index if not exists idx_fk_tenant_status_logs_actor_id on public.tenant_status_logs (actor_id);
create index if not exists idx_fk_tenant_status_logs_school_id on public.tenant_status_logs (school_id);
create index if not exists idx_fk_user_platform_roles_platform_role_id on public.user_platform_roles (platform_role_id);

-- One permissive SELECT policy per role/action avoids evaluating two policies per row.
drop policy if exists "Platform billing profiles" on public.tenant_billing_profiles;
drop policy if exists "Tenant reads own billing profile" on public.tenant_billing_profiles;

create policy "Billing profiles readable by authorized users"
on public.tenant_billing_profiles for select to authenticated
using (
  public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance'])
  or (school_id = public.get_user_school_id() and public.has_tenant_permission('billing.read'))
);

create policy "Platform inserts billing profiles"
on public.tenant_billing_profiles for insert to authenticated
with check (public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance']));

create policy "Platform updates billing profiles"
on public.tenant_billing_profiles for update to authenticated
using (public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance']))
with check (public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance']));

create policy "Platform deletes billing profiles"
on public.tenant_billing_profiles for delete to authenticated
using (public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance']));

drop policy if exists "Platform admins manage tenant limits" on public.tenant_limits;
drop policy if exists "Tenant members read own limits" on public.tenant_limits;

create policy "Tenant limits readable by authorized users"
on public.tenant_limits for select to authenticated
using (public.is_platform_admin() or school_id = public.get_user_school_id());

create policy "Platform inserts tenant limits"
on public.tenant_limits for insert to authenticated
with check (public.is_platform_admin());

create policy "Platform updates tenant limits"
on public.tenant_limits for update to authenticated
using (public.is_platform_admin())
with check (public.is_platform_admin());

create policy "Platform deletes tenant limits"
on public.tenant_limits for delete to authenticated
using (public.is_platform_admin());

