-- Migration: 20260810210000_add_receipt_url_to_payments.sql
-- Description: Add receipt_url to payments and tenant_billing_profiles for payment voucher verification

ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS receipt_url text;
ALTER TABLE public.tenant_billing_profiles ADD COLUMN IF NOT EXISTS latest_receipt_url text;

-- Bucket for payment proofs and invoice vouchers
INSERT INTO storage.buckets (id, name, public)
VALUES ('billing-proofs', 'billing-proofs', true)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Authenticated users can upload billing proofs' AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Authenticated users can upload billing proofs"
        ON storage.objects FOR INSERT TO authenticated
        WITH CHECK (bucket_id = 'billing-proofs');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Authenticated users can view billing proofs' AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Authenticated users can view billing proofs"
        ON storage.objects FOR SELECT TO authenticated
        USING (bucket_id = 'billing-proofs');
    END IF;
END $$;

-- RPC to upload payment proof by tenant or superadmin
CREATE OR REPLACE FUNCTION public.upload_tenant_payment_proof(
    p_school_id uuid,
    p_receipt_url text,
    p_notes text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_subscription_id uuid;
    v_sub_price numeric;
BEGIN
    IF NOT (public.is_platform_admin() OR (public.get_user_school_id() = p_school_id AND public.has_tenant_permission('billing.manage'))) THEN
        RETURN json_build_object('success', false, 'message', 'Acceso denegado para esta institución.');
    END IF;

    IF nullif(trim(p_receipt_url), '') IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Se requiere la URL o foto del comprobante.');
    END IF;

    SELECT id, agreed_price INTO v_subscription_id, v_sub_price
    FROM public.subscriptions
    WHERE school_id = p_school_id
    LIMIT 1;

    INSERT INTO public.tenant_billing_profiles (school_id, latest_receipt_url, updated_at)
    VALUES (p_school_id, trim(p_receipt_url), timezone('utc'::text, now()))
    ON CONFLICT (school_id) DO UPDATE
    SET latest_receipt_url = EXCLUDED.latest_receipt_url,
        updated_at = timezone('utc'::text, now());

    INSERT INTO public.payments (
        school_id, subscription_id, amount, currency, provider,
        status, paid_at, payment_type, notes, receipt_url, recorded_by
    ) VALUES (
        p_school_id, v_subscription_id, COALESCE(v_sub_price, 0), 'USD', 'transfer',
        'pending', timezone('utc'::text, now()), 'subscription',
        nullif(trim(p_notes), ''), trim(p_receipt_url), auth.uid()
    );

    RETURN json_build_object('success', true, 'message', 'Comprobante de factura/transferencia registrado exitosamente.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.upload_tenant_payment_proof(uuid, text, text) TO authenticated;
