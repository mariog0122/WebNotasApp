-- SAFE SYNC: Adds missing tables/columns/policies without deleting data.
-- Run in Supabase SQL Editor as a single script.

-- Extensions
create extension if not exists "uuid-ossp";
create extension if not exists pg_trgm;

-- PROFILES
create table if not exists public.profiles (
  id uuid references auth.users not null primary key,
  email text,
  role text check (role in ('admin', 'teacher')) default 'teacher',
  full_name text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.profiles enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='Enable read access for all users') then
    create policy "Enable read access for all users" on public.profiles for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='Enable insert for own profile') then
    create policy "Enable insert for own profile" on public.profiles for insert with check (auth.uid() = id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='Enable update for own profile') then
    create policy "Enable update for own profile" on public.profiles for update using (auth.uid() = id);
  end if;
end $$;

-- COURSES
create table if not exists public.courses (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  academic_year text not null,
  level text,
  track text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.courses add column if not exists level text;
alter table public.courses add column if not exists track text;
alter table public.courses enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='courses' and policyname='Enable read access for all users') then
    create policy "Enable read access for all users" on public.courses for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='courses' and policyname='Enable write for authenticated users') then
    create policy "Enable write for authenticated users" on public.courses for all using (auth.role() = 'authenticated');
  end if;
end $$;

-- SUBJECTS
create table if not exists public.subjects (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.subjects enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='subjects' and policyname='Enable read access for all users') then
    create policy "Enable read access for all users" on public.subjects for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='subjects' and policyname='Enable write for authenticated users') then
    create policy "Enable write for authenticated users" on public.subjects for all using (auth.role() = 'authenticated');
  end if;
end $$;

-- QUARTERS
create table if not exists public.quarters (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  is_active boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.quarters enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='quarters' and policyname='Enable read access for all users') then
    create policy "Enable read access for all users" on public.quarters for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='quarters' and policyname='Enable write for authenticated users') then
    create policy "Enable write for authenticated users" on public.quarters for all using (auth.role() = 'authenticated');
  end if;
end $$;

-- STUDENTS
create table if not exists public.students (
  id uuid default uuid_generate_v4() primary key,
  full_name text not null,
  course_id uuid references public.courses(id) on delete set null,
  student_cedula text,
  student_birthdate date,
  student_phone text,
  student_address text,
  representative_name text,
  representative_cedula text,
  representative_phone text,
  representative_alt_phone text,
  student_photo_url text,
  representative_photo_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.students
  add column if not exists student_cedula text,
  add column if not exists student_birthdate date,
  add column if not exists student_phone text,
  add column if not exists student_address text,
  add column if not exists representative_name text,
  add column if not exists representative_cedula text,
  add column if not exists representative_phone text,
  add column if not exists representative_alt_phone text,
  add column if not exists student_photo_url text,
  add column if not exists representative_photo_url text;
alter table public.students enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='students' and policyname='Enable read access for all users') then
    create policy "Enable read access for all users" on public.students for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='students' and policyname='Enable write for authenticated users') then
    create policy "Enable write for authenticated users" on public.students for all using (auth.role() = 'authenticated');
  end if;
end $$;

-- COURSE_SUBJECTS
create table if not exists public.course_subjects (
  id uuid default uuid_generate_v4() primary key,
  course_id uuid references public.courses(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete cascade,
  teacher_id uuid references public.profiles(id) on delete set null,
  unique(course_id, subject_id)
);
alter table public.course_subjects enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='course_subjects' and policyname='Enable read access for all users') then
    create policy "Enable read access for all users" on public.course_subjects for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='course_subjects' and policyname='Enable write for authenticated users') then
    create policy "Enable write for authenticated users" on public.course_subjects for all using (auth.role() = 'authenticated');
  end if;
end $$;

-- GRADE DEFINITIONS (advanced grading)
create table if not exists public.grade_definitions (
  id uuid default uuid_generate_v4() primary key,
  course_subject_id uuid references public.course_subjects(id) on delete cascade,
  quarter_id uuid references public.quarters(id) on delete cascade,
  name text not null,
  category text not null,
  weight decimal(5,2) default 1.0,
  sort_order int not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.grade_definitions enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='grade_definitions' and policyname='Enable read access for all users') then
    create policy "Enable read access for all users" on public.grade_definitions for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='grade_definitions' and policyname='Enable write for authenticated users') then
    create policy "Enable write for authenticated users" on public.grade_definitions for all using (auth.role() = 'authenticated');
  end if;
end $$;

-- GRADES
create table if not exists public.grades (
  id uuid default uuid_generate_v4() primary key,
  student_id uuid references public.students(id) on delete cascade,
  course_subject_id uuid references public.course_subjects(id) on delete cascade,
  quarter_id uuid references public.quarters(id) on delete cascade,
  score decimal(5,2),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(student_id, course_subject_id, quarter_id)
);
alter table public.grades
  add column if not exists grade_definition_id uuid references public.grade_definitions(id) on delete cascade;

-- Ensure unique constraint for app upserts
do $$
begin
  if exists (select 1 from pg_constraint where conname = 'grades_student_id_course_subject_id_quarter_id_key') then
    alter table public.grades drop constraint grades_student_id_course_subject_id_quarter_id_key;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'grades_student_id_definition_key') then
    alter table public.grades add constraint grades_student_id_definition_key unique (student_id, grade_definition_id);
  end if;
end $$;

alter table public.grades enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='grades' and policyname='Enable read access for all users') then
    create policy "Enable read access for all users" on public.grades for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='grades' and policyname='Enable write for authenticated users') then
    create policy "Enable write for authenticated users" on public.grades for all using (auth.role() = 'authenticated');
  end if;
end $$;

-- QUALITATIVE GRADES
create table if not exists public.qualitative_grades (
  id uuid default uuid_generate_v4() primary key,
  student_id uuid references public.students(id) on delete cascade,
  course_subject_id uuid references public.course_subjects(id) on delete cascade,
  quarter_id uuid references public.quarters(id) on delete cascade,
  score_text text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(student_id, course_subject_id, quarter_id)
);
alter table public.qualitative_grades enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='qualitative_grades' and policyname='Enable read access for all users') then
    create policy "Enable read access for all users" on public.qualitative_grades for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='qualitative_grades' and policyname='Enable write for authenticated users') then
    create policy "Enable write for authenticated users" on public.qualitative_grades for all using (auth.role() = 'authenticated');
  end if;
end $$;

-- SUPPLEMENTARY EXAMS
create table if not exists public.supplementary_exams (
  id uuid default uuid_generate_v4() primary key,
  student_id uuid references public.students(id) on delete cascade,
  course_subject_id uuid references public.course_subjects(id) on delete cascade,
  score decimal(5,2),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(student_id, course_subject_id)
);
alter table public.supplementary_exams enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='supplementary_exams' and policyname='Enable read access for all users') then
    create policy "Enable read access for all users" on public.supplementary_exams for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='supplementary_exams' and policyname='Enable write for authenticated users') then
    create policy "Enable write for authenticated users" on public.supplementary_exams for all using (auth.role() = 'authenticated');
  end if;
end $$;

-- PROJECT GLOBAL MODULE
create table if not exists public.project_settings (
  id uuid default uuid_generate_v4() primary key,
  course_id uuid references public.courses(id) on delete cascade,
  quarter_id uuid references public.quarters(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete cascade,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (course_id, quarter_id, subject_id)
);
create table if not exists public.project_subject_grades (
  id uuid default uuid_generate_v4() primary key,
  student_id uuid references public.students(id) on delete cascade,
  course_id uuid references public.courses(id) on delete cascade,
  quarter_id uuid references public.quarters(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete cascade,
  score decimal(5,2),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (student_id, course_id, quarter_id, subject_id)
);
alter table public.project_settings enable row level security;
alter table public.project_subject_grades enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='project_settings' and policyname='Enable read access for all users') then
    create policy "Enable read access for all users" on public.project_settings for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='project_settings' and policyname='Enable write for authenticated users') then
    create policy "Enable write for authenticated users" on public.project_settings for all using (auth.role() = 'authenticated');
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='project_subject_grades' and policyname='Enable read access for all users') then
    create policy "Enable read access for all users" on public.project_subject_grades for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='project_subject_grades' and policyname='Enable write for authenticated users') then
    create policy "Enable write for authenticated users" on public.project_subject_grades for all using (auth.role() = 'authenticated');
  end if;
end $$;

-- SYSTEM CONFIG
create table if not exists public.system_config (
  key text primary key,
  value text not null,
  description text
);
alter table public.system_config enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='system_config' and policyname='Enable read access for all users') then
    create policy "Enable read access for all users" on public.system_config for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='system_config' and policyname='Enable write for authenticated users') then
    create policy "Enable write for authenticated users" on public.system_config for all using (auth.role() = 'authenticated');
  end if;
end $$;

insert into public.system_config (key, value, description)
values
('academic_periods', 'TRIMESTRE', 'Academic period structure: TRIMESTRE or QUIMESTRE'),
('regimen', 'SIERRA_AMAZONIA', 'Regimen: SIERRA_AMAZONIA or COSTA_GALAPAGOS')
on conflict (key) do nothing;

-- STORAGE BUCKETS (may require service role; in SQL Editor it usually works)
insert into storage.buckets (id, name, public)
values
('student-photos', 'student-photos', true),
('institution-assets', 'institution-assets', true)
on conflict (id) do nothing;

-- STORAGE POLICIES
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='Public read student photos') then
    create policy "Public read student photos"
      on storage.objects for select
      using (bucket_id = 'student-photos');
  end if;
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='Auth write student photos') then
    create policy "Auth write student photos"
      on storage.objects for insert
      with check (bucket_id = 'student-photos' and auth.role() = 'authenticated');
  end if;
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='Auth update student photos') then
    create policy "Auth update student photos"
      on storage.objects for update
      using (bucket_id = 'student-photos' and auth.role() = 'authenticated')
      with check (bucket_id = 'student-photos' and auth.role() = 'authenticated');
  end if;

  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='Public read institution assets') then
    create policy "Public read institution assets"
      on storage.objects for select
      using (bucket_id = 'institution-assets');
  end if;
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='Auth write institution assets') then
    create policy "Auth write institution assets"
      on storage.objects for insert
      with check (bucket_id = 'institution-assets' and auth.role() = 'authenticated');
  end if;
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='Auth update institution assets') then
    create policy "Auth update institution assets"
      on storage.objects for update
      using (bucket_id = 'institution-assets' and auth.role() = 'authenticated')
      with check (bucket_id = 'institution-assets' and auth.role() = 'authenticated');
  end if;
end $$;

-- PERFORMANCE INDEXES (safe)
create index if not exists students_cedula_idx on public.students (student_cedula);
create index if not exists students_full_name_trgm_idx on public.students using gin (full_name gin_trgm_ops);
create index if not exists students_course_id_idx on public.students (course_id);
create index if not exists grades_definition_id_idx on public.grades (grade_definition_id);
create index if not exists grades_student_id_idx on public.grades (student_id);
create index if not exists project_subject_grades_student_idx on public.project_subject_grades (student_id);
create index if not exists project_subject_grades_course_quarter_idx on public.project_subject_grades (course_id, quarter_id);
create index if not exists qualitative_grades_course_quarter_idx on public.qualitative_grades (course_subject_id, quarter_id);
