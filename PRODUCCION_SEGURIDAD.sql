-- ============================================
-- SEGURIDAD COMPLETA PARA PRODUCCION
-- WebNotas - 2026
-- ============================================

-- ============================================
-- 1. ACTUALIZAR ROL DEL ADMIN
-- ============================================
UPDATE profiles SET role = 'admin' WHERE email = 'admin@webnotas.com';

-- ============================================
-- 2. VERIFICAR QUE SOLO EXISTE EL ADMIN
-- ============================================
-- Verificar usuarios (ejecutar manualmente si hay dudas)
-- SELECT id, email, role FROM profiles;

-- ============================================
-- 3. LIMPIEZA DE POLITICAS RLS ANTIGUAS
-- ============================================

-- Eliminar politicas existentes (si hay duplicados o obsoletas)
DROP POLICY IF EXISTS "Public read institution assets" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated upload institution assets" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated update institution assets" ON storage.objects;
DROP POLICY IF EXISTS "Public read student photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated upload student photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated update student photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated delete student photos" ON storage.objects;

-- ============================================
-- 4. CREAR BUCKETS DE STORAGE (si no existen)
-- ============================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('institution-assets', 'institution-assets', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('student-photos', 'student-photos', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 5. POLITICAS DE STORAGE SEGURAS
-- ============================================

-- Institution assets: solo admin puede subir, todos pueden leer
CREATE POLICY "institution_assets_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'institution-assets');

CREATE POLICY "institution_assets_upload" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'institution-assets'
        AND auth.role() = 'authenticated'
        AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "institution_assets_update" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'institution-assets'
        AND auth.role() = 'authenticated'
        AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- Student photos: solo admins pueden eliminar, authenticated puede leer/escribir
CREATE POLICY "student_photos_read" ON storage.objects
    FOR SELECT USING (bucket_id = 'student-photos');

CREATE POLICY "student_photos_upload" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'student-photos'
        AND auth.role() = 'authenticated'
    );

CREATE POLICY "student_photos_update" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'student-photos'
        AND auth.role() = 'authenticated'
    );

CREATE POLICY "student_photos_delete" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'student-photos'
        AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- ============================================
-- 6. REFORZAR RLS EN TODAS LAS TABLAS
-- ============================================

-- Forzar RLS en todas las tablas
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE quarters ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE grade_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE qualitative_grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_subject_grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplementary_exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_config ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 7. POLITICAS RLS SEGURAS
-- ============================================

-- --- PROFILES ---
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON profiles;

CREATE POLICY "profiles_own" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_own_update" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "profiles_admin_all" ON profiles FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- --- COURSES ---
DROP POLICY IF EXISTS "Authenticated users can view courses" ON courses;
DROP POLICY IF EXISTS "Admins can insert courses" ON courses;
DROP POLICY IF EXISTS "Admins can update courses" ON courses;
DROP POLICY IF EXISTS "Admins can delete courses" ON courses;

CREATE POLICY "courses_all_auth" ON courses FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "courses_admin_cud" ON courses FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- --- SUBJECTS ---
DROP POLICY IF EXISTS "Authenticated users can view subjects" ON subjects;
DROP POLICY IF EXISTS "Admins can insert subjects" ON subjects;
DROP POLICY IF EXISTS "Admins can update subjects" ON subjects;
DROP POLICY IF EXISTS "Admins can delete subjects" ON subjects;

CREATE POLICY "subjects_all_auth" ON subjects FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "subjects_admin_cud" ON subjects FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- --- QUARTERS ---
DROP POLICY IF EXISTS "Authenticated users can view quarters" ON quarters;
DROP POLICY IF EXISTS "Admins can insert quarters" ON quarters;
DROP POLICY IF EXISTS "Admins can update quarters" ON quarters;

CREATE POLICY "quarters_all_auth" ON quarters FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "quarters_admin_cud" ON quarters FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- --- COURSE_SUBJECTS ---
DROP POLICY IF EXISTS "Authenticated users can view course_subjects" ON course_subjects;
DROP POLICY IF EXISTS "Authenticated users can insert course_subjects" ON course_subjects;
DROP POLICY IF EXISTS "Admins can update course_subjects" ON course_subjects;
DROP POLICY IF EXISTS "Admins can delete course_subjects" ON course_subjects;

CREATE POLICY "course_subjects_all_auth" ON course_subjects FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "course_subjects_teacher_insert" ON course_subjects FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "course_subjects_admin_cud" ON course_subjects FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "course_subjects_admin_delete" ON course_subjects FOR DELETE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- --- GRADE_DEFINITIONS ---
DROP POLICY IF EXISTS "Authenticated users can view grade_definitions" ON grade_definitions;
DROP POLICY IF EXISTS "Authenticated users can insert grade_definitions" ON grade_definitions;
DROP POLICY IF EXISTS "Authenticated users can update grade_definitions" ON grade_definitions;
DROP POLICY IF EXISTS "Admins can delete grade_definitions" ON grade_definitions;

CREATE POLICY "grade_definitions_all_auth" ON grade_definitions FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "grade_definitions_teacher_cud" ON grade_definitions FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "grade_definitions_admin_delete" ON grade_definitions FOR DELETE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- --- STUDENTS ---
DROP POLICY IF EXISTS "Authenticated users can view students" ON students;
DROP POLICY IF EXISTS "Authenticated users can insert students" ON students;
DROP POLICY IF EXISTS "Authenticated users can update students" ON students;
DROP POLICY IF EXISTS "Admins can delete students" ON students;

CREATE POLICY "students_all_auth" ON students FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "students_teacher_cud" ON students FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "students_teacher_update" ON students FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "students_admin_delete" ON students FOR DELETE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- --- GRADES ---
DROP POLICY IF EXISTS "Authenticated users can view grades" ON grades;
DROP POLICY IF EXISTS "Authenticated users can insert grades" ON grades;
DROP POLICY IF EXISTS "Authenticated users can update grades" ON grades;
DROP POLICY IF EXISTS "Authenticated users can delete grades" ON grades;

CREATE POLICY "grades_all_auth" ON grades FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "grades_teacher_cud" ON grades FOR ALL USING (auth.role() = 'authenticated');

-- --- QUALITATIVE_GRADES ---
DROP POLICY IF EXISTS "Authenticated users can view qualitative_grades" ON qualitative_grades;
DROP POLICY IF EXISTS "Authenticated users can insert qualitative_grades" ON qualitative_grades;
DROP POLICY IF EXISTS "Authenticated users can update qualitative_grades" ON qualitative_grades;
DROP POLICY IF EXISTS "Authenticated users can delete qualitative_grades" ON qualitative_grades;

CREATE POLICY "qualitative_grades_all_auth" ON qualitative_grades FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "qualitative_grades_teacher_cud" ON qualitative_grades FOR ALL USING (auth.role() = 'authenticated');

-- --- PROJECT_SETTINGS ---
DROP POLICY IF EXISTS "Authenticated users can view project_settings" ON project_settings;
DROP POLICY IF EXISTS "Authenticated users can insert project_settings" ON project_settings;
DROP POLICY IF EXISTS "Authenticated users can update project_settings" ON project_settings;
DROP POLICY IF EXISTS "Authenticated users can delete project_settings" ON project_settings;

CREATE POLICY "project_settings_all_auth" ON project_settings FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "project_settings_teacher_cud" ON project_settings FOR ALL USING (auth.role() = 'authenticated');

-- --- PROJECT_SUBJECT_GRADES ---
DROP POLICY IF EXISTS "Authenticated users can view project_subject_grades" ON project_subject_grades;
DROP POLICY IF EXISTS "Authenticated users can insert project_subject_grades" ON project_subject_grades;
DROP POLICY IF EXISTS "Authenticated users can update project_subject_grades" ON project_subject_grades;
DROP POLICY IF EXISTS "Authenticated users can delete project_subject_grades" ON project_subject_grades;

CREATE POLICY "project_subject_grades_all_auth" ON project_subject_grades FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "project_subject_grades_teacher_cud" ON project_subject_grades FOR ALL USING (auth.role() = 'authenticated');

-- --- SUPPLEMENTARY_EXAMS ---
DROP POLICY IF EXISTS "Authenticated users can view supplementary_exams" ON supplementary_exams;
DROP POLICY IF EXISTS "Authenticated users can insert supplementary_exams" ON supplementary_exams;
DROP POLICY IF EXISTS "Authenticated users can update supplementary_exams" ON supplementary_exams;
DROP POLICY IF EXISTS "Authenticated users can delete supplementary_exams" ON supplementary_exams;

CREATE POLICY "supplementary_exams_all_auth" ON supplementary_exams FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "supplementary_exams_teacher_cud" ON supplementary_exams FOR ALL USING (auth.role() = 'authenticated');

-- --- SYSTEM_CONFIG ---
DROP POLICY IF EXISTS "Authenticated users can view system_config" ON system_config;
DROP POLICY IF EXISTS "Admins can insert system_config" ON system_config;
DROP POLICY IF EXISTS "Admins can update system_config" ON system_config;

CREATE POLICY "system_config_all_auth" ON system_config FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "system_config_admin_cud" ON system_config FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ============================================
-- 8. VERIFICACION
-- ============================================
-- Ejecutar para verificar:
-- SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';
-- SELECT * FROM pg_policies WHERE schemaname = 'public';
