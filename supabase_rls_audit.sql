-- ==============================================================================
-- WEBNOTAS - Supabase Row Level Security (RLS) Audit & Fix Script
-- ==============================================================================

-- 1. Habilitar RLS en todas las tablas importantes si no están activadas ya
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qualitative_grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.institution_config ENABLE ROW LEVEL SECURITY;

-- 2. Eliminar políticas inseguras antiguas (opcional, si existen)
-- DROP POLICY IF EXISTS "Public read" ON public.students;
-- DROP POLICY IF EXISTS "Public write" ON public.students;

-- 3. Crear políticas para la tabla STUDENTS
-- Permitir solo a usuarios AUTENTICADOS leer y modificar estudiantes
CREATE POLICY "Autenticados pueden ver estudiantes" 
ON public.students FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "Autenticados pueden insertar estudiantes" 
ON public.students FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY "Autenticados pueden actualizar estudiantes" 
ON public.students FOR UPDATE 
TO authenticated 
USING (true)
WITH CHECK (true);

CREATE POLICY "Autenticados pueden eliminar estudiantes" 
ON public.students FOR DELETE 
TO authenticated 
USING (true);


-- 4. Crear políticas para la tabla COURSES
CREATE POLICY "Autenticados pueden ver cursos" 
ON public.courses FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "Autenticados pueden gestionar cursos" 
ON public.courses FOR ALL 
TO authenticated 
USING (true)
WITH CHECK (true);


-- 5. Crear políticas para las CALIFICACIONES (GRADES)
-- Nota: En un escenario multi-profesor (tenant_id), aquí añadiríamos: "USING (auth.uid() = user_id)"
-- Dado que actualmente la plataforma es para una institución, aseguramos que al menos estén logueados.
CREATE POLICY "Autenticados pueden ver notas" 
ON public.grades FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "Autenticados pueden modificar notas" 
ON public.grades FOR ALL 
TO authenticated 
USING (true)
WITH CHECK (true);


-- 6. Crear políticas para la CONFIGURACIÓN (INSTITUTION_CONFIG)
-- La configuración la puede leer incluso un usuario anónimo (para cargar logos, nombres antes del login)
CREATE POLICY "Cualquiera puede leer config" 
ON public.institution_config FOR SELECT 
TO public 
USING (true);

CREATE POLICY "Autenticados pueden modificar config" 
ON public.institution_config FOR ALL 
TO authenticated 
USING (true)
WITH CHECK (true);

-- ==============================================================================
-- INSTRUCCIONES:
-- 1. Ve a tu panel de Supabase.
-- 2. Abre el "SQL Editor".
-- 3. Pega este código y dale a "Run".
-- 4. A partir de ahora, nadie podrá acceder a la base de datos sin un token válido de login.
-- ==============================================================================
