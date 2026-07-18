-- CLEAN DATA SCRIPT
-- Executes a cleanup of all grade-related data to allow a fresh start with the new schema.
-- Run this in Supabase SQL Editor.

-- 1. Truncate Transactional Tables (Grades, Definitions, Projects)
truncate table public.grades cascade;
truncate table public.project_subject_grades cascade;
truncate table public.qualitative_grades cascade;
truncate table public.supplementary_exams cascade;

-- 2. Delete Grade Definitions (This triggers the app to recreate them with new new structure)
-- We use DELETE instead of TRUNCATE on this one if there are foreign keys, but CASCADE above should handle it.
-- However, to be safe and ensure ID resets aren't strictly needed (UUIDs are used), we just clear it.
truncate table public.grade_definitions cascade;

-- 3. (Optional) Clear Project Settings if you want to re-configure which subjects are projects
truncate table public.project_settings cascade;

-- NOTE: Students, Courses, Subjects, and Quarters are PRESERVED.
-- If you truly want to wipe EVERYTHING (including students), uncomment the below:
-- truncate table public.students cascade;
-- truncate table public.course_subjects cascade;
-- truncate table public.courses cascade;
-- truncate table public.subjects cascade;
-- truncate table public.quarters cascade;
