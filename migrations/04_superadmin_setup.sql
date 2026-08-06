-- ====================================================================
-- MIGRATION: 04_superadmin_setup.sql
-- PURPOSE: Create 'superadmin' role and permissions.
-- ====================================================================

-- 1. Modify the role check constraint on the profiles table
-- Attempt to drop the default constraint name and any common variations
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS check_role;

-- Add the new constraint allowing 'superadmin'
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check CHECK (role IN ('admin', 'teacher', 'superadmin'));

-- 2. Create the is_superadmin() helper function
CREATE OR REPLACE FUNCTION public.is_superadmin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'superadmin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Update Schools RLS Policies for superadmin
-- We previously had "Isolate reads by school" on schools. We need to allow superadmins to see and edit ALL schools.
DROP POLICY IF EXISTS "Superadmin full access schools" ON public.schools;
CREATE POLICY "Superadmin full access schools" ON public.schools FOR ALL USING (public.is_superadmin());

-- 4. Update Profiles RLS Policies for superadmin
-- Superadmins need to be able to see all profiles to assign them to schools and change their roles.
DROP POLICY IF EXISTS "Superadmin full access profiles" ON public.profiles;
CREATE POLICY "Superadmin full access profiles" ON public.profiles FOR ALL USING (public.is_superadmin());

-- 5. Promote admin@webnotas.com to superadmin
DO $$
DECLARE
  target_user_id uuid;
BEGIN
  SELECT id INTO target_user_id FROM public.profiles WHERE email = 'admin@webnotas.com' LIMIT 1;
  
  IF target_user_id IS NOT NULL THEN
    UPDATE public.profiles SET role = 'superadmin' WHERE id = target_user_id;
  END IF;
END
$$;
