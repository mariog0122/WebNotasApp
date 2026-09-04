# ARCHITECTURE MAP: Módulo de IA y Sistema de Retroalimentación

**Fecha:** 2026-09-03  
**Proyecto:** LOGREVA (WebNotasApp)  
**Entorno:** SaaS Educativo Multi-Tenant (Vue 3, Vite, Tailwind CSS, Supabase / PostgreSQL)

---

## 1. Visión General del Sistema Actual

LOGREVA es una plataforma de gestión escolar multi-inquilino diseñada para instituciones educativas de Ecuador. Dispone de un módulo de Planificación Educativa con IA basado en el currículo nacional del Ministerio de Educación (MINEDUC), destrezas con criterios de desempeño (DCD), metodología ERCA y diseño universal para el aprendizaje (DUA).

```text
+-----------------------------------------------------------------------------------+
|                                 CLIENTE (Vue 3 SPA)                              |
|                                                                                   |
|  [AIPlanning.vue] <---> [useAIPlanning.js]                                        |
|         |                        |                                                |
|         v                        v                                                |
|  [PlanningDocumentViewer]  [EducationAIGateway.js] ---> [AIPrivacySanitizer.js]  |
|  [PlanningWizardModal]           |                         (Capa de Sanitización) |
|  [FeedbackActionButtons]         +---> [AIContextBuilder.js]                      |
|                                  |        |                                       |
|                                  |        +-> [PromptRegistry.js]                 |
|                                  |                                                |
|                                  +---> Proveedores:                               |
|                                        - GeminiEducationAIProvider.js             |
|                                        - OpenAIEducationAIProvider.js             |
|                                        - DemoEducationAIProvider.js               |
+------------------------------------------+----------------------------------------+
                                           |
                                           v Supabase Client (PostgREST / RPC / RLS)
+-----------------------------------------------------------------------------------+
|                               BACKEND (PostgreSQL / Supabase)                     |
|                                                                                   |
|  - Tablas Core: schools, profiles, courses, subjects, students                    |
|  - Tablas IA: lesson_plans, lesson_plan_resources, student_support_plans          |
|  - Configuración & Ledger: institution_ai_settings, ai_usage_ledger               |
|  - Sistema Feedback & Cuarentena:                                                 |
|      * ai_feedback_logs (Registro granular de feedback y diffs)                   |
|      * ai_knowledge_quarantine (Zona de aislamiento de candidatos)                |
|      * ai_institutional_memory (Base de conocimiento y memoria RAG validada)      |
|      * ai_evaluation_runs (Auditoría y control de regresión de modelos)           |
+-----------------------------------------------------------------------------------+
```

---

## 2. Mapa de Archivos Existentes Relacionados

### 2.1 Capa de Presentación (UI / Vue Components)
* `app/src/views/AIPlanning.vue`: Vista principal del módulo de planificación curricular con IA.
* `app/src/views/SuperAdmin.vue`: Panel de administración global de la plataforma (SuperAdmin).
* `app/src/views/superadmin/TenantsTab.vue`: Gestión de instituciones y activación de feature flags por colegio.
* `app/src/components/planning/PlanningDocumentViewer.vue`: Visor del plan de clase generado (6 pestañas: Resumen, ERCA, Evaluación, DUA, Recursos, Seguimiento).
* `app/src/components/planning/PlanningWizardModal.vue`: Asistente de 5 pasos para configuración curricular sin necesidad de redactar prompts.
* `app/src/components/planning/PlanningResourceCreatorModal.vue`: Generador de 19 tipos de recursos didácticos de aula.
* `app/src/components/planning/StudentSupportModal.vue`: Generador de planes de recuperación pedagógica y adaptaciones.
* `app/src/components/planning/InstitutionAISettingsModal.vue`: Configuración del proveedor de IA (Managed, BYOK, Demo), modelos y cuotas.

### 2.2 Capa de Orquestación y Lógica de IA (`app/src/lib/ai/`)
* `app/src/lib/ai/EducationAIGateway.js`: Gateway principal que abstrae la selección de proveedor, anonimización básica de estudiantes y registro de telemetría en `ai_usage_ledger`.
* `app/src/lib/ai/types.js`: Tipos y constantes (`AI_PROVIDERS`, `AI_MODELS`, `AI_TASK_TYPES`, `AI_STATUSES`).
* `app/src/lib/ai/GeminiEducationAIProvider.js`: Adaptador para Google Gemini API (modelos 2.5 Flash, 2.5 Flash-Lite, 2.5 Pro, 3.7 Flash).
* `app/src/lib/ai/OpenAIEducationAIProvider.js`: Adaptador para OpenAI API (modelos gpt-5.6-luna, gpt-4o-mini, gpt-4o).
* `app/src/lib/ai/DemoEducationAIProvider.js`: Proveedor determinista para entornos sin clave API o modo demostrativo.
* `app/src/lib/ecuadorCurriculumCatalog.js`: Catálogo curricular estático versionado de Ecuador (niveles, destrezas DCD, criterios de evaluación, indicadores).

### 2.3 Capa de Estado y Acceso a Datos
* `app/src/composables/useAIPlanning.js`: Composable reactivo que gestiona el ciclo de vida de generación, guardado de versiones y llamadas al Gateway.
* `app/src/stores/auth.js`: Store Pinia de autenticación y contexto de usuario (`school_id`, `role`, `accessContext`).
* `app/src/lib/supabase.js`: Cliente de conexión Supabase con persistencia de sesión.
* `app/src/lib/permissions.js`: Control de permisos basados en roles (`admin`, `teacher`, `dece`, `superadmin`).

### 2.4 Capa de Base de Datos y Migraciones
* `migrations/49_ai_lesson_planning_module.sql`: Migración base que define `lesson_plans`, `lesson_plan_versions`, `lesson_plan_resources`, `student_support_plans`, `institution_ai_settings`, `ai_usage_ledger` y políticas RLS multi-tenant.
* `migrations/50_student_curricular_adaptations.sql`: Extensión de campos de adaptaciones curriculares en estudiantes y planes.

---

## 3. Modelo Multi-Tenant y Seguridad Existente

* **Aislamiento por `school_id`**: Cada consulta utiliza el contexto del usuario autenticado vía `public.get_user_school_id()`.
* **Row Level Security (RLS)**: Activado en todas las tablas con políticas diferenciadas para `SELECT`, `INSERT`, `UPDATE` y `DELETE`.
* **Funciones de Autorización**: `public.is_platform_admin()`, `public.is_admin()`, `public.has_tenant_permission()`.
* **Protección de Datos Estudiantiles Preexistente**: `EducationAIGateway.anonymizeStudentInput()` tokeniza nombres e IDs de estudiantes con `[ESTUDIANTE_ANONIMO]` antes de llamar a las APIs de IA.

---

## 4. Deuda Técnica y Oportunidades Identificadas

1. **Ausencia de Pipeline de Feedback Estructurado**: Los docentes podían editar las planificaciones, pero no existía un mecanismo para registrar si el contenido inicial fue acertado, ni capturar categorías de fallo pedagógico.
2. **Prompts Rígidos en Proveedores**: Los prompts estaban embebidos como strings dentro de cada método de los adaptadores, dificultando su versionado o enriquecimiento contextual dinámico.
3. **Falta de Memoria Institucional Controlada**: Cada generación empezaba desde cero sin poder aprovechar ejemplos previos validados como excelentes por la propia institución educativa.

---

## 5. Estrategia de Extensión (Regla de No Ruptura)

Seguiremos el principio arquitectónico: **EXTENDER > ENVOLVER > ADAPTAR > REFACTORIZAR**.
* Los métodos públicos existentes de `EducationAIGateway` (`generatePlan`, `regenerateSection`, `generateResource`, `generateStudentSupport`) mantendrán intactas sus firmas y contratos de respuesta.
* Se incorporarán servicios desacoplados para sanitización, clasificación, registro de prompts y contexto RAG sin mutar los adaptadores existentes de proveedores.
* El frontend integrará botones de micro-feedback discretos sin alterar el diseño del visor de planificaciones ni sobrecargar la experiencia del docente.
