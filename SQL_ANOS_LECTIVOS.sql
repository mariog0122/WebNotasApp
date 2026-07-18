-- ============================================
-- MODULO: Anos Lectivos
-- Tabla: academic_years
-- ============================================

-- Tabla de anos lectivos
CREATE TABLE IF NOT EXISTS academic_years (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    start_year INTEGER NOT NULL,
    end_year INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT false NOT NULL,
    is_current BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE academic_years IS 'Anos lectivos (ej: 2024-2025, 2025-2026)';
COMMENT ON COLUMN academic_years.name IS 'Nombre del ano lectivo';
COMMENT ON COLUMN academic_years.start_year IS 'Ano de inicio';
COMMENT ON COLUMN academic_years.end_year IS 'Ano de fin';
COMMENT ON COLUMN academic_years.is_active IS 'Si esta activo para calificaciones';
COMMENT ON COLUMN academic_years.is_current IS 'Si es el ano lectivo actual/principal';

-- Index
CREATE INDEX IF NOT EXISTS idx_academic_years_active ON academic_years(is_active);
CREATE INDEX IF NOT EXISTS idx_academic_years_current ON academic_years(is_current);

-- Anos lectivos por defecto (ejecutar solo si no existen)
INSERT INTO academic_years (name, start_year, end_year, is_active, is_current)
VALUES
    ('2024-2025', 2024, 2025, true, true),
    ('2025-2026', 2025, 2026, false, false)
ON CONFLICT (name) DO NOTHING;

-- ============================================
-- FUNCION: Obtener ano lectivo actual
-- ============================================
CREATE OR REPLACE FUNCTION get_current_academic_year()
RETURNS academic_years AS $$
BEGIN
    RETURN (SELECT * FROM academic_years WHERE is_current = true LIMIT 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCION: Copiar cursos a nuevo ano lectivo
-- ============================================
CREATE OR REPLACE FUNCTION copy_courses_to_academic_year(
    source_year_id UUID,
    target_year_id UUID,
    include_subjects BOOLEAN DEFAULT true
)
RETURNS TABLE(new_course_id UUID, original_course_id UUID, course_name TEXT) AS $$
DECLARE
    source_year academic_years;
    target_year academic_years;
    new_course_id UUID;
    old_course_id UUID;
    cs_record RECORD;
    new_cs_id UUID;
BEGIN
    -- Obtener anos
    SELECT * INTO source_year FROM academic_years WHERE id = source_year_id;
    SELECT * INTO target_year FROM academic_years WHERE id = target_year_id;

    IF source_year IS NULL THEN
        RAISE EXCEPTION 'Ano lectivo fuente no encontrado';
    END IF;

    IF target_year IS NULL THEN
        RAISE EXCEPTION 'Ano lectivo destino no encontrado';
    END IF;

    -- Copiar cada curso
    FOR cs_record IN
        SELECT c.* FROM courses c
        WHERE c.academic_year = source_year.name
    LOOP
        old_course_id := cs_record.id;

        -- Crear nuevo curso
        INSERT INTO courses (name, academic_year, level, track)
        VALUES (cs_record.name, target_year.name, cs_record.level, cs_record.track)
        RETURNING id INTO new_course_id;

        RETURN QUERY SELECT new_course_id, old_course_id, cs_record.name;

        -- Copiar materias del curso si se solicito
        IF include_subjects THEN
            INSERT INTO course_subjects (course_id, subject_id)
            SELECT new_course_id, subject_id
            FROM course_subjects
            WHERE course_id = old_course_id;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCION: Obtener anos lectivos disponibles
-- ============================================
CREATE OR REPLACE FUNCTION get_academic_years_list()
RETURNS TABLE(
    id UUID,
    name TEXT,
    start_year INTEGER,
    end_year INTEGER,
    is_active BOOLEAN,
    is_current BOOLEAN,
    courses_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ay.id,
        ay.name,
        ay.start_year,
        ay.end_year,
        ay.is_active,
        ay.is_current,
        COUNT(c.id)::BIGINT as courses_count
    FROM academic_years ay
    LEFT JOIN courses c ON c.academic_year = ay.name
    GROUP BY ay.id, ay.name, ay.start_year, ay.end_year, ay.is_active, ay.is_current
    ORDER BY ay.start_year DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- RLS para academic_years
-- ============================================
ALTER TABLE academic_years ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "academic_years_all_auth" ON academic_years;
CREATE POLICY "academic_years_all_auth" ON academic_years
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "academic_years_admin_cud" ON academic_years;
CREATE POLICY "academic_years_admin_cud" ON academic_years
    FOR ALL USING (is_admin());
