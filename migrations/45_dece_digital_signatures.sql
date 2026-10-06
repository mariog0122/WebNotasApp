-- Migration 45: Add digital signature support to student_alerts
ALTER TABLE public.student_alerts ADD COLUMN IF NOT EXISTS is_digitally_signed BOOLEAN DEFAULT false;
ALTER TABLE public.student_alerts ADD COLUMN IF NOT EXISTS signature_data JSONB;
ALTER TABLE public.student_alerts ADD COLUMN IF NOT EXISTS signed_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.student_alerts ADD COLUMN IF NOT EXISTS signed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
