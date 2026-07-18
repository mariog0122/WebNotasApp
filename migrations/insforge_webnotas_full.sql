/* Enable UUID extensions */
create extension if not exists "uuid-ossp";

/* USERS (Extends Supabase Auth) */
create table if not exists public.profiles (
  id uuid references auth.users not null primary key,
  email text,
  role text check (role in ('admin', 'teacher')) default 'teacher',
  full_name text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

/* RLS Policies */
alter table public.profiles enable row level security;

drop policy if exists "Public profiles are viewable by everyone." on public.profiles;
create policy "Public profiles are viewable by everyone."
  on public.profiles for select
  using ( true );

drop policy if exists "Users can insert their own profile." on public.profiles;
create policy "Users can insert their own profile."
  on public.profiles for insert
  with check ( auth.uid() = id );

drop policy if exists "Users can update own profile." on public.profiles;
create policy "Users can update own profile."
  on public.profiles for update
  using ( auth.uid() = id );

/* COURSES */
create table if not exists public.courses (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  academic_year text not null,
  level text,
  track text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

/* Course extensions (safe for existing DBs) */
alter table public.courses add column if not exists level text;
alter table public.courses add column if not exists track text;

/* SUBJECTS */
create table if not exists public.subjects (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

/* QUARTERS */
create table if not exists public.quarters (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  is_active boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

/* STUDENTS */
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

/* Student Profile Extensions (safe for existing DBs) */
alter table public.students add column if not exists student_cedula text;
alter table public.students add column if not exists student_birthdate date;
alter table public.students add column if not exists student_phone text;
alter table public.students add column if not exists student_address text;
alter table public.students add column if not exists representative_name text;
alter table public.students add column if not exists representative_cedula text;
alter table public.students add column if not exists representative_phone text;
alter table public.students add column if not exists representative_alt_phone text;
alter table public.students add column if not exists student_photo_url text;
alter table public.students add column if not exists representative_photo_url text;

/* COURSE_SUBJECTS */
create table if not exists public.course_subjects (
  id uuid default uuid_generate_v4() primary key,
  course_id uuid references public.courses(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete cascade,
  teacher_id uuid references public.profiles(id) on delete set null,
  unique(course_id, subject_id)
);

/* GRADES */
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

/* SYSTEM CONFIG */
create table if not exists public.system_config (
  key text primary key,
  value text not null,
  description text
);

/* SUPPLEMENTARY EXAMS (SUPLETORIO) */
create table if not exists public.supplementary_exams (
  id uuid default uuid_generate_v4() primary key,
  student_id uuid references public.students(id) on delete cascade,
  course_subject_id uuid references public.course_subjects(id) on delete cascade,
  score decimal(5,2),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(student_id, course_subject_id)
);

/* QUALITATIVE GRADES (Inicial/Preparatoria/Elemental) */
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

alter table public.supplementary_exams enable row level security;
drop policy if exists "Enable read access for all users" on public.supplementary_exams;
create policy "Enable read access for all users" on public.supplementary_exams for select using (true);
drop policy if exists "Enable write for authenticated users" on public.supplementary_exams;
create policy "Enable write for authenticated users" on public.supplementary_exams for all using (auth.role() = 'authenticated');

alter table public.qualitative_grades enable row level security;
drop policy if exists "Enable read access for all users" on public.qualitative_grades;
create policy "Enable read access for all users" on public.qualitative_grades for select using (true);
drop policy if exists "Enable write for authenticated users" on public.qualitative_grades;
create policy "Enable write for authenticated users" on public.qualitative_grades for all using (auth.role() = 'authenticated');

/* Initial Data */
insert into public.system_config (key, value, description)
values
('quarter_average_formula', 'AVERAGE', 'Standard arithmetic mean of all subject grades in a quarter'),
('final_average_formula', 'WEIGHTED', 'Weighted average of quarters'),
('academic_periods', 'TRIMESTRE', 'Academic period structure: TRIMESTRE or QUIMESTRE'),
('regimen', 'SIERRA_AMAZONIA', 'Regimen: SIERRA_AMAZONIA or COSTA_GALAPAGOS')
on conflict (key) do nothing;

/* RLS POLICIES FOR ALL TABLES */

/* Courses */
alter table public.courses enable row level security;
drop policy if exists "Enable read access for all users" on public.courses;
create policy "Enable read access for all users" on public.courses for select using (true);
drop policy if exists "Enable insert for authenticated users only" on public.courses;
create policy "Enable insert for authenticated users only" on public.courses for insert with check (auth.role() = 'authenticated');
drop policy if exists "Enable update for authenticated users only" on public.courses;
create policy "Enable update for authenticated users only" on public.courses for update using (auth.role() = 'authenticated');
drop policy if exists "Enable delete for authenticated users only" on public.courses;
create policy "Enable delete for authenticated users only" on public.courses for delete using (auth.role() = 'authenticated');

/* Subjects */
alter table public.subjects enable row level security;
drop policy if exists "Enable read access for all users" on public.subjects;
create policy "Enable read access for all users" on public.subjects for select using (true);
drop policy if exists "Enable write for authenticated users" on public.subjects;
create policy "Enable write for authenticated users" on public.subjects for all using (auth.role() = 'authenticated');

/* Quarters */
alter table public.quarters enable row level security;
drop policy if exists "Enable read access for all users" on public.quarters;
create policy "Enable read access for all users" on public.quarters for select using (true);
drop policy if exists "Enable write for authenticated users" on public.quarters;
create policy "Enable write for authenticated users" on public.quarters for all using (auth.role() = 'authenticated');

/* Students */
alter table public.students enable row level security;
drop policy if exists "Enable read access for all users" on public.students;
create policy "Enable read access for all users" on public.students for select using (true);
drop policy if exists "Enable write for authenticated users" on public.students;
create policy "Enable write for authenticated users" on public.students for all using (auth.role() = 'authenticated');

/* Course Subjects */
alter table public.course_subjects enable row level security;
drop policy if exists "Enable read access for all users" on public.course_subjects;
create policy "Enable read access for all users" on public.course_subjects for select using (true);
drop policy if exists "Enable write for authenticated users" on public.course_subjects;
create policy "Enable write for authenticated users" on public.course_subjects for all using (auth.role() = 'authenticated');

/* Grades */
alter table public.grades enable row level security;
drop policy if exists "Enable read access for all users" on public.grades;
create policy "Enable read access for all users" on public.grades for select using (true);
drop policy if exists "Enable write for authenticated users" on public.grades;
create policy "Enable write for authenticated users" on public.grades for all using (auth.role() = 'authenticated');

/* System Config */
alter table public.system_config enable row level security;
drop policy if exists "Enable read access for all users" on public.system_config;
create policy "Enable read access for all users" on public.system_config for select using (true);
drop policy if exists "Enable write for authenticated users" on public.system_config;
create policy "Enable write for authenticated users" on public.system_config for all using (auth.role() = 'authenticated');

-- Global Project settings and grades
create table if not exists public.project_settings (
  id uuid default uuid_generate_v4() primary key,
  course_id uuid references public.courses(id) on delete cascade,
  quarter_id uuid references public.quarters(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete cascade,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (course_id, quarter_id, subject_id)
);

create table if not exists public.project_grades (
  id uuid default uuid_generate_v4() primary key,
  student_id uuid references public.students(id) on delete cascade,
  course_id uuid references public.courses(id) on delete cascade,
  quarter_id uuid references public.quarters(id) on delete cascade,
  score decimal(5,2),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (student_id, course_id, quarter_id)
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
alter table public.project_grades enable row level security;
alter table public.project_subject_grades enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'project_settings' and policyname = 'Enable read access for all users') then
    create policy "Enable read access for all users" on public.project_settings for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'project_settings' and policyname = 'Enable write for authenticated users') then
    create policy "Enable write for authenticated users" on public.project_settings for all using (auth.role() = 'authenticated');
  end if;
end
$$;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'project_grades' and policyname = 'Enable read access for all users') then
    create policy "Enable read access for all users" on public.project_grades for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'project_grades' and policyname = 'Enable write for authenticated users') then
    create policy "Enable write for authenticated users" on public.project_grades for all using (auth.role() = 'authenticated');
  end if;
end
$$;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'project_subject_grades' and policyname = 'Enable read access for all users') then
    create policy "Enable read access for all users" on public.project_subject_grades for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'project_subject_grades' and policyname = 'Enable write for authenticated users') then
    create policy "Enable write for authenticated users" on public.project_subject_grades for all using (auth.role() = 'authenticated');
  end if;
end
$$;


-- Create Definitions table for dynamic columns
create table if not exists public.grade_definitions (
  id uuid default uuid_generate_v4() primary key,
  course_subject_id uuid references public.course_subjects(id) on delete cascade,
  quarter_id uuid references public.quarters(id) on delete cascade,
  name text not null, -- "Insumo 1", "Leccion Oral", etc.
  category text not null, -- INDIVIDUAL, GRUPAL, SUMATIVA, REFUERZO
  weight decimal(5,2) default 1.0, 
  sort_order int not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.grade_definitions enable row level security;

-- Policies safely created
do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'grade_definitions' and policyname = 'Enable read access for all users') then
    create policy "Enable read access for all users" on public.grade_definitions for select using (true);
  end if;

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'grade_definitions' and policyname = 'Enable write for authenticated users') then
    create policy "Enable write for authenticated users" on public.grade_definitions for all using (auth.role() = 'authenticated');
  end if;
end
$$;

-- Modify Grades table
delete from public.grades; -- Clear data to avoid conflicts

alter table public.grades 
  add column if not exists grade_definition_id uuid references public.grade_definitions(id) on delete cascade;

-- Remove old unique constraint
alter table public.grades 
  drop constraint if exists grades_student_id_course_subject_id_quarter_id_key;

-- Add new unique constraint
alter table public.grades
  drop constraint if exists grades_student_id_definition_key;

alter table public.grades
  add constraint grades_student_id_definition_key unique (student_id, grade_definition_id);


-- ====================================================================
-- TABLA DE AUDITORÃA - WebNotas
-- Ejecutar en Supabase SQL Editor para rastrear cambios de notas
-- ====================================================================

-- Tabla de auditorÃ­a para cambios en calificaciones
create table if not exists public.audit_log (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users(id) not null,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  table_name text not null,
  record_id uuid,
  old_values jsonb,
  new_values jsonb,
  ip_address text,
  user_agent text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Habilitar RLS
alter table public.audit_log enable row level security;

-- PolÃ­ticas de acceso (solo admins pueden ver logs)
drop policy if exists "Admins can view audit logs" on public.audit_log;
create policy "Admins can view audit logs" on public.audit_log 
  for select using (
    exists (
      select 1 from public.profiles 
      where profiles.id = auth.uid() 
      and profiles.role = 'admin'
    )
  );

-- Nadie puede insertar directamente (se hace vÃ­a triggers)
drop policy if exists "No direct insert" on public.audit_log;

-- Ãndice para consultas frecuentes
create index if not exists idx_audit_log_created_at on audit_log(created_at desc);
create index if not exists idx_audit_log_user_id on audit_log(user_id);
create index if not exists idx_audit_log_table_name on audit_log(table_name);
create index if not exists idx_audit_log_record_id on audit_log(record_id);

-- ====================================================================
-- TRIGGERS PARA AUDITORÃA DE CALIFICACIONES
-- ====================================================================

-- FunciÃ³n genÃ©rica de auditorÃ­a
create or replace function public.audit_grades_changes()
returns trigger as $$
begin
  if (TG_OP = 'INSERT') then
    insert into public.audit_log (user_id, action, table_name, record_id, new_values)
    values (
      auth.uid(),
      'INSERT',
      TG_TABLE_NAME,
      NEW.id,
      to_jsonb(NEW)
    );
    return NEW;
  elsif (TG_OP = 'UPDATE') then
    insert into public.audit_log (user_id, action, table_name, record_id, old_values, new_values)
    values (
      auth.uid(),
      'UPDATE',
      TG_TABLE_NAME,
      NEW.id,
      to_jsonb(OLD),
      to_jsonb(NEW)
    );
    return NEW;
  elsif (TG_OP = 'DELETE') then
    insert into public.audit_log (user_id, action, table_name, record_id, old_values)
    values (
      auth.uid(),
      'DELETE',
      TG_TABLE_NAME,
      OLD.id,
      to_jsonb(OLD)
    );
    return OLD;
  end if;
  return null;
end;
$$ language plpgsql security definer;

-- Trigger para tabla grades
drop trigger if exists audit_grades_trigger on public.grades;
create trigger audit_grades_trigger
  after insert or update or delete on public.grades
  for each row execute function public.audit_grades_changes();

-- Trigger para tabla qualitative_grades
drop trigger if exists audit_qualitative_grades_trigger on public.qualitative_grades;
create trigger audit_qualitative_grades_trigger
  after insert or update or delete on public.qualitative_grades
  for each row execute function public.audit_grades_changes();

-- Trigger para tabla project_subject_grades
drop trigger if exists audit_project_grades_trigger on public.project_subject_grades;
create trigger audit_project_grades_trigger
  after insert or update or delete on public.project_subject_grades
  for each row execute function public.audit_grades_changes();

-- ====================================================================
-- ÃNDICES DE RENDIMIENTO - WebNotas
-- Ejecutar en Supabase SQL Editor para optimizar consultas frecuentes
-- ====================================================================

-- Ãndice para bÃºsqueda de estudiantes por curso
CREATE INDEX IF NOT EXISTS idx_students_course_id ON students(course_id);

-- Ãndice para bÃºsqueda de estudiantes por nombre (bÃºsquedas parciales)
CREATE INDEX IF NOT EXISTS idx_students_full_name ON students USING gin(to_tsvector('simple', full_name));

-- Ãndice para bÃºsqueda de estudiantes por cÃ©dula
CREATE INDEX IF NOT EXISTS idx_students_cedula ON students(student_cedula) WHERE student_cedula IS NOT NULL;

-- Ãndices para calificaciones (consultas muy frecuentes)
CREATE INDEX IF NOT EXISTS idx_grades_student_id ON grades(student_id);
CREATE INDEX IF NOT EXISTS idx_grades_grade_definition_id ON grades(grade_definition_id);
CREATE INDEX IF NOT EXISTS idx_grades_student_def ON grades(student_id, grade_definition_id);

-- Ãndices para definiciones de calificaciones
CREATE INDEX IF NOT EXISTS idx_grade_defs_course_subject ON grade_definitions(course_subject_id);
CREATE INDEX IF NOT EXISTS idx_grade_defs_quarter ON grade_definitions(quarter_id);
CREATE INDEX IF NOT EXISTS idx_grade_defs_course_quarter ON grade_definitions(course_subject_id, quarter_id);

-- Ãndices para materias de curso
CREATE INDEX IF NOT EXISTS idx_course_subjects_course_id ON course_subjects(course_id);
CREATE INDEX IF NOT EXISTS idx_course_subjects_subject_id ON course_subjects(subject_id);
CREATE INDEX IF NOT EXISTS idx_course_subjects_teacher_id ON course_subjects(teacher_id) WHERE teacher_id IS NOT NULL;

-- Ãndices para calificaciones cualitativas
CREATE INDEX IF NOT EXISTS idx_qualitative_grades_student_id ON qualitative_grades(student_id);
CREATE INDEX IF NOT EXISTS idx_qualitative_grades_course_subject ON qualitative_grades(course_subject_id);
CREATE INDEX IF NOT EXISTS idx_qualitative_grades_quarter ON qualitative_grades(quarter_id);

-- Ãndices para exÃ¡menes supletorios
CREATE INDEX IF NOT EXISTS idx_supplementary_exams_student_id ON supplementary_exams(student_id);
CREATE INDEX IF NOT EXISTS idx_supplementary_exams_course_subject ON supplementary_exams(course_subject_id);

-- Ãndices para proyecto (si estÃ¡ habilitado)
CREATE INDEX IF NOT EXISTS idx_project_settings_course_quarter ON project_settings(course_id, quarter_id);
CREATE INDEX IF NOT EXISTS idx_project_grades_student_course_quarter ON project_subject_grades(student_id, course_id, quarter_id);

-- Ãndice para configuraciones del sistema
CREATE INDEX IF NOT EXISTS idx_system_config_key ON system_config(key);

-- Ãndices para perfiles de usuario
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);

-- Ãndice para cursos por aÃ±o acadÃ©mico
CREATE INDEX IF NOT EXISTS idx_courses_academic_year ON courses(academic_year);

-- Ãndices para auditorÃ­a (si se implementa)
-- CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON audit_log(created_at);
-- CREATE INDEX IF NOT EXISTS idx_audit_log_user_id ON audit_log(user_id);

