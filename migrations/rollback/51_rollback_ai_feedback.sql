-- ==============================================================================
-- ROLLBACK MIGRACIÓN 51: REVERTIR SISTEMA DE FEEDBACK Y MEMORIA DE IA
-- ==============================================================================

BEGIN;

DROP FUNCTION IF EXISTS public.review_quarantine_item(uuid, text, text, text);
DROP FUNCTION IF EXISTS public.get_institutional_ai_context(uuid, text, text, text);
DROP FUNCTION IF EXISTS public.submit_ai_feedback(uuid, text, uuid, text, int, text, text[], text, jsonb);

DROP TABLE IF EXISTS public.ai_audit_events CASCADE;
DROP TABLE IF EXISTS public.ai_evaluation_runs CASCADE;
DROP TABLE IF EXISTS public.ai_institutional_memory CASCADE;
DROP TABLE IF EXISTS public.ai_knowledge_quarantine CASCADE;
DROP TABLE IF EXISTS public.ai_feedback_logs CASCADE;

COMMIT;
