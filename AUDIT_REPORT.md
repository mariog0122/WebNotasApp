# AUDIT_REPORT.md — AUDITORÍA TÉCNICA DEL SISTEMA WEBNOTAS SAAS

**Fecha de Auditoría:** 7 de Agosto de 2026  
**Proyecto:** WebNotasApp — Centro de Comando SaaS Multi-Tenant  
**Estado:** Finalizado — Fase 1 Completada  

---

## 1. ARQUITECTURA ENCONTRADA

### 1.1 Frontend
- **Framework:** Vue 3 (Vite, Options API / Composition API `<script setup>`).
- **Estado Global:** Pinia (`useAuthStore`, `useUIStore`).
- **Enrutamiento:** Vue Router con guard global `beforeEach` revalidando sesión con `authStore.ensureSession()`.
- **Estilos & Iconos:** TailwindCSS v3 con soporte de modo oscuro (`dark:`) + Lucide Icons + Vue Sonner.

### 1.2 Backend & Servicios (BaaS)
- **Motor:** Supabase (PostgreSQL 15+).
- **Autenticación:** Supabase Auth (`auth.users`) enlazado a `public.profiles` mediante FK `id = auth.uid()`.
- **Almacenamiento:** Buckets de Supabase Storage (`institution-assets`, `student-photos`).
- **Lógica de Negocio:** Triggers en PL/pgSQL y Funciones RPC (`invite_teacher_by_email`, `copy_academic_year_data`, `set_school_id_from_auth`).

### 1.3 Esquema de Datos Actual
- **Tablas Principales:**
  - `schools` (id, name, is_active, created_at)
  - `profiles` (id [FK auth.users], email, role, full_name, school_id [FK schools], created_at)
  - `courses` (id, name, academic_year, level, track, school_id [FK schools])
  - `subjects` (id, name, school_id [FK schools])
  - `quarters` (id, name, is_active, is_locked, school_id [FK schools])
  - `students` (id, full_name, course_id, student_cedula, representative_name, ..., school_id [FK schools])
  - `course_subjects` (id, course_id, subject_id, teacher_id, school_id [FK schools])
  - `grade_definitions` (id, course_subject_id, quarter_id, name, category, weight, sort_order, school_id [FK schools])
  - `grades` (id, student_id, grade_definition_id, score, school_id indirecto por estudiante)
  - `qualitative_grades`, `supplementary_exams`, `project_settings`, `project_grades`, `project_subject_grades`
  - `system_config` (school_id, key, value, description) — PK Compuesta `(school_id, key)`
  - `student_alerts` (id, student_id, severity, description, school_id [FK schools])
  - `audit_log` (id, user_id, action, table_name, record_id, old_values, new_values, created_at)

---

## 2. PROBLEMAS Y RIESGOS CRÍTICOS DETECTADOS

> [!CAUTION]
> **Riesgo Crítico 1: Vulnerabilidad de Aislamiento Multi-Tenant (Cross-Tenant Data Leakage)**  
> Aunque la migración `03_saas_multitenancy.sql` introdujo RLS filtrando por `school_id = get_user_school_id()`, scripts posteriores de parche como `CORREGIR_RECURSION_SQL.sql`, `supabase_rls_audit.sql` y `PRODUCCION_SEGURIDAD.sql` **sobreescribieron** las políticas con reglas abiertas del tipo:  
> `CREATE POLICY "courses_select_all" ON courses FOR SELECT USING (auth.role() = 'authenticated');`  
> **Efecto:** Cualquier usuario autenticado de la Institución A puede consultar, ver e incluso modificar datos (estudiantes, notas, cursos) de la Institución B realizando peticiones HTTP directas a la API REST de Supabase.

> [!WARNING]
> **Riesgo 2: Elevación de Privilegios Involuntaria (Privilege Escalation)**  
> La política actual en `profiles` dice:  
> `CREATE POLICY "profiles_admin_all" ON profiles FOR ALL USING (is_admin());`  
> Dado que la función `is_admin()` devuelve `true` para cualquier usuario con `role = 'admin'` (rectores de colegios), **cualquier Rector de un colegio puede enviar una petición UPDATE a Supabase y cambiarse su propio rol a `superadmin`**, obteniendo acceso total a la plataforma SaaS.

> [!WARNING]
> **Riesgo 3: Permisos Hardcodeados y Validación Exclusiva en Frontend**  
> Actualmente los permisos se definen en `app/src/lib/permissions.js` como un mapa JS plano de tres roles (`superadmin`, `admin`, `teacher`). El backend de Supabase **no valida si un usuario tiene permisos para crear estudiantes o ver alertas DECE**, únicamente valida `auth.role() = 'authenticated'`.

> [!NOTE]
> **Problema 4: Dependencia Exclusiva del Estado Booleano `is_active`**  
> Los colegios sólo tienen un campo `is_active` (`true`/`false`). No existen conceptos de `trial`, `past_due`, `grace_period`, `suspended`, `cancelled` o `archived`. Tampoco hay registros del motivo de suspensión, fecha ni actor.

> [!NOTE]
> **Problema 5: Ausencia de Módulos (Feature Flags), Límites y Suscripciones Reales**  
> El Panel SuperAdmin actual sólo permite ingresar un nombre y marcar un checkbox. No existen tablas para `plans`, `subscriptions`, `payments`, `tenant_features` ni `tenant_limits`. No hay control de cuántos estudiantes o usuarios puede registrar una institución ni alertas de uso (80%, 90%, 100%).

---

## 3. CAMBIOS RECOMENDADOS Y ARQUITECTURA PROPUESTA

1. **Refactorización de Roles y Membresías Multi-Tenant:**
   - Separar **Platform Roles** (`platform_owner`, `platform_admin`, `platform_support`, `platform_finance`, `platform_readonly`) de **Tenant Roles** (`school_admin`, `rector`, `vicerrector`, `secretary`, `teacher`, `inspector`, `counselor`, `student`, `parent`).
   - Crear la tabla `tenant_memberships` para permitir que un usuario pertenezca a más de una institución con diferentes roles.
   - El `platform_owner` / `platform_admin` no requiere `tenant_id` asignado.

2. **Aislamiento RLS Impregnable (Multi-Tenant Security):**
   - Re-implementar políticas RLS basadas en `public.get_current_tenant_id()` y `public.has_tenant_permission(permission_name)`.
   - Garantizar que la consulta a `profiles` para verificar roles use funciones `SECURITY DEFINER` libres de recursión infinita y sin permitir self-elevation.

3. **Ciclo de Vida de Estado de la Institución:**
   - Reemplazar el concepto simple `is_active` por el enumerado: `trial`, `active`, `past_due`, `grace_period`, `suspended`, `cancelled`, `archived`.
   - Implementar tabla de historial de estados `tenant_status_logs` (motivo, actor, fecha, observación).
   - Bloquear el acceso a la app cuando la institución esté `suspended` o `cancelled`, permitiendo ingreso exclusivo al SuperAdmin.

4. **Centro de Comando SuperAdmin Completo:**
   - Dashboard con métricas reales obtenidas mediante consultas agrupadas / RPC de BD (conteo por estados, usuarios totales, docentes, estudiantes, almacenamiento en buckets).
   - Tabla interactiva en `/superadmin/tenants` con búsqueda, filtros, paginación, estados con badges de alta visibilidad, acciones contextuales y ocultamiento de UUIDs principales.
   - Wizard de creación de colegio en 5 pasos transaccionales (Datos, Admin, Plan, Facturación, Confirmación).

5. **Feature Flags, Límites e Impersonación:**
   - Tabla `tenant_features` para activar/desactivar módulos (`grades`, `attendance`, `alerts`, `reports`, `ai`, etc.).
   - Tabla `tenant_limits` para restringir `max_users`, `max_teachers`, `max_students`, `storage_mb`.
   - Sistema de Impersonación segura ("Entrar como administrador") mediante sesión temporal registrada en `impersonation_logs` con banner persistente global en el UI.
   - Sistema de Auditoría global `audit_logs` para registrar cambios críticos y evitar autosave en acciones peligrosas.

---

## 4. MIGRACIONES NECESARIAS (SQL MIGRATIONS PLAN)

Se crearán e implementarán las siguientes migraciones ordenadas en la carpeta `migrations/`:

1. `07_saas_rbac_multi_tenant.sql`:
   - Enums para `platform_role_type`, `tenant_role_type`, `tenant_status_type`.
   - Tablas `platform_roles`, `tenant_roles`, `permissions`, `role_permissions`, `user_platform_roles`, `tenant_memberships`.
   - Funciones helper `is_platform_admin()`, `get_user_tenant_ids()`, `has_platform_permission()`.
2. `08_tenant_lifecycle_plans.sql`:
   - Alteración / Extensión de `schools` (a `tenants`/`schools` con soporte de estados, país, ciudad, timezone, etc.).
   - Tablas `plans`, `subscriptions`, `payments`, `tenant_status_logs`.
3. `09_tenant_features_limits.sql`:
   - Tablas `tenant_features` y `tenant_limits`.
   - Triggers/funciones para validar límites en inserción de usuarios y estudiantes.
4. `10_impersonation_and_audit.sql`:
   - Tablas `impersonation_logs` y actualización de `audit_logs` para eventos del sistema SaaS.
5. `11_secure_rls_policies.sql`:
   - Reestructuración total de RLS en todas las tablas (`courses`, `students`, `grades`, etc.) exigiendo coincidencia de `tenant_id` O permiso `is_platform_admin()`.

---

## 5. ARCHIVOS QUE SERÁN MODIFICADOS / CREADOS EN FRONTEND

- `app/src/stores/auth.js` (Soporte para platform_roles, memberships, impersonation state).
- `app/src/router/index.js` (Rutas protegidas por platform roles y estado del tenant).
- `app/src/lib/permissions.js` (Integración con RBAC de backend).
- `app/src/views/SuperAdmin.vue` (Rediseño total como Centro de Comando).
- `app/src/components/MainLayout.vue` (Banner global de Impersonación y menú contextual según Platform Role).
- Nuevos componentes en `app/src/views/superadmin/`:
  - `Overview.vue` (Métricas e indicadores en tiempo real).
  - `TenantsList.vue` (Tabla profesional de instituciones con filtros y acciones).
  - `TenantWizard.vue` (Wizard de 5 pasos transaccional).
  - `PlansSubscriptions.vue` (Gestión de planes y facturación).
  - `AuditLogs.vue` (Visor de auditoría de seguridad).
  - `SystemHealth.vue` (Salud y estado de servicios).

---

**Conclusión:**  
La auditoría técnica ha finalizado y se han documentado todos los hallazgos y riesgos. Quedamos a la espera del visto bueno para proceder a ejecutar la Fase 2 y subsecuentes.
