create or replace function public.get_tenant_usage_stats(p_school_id uuid)
returns json language plpgsql security definer
set search_path = pg_catalog, public, auth as $$
declare
  v_users_count integer;
  v_teachers_count integer;
  v_students_count integer;
  v_courses_count integer;
  v_grades_count integer;
begin
  if auth.uid() is null or not public.is_platform_admin() then
    raise exception 'PLATFORM_ADMIN_REQUIRED' using errcode = '42501';
  end if;
  if p_school_id is null or not exists (select 1 from public.schools where id = p_school_id) then
    raise exception 'TENANT_NOT_FOUND' using errcode = 'P0002';
  end if;

  select count(*) into v_users_count from public.profiles where school_id = p_school_id;
  select count(*) into v_teachers_count from public.profiles where school_id = p_school_id and role in ('docente', 'teacher');
  select count(*) into v_students_count from public.students where school_id = p_school_id;
  select count(*) into v_courses_count from public.courses where school_id = p_school_id;
  select count(*) into v_grades_count
  from public.grades
  where student_id in (select id from public.students where school_id = p_school_id);

  return json_build_object(
    'users_count', v_users_count,
    'teachers_count', v_teachers_count,
    'students_count', v_students_count,
    'courses_count', v_courses_count,
    'grades_count', v_grades_count
  );
end;
$$;

revoke all on function public.get_tenant_usage_stats(uuid) from public, anon;
grant execute on function public.get_tenant_usage_stats(uuid) to authenticated, service_role;

-- These three public overloads belong to retired client flows. Current clients
-- use the UUID course-copy RPC and Edge Functions for user management.
revoke all on function public.copy_courses_to_academic_year(uuid, text, text) from public, anon, authenticated;
grant execute on function public.copy_courses_to_academic_year(uuid, text, text) to service_role;

revoke all on function public.invite_teacher_by_email(text) from public, anon, authenticated;
grant execute on function public.invite_teacher_by_email(text) to service_role;

revoke all on function public.is_school_entitled(uuid) from public, anon, authenticated;
grant execute on function public.is_school_entitled(uuid) to service_role;

notify pgrst, 'reload schema';
