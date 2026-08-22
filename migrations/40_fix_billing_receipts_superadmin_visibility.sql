-- ==============================================================================
-- MIGRACIÓN 40: Visibilidad y Acceso a Comprobantes de Factura/Pago para Superadmin
-- ==============================================================================
-- 1. Asegura que el bucket de almacenamiento 'billing-proofs' sea público y accesible.
-- 2. Actualiza las políticas RLS en 'tenant_billing_profiles' para que el Superadmin
--    pueda consultar y visualizar todos los comprobantes cargados por las instituciones.
-- 3. Mejora 'upload_tenant_payment_proof' para que administradores de colegio puedan
--    subir comprobantes sin bloqueos de permisos.

BEGIN;

-- 1. Asegurar bucket de almacenamiento 'billing-proofs' como público
INSERT INTO storage.buckets (id, name, public)
VALUES ('billing-proofs', 'billing-proofs', true)
ON CONFLICT (id) DO UPDATE
SET public = true;

-- 2. Políticas RLS en storage.objects para 'billing-proofs'
DROP POLICY IF EXISTS "Authenticated users can upload billing proofs" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can view billing proofs" ON storage.objects;
DROP POLICY IF EXISTS "Public view for billing proofs" ON storage.objects;
DROP POLICY IF EXISTS "Allow upload billing proofs" ON storage.objects;

CREATE POLICY "Public view for billing proofs"
ON storage.objects FOR SELECT
USING (bucket_id = 'billing-proofs');

CREATE POLICY "Allow upload billing proofs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'billing-proofs');

CREATE POLICY "Allow update billing proofs"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'billing-proofs');

-- 3. Actualizar políticas RLS en public.tenant_billing_profiles
ALTER TABLE public.tenant_billing_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Billing profiles readable by authorized users" ON public.tenant_billing_profiles;
DROP POLICY IF EXISTS "Platform billing profiles" ON public.tenant_billing_profiles;
DROP POLICY IF EXISTS "Tenant reads own billing profile" ON public.tenant_billing_profiles;
DROP POLICY IF EXISTS "Platform inserts billing profiles" ON public.tenant_billing_profiles;
DROP POLICY IF EXISTS "Platform updates billing profiles" ON public.tenant_billing_profiles;
DROP POLICY IF EXISTS "Platform deletes billing profiles" ON public.tenant_billing_profiles;

-- Política de lectura para Superadmins y miembros de la institución
CREATE POLICY "Billing profiles readable by authorized users"
ON public.tenant_billing_profiles FOR SELECT
TO authenticated
USING (
  public.is_platform_admin()
  OR public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance'])
  OR school_id = public.get_user_school_id()
  OR EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() 
      AND (school_id = tenant_billing_profiles.school_id OR role = 'superadmin')
  )
);

-- Política de inserción
CREATE POLICY "Billing profiles insertable by authorized users"
ON public.tenant_billing_profiles FOR INSERT
TO authenticated
WITH CHECK (
  public.is_platform_admin()
  OR public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance'])
  OR school_id = public.get_user_school_id()
  OR EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() 
      AND (school_id = tenant_billing_profiles.school_id OR role IN ('superadmin', 'admin', 'school_admin', 'rector'))
  )
);

-- Política de actualización
CREATE POLICY "Billing profiles updatable by authorized users"
ON public.tenant_billing_profiles FOR UPDATE
TO authenticated
USING (
  public.is_platform_admin()
  OR public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance'])
  OR school_id = public.get_user_school_id()
  OR EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() 
      AND (school_id = tenant_billing_profiles.school_id OR role IN ('superadmin', 'admin', 'school_admin', 'rector'))
  )
);

GRANT SELECT, INSERT, UPDATE ON TABLE public.tenant_billing_profiles TO authenticated;

-- 4. Actualizar función upload_tenant_payment_proof con permisos flexibles
CREATE OR REPLACE FUNCTION public.upload_tenant_payment_proof(
    p_school_id uuid,
    p_receipt_url text,
    p_notes text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE
    v_clean_url text;
    v_payment_id uuid;
    v_user_role text;
BEGIN
    SELECT role INTO v_user_role FROM public.profiles WHERE id = auth.uid();

    IF NOT (
        public.is_platform_admin()
        OR public.has_platform_role(array['platform_owner', 'platform_admin', 'platform_finance'])
        OR public.get_user_school_id() = p_school_id
        OR v_user_role IN ('superadmin', 'admin', 'school_admin', 'rector')
        OR EXISTS (SELECT 1 FROM public.tenant_memberships WHERE user_id = auth.uid() AND school_id = p_school_id AND is_active)
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Acceso denegado para registrar comprobante en esta institución.');
    END IF;

    v_clean_url := nullif(trim(p_receipt_url), '');
    IF v_clean_url IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Se requiere la URL o foto del comprobante.');
    END IF;

    -- Registrar o actualizar perfil de facturación
    INSERT INTO public.tenant_billing_profiles (school_id, latest_receipt_url, updated_at)
    VALUES (p_school_id, v_clean_url, timezone('utc'::text, now()))
    ON CONFLICT (school_id) DO UPDATE
    SET latest_receipt_url = EXCLUDED.latest_receipt_url,
        updated_at = timezone('utc'::text, now());

    -- Registrar pago en estado pendiente
    INSERT INTO public.payments (
        school_id, amount, currency, provider,
        status, paid_at, payment_type, notes, receipt_url, recorded_by
    ) VALUES (
        p_school_id, 0, 'USD', 'transfer',
        'pending', timezone('utc'::text, now()), 'subscription',
        COALESCE(nullif(trim(p_notes), ''), 'Comprobante subido por la institución'),
        v_clean_url, auth.uid()
    ) RETURNING id INTO v_payment_id;

    RETURN json_build_object(
        'success', true, 
        'message', 'Comprobante de pago registrado exitosamente.',
        'payment_id', v_payment_id,
        'receipt_url', v_clean_url
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.upload_tenant_payment_proof(uuid, text, text) TO authenticated, service_role;

-- 5. Recargar caché de PostgREST
NOTIFY pgrst, 'reload schema';

COMMIT;
