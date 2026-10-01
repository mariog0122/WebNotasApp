-- Remove permissive policy bypasses and redundant index copies.

alter table public.courses
alter column school_id set not null;

drop policy if exists courses_select on public.courses;
drop policy if exists courses_insert on public.courses;
drop policy if exists courses_update on public.courses;
drop policy if exists courses_delete on public.courses;
drop policy if exists courses_select_policy on public.courses;
drop policy if exists courses_insert_policy on public.courses;
drop policy if exists courses_update_policy on public.courses;
drop policy if exists courses_delete_policy on public.courses;

create policy courses_select
on public.courses for select to authenticated
using (
  public.is_platform_admin()
  or public.is_active_tenant_member(school_id)
);
create policy courses_insert
on public.courses for insert to authenticated
with check (
  public.is_platform_admin()
  or (
    school_id = public.get_user_school_id()
    and public.has_tenant_permission('settings.manage')
  )
);
create policy courses_update
on public.courses for update to authenticated
using (
  public.is_platform_admin()
  or (
    school_id = public.get_user_school_id()
    and public.has_tenant_permission('settings.manage')
  )
)
with check (
  public.is_platform_admin()
  or (
    school_id = public.get_user_school_id()
    and public.has_tenant_permission('settings.manage')
  )
);
create policy courses_delete
on public.courses for delete to authenticated
using (
  public.is_platform_admin()
  or (
    school_id = public.get_user_school_id()
    and public.has_tenant_permission('settings.manage')
  )
);

drop policy if exists institution_ai_settings_select on public.institution_ai_settings;
drop policy if exists institution_ai_settings_manage on public.institution_ai_settings;
create policy institution_ai_settings_select
on public.institution_ai_settings for select to authenticated
using (
  public.is_platform_admin()
  or school_id = public.get_user_school_id()
);
create policy institution_ai_settings_insert
on public.institution_ai_settings for insert to authenticated
with check (
  public.is_platform_admin()
  or (school_id = public.get_user_school_id() and public.is_admin())
);
create policy institution_ai_settings_update
on public.institution_ai_settings for update to authenticated
using (
  public.is_platform_admin()
  or (school_id = public.get_user_school_id() and public.is_admin())
)
with check (
  public.is_platform_admin()
  or (school_id = public.get_user_school_id() and public.is_admin())
);
create policy institution_ai_settings_delete
on public.institution_ai_settings for delete to authenticated
using (
  public.is_platform_admin()
  or (school_id = public.get_user_school_id() and public.is_admin())
);

drop policy if exists "Superadmins can update schools" on public.schools;
drop policy if exists "Superadmins can delete schools" on public.schools;

drop policy if exists tenant_features_select_policy on public.tenant_features;
drop policy if exists tenant_features_all_policy on public.tenant_features;
create policy tenant_features_select
on public.tenant_features for select to authenticated
using (
  public.is_platform_admin()
  or school_id = public.get_user_school_id()
);
create policy tenant_features_insert
on public.tenant_features for insert to authenticated
with check (public.is_platform_admin());
create policy tenant_features_update
on public.tenant_features for update to authenticated
using (public.is_platform_admin())
with check (public.is_platform_admin());
create policy tenant_features_delete
on public.tenant_features for delete to authenticated
using (public.is_platform_admin());

drop policy if exists "Platform admins manage tenant limits" on public.tenant_limits;
drop policy if exists "Tenant members read own limits" on public.tenant_limits;
create policy tenant_limits_select
on public.tenant_limits for select to authenticated
using (
  public.is_platform_admin()
  or school_id = public.get_user_school_id()
);
create policy tenant_limits_insert
on public.tenant_limits for insert to authenticated
with check (public.is_platform_admin());
create policy tenant_limits_update
on public.tenant_limits for update to authenticated
using (public.is_platform_admin())
with check (public.is_platform_admin());
create policy tenant_limits_delete
on public.tenant_limits for delete to authenticated
using (public.is_platform_admin());

drop index if exists public.idx_courses_school_id;
drop index if exists public.idx_grades_course_subject_id;
drop index if exists public.idx_grades_quarter_id;
drop index if exists public.idx_grades_composite;
drop index if exists public.idx_grades_student_definition;
drop index if exists public.idx_payments_school_id;
