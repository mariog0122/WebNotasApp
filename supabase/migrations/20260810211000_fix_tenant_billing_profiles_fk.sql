-- Migration: 20260810211000_fix_tenant_billing_profiles_fk.sql
-- Description: Ensure tenant_billing_profiles table and FK relationship to schools exist cleanly

CREATE TABLE IF NOT EXISTS public.tenant_billing_profiles (
    school_id uuid PRIMARY KEY REFERENCES public.schools(id) ON DELETE CASCADE,
    implementation_fee_status text DEFAULT 'pending',
    implementation_fee_paid_at timestamptz,
    implementation_fee_payment_id uuid REFERENCES public.payments(id) ON DELETE SET NULL,
    latest_receipt_url text,
    created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.tenant_billing_profiles ADD COLUMN IF NOT EXISTS latest_receipt_url text;

ALTER TABLE public.tenant_billing_profiles ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Platform billing profiles' AND tablename = 'tenant_billing_profiles'
    ) THEN
        CREATE POLICY "Platform billing profiles" ON public.tenant_billing_profiles
        FOR ALL TO authenticated
        USING (public.is_platform_admin());
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Tenant reads own billing profile' AND tablename = 'tenant_billing_profiles'
    ) THEN
        CREATE POLICY "Tenant reads own billing profile" ON public.tenant_billing_profiles
        FOR SELECT TO authenticated
        USING (school_id = public.get_user_school_id());
    END IF;
END $$;

GRANT ALL ON TABLE public.tenant_billing_profiles TO authenticated;
