-- ====================================================================
-- MIGRATION: 20260810195500_fix_tenant_memberships_profiles_fk.sql
-- PURPOSE: Añadir FK de tenant_memberships(user_id) a public.profiles(id)
-- para permitir relaciones anidadas nativas en PostgREST / Supabase API.
-- ====================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'tenant_memberships_user_id_profiles_fkey'
          AND table_name = 'tenant_memberships'
          AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.tenant_memberships
        ADD CONSTRAINT tenant_memberships_user_id_profiles_fkey
        FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
    END IF;
END $$;
