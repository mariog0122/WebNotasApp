-- ====================================================================
-- MIGRATION: 05_period_locking.sql
-- PURPOSE: Implement Data Locking for closed grading periods.
-- Adds 'is_locked' to quarters and restricts teacher write access.
-- ====================================================================

-- 1. Add is_locked column to quarters
ALTER TABLE public.quarters ADD COLUMN IF NOT EXISTS is_locked boolean DEFAULT false;

-- 2. Update RLS on 'grades'
DROP POLICY IF EXISTS "Admin or Assigned Teacher write" ON public.grades;
CREATE POLICY "Admin or Assigned Teacher write" ON public.grades FOR ALL USING (
  public.is_admin() OR (
    EXISTS (
      SELECT 1 FROM public.course_subjects cs
      WHERE cs.id = course_subject_id
      AND cs.teacher_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM public.quarters q
      WHERE q.id = quarter_id
      AND q.is_locked = false
    )
  )
);

-- 3. Update RLS on 'qualitative_grades'
DROP POLICY IF EXISTS "Admin or Assigned Teacher write" ON public.qualitative_grades;
CREATE POLICY "Admin or Assigned Teacher write" ON public.qualitative_grades FOR ALL USING (
  public.is_admin() OR (
    EXISTS (
      SELECT 1 FROM public.course_subjects cs
      WHERE cs.id = course_subject_id
      AND cs.teacher_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM public.quarters q
      WHERE q.id = quarter_id
      AND q.is_locked = false
    )
  )
);

-- 4. Update RLS on 'project_subject_grades'
DROP POLICY IF EXISTS "Admin or Assigned Teacher write" ON public.project_subject_grades;
CREATE POLICY "Admin or Assigned Teacher write" ON public.project_subject_grades FOR ALL USING (
  public.is_admin() OR (
    EXISTS (
      SELECT 1 FROM public.course_subjects cs
      WHERE cs.course_id = project_subject_grades.course_id
      AND cs.subject_id = project_subject_grades.subject_id
      AND cs.teacher_id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM public.quarters q
      WHERE q.id = quarter_id
      AND q.is_locked = false
    )
  )
);

-- 5. (Optional) If we want project_grades (the summary) to also be locked, 
-- we would need a quarter context. But project_grades is per course/student, not per quarter.
-- We'll leave it as is, since it's an annual aggregation.
