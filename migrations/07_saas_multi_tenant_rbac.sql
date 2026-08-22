-- ====================================================================
-- MIGRATION: 07_saas_multi_tenant_rbac.sql
-- PURPOSE: FASE 2 & FASE 7 - Modelo Multi-Tenant RBAC completo
-- Introduce Platform Roles, Tenant Roles, Permisos granulares y Memberships
-- ====================================================================

-- 1. ENUMS Y COMPATIBILIDAD
DO $$ BEGIN
    CREATE TYPE public.platform_role_type AS ENUM (
        'platform_owner',
        'platform_admin',
        'platform_support',
        'platform_finance',
        'platform_readonly'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE public.tenant_role_type AS ENUM (
        'school_admin',
        'rector',
        'vicerrector',
        'secretary',
        'teacher',
        'inspector',
        'counselor',
        'student',
        'parent'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 2. PLATFORM ROLES TABLE
CREATE TABLE IF NOT EXISTS public.platform_roles (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    name public.platform_role_type UNIQUE NOT NULL,
    description text NOT NULL,
    created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

INSERT INTO public.platform_roles (name, description) VALUES
('platform_owner', 'Propietario de la plataforma SaaS con control total'),
('platform_admin', 'Administrador global de la plataforma'),
('platform_support', 'Soporte técnico global e impersonación autorizada'),
('platform_finance', 'Gestión financiera, planes y pagos'),
('platform_readonly', 'Auditor de plataforma con acceso de solo lectura')
ON CONFLICT (name) DO NOTHING;

-- 3. TENANT ROLES TABLE
CREATE TABLE IF NOT EXISTS public.tenant_roles (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    name public.tenant_role_type UNIQUE NOT NULL,
    description text NOT NULL,
    created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

INSERT INTO public.tenant_roles (name, description) VALUES
('school_admin', 'Administrador del sistema en la institución'),
('rector', 'Rector / Director de la institución'),
('vicerrector', 'Vicerrector / Director Académico'),
('secretary', 'Secretaría académica y administración de fichas'),
('teacher', 'Docente de asignaturas y registro de notas'),
('inspector', 'Inspector general y disciplina'),
('counselor', 'Consejería / DECE y bienestar estudiantil'),
('student', 'Estudiante registrado'),
('parent', 'Padre / Apoderado del estudiante')
ON CONFLICT (name) DO NOTHING;

-- 4. PERMISSIONS TABLE
CREATE TABLE IF NOT EXISTS public.permissions (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    code text UNIQUE NOT NULL,
    module text NOT NULL,
    description text NOT NULL,
    created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

INSERT INTO public.permissions (code, module, description) VALUES
('students.read', 'students', 'Ver registros de estudiantes'),
('students.create', 'students', 'Registrar estudiantes'),
('students.update', 'students', 'Actualizar estudiantes'),
('students.delete', 'students', 'Eliminar estudiantes'),
('grades.read', 'grades', 'Ver calificaciones'),
('grades.create', 'grades', 'Ingresar calificaciones'),
('grades.update', 'grades', 'Modificar calificaciones'),
('attendance.read', 'attendance', 'Ver registros de asistencia'),
('attendance.manage', 'attendance', 'Gestionar asistencia'),
('reports.read', 'reports', 'Ver reportes y sábanas'),
('reports.export', 'reports', 'Exportar boletines en PDF/Excel'),
('users.read', 'users', 'Ver usuarios de la institución'),
('users.invite', 'users', 'Invitar usuarios a la institución'),
('users.manage', 'users', 'Gestionar roles y accesos de usuarios'),
('billing.read', 'billing', 'Ver información de facturación y planes'),
('billing.manage', 'billing', 'Gestionar suscripción y pagos'),
('settings.read', 'settings', 'Ver configuración institucional'),
('settings.manage', 'settings', 'Modificar configuración institucional')
ON CONFLICT (code) DO NOTHING;

-- 5. ROLE_PERMISSIONS TABLE
CREATE TABLE IF NOT EXISTS public.role_permissions (
    tenant_role_id uuid REFERENCES public.tenant_roles(id) ON DELETE CASCADE,
    permission_id uuid REFERENCES public.permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (tenant_role_id, permission_id)
);

-- Asignar permisos por defecto a tenant_roles
DO $$
DECLARE
    r_admin_id uuid;
    r_rector_id uuid;
    r_teacher_id uuid;
    p_rec RECORD;
BEGIN
    SELECT id INTO r_admin_id FROM public.tenant_roles WHERE name = 'school_admin';
    SELECT id INTO r_rector_id FROM public.tenant_roles WHERE name = 'rector';
    SELECT id INTO r_teacher_id FROM public.tenant_roles WHERE name = 'teacher';

    -- Permisos totales para admin y rector
    FOR p_rec IN SELECT id FROM public.permissions LOOP
        IF r_admin_id IS NOT NULL THEN
            INSERT INTO public.role_permissions (tenant_role_id, permission_id) VALUES (r_admin_id, p_rec.id) ON CONFLICT DO NOTHING;
        END IF;
        IF r_rector_id IS NOT NULL THEN
            INSERT INTO public.role_permissions (tenant_role_id, permission_id) VALUES (r_rector_id, p_rec.id) ON CONFLICT DO NOTHING;
        END IF;
    END LOOP;

    -- Permisos para docente
    IF r_teacher_id IS NOT NULL THEN
        FOR p_rec IN SELECT id FROM public.permissions WHERE code IN ('students.read', 'grades.read', 'grades.create', 'grades.update', 'attendance.read', 'attendance.manage', 'reports.read', 'reports.export') LOOP
            INSERT INTO public.role_permissions (tenant_role_id, permission_id) VALUES (r_teacher_id, p_rec.id) ON CONFLICT DO NOTHING;
        END LOOP;
    END IF;
END $$;

-- 6. USER_PLATFORM_ROLES TABLE
CREATE TABLE IF NOT EXISTS public.user_platform_roles (
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    platform_role_id uuid REFERENCES public.platform_roles(id) ON DELETE CASCADE,
    created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (user_id, platform_role_id)
);

-- Promover administradores existentes con role='superadmin' en profiles a platform_owner
DO $$
DECLARE
    prof_rec RECORD;
    owner_role_id uuid;
BEGIN
    SELECT id INTO owner_role_id FROM public.platform_roles WHERE name = 'platform_owner';
    IF owner_role_id IS NOT NULL THEN
        FOR prof_rec IN SELECT id FROM public.profiles WHERE role = 'superadmin' LOOP
            INSERT INTO public.user_platform_roles (user_id, platform_role_id) VALUES (prof_rec.id, owner_role_id) ON CONFLICT DO NOTHING;
        END LOOP;
    END IF;
END $$;

-- 7. TENANT_MEMBERSHIPS TABLE (Múltiples instituciones por usuario)
CREATE TABLE IF NOT EXISTS public.tenant_memberships (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    tenant_role_id uuid REFERENCES public.tenant_roles(id) ON DELETE RESTRICT NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, school_id)
);

-- Migrar perfiles existentes a tenant_memberships
DO $$
DECLARE
    prof_rec RECORD;
    admin_role_id uuid;
    teacher_role_id uuid;
    target_role_id uuid;
BEGIN
    SELECT id INTO admin_role_id FROM public.tenant_roles WHERE name = 'school_admin';
    SELECT id INTO teacher_role_id FROM public.tenant_roles WHERE name = 'teacher';

    FOR prof_rec IN SELECT id, school_id, role FROM public.profiles WHERE school_id IS NOT NULL LOOP
        IF prof_rec.role = 'admin' THEN
            target_role_id := admin_role_id;
        ELSE
            target_role_id := teacher_role_id;
        END IF;

        IF target_role_id IS NOT NULL THEN
            INSERT INTO public.tenant_memberships (user_id, school_id, tenant_role_id)
            VALUES (prof_rec.id, prof_rec.school_id, target_role_id)
            ON CONFLICT (user_id, school_id) DO NOTHING;
        END IF;
    END LOOP;
END $$;

-- 8. FUNCIONES SECURITY DEFINER PARA SEGURIDAD Y PERMISOS SIN RECURSIÓN
CREATE OR REPLACE FUNCTION public.is_platform_admin()
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM public.user_platform_roles upr
        JOIN public.platform_roles pr ON pr.id = upr.platform_role_id
        WHERE upr.user_id = auth.uid() 
          AND pr.name IN ('platform_owner', 'platform_admin', 'platform_support')
    ) OR EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'superadmin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.is_platform_owner()
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM public.user_platform_roles upr
        JOIN public.platform_roles pr ON pr.id = upr.platform_role_id
        WHERE upr.user_id = auth.uid() 
          AND pr.name = 'platform_owner'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS uuid AS $$
DECLARE
    user_sec_school uuid;
BEGIN
    -- Primero verificar si hay una membresía activa
    SELECT tm.school_id INTO user_sec_school
    FROM public.tenant_memberships tm
    WHERE tm.user_id = auth.uid() AND tm.is_active = true
    LIMIT 1;

    IF user_sec_school IS NOT NULL THEN
        RETURN user_sec_school;
    END IF;

    -- Respaldo a profiles.school_id
    SELECT p.school_id INTO user_sec_school
    FROM public.profiles p
    WHERE p.id = auth.uid();

    RETURN user_sec_school;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.has_tenant_permission(perm_code text)
RETURNS boolean AS $$
BEGIN
    -- Un platform admin siempre tiene permiso
    IF public.is_platform_admin() THEN
        RETURN true;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM public.tenant_memberships tm
        JOIN public.role_permissions rp ON rp.tenant_role_id = tm.tenant_role_id
        JOIN public.permissions p ON p.id = rp.permission_id
        WHERE tm.user_id = auth.uid()
          AND tm.is_active = true
          AND p.code = perm_code
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
