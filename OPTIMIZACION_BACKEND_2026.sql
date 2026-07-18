-- ============================================
-- OPTIMIZACION DE BACKEND - WEBNOTAS (BEST PRACTICES)
-- Instrucciones: Copiar y ejecutar este script completo en el SQL Editor de Supabase.
-- ============================================

-- ============================================
-- FASE 1: FUNCIONES DE DESEMPEÑO RLS
-- ============================================

-- Funcion para obtener el rol del usuario de forma cacheable (STABLE)
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text AS $$
DECLARE
  v_role text;
BEGIN
  SELECT role INTO v_role
  FROM profiles
  WHERE id = auth.uid();
  RETURN v_role;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- Helpers de verificacion rapidos
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN get_my_role() = 'admin';
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.is_teacher()
RETURNS boolean AS $$
BEGIN
  RETURN get_my_role() IN ('admin', 'teacher');
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- ============================================
-- FASE 2: INDICES DE RENDIMIENTO (QUERY PERFORMANCE)
-- ============================================

-- Students: Acelera carga por curso
CREATE INDEX IF NOT EXISTS idx_students_course_id ON students(course_id);
CREATE INDEX IF NOT EXISTS idx_students_representative_cedula ON students(representative_cedula);

-- Courses: Acelera filtrado por año
CREATE INDEX IF NOT EXISTS idx_courses_academic_year ON courses(academic_year);

-- Grades: Vital para el rendimiento de las actas de calificaciones
CREATE INDEX IF NOT EXISTS idx_grades_student_id ON grades(student_id);
CREATE INDEX IF NOT EXISTS idx_grades_grade_definition_id ON grades(grade_definition_id);
CREATE INDEX IF NOT EXISTS idx_grades_composite ON grades(student_id, grade_definition_id);

-- Grade Definitions: Acelera carga de columnas de notas
CREATE INDEX IF NOT EXISTS idx_grade_definitions_cs_quarter ON grade_definitions(course_subject_id, quarter_id);

-- Course Subjects: Acelera joins
CREATE INDEX IF NOT EXISTS idx_course_subjects_course_id ON course_subjects(course_id);
CREATE INDEX IF NOT EXISTS idx_course_subjects_subject_id ON course_subjects(subject_id);

-- Project Settings & Grades
CREATE INDEX IF NOT EXISTS idx_project_settings_composite ON project_settings(course_id, quarter_id);
CREATE INDEX IF NOT EXISTS idx_psg_composite ON project_subject_grades(student_id, quarter_id);

-- ============================================
-- FASE 3: REFACTORIZACION DE POLITICAS RLS (SECURITY & SPEED)
-- ============================================

-- Restringir acceso publico anonimo (Hardening)
-- Cambiamos "true" por "(auth.uid() IS NOT NULL)" en lecturas generales.

-- PROFILES
DROP POLICY IF EXISTS "Users can view all profiles" ON profiles;
CREATE POLICY "Users can view all profiles" ON profiles
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- STUDENTS
DROP POLICY IF EXISTS "Anyone can read students" ON students;
CREATE POLICY "Anyone can read students" ON students
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Admins can manage students" ON students;
CREATE POLICY "Admins can manage students" ON students
  FOR ALL USING (is_admin());

-- COURSES
DROP POLICY IF EXISTS "Anyone can read courses" ON courses;
CREATE POLICY "Anyone can read courses" ON courses
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Admins can manage courses" ON courses;
CREATE POLICY "Admins can manage courses" ON courses
  FOR ALL USING (is_admin());

-- GRADES
DROP POLICY IF EXISTS "Anyone can read grades" ON grades;
CREATE POLICY "Anyone can read grades" ON grades
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Teachers and admins can insert grades" ON grades;
CREATE POLICY "Teachers and admins can insert grades" ON grades
  FOR INSERT WITH CHECK (is_teacher());

DROP POLICY IF EXISTS "Teachers and admins can update grades" ON grades;
CREATE POLICY "Teachers and admins can update grades" ON grades
  FOR UPDATE USING (is_teacher());

DROP POLICY IF EXISTS "Admins can delete grades" ON grades;
CREATE POLICY "Admins can delete grades" ON grades
  FOR DELETE USING (is_admin());

-- SYSTEM_CONFIG
DROP POLICY IF EXISTS "Admins can read system_config" ON system_config;
CREATE POLICY "Admins can read system_config" ON system_config
  FOR SELECT USING (is_admin());

DROP POLICY IF EXISTS "Admins can manage system_config" ON system_config;
CREATE POLICY "Admins can manage system_config" ON system_config
  FOR ALL USING (is_admin());

-- SUPPLEMENTARY_EXAMS
DROP POLICY IF EXISTS "Anyone can read supplementary_exams" ON supplementary_exams;
CREATE POLICY "Anyone can read supplementary_exams" ON supplementary_exams
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Admins can manage supplementary_exams" ON supplementary_exams;
CREATE POLICY "Admins can manage supplementary_exams" ON supplementary_exams
  FOR ALL USING (is_admin());

-- PROJECT_SETTINGS
DROP POLICY IF EXISTS "Anyone can read project_settings" ON project_settings;
CREATE POLICY "Anyone can read project_settings" ON project_settings
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Teachers and admins can manage project_settings" ON project_settings;
CREATE POLICY "Teachers and admins can manage project_settings" ON project_settings
  FOR ALL USING (is_teacher());

-- PROJECT_SUBJECT_GRADES
DROP POLICY IF EXISTS "Anyone can read project_subject_grades" ON project_subject_grades;
CREATE POLICY "Anyone can read project_subject_grades" ON project_subject_grades
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Teachers and admins can insert project_subject_grades" ON project_subject_grades;
CREATE POLICY "Teachers and admins can insert project_subject_grades" ON project_subject_grades
  FOR INSERT WITH CHECK (is_teacher());

DROP POLICY IF EXISTS "Teachers and admins can update project_subject_grades" ON project_subject_grades;
CREATE POLICY "Teachers and admins can update project_subject_grades" ON project_subject_grades
  FOR UPDATE USING (is_teacher());

DROP POLICY IF EXISTS "Admins can delete project_subject_grades" ON project_subject_grades;
CREATE POLICY "Admins can delete project_subject_grades" ON project_subject_grades
  FOR DELETE USING (is_admin());

-- ============================================
-- VERIFICACION FINAL
-- ============================================
SELECT schemaname, tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
