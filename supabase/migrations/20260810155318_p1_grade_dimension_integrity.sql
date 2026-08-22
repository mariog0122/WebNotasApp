-- Restore and enforce the canonical relationship:
-- grade -> grade_definition -> course_subject + quarter.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

update public.grades g
set course_subject_id = gd.course_subject_id,
    quarter_id = gd.quarter_id,
    updated_at = timezone('utc'::text, now())
from public.grade_definitions gd
where gd.id = g.grade_definition_id
  and (
    g.course_subject_id is distinct from gd.course_subject_id
    or g.quarter_id is distinct from gd.quarter_id
  );

create or replace function private.synchronize_grade_dimensions_from_definition()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_course_subject_id uuid;
  v_quarter_id uuid;
  v_definition_school_id uuid;
  v_definition_course_id uuid;
  v_student_school_id uuid;
  v_student_course_id uuid;
begin
  select gd.course_subject_id, gd.quarter_id, gd.school_id, cs.course_id
  into v_course_subject_id, v_quarter_id, v_definition_school_id, v_definition_course_id
  from public.grade_definitions gd
  join public.course_subjects cs on cs.id = gd.course_subject_id
  where gd.id = new.grade_definition_id;

  if v_course_subject_id is null or v_quarter_id is null then
    raise exception 'GRADE_DEFINITION_NOT_FOUND' using errcode = '23503';
  end if;

  select st.school_id, st.course_id
  into v_student_school_id, v_student_course_id
  from public.students st
  where st.id = new.student_id;

  if v_student_school_id is null then
    raise exception 'GRADE_STUDENT_NOT_FOUND' using errcode = '23503';
  end if;

  if v_student_school_id is distinct from v_definition_school_id
     or v_student_course_id is distinct from v_definition_course_id then
    raise exception 'GRADE_TARGET_TENANT_OR_COURSE_MISMATCH' using errcode = '23514';
  end if;

  new.course_subject_id := v_course_subject_id;
  new.quarter_id := v_quarter_id;
  new.updated_at := timezone('utc'::text, now());
  return new;
end;
$$;

revoke all on function private.synchronize_grade_dimensions_from_definition() from public, anon, authenticated;

drop trigger if exists synchronize_grade_dimensions_from_definition on public.grades;
create trigger synchronize_grade_dimensions_from_definition
before insert or update on public.grades
for each row
execute function private.synchronize_grade_dimensions_from_definition();

alter table public.grades
  alter column student_id set not null,
  alter column grade_definition_id set not null,
  alter column course_subject_id set not null,
  alter column quarter_id set not null;
