# TECHNICAL DESIGN: Sistema Seguro de Retroalimentación y Mejora Continua de IA

**Fecha:** 2026-09-03  
**Proyecto:** LOGREVA (WebNotasApp)  

---

## 1. Arquitectura en Capas

El sistema se estructura en capas desacopladas que respetan los principios de Clean Architecture y SOLID:

```text
+-----------------------------------------------------------------------------------+
| 1. PRESENTATION LAYER (Vue 3 Components)                                          |
|    - FeedbackActionButtons.vue (👍 Útil / 👎 Necesita mejora / ✏️ Sugerir)        |
|    - PlanningFeedbackModal.vue (Categorías rápidas, texto opcional, diff viewer)  |
|    - AIImprovementCenterTab.vue (Panel SuperAdmin: Métricas, Cuarentena, Revisión)|
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| 2. APPLICATION / STATE LAYER (Composables & Stores)                               |
|    - useAIPlanning.js (Manejo de estado de feedback, diffs, suscripción)          |
|    - authStore (Identidad autenticada, tenant context, control de roles)          |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| 3. DOMAIN & SECURITY SERVICES (`app/src/lib/ai/`)                                 |
|    - AIPrivacySanitizer.js (Detector PII ecuatoriano y filtro anti-inyección)     |
|    - FeedbackClassificationService.js (Clasificación taxonómica y confidence)     |
|    - KnowledgePromotionService.js (Control de cuarentena y compuerta de aprobación)|
|    - AIEvaluationService.js (Evaluación contra Golden Dataset)                    |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| 4. AI ORCHESTRATION & RAG LAYER                                                   |
|    - EducationAIGateway.js (Punto de entrada unificado y telemetría)              |
|    - AIContextBuilder.js (Ensamblador de contexto RAG con límite estricto de tokens)|
|    - PromptRegistry.js (Catálogo centralizado de prompts versionados con rollback)|
|    - Adaptadores: Gemini / OpenAI / Demo Providers                                |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| 5. DATA & KNOWLEDGE LAYER (PostgreSQL / Supabase)                                 |
|    - ai_feedback_logs (Registro de feedback con diffs estructurados)              |
|    - ai_knowledge_quarantine (Zona de aislamiento de candidatos a conocimiento)   |
|    - ai_institutional_memory (Base de conocimiento y memoria RAG aprobada)        |
|    - ai_evaluation_runs (Historial de auditoría y métricas de evaluación)         |
+-----------------------------------------------------------------------------------+
```

---

## 2. Flujo Completo del Ciclo de Retroalimentación (14 Pasos)

```text
[1. GENERATE]
Docente genera un plan didáctico o recurso en el módulo.
      ↓
[2. COLLECT]
El docente hace clic en "👍 Útil", "👎 Necesita mejora" o "✏️ Sugerir corrección",
o edita manualmente la planificación (captura automática del diff).
      ↓
[3. SANITIZE]
AIPrivacySanitizer analiza el texto:
  * Redacta cédulas ecuatorianas (Módulo 10).
  * Redacta nombres propios, correos, teléfonos y diagnósticos clínicos DECE.
  * Neutraliza intentos de jailbreak o prompt injection.
      ↓
[4. CLASSIFY]
FeedbackClassificationService categoriza el feedback:
  (pedagogical, curriculum, difficulty, format, methodology, institutional_preference).
      ↓
[5. SCORE]
Se calcula un Confidence Score (0.0 a 1.0) y nivel de riesgo (low, medium, high).
      ↓
[6. QUARANTINE]
Si el feedback contiene sugerencias o correcciones reutilizables, se almacena en
`ai_knowledge_quarantine` con estado 'quarantined'. NUNCA entra directo a producción.
      ↓
[7. REVIEW]
El Coordinador Académico o SuperAdmin inspecciona el elemento en el "AI Improvement Center".
      ↓
[8. VALIDATE]
El evaluador humano verifica la pertinencia pedagógica y ausencia de sesgos.
      ↓
[9. EVALUATE]
AIEvaluationService evalúa el impacto potencial contra el Golden Dataset curricular.
      ↓
[10. PROMOTE]
Si la evaluación supera el umbral (score >= 0.90) y es aprobado por el revisor humano,
KnowledgePromotionService lo promueve a `ai_institutional_memory` (Level 2 o Level 3).
      ↓
[11. RETRIEVE]
En futuras generaciones, AIContextBuilder recupera mediante RAG hasta 2 ejemplos
o lineamientos verificados para esa materia y nivel dentro de la misma institución.
      ↓
[12. GENERATE]
El LLM genera la nueva planificación enriquecida con el contexto institucional.
      ↓
[13. MEASURE]
Se evalúa la tasa de satisfacción y reducción de correcciones en esa materia.
      ↓
[14. ITERATE]
El ciclo continúa refinándose de forma segura y permanente.
```

---

## 3. Niveles de Conocimiento (Knowledge Scopes)

| Nivel | Ámbito | Descripción | Mecanismo de Promoción |
|---|---|---|---|
| **Level 1: Docente (User Preference)** | Individual | Preferencias específicas del profesor (ej. prefiere sesiones con actividades grupales de máximo 10 min). | Guardado en perfil docente con aislamiento por `user_id`. Solo afecta sus propias planificaciones. |
| **Level 2: Institucional (Institution Memory)** | Colegio | Formatos específicos, directrices metodológicas de la unidad educativa o ejemplos dorados propios. | Requiere aprobación del Administrador / Coordinador del colegio (`school_id`). Aislamiento multi-tenant por RLS. |
| **Level 3: Global Verificado (Global Knowledge)** | Plataforma | Buenas prácticas curriculares ecuatorianas y adaptaciones DUA validadas por expertos ministeriales/pedagógicos. | Requiere aprobación explícita de un SuperAdmin de la plataforma y validación completa contra el Golden Dataset. |

---

## 4. Ensamblador de Contexto Seguro (AIContextBuilder)

Para evitar la contaminación del System Prompt y el desbordamiento de la ventana de contexto:

1. **Inyección Delimitada**:
   El contexto recuperado por RAG se inyecta como un bloque de datos estructurado en el mensaje del usuario o en una sección claramente demarcada:
   ```json
   {
     "directrices_institucionales": [...],
     "ejemplo_referencia_aprobado": {...}
   }
   ```
2. **Presupuesto Estricto de Tokens**:
   - Currículo oficial base: ~300 tokens.
   - Parámetros de la clase: ~150 tokens.
   - Memoria institucional recuperada (RAG Top-2): máximo 400 tokens.
   - Margen de seguridad: El contexto adicional nunca puede superar el 20% del presupuesto total de entrada.
3. **Inmutabilidad del System Prompt**:
   El System Prompt base define el rol pedagógico del modelo y las directrices curriculares de Ecuador. **Ningún feedback de usuario puede alterar este texto.**
