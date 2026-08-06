-- ====================================================================
-- MIGRATION: 02_rls_security_update.sql
-- PURPOSE: Fix overly permissive RLS policies for WebNotas.
-- Restricts structural tables to 'admin' role only for write operations.
-- Restricts grade tables to 'admin' role OR the assigned 'teacher_id'.
-- ====================================================================

-- Helper function to check if the current user is an admin
create or replace function public.is_admin()
returns boolean as $$
begin
  return exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
end;
$$ language plpgsql security definer;

-- ====================================================================
-- 1. STRUCTURAL TABLES: Admin Only for INSERT, UPDATE, DELETE
-- ====================================================================

-- COURSES
drop policy if exists "Enable insert for authenticated users only" on public.courses;
drop policy if exists "Enable update for authenticated users only" on public.courses;
drop policy if exists "Enable delete for authenticated users only" on public.courses;
drop policy if exists "Admins only write" on public.courses;
create policy "Admins only write" on public.courses for all using (public.is_admin());

-- SUBJECTS
drop policy if exists "Enable write for authenticated users" on public.subjects;
drop policy if exists "Admins only write" on public.subjects;
create policy "Admins only write" on public.subjects for all using (public.is_admin());

-- QUARTERS
drop policy if exists "Enable write for authenticated users" on public.quarters;
drop policy if exists "Admins only write" on public.quarters;
create policy "Admins only write" on public.quarters for all using (public.is_admin());

-- STUDENTS
drop policy if exists "Enable write for authenticated users" on public.students;
drop policy if exists "Admins only write" on public.students;
create policy "Admins only write" on public.students for all using (public.is_admin());

-- COURSE_SUBJECTS
drop policy if exists "Enable write for authenticated users" on public.course_subjects;
drop policy if exists "Admins only write" on public.course_subjects;
create policy "Admins only write" on public.course_subjects for all using (public.is_admin());

-- SYSTEM_CONFIG
drop policy if exists "Enable write for authenticated users" on public.system_config;
drop policy if exists "Admins only write" on public.system_config;
create policy "Admins only write" on public.system_config for all using (public.is_admin());

-- GRADE_DEFINITIONS
drop policy if exists "Enable write for authenticated users" on public.grade_definitions;
drop policy if exists "Admins only write" on public.grade_definitions;
create policy "Admins only write" on public.grade_definitions for all using (public.is_admin());


-- ====================================================================
-- 2. GRADE TABLES: Admin OR Assigned Teacher for INSERT, UPDATE, DELETE
-- ====================================================================

-- GRADES
drop policy if exists "Enable write for authenticated users" on public.grades;
drop policy if exists "Admin or Assigned Teacher write" on public.grades;
create policy "Admin or Assigned Teacher write" on public.grades for all using (
  public.is_admin() or exists (
    select 1 from public.course_subjects cs
    where cs.id = course_subject_id
    and cs.teacher_id = auth.uid()
  )
);

-- QUALITATIVE GRADES
drop policy if exists "Enable write for authenticated users" on public.qualitative_grades;
drop policy if exists "Admin or Assigned Teacher write" on public.qualitative_grades;
create policy "Admin or Assigned Teacher write" on public.qualitative_grades for all using (
  public.is_admin() or exists (
    select 1 from public.course_subjects cs
    where cs.id = course_subject_id
    and cs.teacher_id = auth.uid()
  )
);

-- SUPPLEMENTARY EXAMS
drop policy if exists "Enable write for authenticated users" on public.supplementary_exams;
drop policy if exists "Admin or Assigned Teacher write" on public.supplementary_exams;
create policy "Admin or Assigned Teacher write" on public.supplementary_exams for all using (
  public.is_admin() or exists (
    select 1 from public.course_subjects cs
    where cs.id = course_subject_id
    and cs.teacher_id = auth.uid()
  )
);

-- ====================================================================
-- 3. PROJECT TABLES: Admin OR Assigned Teacher (by course/subject match)
-- ====================================================================

-- PROJECT SETTINGS
drop policy if exists "Enable write for authenticated users" on public.project_settings;
drop policy if exists "Admin or Assigned Teacher write" on public.project_settings;
create policy "Admin or Assigned Teacher write" on public.project_settings for all using (
  public.is_admin() or exists (
    select 1 from public.course_subjects cs
    where cs.course_id = project_settings.course_id
    and cs.subject_id = project_settings.subject_id
    and cs.teacher_id = auth.uid()
  )
);

-- PROJECT SUBJECT GRADES
drop policy if exists "Enable write for authenticated users" on public.project_subject_grades;
drop policy if exists "Admin or Assigned Teacher write" on public.project_subject_grades;
create policy "Admin or Assigned Teacher write" on public.project_subject_grades for all using (
  public.is_admin() or exists (
    select 1 from public.course_subjects cs
    where cs.course_id = project_subject_grades.course_id
    and cs.subject_id = project_subject_grades.subject_id
    and cs.teacher_id = auth.uid()
  )
);

-- PROJECT GRADES (Summary Table)
drop policy if exists "Enable write for authenticated users" on public.project_grades;
drop policy if exists "Admin or Assigned Teacher write" on public.project_grades;
create policy "Admin or Assigned Teacher write" on public.project_grades for all using (
  public.is_admin() or exists (
    select 1 from public.course_subjects cs
    where cs.course_id = project_grades.course_id
    and cs.teacher_id = auth.uid()
  )
);
