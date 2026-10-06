-- Aísla Planificación Curricular IA por la institución seleccionada, falla
-- cerrado cuando la configuración no existe y valida todas las relaciones.

create or replace function public.check_ai_planning_access(p_school_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_caller_id uuid := auth.uid();
  v_feature_enabled boolean;
  v_school_available boolean := false;
  v_ai_settings public.institution_ai_settings%rowtype;
  v_usage_count integer := 0;
  v_teacher_daily_count integer := 0;
  v_sub_status text := 'unavailable';
  v_module_enabled boolean := false;
  v_has_api_key boolean := false;
begin
  if v_caller_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if p_school_id is null
     or not private.has_intelligence_permission(p_school_id, 'grades.read') then
    raise exception 'AI_PLANNING_ACCESS_DENIED' using errcode = '42501';
  end if;

  select coalesce(s.is_active, true)
         and s.status::text in ('active', 'trial', 'past_due', 'grace_period')
    into v_school_available
  from public.schools s
  where s.id = p_school_id;

  select tf.enabled into v_feature_enabled
  from public.tenant_features tf
  where tf.school_id = p_school_id
    and tf.feature_key = 'ai_planning';

  select sub.status::text into v_sub_status
  from public.subscriptions sub
  where sub.school_id = p_school_id
  order by sub.created_at desc
  limit 1;

  select * into v_ai_settings
  from public.institution_ai_settings settings
  where settings.school_id = p_school_id;

  v_has_api_key := coalesce(v_ai_settings.has_api_key, false);
  v_module_enabled := coalesce(v_feature_enabled, false)
    and coalesce(v_school_available, false)
    and coalesce(v_sub_status, 'unavailable') in ('active', 'trial', 'past_due', 'grace_period')
    and coalesce(v_ai_settings.is_active, false)
    and coalesce(v_ai_settings.status, 'unavailable') in ('active', 'demo');

  if v_module_enabled then
    select count(*) into v_usage_count
    from public.ai_usage_ledger ledger
    where ledger.school_id = p_school_id
      and ledger.created_at >= date_trunc('month', now())
      and ledger.status = 'success';

    select count(*) into v_teacher_daily_count
    from public.ai_usage_ledger ledger
    where ledger.school_id = p_school_id
      and ledger.user_id = v_caller_id
      and ledger.created_at >= date_trunc('day', now())
      and ledger.status = 'success';
  end if;

  return jsonb_build_object(
    'school_id', p_school_id,
    'module_enabled', v_module_enabled,
    'subscription_status', coalesce(v_sub_status, 'unavailable'),
    'mode', coalesce(v_ai_settings.mode, 'unavailable'),
    'provider', v_ai_settings.provider,
    'model_id', v_ai_settings.model_id,
    'ai_status', coalesce(v_ai_settings.status, 'unavailable'),
    'has_api_key', v_has_api_key,
    'is_demo', coalesce(v_ai_settings.mode = 'demo', false) or not v_has_api_key,
    'monthly_quota', coalesce(v_ai_settings.monthly_quota_generations, 0),
    'monthly_usage', v_usage_count,
    'teacher_daily_limit', coalesce(v_ai_settings.teacher_daily_limit, 0),
    'teacher_daily_usage', v_teacher_daily_count,
    'is_limit_reached', v_usage_count >= coalesce(v_ai_settings.monthly_quota_generations, 0),
    'is_teacher_limit_reached', v_teacher_daily_count >= coalesce(v_ai_settings.teacher_daily_limit, 0)
  );
end;
$$;

revoke all on function public.check_ai_planning_access(uuid) from public, anon;
grant execute on function public.check_ai_planning_access(uuid) to authenticated;

create or replace function public.can_access_lesson_plan(
  p_school_id uuid,
  p_teacher_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private, auth
as $$
  select private.has_intelligence_permission(p_school_id, 'grades.read')
    and (
      private.has_intelligence_permission(p_school_id, 'settings.manage')
      or p_teacher_id = (select auth.uid())
    );
$$;

revoke all on function public.can_access_lesson_plan(uuid, uuid) from public, anon;
grant execute on function public.can_access_lesson_plan(uuid, uuid) to authenticated;

create or replace function private.validate_lesson_plan_tenant()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_course_year text;
begin
  if new.school_id is null then
    raise exception 'PLANNING_TENANT_REQUIRED' using errcode = '23514';
  end if;
  if new.course_id is not null then
    select c.academic_year into v_course_year
    from public.courses c
    where c.id = new.course_id and c.school_id = new.school_id;
    if v_course_year is null then
      raise exception 'PLANNING_COURSE_TENANT_MISMATCH' using errcode = '23514';
    end if;
    if new.academic_year is distinct from v_course_year then
      raise exception 'PLANNING_ACADEMIC_YEAR_MISMATCH' using errcode = '23514';
    end if;
  end if;
  if new.subject_id is not null and not exists (
    select 1 from public.subjects subject
    where subject.id = new.subject_id and subject.school_id = new.school_id
  ) then
    raise exception 'PLANNING_SUBJECT_TENANT_MISMATCH' using errcode = '23514';
  end if;
  if new.course_id is not null and new.subject_id is not null and not exists (
    select 1 from public.course_subjects cs
    where cs.school_id = new.school_id
      and cs.course_id = new.course_id
      and cs.subject_id = new.subject_id
  ) then
    raise exception 'PLANNING_SUBJECT_COURSE_MISMATCH' using errcode = '23514';
  end if;
  if new.quarter_id is not null and not exists (
    select 1 from public.quarters q
    where q.id = new.quarter_id and q.school_id = new.school_id
  ) then
    raise exception 'PLANNING_QUARTER_TENANT_MISMATCH' using errcode = '23514';
  end if;
  return new;
end;
$$;

create or replace function private.validate_planning_child_tenant()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_plan public.lesson_plans;
begin
  if tg_table_name = 'lesson_plan_resources' then
    select * into v_plan from public.lesson_plans where id = new.lesson_plan_id;
    if v_plan.id is null or v_plan.school_id <> new.school_id
       or v_plan.teacher_id <> new.teacher_id then
      raise exception 'RESOURCE_PLAN_TENANT_MISMATCH' using errcode = '23514';
    end if;
    if exists (
      select 1 from unnest(coalesce(new.target_students, array[]::uuid[])) student_id
      where not exists (
        select 1 from public.students s
        where s.id = student_id and s.school_id = new.school_id
      )
    ) then
      raise exception 'RESOURCE_STUDENT_TENANT_MISMATCH' using errcode = '23514';
    end if;
  elsif tg_table_name = 'student_support_plans' then
    if not exists (
      select 1 from public.students s
      where s.id = new.student_id
        and s.school_id = new.school_id
        and (new.course_id is null or s.course_id = new.course_id)
    ) then
      raise exception 'SUPPORT_STUDENT_TENANT_MISMATCH' using errcode = '23514';
    end if;
    if new.lesson_plan_id is not null then
      select * into v_plan from public.lesson_plans where id = new.lesson_plan_id;
      if v_plan.id is null or v_plan.school_id <> new.school_id
         or (new.course_id is not null and v_plan.course_id is distinct from new.course_id)
         or (new.subject_id is not null and v_plan.subject_id is distinct from new.subject_id) then
        raise exception 'SUPPORT_PLAN_TENANT_MISMATCH' using errcode = '23514';
      end if;
    end if;
    if new.course_id is not null and not exists (
      select 1 from public.courses c
      where c.id = new.course_id and c.school_id = new.school_id
    ) then
      raise exception 'SUPPORT_COURSE_TENANT_MISMATCH' using errcode = '23514';
    end if;
    if new.subject_id is not null and not exists (
      select 1 from public.subjects subject
      where subject.id = new.subject_id and subject.school_id = new.school_id
    ) then
      raise exception 'SUPPORT_SUBJECT_TENANT_MISMATCH' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.validate_lesson_plan_tenant() from public, anon, authenticated;
revoke all on function private.validate_planning_child_tenant() from public, anon, authenticated;

drop trigger if exists validate_lesson_plan_tenant on public.lesson_plans;
create trigger validate_lesson_plan_tenant
before insert or update on public.lesson_plans
for each row execute function private.validate_lesson_plan_tenant();

drop trigger if exists validate_lesson_plan_resource_tenant on public.lesson_plan_resources;
create trigger validate_lesson_plan_resource_tenant
before insert or update on public.lesson_plan_resources
for each row execute function private.validate_planning_child_tenant();

drop trigger if exists validate_student_support_plan_tenant on public.student_support_plans;
create trigger validate_student_support_plan_tenant
before insert or update on public.student_support_plans
for each row execute function private.validate_planning_child_tenant();

drop policy if exists lesson_plans_select on public.lesson_plans;
drop policy if exists lesson_plans_insert on public.lesson_plans;
drop policy if exists lesson_plans_update on public.lesson_plans;
drop policy if exists lesson_plans_delete on public.lesson_plans;

create policy lesson_plans_select on public.lesson_plans
for select to authenticated
using (public.can_access_lesson_plan(school_id, teacher_id));
create policy lesson_plans_insert on public.lesson_plans
for insert to authenticated
with check (
  public.can_access_lesson_plan(school_id, teacher_id)
  and teacher_id = (select auth.uid())
);
create policy lesson_plans_update on public.lesson_plans
for update to authenticated
using (public.can_access_lesson_plan(school_id, teacher_id))
with check (public.can_access_lesson_plan(school_id, teacher_id));
create policy lesson_plans_delete on public.lesson_plans
for delete to authenticated
using (public.can_access_lesson_plan(school_id, teacher_id));

drop policy if exists lesson_plan_versions_select on public.lesson_plan_versions;
drop policy if exists lesson_plan_versions_insert on public.lesson_plan_versions;
create policy lesson_plan_versions_select on public.lesson_plan_versions
for select to authenticated
using (
  exists (
    select 1 from public.lesson_plans plan
    where plan.id = lesson_plan_id
      and public.can_access_lesson_plan(plan.school_id, plan.teacher_id)
  )
);
create policy lesson_plan_versions_insert on public.lesson_plan_versions
for insert to authenticated
with check (
  (created_by is null or created_by = (select auth.uid()))
  and exists (
    select 1 from public.lesson_plans plan
    where plan.id = lesson_plan_id
      and public.can_access_lesson_plan(plan.school_id, plan.teacher_id)
  )
);

drop policy if exists lesson_plan_resources_all on public.lesson_plan_resources;
create policy lesson_plan_resources_all on public.lesson_plan_resources
for all to authenticated
using (public.can_access_lesson_plan(school_id, teacher_id))
with check (public.can_access_lesson_plan(school_id, teacher_id));

drop policy if exists student_support_plans_all on public.student_support_plans;
create policy student_support_plans_all on public.student_support_plans
for all to authenticated
using (public.can_access_lesson_plan(school_id, teacher_id))
with check (public.can_access_lesson_plan(school_id, teacher_id));

drop policy if exists student_support_events_select on public.student_support_events;
drop policy if exists student_support_events_insert on public.student_support_events;
create policy student_support_events_select on public.student_support_events
for select to authenticated
using (
  exists (
    select 1 from public.student_support_plans support
    where support.id = support_plan_id
      and public.can_access_lesson_plan(support.school_id, support.teacher_id)
  )
);
create policy student_support_events_insert on public.student_support_events
for insert to authenticated
with check (
  (created_by is null or created_by = (select auth.uid()))
  and exists (
    select 1 from public.student_support_plans support
    where support.id = support_plan_id
      and public.can_access_lesson_plan(support.school_id, support.teacher_id)
  )
);

drop policy if exists institution_ai_settings_select on public.institution_ai_settings;
create policy institution_ai_settings_select on public.institution_ai_settings
for select to authenticated
using (public.can_access_lesson_plan(school_id, (select auth.uid())));

drop policy if exists ai_usage_ledger_select on public.ai_usage_ledger;
drop policy if exists ai_usage_ledger_insert on public.ai_usage_ledger;
create policy ai_usage_ledger_select on public.ai_usage_ledger
for select to authenticated
using (public.can_access_lesson_plan(school_id, user_id));
create policy ai_usage_ledger_insert on public.ai_usage_ledger
for insert to authenticated
with check (
  public.can_access_lesson_plan(school_id, user_id)
  and user_id = (select auth.uid())
);
