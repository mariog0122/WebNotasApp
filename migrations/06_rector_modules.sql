-- ====================================================================
-- MIGRATION: 06_rector_modules.sql
-- PURPOSE: Adds support for School Configuration (Multi-tenant system_config)
-- and provides a secure RPC for Rectors to invite/link newly registered teachers.
-- ====================================================================

-- 1. SYSTEM_CONFIG MULTI-TENANCY
-- Drop existing primary key on 'key'
ALTER TABLE public.system_config DROP CONSTRAINT IF EXISTS system_config_pkey CASCADE;

-- Add a composite primary key to allow the same key for multiple schools
ALTER TABLE public.system_config ADD PRIMARY KEY (school_id, key);

-- Drop old RLS policy for system_config writes to allow Admins to edit their own school config
DROP POLICY IF EXISTS "Admins only write" ON public.system_config;
CREATE POLICY "Admins only write their own school config" ON public.system_config
  FOR ALL
  USING (
    public.is_admin() AND school_id = public.get_user_school_id()
  );

-- 2. SECURE RPC TO LINK TEACHERS
CREATE OR REPLACE FUNCTION public.invite_teacher_by_email(teacher_email text)
RETURNS json AS $$
DECLARE
  target_profile record;
  rector_school_id uuid;
BEGIN
  -- Ensure caller is admin
  IF NOT public.is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Solo los administradores pueden invitar profesores.');
  END IF;

  -- Get rector's school_id
  SELECT school_id INTO rector_school_id FROM public.profiles WHERE id = auth.uid();
  IF rector_school_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'El administrador no tiene un colegio asignado.');
  END IF;

  -- Find the profile by email
  SELECT * INTO target_profile FROM public.profiles WHERE email = teacher_email;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'No se encontró ningún usuario con ese correo electrónico. Asegúrate de que el profesor ya se haya registrado.');
  END IF;

  IF target_profile.school_id IS NOT NULL THEN
    -- if it's already in the rector's school
    IF target_profile.school_id = rector_school_id THEN
      RETURN json_build_object('success', false, 'message', 'El profesor ya pertenece a tu colegio.');
    ELSE
      RETURN json_build_object('success', false, 'message', 'El usuario ya pertenece a otro colegio.');
    END IF;
  END IF;

  -- Update profile
  UPDATE public.profiles 
  SET school_id = rector_school_id, role = 'teacher' 
  WHERE id = target_profile.id;

  RETURN json_build_object('success', true, 'message', 'Profesor vinculado exitosamente al colegio.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
