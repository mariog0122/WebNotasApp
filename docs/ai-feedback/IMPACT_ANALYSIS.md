# IMPACT ANALYSIS: Sistema Seguro de Retroalimentación y Mejora Continua de IA

**Fecha:** 2026-09-03  
**Proyecto:** LOGREVA (WebNotasApp)  

---

## 1. Archivos que se Modificarán (Extendiendo sin Romper)

| Archivo | Motivo de la Modificación | Estrategia de Mitigación / No Ruptura |
|---|---|---|
| `app/src/lib/ai/types.js` | Agregar constantes y enums de feedback (`AI_FEEDBACK_CATEGORIES`, `AI_FEEDBACK_STATUSES`, `AI_KNOWLEDGE_SCOPES`, `AI_EVALUATION_METRICS`). | Solo adición de exports inmutables (`Object.freeze`). Cero cambios sobre las constantes preexistentes. |
| `app/src/lib/ai/EducationAIGateway.js` | Enlazar `AIPrivacySanitizer`, `AIContextBuilder` y nuevo método `submitFeedback`. | Los métodos existentes `generatePlan`, `regenerateSection`, etc., conservan sus firmas y parámetros exactamente iguales. La inyección de memoria institucional se realiza como un bloque contextual aditivo y seguro. |
| `app/src/composables/useAIPlanning.js` | Añadir estado y handlers para feedback modal (`showFeedbackModal`, `submitPlanFeedback`, `capturePlanDiff`). | Los métodos actuales de carga de planes, guardado de versiones y exportación siguen funcionando sin alteraciones. |
| `app/src/components/planning/PlanningDocumentViewer.vue` | Incorporar botones discretos de feedback (`FeedbackActionButtons.vue`) en barra superior y secciones, y diff tracking al guardar. | El visor conserva su estructura de 6 tabs y estilos idénticos. Los botones de feedback se integran de forma no invasiva. |
| `app/src/components/planning/InstitutionAISettingsModal.vue` | Añadir pestaña institucional de "Memoria & Calidad Pedagógica" para que directivos gestionen lineamientos propios. | Pestaña aditiva. No se tocan las pestañas existentes de configuración de API Key ni cuotas de consumo. |
| `app/src/views/SuperAdmin.vue` | Añadir pestaña de administración "AI Improvement Center" condicional a rol SuperAdmin. | Integración desacoplada como tab adicional dentro del contenedor de pestañas de SuperAdmin. |

---

## 2. Archivos que NO se Tocarán (Núcleo Protegido)

* `app/src/lib/ecuadorCurriculumCatalog.js` (Catálogo ministerial estable).
* `app/src/lib/ai/GeminiEducationAIProvider.js` (Adaptador de llamadas API a Google).
* `app/src/lib/ai/OpenAIEducationAIProvider.js` (Adaptador de llamadas API a OpenAI).
* `app/src/lib/ai/DemoEducationAIProvider.js` (Generador determinista ERCA/DUA).
* `app/src/components/planning/PlanningWizardModal.vue` (Asistente de 5 pasos intacto).
* `app/src/components/planning/PlanningResourceCreatorModal.vue` (Generador de recursos intacto).
* `app/src/components/planning/StudentSupportModal.vue` (Modal de adaptaciones intacto).
* `app/src/components/planning/PlanningOfficialPrintDocument.vue` (Motor de impresión oficial MINEDUC).
* Tablas y modelos preexistentes: `courses`, `subjects`, `students`, `grades`, `attendance`, `profiles`, `schools`.

---

## 3. Nuevos Archivos que se Crearán

### 3.1 Backend & Base de Datos
* `migrations/51_ai_feedback_and_institutional_memory.sql`: Esquema para `ai_feedback_logs`, `ai_knowledge_quarantine`, `ai_institutional_memory`, `ai_evaluation_runs`, funciones RPC y RLS multi-tenant.

### 3.2 Capa de Dominio, Servicios y Seguridad IA (`app/src/lib/ai/`)
* `app/src/lib/ai/AIPrivacySanitizer.js`: Sanitizador de PII (cédulas ecuatorianas, nombres, teléfonos, emails, datos DECE) y barrera contra inyecciones de prompts.
* `app/src/lib/ai/FeedbackClassificationService.js`: Clasificador de feedback pedagógico, cálculo de confianza y nivel de riesgo.
* `app/src/lib/ai/PromptRegistry.js`: Registro centralizado y versionado de plantillas de prompts para evitar textos hardcodeados.
* `app/src/lib/ai/AIContextBuilder.js`: Ensamblador seguro de contexto RAG delimitado (currículo + directrices institucionales + preferencias docentes + conocimiento validado).
* `app/src/lib/ai/KnowledgePromotionService.js`: Servicio de revisión, cuarentena y promoción controlada de conocimiento pedagógico.
* `app/src/lib/ai/AIEvaluationService.js`: Evaluador de calidad y detector de regresiones automatizado.
* `app/src/lib/ai/GoldenDataset.js`: Dataset de referencia curricular ecuatoriano con casos de prueba esperados.

### 3.3 Componentes de Presentación (Frontend)
* `app/src/components/planning/FeedbackActionButtons.vue`: Componente discreto reutilizable con acciones `👍 Útil`, `👎 Necesita mejora` y `✏️ Sugerir corrección`.
* `app/src/components/planning/PlanningFeedbackModal.vue`: Modal con categorías rápidas, captura opcional de sugerencias con anonimización en vivo y diff estructurado.
* `app/src/views/superadmin/AIImprovementCenterTab.vue`: Centro de Control de IA en SuperAdmin (métricas, revisión de cuarentena, aprobación/rechazo de conocimiento).

### 3.4 Suites de Pruebas Automatizadas
* `app/tests/aiFeedbackSecurity.test.js`: Pruebas de sanitización PII, inyección de prompts y aislamiento multi-tenant.
* `app/tests/aiContextBuilderAndRAG.test.js`: Pruebas de límites de contexto, ensamblaje de conocimiento y no contaminación de prompts.
* `app/tests/aiEvaluationGoldenDataset.test.js`: Pruebas de evaluación automatizada contra el Golden Dataset de Ecuador.

---

## 4. Matriz de Riesgos y Mitigaciones

| Riesgo Identificado | Impacto | Severidad | Mitigación Implementada |
|---|---|---|---|
| **Contaminación de Prompts (Prompt Poisoning)** | Alto | Crítica | El feedback **NUNCA** se inyecta directamente al System Prompt. Pasa obligatoriamente por cuarentena, sanitización de expresiones maliciosas y aprobación humana antes de integrarse al RAG. |
| **Fuga de Datos Sensibles de Menores (PII)** | Alto | Crítica | Doble filtro de redacción en cliente y servidor (`AIPrivacySanitizer`). Se tokenizan automáticamente cédulas ecuatorianas, nombres y diagnósticos clínicos DECE. |
| **Escalamiento Cross-Tenant (Inter-colegio)** | Crítico | Crítica | Cláusulas de PostgreSQL RLS vinculadas a `school_id = public.get_user_school_id()`. Cada institución tiene su propia partición de memoria aislada. |
| **Regresión en Generaciones Existentes** | Medio | Alta | Pruebas de regresión con el Golden Dataset antes de promover cualquier versión de prompt o conocimiento. Si el score baja de 0.90, la promoción se bloquea. |
| **Sobrecarga de Contexto en LLM (Token Bloat)** | Medio | Media | `AIContextBuilder` aplica límites estrictos de tokens (máximo 400 tokens de conocimiento institucional) ordenados por relevancia (Top-K = 2). |
| **Spam o Flood de Feedback Malicioso** | Bajo | Media | Rate limiting de máximo 20 envíos de feedback por usuario por hora y deduplicación basada en hash MD5. |

---

## 5. Estrategia de Rollback

En caso de cualquier eventualidad:
1. **Feature Flags**: Si se presenta una anomalía, el módulo se puede desactivar inmediatamente mediante el feature flag `ai_feedback_enabled: false` en `tenant_features` sin necesidad de un nuevo despliegue.
2. **Reversibilidad de Base de Datos**: Script de rollback SQL dedicado (`migrations/rollback/51_rollback_ai_feedback.sql`) que elimina limpiamente las tablas nuevas sin afectar `lesson_plans` ni `ai_usage_ledger`.
3. **Desacoplamiento de Código**: Al remover las referencias en `useAIPlanning.js`, el sistema revierte inmediatamente a la versión previa de generación.
