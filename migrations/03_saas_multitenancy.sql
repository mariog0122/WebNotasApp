-- ====================================================================
-- MIGRATION: 03_saas_multitenancy.sql
-- PURPOSE: Transform the database to a Multi-Tenant SaaS architecture.
-- Adds 'schools' table, injects 'school_id' across the schema, 
-- migrates existing data to a default school, automates school_id assignment,
-- and enforces Row Level Security (RLS) isolation.
-- ====================================================================

-- 1. CREATE SCHOOLS TABLE
create table if not exists public.schools (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  is_active boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Insert a default school for existing data
do $$
declare
  default_school_id uuid;
begin
  if not exists (select 1 from public.schools where name = 'Colegio Base (Migrado)') then
    insert into public.schools (name) values ('Colegio Base (Migrado)') returning id into default_school_id;
  end if;
end
$$;

-- 2. ADD SCHOOL_ID TO TABLES
alter table public.profiles add column if not exists school_id uuid references public.schools(id) on delete cascade;
alter table public.courses add column if not exists school_id uuid references public.schools(id) on delete cascade;
alter table public.quarters add column if not exists school_id uuid references public.schools(id) on delete cascade;
alter table public.subjects add column if not exists school_id uuid references public.schools(id) on delete cascade;
alter table public.students add column if not exists school_id uuid references public.schools(id) on delete cascade;
alter table public.system_config add column if not exists school_id uuid references public.schools(id) on delete cascade;
alter table public.grade_definitions add column if not exists school_id uuid references public.schools(id) on delete cascade;
alter table public.course_subjects add column if not exists school_id uuid references public.schools(id) on delete cascade;
alter table public.student_alerts add column if not exists school_id uuid references public.schools(id) on delete cascade;

-- 3. MIGRATE EXISTING DATA TO THE DEFAULT SCHOOL
do $$
declare
  default_school_id uuid;
begin
  select id into default_school_id from public.schools limit 1;
  
  update public.profiles set school_id = default_school_id where school_id is null;
  update public.courses set school_id = default_school_id where school_id is null;
  update public.quarters set school_id = default_school_id where school_id is null;
  update public.subjects set school_id = default_school_id where school_id is null;
  update public.students set school_id = default_school_id where school_id is null;
  update public.system_config set school_id = default_school_id where school_id is null;
  update public.grade_definitions set school_id = default_school_id where school_id is null;
  update public.course_subjects set school_id = default_school_id where school_id is null;
  update public.student_alerts set school_id = default_school_id where school_id is null;
end
$$;

-- Make school_id NOT NULL for future structural integrity (optional, but recommended for SaaS)
-- We won't strictly enforce it as NOT NULL in SQL yet, to avoid breaking legacy queries immediately, 
-- but we will enforce it via Triggers and RLS.

-- 4. AUTOMATIC SCHOOL ASSIGNMENT TRIGGERS
create or replace function public.set_school_id_from_auth()
returns trigger as $$
declare
  user_school_id uuid;
begin
  select school_id into user_school_id from public.profiles where id = auth.uid();
  if user_school_id is not null then
    NEW.school_id = user_school_id;
  end if;
  return NEW;
end;
$$ language plpgsql security definer;

-- Apply triggers
drop trigger if exists set_courses_school_id on public.courses;
create trigger set_courses_school_id before insert on public.courses for each row execute function public.set_school_id_from_auth();

drop trigger if exists set_quarters_school_id on public.quarters;
create trigger set_quarters_school_id before insert on public.quarters for each row execute function public.set_school_id_from_auth();

drop trigger if exists set_subjects_school_id on public.subjects;
create trigger set_subjects_school_id before insert on public.subjects for each row execute function public.set_school_id_from_auth();

drop trigger if exists set_students_school_id on public.students;
create trigger set_students_school_id before insert on public.students for each row execute function public.set_school_id_from_auth();

drop trigger if exists set_sysconfig_school_id on public.system_config;
create trigger set_sysconfig_school_id before insert on public.system_config for each row execute function public.set_school_id_from_auth();

drop trigger if exists set_grade_defs_school_id on public.grade_definitions;
create trigger set_grade_defs_school_id before insert on public.grade_definitions for each row execute function public.set_school_id_from_auth();

drop trigger if exists set_course_subjects_school_id on public.course_subjects;
create trigger set_course_subjects_school_id before insert on public.course_subjects for each row execute function public.set_school_id_from_auth();

drop trigger if exists set_student_alerts_school_id on public.student_alerts;
create trigger set_student_alerts_school_id before insert on public.student_alerts for each row execute function public.set_school_id_from_auth();

-- 5. RLS ISOLATION FOR MULTI-TENANCY (READ OPERATIONS)

-- Helper function for quickly getting the user's school
create or replace function public.get_user_school_id()
returns uuid as $$
  select school_id from public.profiles where id = auth.uid();
$$ language sql stable security definer;

-- Apply Select Isolation Policies
alter table public.schools enable row level security;
drop policy if exists "Enable read access for all users" on public.schools;
create policy "Isolate reads by school" on public.schools for select using (id = public.get_user_school_id());

-- For profiles, users can only see profiles from their own school
drop policy if exists "Public profiles are viewable by everyone." on public.profiles;
create policy "Public profiles are viewable by everyone." on public.profiles for select using (school_id = public.get_user_school_id());

-- For all structural tables
drop policy if exists "Enable read access for all users" on public.courses;
create policy "Isolate reads by school" on public.courses for select using (school_id = public.get_user_school_id());

drop policy if exists "Enable read access for all users" on public.quarters;
create policy "Isolate reads by school" on public.quarters for select using (school_id = public.get_user_school_id());

drop policy if exists "Enable read access for all users" on public.subjects;
create policy "Isolate reads by school" on public.subjects for select using (school_id = public.get_user_school_id());

drop policy if exists "Enable read access for all users" on public.students;
create policy "Isolate reads by school" on public.students for select using (school_id = public.get_user_school_id());

drop policy if exists "Enable read access for all users" on public.system_config;
create policy "Isolate reads by school" on public.system_config for select using (school_id = public.get_user_school_id());

drop policy if exists "Enable read access for all users" on public.grade_definitions;
create policy "Isolate reads by school" on public.grade_definitions for select using (school_id = public.get_user_school_id());

drop policy if exists "Enable read access for all users" on public.course_subjects;
create policy "Isolate reads by school" on public.course_subjects for select using (school_id = public.get_user_school_id());

drop policy if exists "Enable read access for all users" on public.student_alerts;
create policy "Isolate reads by school" on public.student_alerts for select using (school_id = public.get_user_school_id());

-- For transaction tables (Grades) without direct school_id, isolate via student relation
drop policy if exists "Enable read access for all users" on public.grades;
create policy "Isolate reads by school via student" on public.grades for select using (
  exists (select 1 from public.students where id = grades.student_id and school_id = public.get_user_school_id())
);

drop policy if exists "Enable read access for all users" on public.qualitative_grades;
create policy "Isolate reads by school via student" on public.qualitative_grades for select using (
  exists (select 1 from public.students where id = qualitative_grades.student_id and school_id = public.get_user_school_id())
);

drop policy if exists "Enable read access for all users" on public.supplementary_exams;
create policy "Isolate reads by school via student" on public.supplementary_exams for select using (
  exists (select 1 from public.students where id = supplementary_exams.student_id and school_id = public.get_user_school_id())
);
