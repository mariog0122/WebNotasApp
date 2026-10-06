-- Use one tenant-safe implementation for both course-copy RPC overloads.

create or replace function public.copy_courses_to_academic_year(
  source_year_id uuid,
  target_year_id uuid,
  include_subjects boolean default true
)
returns table(new_course_id uuid, original_course_id uuid, course_name text)
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  source_year public.academic_years;
  target_year public.academic_years;
  source_course record;
  created_course_id uuid;
  existing_course_id uuid;
  actor_school_id uuid := public.get_user_school_id();
  actor_is_platform_admin boolean := public.is_platform_admin();
begin
  if auth.uid() is null then
    raise exception 'COURSE_COPY_AUTH_REQUIRED' using errcode = '42501';
  end if;

  select * into source_year
  from public.academic_years
  where id = source_year_id;

  select * into target_year
  from public.academic_years
  where id = target_year_id;

  if source_year.id is null or target_year.id is null then
    raise exception 'ACADEMIC_YEAR_NOT_FOUND' using errcode = 'P0002';
  end if;

  if source_year.id = target_year.id then
    raise exception 'COURSE_COPY_SAME_YEAR' using errcode = '22023';
  end if;

  if source_year.school_id <> target_year.school_id then
    raise exception 'COURSE_COPY_CROSS_TENANT_FORBIDDEN' using errcode = '42501';
  end if;

  if not actor_is_platform_admin and (
    actor_school_id is distinct from source_year.school_id
    or not public.has_tenant_permission('settings.manage')
  ) then
    raise exception 'COURSE_COPY_FORBIDDEN' using errcode = '42501';
  end if;

  for source_course in
    select c.*
    from public.courses c
    where c.school_id = source_year.school_id
      and c.academic_year = source_year.name
    order by c.created_at, c.id
  loop
    select c.id into existing_course_id
    from public.courses c
    where c.school_id = target_year.school_id
      and c.academic_year = target_year.name
      and lower(trim(c.name)) = lower(trim(source_course.name))
    limit 1;

    if existing_course_id is null then
      insert into public.courses (
        name,
        academic_year,
        level,
        track,
        school_id,
        tutor_name
      ) values (
        trim(source_course.name),
        target_year.name,
        source_course.level,
        source_course.track,
        target_year.school_id,
        source_course.tutor_name
      )
      returning id into created_course_id;
    else
      created_course_id := existing_course_id;
    end if;

    if include_subjects and created_course_id is not null then
      insert into public.course_subjects (
        course_id,
        subject_id,
        teacher_id,
        school_id
      )
      select
        created_course_id,
        cs.subject_id,
        null,
        target_year.school_id
      from public.course_subjects cs
      where cs.course_id = source_course.id
        and cs.school_id = source_year.school_id
      on conflict (course_id, subject_id) do nothing;
    end if;

    new_course_id := created_course_id;
    original_course_id := source_course.id;
    course_name := source_course.name;
    return next;
  end loop;
end;
$$;

create or replace function public.copy_courses_to_academic_year(
  p_school_id uuid,
  p_source_academic_year text,
  p_target_academic_year text
)
returns json
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_source_year_id uuid;
  v_target_year_id uuid;
  v_source_count integer;
  v_existing_count integer;
begin
  if auth.uid() is null then
    raise exception 'COURSE_COPY_AUTH_REQUIRED' using errcode = '42501';
  end if;

  select id into v_source_year_id
  from public.academic_years
  where school_id = p_school_id
    and name = trim(p_source_academic_year);

  select id into v_target_year_id
  from public.academic_years
  where school_id = p_school_id
    and name = trim(p_target_academic_year);

  if v_source_year_id is null or v_target_year_id is null then
    raise exception 'ACADEMIC_YEAR_NOT_FOUND' using errcode = 'P0002';
  end if;

  select count(*) into v_source_count
  from public.courses c
  where c.school_id = p_school_id
    and c.academic_year = trim(p_source_academic_year);

  select count(*) into v_existing_count
  from public.courses source_course
  where source_course.school_id = p_school_id
    and source_course.academic_year = trim(p_source_academic_year)
    and exists (
      select 1
      from public.courses target_course
      where target_course.school_id = p_school_id
        and target_course.academic_year = trim(p_target_academic_year)
        and lower(trim(target_course.name)) = lower(trim(source_course.name))
    );

  perform public.copy_courses_to_academic_year(
    v_source_year_id,
    v_target_year_id,
    true
  );

  return json_build_object(
    'success', true,
    'inserted', greatest(v_source_count - v_existing_count, 0),
    'skipped', v_existing_count,
    'message', format(
      'Se copiaron %s cursos (%s omitidos por ya existir).',
      greatest(v_source_count - v_existing_count, 0),
      v_existing_count
    )
  );
end;
$$;

revoke all on function public.copy_courses_to_academic_year(uuid, uuid, boolean)
from public, anon;
revoke all on function public.copy_courses_to_academic_year(uuid, text, text)
from public, anon;
grant execute on function public.copy_courses_to_academic_year(uuid, uuid, boolean)
to authenticated, service_role;
grant execute on function public.copy_courses_to_academic_year(uuid, text, text)
to authenticated, service_role;
