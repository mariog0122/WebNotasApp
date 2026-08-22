-- Migration 30: Añadir tutor_name a la tabla de cursos
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS tutor_name text;
