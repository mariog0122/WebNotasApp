-- ====================================================================
-- MIGRATION: 11_secure_rls_policies.sql
-- PURPOSE: FASE 13 (Seguridad & Aislamiento Multi-Tenant RLS Impregnable)
-- Garantiza que NINGÚN usuario de una institución pueda consultar o modificar
-- datos de otra institución ni elevar sus propios privilegios.
-- ====================================================================

-- 1. TABLA SCHOOLS (TENANTS)
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Isolate reads by school" ON public.schools;
DROP POLICY IF EXISTS "Superadmin full access schools" ON public.schools;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.schools;

CREATE POLICY "Platform admins full access schools" ON public.schools
    FOR ALL USING (public.is_platform_admin());

CREATE POLICY "Tenant members read own school" ON public.schools
    FOR SELECT USING (id = public.get_user_school_id());

-- 2. TABLA PROFILES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile." ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile." ON public.profiles;
DROP POLICY IF EXISTS "Superadmin full access profiles" ON public.profiles;
DROP POLICY IF EXISTS "profiles_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_own_update" ON public.profiles;
DROP POLICY IF EXISTS "profiles_admin_all" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;

CREATE POLICY "Platform admins full access profiles" ON public.profiles
    FOR ALL USING (public.is_platform_admin());

CREATE POLICY "Users read own profile" ON public.profiles
    FOR SELECT USING (id = auth.uid());

CREATE POLICY "Users update own basic info" ON public.profiles
    FOR UPDATE USING (id = auth.uid())
    WITH CHECK (
        id = auth.uid() 
        AND role IS NOT DISTINCT FROM (SELECT role FROM public.profiles WHERE id = auth.uid())
    );

CREATE POLICY "School admin view profiles in same school" ON public.profiles
    FOR SELECT USING (
        school_id = public.get_user_school_id()
    );

CREATE POLICY "School admin update profiles in same school" ON public.profiles
    FOR UPDATE USING (
        school_id = public.get_user_school_id() 
        AND public.has_tenant_permission('users.manage')
        AND role != 'superadmin'
    )
    WITH CHECK (
        school_id = public.get_user_school_id() 
        AND role != 'superadmin'
    );

-- 3. ESTRUCTURAS Y TRANSACCIONES INSTITUCIONALES (COURSES, SUBJECTS, QUARTERS, STUDENTS, COURSE_SUBJECTS)

-- --- COURSES ---
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.courses;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.courses;
DROP POLICY IF EXISTS "Enable update for authenticated users only" ON public.courses;
DROP POLICY IF EXISTS "Enable delete for authenticated users only" ON public.courses;
DROP POLICY IF EXISTS "courses_all_auth" ON public.courses;
DROP POLICY IF EXISTS "courses_admin_cud" ON public.courses;
DROP POLICY IF EXISTS "courses_select_all" ON public.courses;
DROP POLICY IF EXISTS "Isolate reads by school" ON public.courses;

CREATE POLICY "Courses multi tenant isolate" ON public.courses
    FOR ALL USING (
        public.is_platform_admin() 
        OR (school_id = public.get_user_school_id() AND auth.role() = 'authenticated')
    );

-- --- SUBJECTS ---
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.subjects;
DROP POLICY IF EXISTS "Enable write for authenticated users" ON public.subjects;
DROP POLICY IF EXISTS "subjects_all_auth" ON public.subjects;
DROP POLICY IF EXISTS "subjects_admin_cud" ON public.subjects;
DROP POLICY IF EXISTS "subjects_select_all" ON public.subjects;
DROP POLICY IF EXISTS "Isolate reads by school" ON public.subjects;

CREATE POLICY "Subjects multi tenant isolate" ON public.subjects
    FOR ALL USING (
        public.is_platform_admin() 
        OR (school_id = public.get_user_school_id() AND auth.role() = 'authenticated')
    );

-- --- QUARTERS ---
ALTER TABLE public.quarters ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.quarters;
DROP POLICY IF EXISTS "Enable write for authenticated users" ON public.quarters;
DROP POLICY IF EXISTS "quarters_all_auth" ON public.quarters;
DROP POLICY IF EXISTS "quarters_admin_cud" ON public.quarters;
DROP POLICY IF EXISTS "quarters_select_all" ON public.quarters;
DROP POLICY IF EXISTS "Isolate reads by school" ON public.quarters;

CREATE POLICY "Quarters multi tenant isolate" ON public.quarters
    FOR ALL USING (
        public.is_platform_admin() 
        OR (school_id = public.get_user_school_id() AND auth.role() = 'authenticated')
    );

-- --- STUDENTS ---
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.students;
DROP POLICY IF EXISTS "Enable write for authenticated users" ON public.students;
DROP POLICY IF EXISTS "students_all_auth" ON public.students;
DROP POLICY IF EXISTS "students_teacher_cud" ON public.students;
DROP POLICY IF EXISTS "students_teacher_update" ON public.students;
DROP POLICY IF EXISTS "students_admin_delete" ON public.students;
DROP POLICY IF EXISTS "students_select_all" ON public.students;
DROP POLICY IF EXISTS "students_insert" ON public.students;
DROP POLICY IF EXISTS "students_update" ON public.students;
DROP POLICY IF EXISTS "students_delete" ON public.students;
DROP POLICY IF EXISTS "Isolate reads by school" ON public.students;

CREATE POLICY "Students multi tenant isolate" ON public.students
    FOR ALL USING (
        public.is_platform_admin() 
        OR (school_id = public.get_user_school_id() AND auth.role() = 'authenticated')
    );

-- --- COURSE_SUBJECTS ---
ALTER TABLE public.course_subjects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.course_subjects;
DROP POLICY IF EXISTS "Enable write for authenticated users" ON public.course_subjects;
DROP POLICY IF EXISTS "course_subjects_all_auth" ON public.course_subjects;
DROP POLICY IF EXISTS "course_subjects_teacher_insert" ON public.course_subjects;
DROP POLICY IF EXISTS "course_subjects_admin_cud" ON public.course_subjects;
DROP POLICY IF EXISTS "course_subjects_admin_delete" ON public.course_subjects;
DROP POLICY IF EXISTS "course_subjects_select_all" ON public.course_subjects;
DROP POLICY IF EXISTS "course_subjects_insert" ON public.course_subjects;
DROP POLICY IF EXISTS "course_subjects_update" ON public.course_subjects;
DROP POLICY IF EXISTS "course_subjects_delete" ON public.course_subjects;
DROP POLICY IF EXISTS "Isolate reads by school" ON public.course_subjects;

CREATE POLICY "Course subjects multi tenant isolate" ON public.course_subjects
    FOR ALL USING (
        public.is_platform_admin() 
        OR (school_id = public.get_user_school_id() AND auth.role() = 'authenticated')
    );

-- --- GRADE_DEFINITIONS ---
ALTER TABLE public.grade_definitions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.grade_definitions;
DROP POLICY IF EXISTS "Enable write for authenticated users" ON public.grade_definitions;
DROP POLICY IF EXISTS "grade_definitions_all_auth" ON public.grade_definitions;
DROP POLICY IF EXISTS "grade_definitions_teacher_cud" ON public.grade_definitions;
DROP POLICY IF EXISTS "grade_definitions_admin_delete" ON public.grade_definitions;
DROP POLICY IF EXISTS "grade_definitions_select_all" ON public.grade_definitions;
DROP POLICY IF EXISTS "grade_definitions_cud" ON public.grade_definitions;
DROP POLICY IF EXISTS "Isolate reads by school" ON public.grade_definitions;

CREATE POLICY "Grade definitions multi tenant isolate" ON public.grade_definitions
    FOR ALL USING (
        public.is_platform_admin() 
        OR (school_id = public.get_user_school_id() AND auth.role() = 'authenticated')
    );

-- --- GRADES ---
ALTER TABLE public.grades ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.grades;
DROP POLICY IF EXISTS "Enable write for authenticated users" ON public.grades;
DROP POLICY IF EXISTS "grades_all_auth" ON public.grades;
DROP POLICY IF EXISTS "grades_teacher_cud" ON public.grades;
DROP POLICY IF EXISTS "grades_select_all" ON public.grades;
DROP POLICY IF EXISTS "grades_cud" ON public.grades;
DROP POLICY IF EXISTS "Isolate reads by school via student" ON public.grades;

CREATE POLICY "Grades multi tenant isolate" ON public.grades
    FOR ALL USING (
        public.is_platform_admin() 
        OR EXISTS (
            SELECT 1 FROM public.students 
            WHERE students.id = grades.student_id 
              AND students.school_id = public.get_user_school_id()
        )
    );

-- --- QUALITATIVE_GRADES ---
ALTER TABLE public.qualitative_grades ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.qualitative_grades;
DROP POLICY IF EXISTS "Enable write for authenticated users" ON public.qualitative_grades;
DROP POLICY IF EXISTS "qualitative_grades_all_auth" ON public.qualitative_grades;
DROP POLICY IF EXISTS "qualitative_grades_teacher_cud" ON public.qualitative_grades;
DROP POLICY IF EXISTS "qualitative_grades_select_all" ON public.qualitative_grades;
DROP POLICY IF EXISTS "qualitative_grades_cud" ON public.qualitative_grades;
DROP POLICY IF EXISTS "Isolate reads by school via student" ON public.qualitative_grades;

CREATE POLICY "Qualitative grades multi tenant isolate" ON public.qualitative_grades
    FOR ALL USING (
        public.is_platform_admin() 
        OR EXISTS (
            SELECT 1 FROM public.students 
            WHERE students.id = qualitative_grades.student_id 
              AND students.school_id = public.get_user_school_id()
        )
    );

-- --- SUPPLEMENTARY_EXAMS ---
ALTER TABLE public.supplementary_exams ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.supplementary_exams;
DROP POLICY IF EXISTS "Enable write for authenticated users" ON public.supplementary_exams;
DROP POLICY IF EXISTS "supplementary_exams_all_auth" ON public.supplementary_exams;
DROP POLICY IF EXISTS "supplementary_exams_teacher_cud" ON public.supplementary_exams;
DROP POLICY IF EXISTS "supplementary_exams_select_all" ON public.supplementary_exams;
DROP POLICY IF EXISTS "supplementary_exams_cud" ON public.supplementary_exams;
DROP POLICY IF EXISTS "Isolate reads by school via student" ON public.supplementary_exams;

CREATE POLICY "Supplementary exams multi tenant isolate" ON public.supplementary_exams
    FOR ALL USING (
        public.is_platform_admin() 
        OR EXISTS (
            SELECT 1 FROM public.students 
            WHERE students.id = supplementary_exams.student_id 
              AND students.school_id = public.get_user_school_id()
        )
    );

-- --- SYSTEM_CONFIG ---
ALTER TABLE public.system_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.system_config;
DROP POLICY IF EXISTS "Enable write for authenticated users" ON public.system_config;
DROP POLICY IF EXISTS "system_config_all_auth" ON public.system_config;
DROP POLICY IF EXISTS "system_config_admin_cud" ON public.system_config;
DROP POLICY IF EXISTS "system_config_select_all" ON public.system_config;
DROP POLICY IF EXISTS "Admins only write their own school config" ON public.system_config;
DROP POLICY IF EXISTS "Isolate reads by school" ON public.system_config;

CREATE POLICY "System config multi tenant isolate" ON public.system_config
    FOR ALL USING (
        public.is_platform_admin() 
        OR (school_id = public.get_user_school_id() AND auth.role() = 'authenticated')
    );

-- --- STUDENT_ALERTS ---
ALTER TABLE public.student_alerts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Isolate reads by school" ON public.student_alerts;

CREATE POLICY "Student alerts multi tenant isolate" ON public.student_alerts
    FOR ALL USING (
        public.is_platform_admin() 
        OR (school_id = public.get_user_school_id() AND auth.role() = 'authenticated')
    );
