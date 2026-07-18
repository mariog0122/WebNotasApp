-- ============================================
-- CORRECCION: Infinite recursion fix
-- WebNotas - 2026
-- ============================================

-- Eliminar policies problematicas
DROP POLICY IF EXISTS "profiles_own" ON profiles;
DROP POLICY IF EXISTS "profiles_own_update" ON profiles;
DROP POLICY IF EXISTS "profiles_admin_all" ON profiles;
DROP POLICY IF EXISTS "courses_admin_cud" ON courses;
DROP POLICY IF EXISTS "subjects_admin_cud" ON subjects;
DROP POLICY IF EXISTS "quarters_admin_cud" ON quarters;
DROP POLICY IF EXISTS "course_subjects_admin_cud" ON course_subjects;
DROP POLICY IF EXISTS "course_subjects_admin_delete" ON course_subjects;
DROP POLICY IF EXISTS "grade_definitions_admin_delete" ON grade_definitions;
DROP POLICY IF EXISTS "students_admin_delete" ON students;
DROP POLICY IF EXISTS "system_config_admin_cud" ON system_config;

-- ============================================
-- FUNCION SEGURA PARA CHECK ADMIN (sin recursion)
-- ============================================
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- PROFILES POLICIES (sin recursion)
-- ============================================
CREATE POLICY "profiles_select_own" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "profiles_admin_all" ON profiles FOR ALL USING (is_admin());

-- ============================================
-- COURSES POLICIES
-- ============================================
CREATE POLICY "courses_select_all" ON courses FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "courses_admin_cud" ON courses FOR ALL USING (is_admin());

-- ============================================
-- SUBJECTS POLICIES
-- ============================================
CREATE POLICY "subjects_select_all" ON subjects FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "subjects_admin_cud" ON subjects FOR ALL USING (is_admin());

-- ============================================
-- QUARTERS POLICIES
-- ============================================
CREATE POLICY "quarters_select_all" ON quarters FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "quarters_admin_cud" ON quarters FOR ALL USING (is_admin());

-- ============================================
-- COURSE_SUBJECTS POLICIES
-- ============================================
CREATE POLICY "course_subjects_select_all" ON course_subjects FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "course_subjects_insert" ON course_subjects FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "course_subjects_update" ON course_subjects FOR UPDATE USING (is_admin());
CREATE POLICY "course_subjects_delete" ON course_subjects FOR DELETE USING (is_admin());

-- ============================================
-- GRADE_DEFINITIONS POLICIES
-- ============================================
CREATE POLICY "grade_definitions_select_all" ON grade_definitions FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "grade_definitions_cud" ON grade_definitions FOR ALL USING (auth.role() = 'authenticated');

-- ============================================
-- STUDENTS POLICIES
-- ============================================
CREATE POLICY "students_select_all" ON students FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "students_insert" ON students FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "students_update" ON students FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "students_delete" ON students FOR DELETE USING (is_admin());

-- ============================================
-- GRADES POLICIES
-- ============================================
CREATE POLICY "grades_select_all" ON grades FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "grades_cud" ON grades FOR ALL USING (auth.role() = 'authenticated');

-- ============================================
-- QUALITATIVE_GRADES POLICIES
-- ============================================
CREATE POLICY "qualitative_grades_select_all" ON qualitative_grades FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "qualitative_grades_cud" ON qualitative_grades FOR ALL USING (auth.role() = 'authenticated');

-- ============================================
-- PROJECT_SETTINGS POLICIES
-- ============================================
CREATE POLICY "project_settings_select_all" ON project_settings FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "project_settings_cud" ON project_settings FOR ALL USING (auth.role() = 'authenticated');

-- ============================================
-- PROJECT_SUBJECT_GRADES POLICIES
-- ============================================
CREATE POLICY "project_subject_grades_select_all" ON project_subject_grades FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "project_subject_grades_cud" ON project_subject_grades FOR ALL USING (auth.role() = 'authenticated');

-- ============================================
-- SUPPLEMENTARY_EXAMS POLICIES
-- ============================================
CREATE POLICY "supplementary_exams_select_all" ON supplementary_exams FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "supplementary_exams_cud" ON supplementary_exams FOR ALL USING (auth.role() = 'authenticated');

-- ============================================
-- SYSTEM_CONFIG POLICIES
-- ============================================
CREATE POLICY "system_config_select_all" ON system_config FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "system_config_admin_cud" ON system_config FOR ALL USING (is_admin());

-- ============================================
-- VERIFICAR
-- ============================================
-- SELECT * FROM pg_policies WHERE schemaname = 'public';
