-- =============================================================================
-- Migración 50: Adaptaciones Curriculares en Ficha de Estudiantes y Recuperación IA
-- =============================================================================

-- 1. Agregar columnas de adaptación curricular a la tabla public.students
ALTER TABLE public.students 
ADD COLUMN IF NOT EXISTS has_adaptation boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS adaptation_grade text DEFAULT '1', -- '1', '2', '3'
ADD COLUMN IF NOT EXISTS adaptation_type text DEFAULT '',
ADD COLUMN IF NOT EXISTS adaptation_details text DEFAULT '';

-- 2. Índice para consultas rápidas de adaptaciones por curso
CREATE INDEX IF NOT EXISTS idx_students_adaptation ON public.students(course_id, has_adaptation) WHERE has_adaptation = true;

-- 3. Comentarios informativos de columnas
COMMENT ON COLUMN public.students.has_adaptation IS 'Indica si el estudiante requiere Adaptación Curricular formal (NEE / DUA)';
COMMENT ON COLUMN public.students.adaptation_grade IS 'Grado de adaptación curricular según normativa MinEduc: 1 (Acceso), 2 (No significativa), 3 (Significativa)';
COMMENT ON COLUMN public.students.adaptation_details IS 'Detalle o especificaciones pedagógicas de la adaptación requerida para el estudiante';
