-- ====================================================================
-- MIGRATION: 08_tenant_lifecycle_plans.sql
-- PURPOSE: FASE 3 (Estados de Institución) y FASE 8 (Planes y Suscripciones)
-- Extiende la tabla schools con metadatos institucionales y ciclo de vida SaaS.
-- ====================================================================

-- 1. TENANT STATUS TYPE ENUM
DO $$ BEGIN
    CREATE TYPE public.tenant_status_type AS ENUM (
        'trial',
        'active',
        'past_due',
        'grace_period',
        'suspended',
        'cancelled',
        'archived'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 2. EXTENDER TABLA SCHOOLS (TENANTS)
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS code text;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS trade_name text;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS country text DEFAULT 'Ecuador';
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS province text;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS city text;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS timezone text DEFAULT 'America/Guayaquil';
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS status public.tenant_status_type DEFAULT 'active' NOT NULL;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS suspended_reason text;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS suspended_at timestamptz;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS suspended_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT timezone('utc'::text, now());

-- Sincronizar campo legacy is_active con status
UPDATE public.schools SET status = 'active' WHERE is_active = true AND status IS NULL;
UPDATE public.schools SET status = 'suspended' WHERE is_active = false AND status IS NULL;

-- 3. HISTORIAL DE ESTADOS DE LA INSTITUCIÓN
CREATE TABLE IF NOT EXISTS public.tenant_status_logs (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    previous_status public.tenant_status_type,
    new_status public.tenant_status_type NOT NULL,
    reason text,
    observation text,
    actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. PLANS TABLE
CREATE TABLE IF NOT EXISTS public.plans (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    name text NOT NULL,
    code text UNIQUE NOT NULL,
    price decimal(10,2) NOT NULL DEFAULT 0.00,
    currency text DEFAULT 'USD' NOT NULL,
    billing_interval text CHECK (billing_interval IN ('monthly', 'yearly')) DEFAULT 'monthly' NOT NULL,
    limits jsonb DEFAULT '{}'::jsonb NOT NULL,
    features jsonb DEFAULT '{}'::jsonb NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

INSERT INTO public.plans (name, code, price, currency, billing_interval, limits, features) VALUES
('Plan Prueba', 'trial', 0.00, 'USD', 'monthly', '{"max_users": 10, "max_teachers": 5, "max_students": 100, "storage_mb": 2048}'::jsonb, '{"grades": true, "attendance": true, "reports": true}'::jsonb),
('Plan Básico', 'basic', 29.99, 'USD', 'monthly', '{"max_users": 25, "max_teachers": 15, "max_students": 300, "storage_mb": 5120}'::jsonb, '{"grades": true, "attendance": true, "reports": true, "alerts": true}'::jsonb),
('Plan Profesional', 'pro', 79.99, 'USD', 'monthly', '{"max_users": 100, "max_teachers": 50, "max_students": 1500, "storage_mb": 20480}'::jsonb, '{"grades": true, "attendance": true, "reports": true, "alerts": true, "projects": true, "pdf_advanced": true}'::jsonb),
('Plan Enterprise', 'enterprise', 199.99, 'USD', 'monthly', '{"max_users": 1000, "max_teachers": 500, "max_students": 10000, "storage_mb": 102400}'::jsonb, '{"grades": true, "attendance": true, "reports": true, "alerts": true, "projects": true, "pdf_advanced": true, "ai": true, "api": true}'::jsonb)
ON CONFLICT (code) DO NOTHING;

-- 5. SUBSCRIPTIONS TABLE
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE UNIQUE NOT NULL,
    plan_id uuid REFERENCES public.plans(id) ON DELETE RESTRICT NOT NULL,
    status public.tenant_status_type DEFAULT 'active' NOT NULL,
    started_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
    next_billing_date timestamptz,
    grace_period_until timestamptz,
    cancelled_at timestamptz,
    created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Asignar plan por defecto a escuelas existentes
DO $$
DECLARE
    pro_plan_id uuid;
    sch_rec RECORD;
BEGIN
    SELECT id INTO pro_plan_id FROM public.plans WHERE code = 'pro';
    IF pro_plan_id IS NOT NULL THEN
        FOR sch_rec IN SELECT id FROM public.schools LOOP
            INSERT INTO public.subscriptions (school_id, plan_id, status, started_at)
            VALUES (sch_rec.id, pro_plan_id, 'active', now())
            ON CONFLICT (school_id) DO NOTHING;
        END LOOP;
    END IF;
END $$;

-- 6. PAYMENTS TABLE
CREATE TABLE IF NOT EXISTS public.payments (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    subscription_id uuid REFERENCES public.subscriptions(id) ON DELETE SET NULL,
    amount decimal(10,2) NOT NULL,
    currency text DEFAULT 'USD' NOT NULL,
    provider text DEFAULT 'manual' NOT NULL, -- manual, stripe, paypal, transfer, etc.
    provider_reference text,
    status text CHECK (status IN ('pending', 'completed', 'failed', 'refunded')) DEFAULT 'completed' NOT NULL,
    paid_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. RPC TRANSACCIONAL PARA WIZARD DE ALTA DE INSTITUCIÓN (FASE 6)
CREATE OR REPLACE FUNCTION public.provision_tenant_wizard(
    p_name text,
    p_trade_name text,
    p_code text,
    p_country text,
    p_province text,
    p_city text,
    p_timezone text,
    p_admin_name text,
    p_admin_email text,
    p_admin_phone text,
    p_plan_id uuid,
    p_billing_cycle text,
    p_price decimal
)
RETURNS json AS $$
DECLARE
    new_school_id uuid;
    admin_user_id uuid;
    admin_tenant_role_id uuid;
    new_sub_id uuid;
BEGIN
    -- Validar que solo un Platform Admin puede ejecutar el provisioning
    IF NOT public.is_platform_admin() THEN
        RETURN json_build_object('success', false, 'message', 'Acceso denegado: Se requiere rol de Platform Admin.');
    END IF;

    -- 1. Crear Escuela / Tenant
    INSERT INTO public.schools (name, trade_name, code, country, province, city, timezone, status, is_active)
    VALUES (
        p_name, 
        COALESCE(p_trade_name, p_name), 
        p_code, 
        COALESCE(p_country, 'Ecuador'), 
        p_province, 
        p_city, 
        COALESCE(p_timezone, 'America/Guayaquil'), 
        'active', 
        true
    )
    RETURNING id INTO new_school_id;

    -- 2. Buscar si el usuario admin ya existe por su email en profiles
    SELECT id INTO admin_user_id FROM public.profiles WHERE lower(email) = lower(p_admin_email);

    -- Si no existe en profiles, crearemos su perfil placeholder para vincularlo cuando cree su contraseña
    -- O si ya existe en auth.users
    IF admin_user_id IS NULL THEN
        SELECT id INTO admin_user_id FROM auth.users WHERE lower(email) = lower(p_admin_email);
    END IF;

    -- Si se encontró usuario, asignarle rol de colegio
    SELECT id INTO admin_tenant_role_id FROM public.tenant_roles WHERE name = 'school_admin';
    
    IF admin_user_id IS NOT NULL AND admin_tenant_role_id IS NOT NULL THEN
        UPDATE public.profiles SET school_id = new_school_id, role = 'admin' WHERE id = admin_user_id;
        
        INSERT INTO public.tenant_memberships (user_id, school_id, tenant_role_id)
        VALUES (admin_user_id, new_school_id, admin_tenant_role_id)
        ON CONFLICT (user_id, school_id) DO UPDATE SET is_active = true;
    END IF;

    -- 3. Crear Suscripción
    INSERT INTO public.subscriptions (school_id, plan_id, status, started_at, next_billing_date)
    VALUES (
        new_school_id, 
        p_plan_id, 
        'active', 
        now(), 
        CASE WHEN p_billing_cycle = 'yearly' THEN now() + interval '1 year' ELSE now() + interval '1 month' END
    )
    RETURNING id INTO new_sub_id;

    -- 4. Registrar Primer Pago Inicial si aplica
    IF p_price > 0 THEN
        INSERT INTO public.payments (school_id, subscription_id, amount, currency, provider, status, paid_at)
        VALUES (new_school_id, new_sub_id, p_price, 'USD', 'manual', 'completed', now());
    END IF;

    -- 5. Registrar en tenant_status_logs
    INSERT INTO public.tenant_status_logs (school_id, previous_status, new_status, reason, observation, actor_id)
    VALUES (new_school_id, NULL, 'active', 'Alta de Institución (Wizard)', 'Provisioning inicial completado', auth.uid());

    RETURN json_build_object(
        'success', true, 
        'message', 'Institución provisionada exitosamente.',
        'school_id', new_school_id,
        'admin_registered', (admin_user_id IS NOT NULL)
    );
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', 'Error en el provisioning: ' || SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
