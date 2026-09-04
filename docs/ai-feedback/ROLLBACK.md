# ROLLBACK: Procedimiento de Reversión Segura e Inmediata

**Fecha:** 2026-09-03  
**Proyecto:** LOGREVA (WebNotasApp)  

---

## 1. Escenarios de Reversión

### Escenario A: Desactivación Inmediata Sin Redespliegue (Zero-Downtime Feature Flag)
Si se desea desactivar la recolección de feedback o la memoria RAG sin necesidad de hacer un nuevo despliegue de código:
1. Conectar a PostgreSQL / Supabase.
2. Desactivar el feature flag a nivel de tenant o global:
   ```sql
   UPDATE public.tenant_features
   SET enabled = false
   WHERE feature_key = 'ai_feedback';
   ```
3. El frontend y el gateway automáticamente omitirán la inyección de memoria institucional y la recolección de retroalimentación sin generar ningún error al usuario.

---

### Escenario B: Reversión de Memoria o Prompt Específico (Rollback Lógico)
Si un lineamiento institucional o ejemplo dorado promovido a `ai_institutional_memory` introduce un estilo no deseado:
1. Identificar el `id` del registro en `ai_institutional_memory`.
2. Desactivarlo o restaurar su versión anterior:
   ```sql
   UPDATE public.ai_institutional_memory
   SET is_active = false, updated_at = now()
   WHERE id = '<MEMORY_UUID>';
   ```
3. Para prompts del sistema versionados, invocar en código o consola:
   ```js
   PromptRegistry.rollbackVersion('planning-generator', 1)
   ```

---

### Escenario C: Rollback Completo de Base de Datos
Si se requiere eliminar por completo las nuevas tablas creadas en la migración 51:
```bash
psql -h <SUPABASE_HOST> -U postgres -d postgres -f migrations/rollback/51_rollback_ai_feedback.sql
```
*Nota: Este script elimina exclusivamente las tablas `ai_feedback_logs`, `ai_knowledge_quarantine`, `ai_institutional_memory`, `ai_evaluation_runs` y `ai_audit_events`. Las tablas preexistentes de la plataforma (`lesson_plans`, `courses`, `schools`, etc.) NO se ven afectadas en absoluto.*
