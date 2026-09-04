# DEPLOYMENT: Guía de Despliegue a Producción

**Fecha:** 2026-09-03  
**Proyecto:** LOGREVA (WebNotasApp)  

---

## 1. Orden de Ejecución Pre-Flight

1. **Paso 1: Aplicación de Migración de Base de Datos en Supabase / PostgreSQL**:
   Ejecutar el script SQL en la consola de Supabase o CLI:
   ```bash
   psql -h <SUPABASE_HOST> -U postgres -d postgres -f migrations/51_ai_feedback_and_institutional_memory.sql
   ```
   *Verificar que se hayan creado las 5 tablas (`ai_feedback_logs`, `ai_knowledge_quarantine`, `ai_institutional_memory`, `ai_evaluation_runs`, `ai_audit_events`) y las 3 funciones RPC (`submit_ai_feedback`, `get_institutional_ai_context`, `review_quarantine_item`).*

2. **Paso 2: Verificación de Políticas RLS**:
   Ejecutar consulta de control:
   ```sql
   SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE 'ai_%';
   ```
   *Todas deben retornar `rowsecurity = true`.*

3. **Paso 3: Compilación y Despliegue de Frontend**:
   ```bash
   cd app
   npm run build
   ```
   *El bundle optimizado se genera en `app/dist/`.*

4. **Paso 4: Smoke Test Post-Despliegue**:
   - Iniciar sesión como docente.
   - Abrir una planificación didáctica generada y presionar `👍 Útil`.
   - Verificar en `ai_feedback_logs` que se haya creado el registro con `rating = 5` y `status = 'received'`.
   - Abrir como SuperAdmin la pestaña `AI Improvement Center` en `/superadmin` y verificar que las métricas carguen correctamente.
