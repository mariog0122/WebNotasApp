# SECURITY_AUDIT.md — AUDITORÍA DE SEGURIDAD Y CAPACIDADES REALES DE WEBNOTAS SAAS

**Fecha de Auditoría:** 8 de Agosto de 2026  
**Proyecto:** WebNotasApp — Plataforma SaaS Educativa B2B Multi-Tenant  
**Auditoría:** Ciberseguridad & Diagnóstico Técnico de Infraestructura  

---

## 1. INVENTARIO DE CAPACIDADES TÉCNICAS VERIFICADAS

### 1.1 Autenticación & Control de Sesión
- **Motor:** Supabase Auth (Basado en GoTrue & PostgreSQL).
- **Mecanismo de Tokens:** JWT (JSON Web Tokens) firmados con secreto del proyecto Supabase.
- **Persistencia de Sesión:** Manejada via Supabase Client SDK en `localStorage` (`webnotas-auth-token`).
- **Recuperación de Contraseña:** Habilitada mediante `supabase.auth.resetPasswordForEmail()` con flujo PKCE/hash token.
- **MFA (Multi-Factor Authentication):** [NO IMPLEMENTADO] — No activado actualmente en la plataforma.
- **Políticas de Contraseña:** Mínimo 6 caracteres en frontend y validación básica en Auth.

**Estado:** `IMPLEMENTADO` (Autenticación JWT, Recuperación de Clave, Persistencia) / `NO IMPLEMENTADO` (MFA).

---

### 1.2 Autorización & Roles (RBAC)
- **Roles de Plataforma:** `platform_owner`, `platform_admin`, `platform_support`, `platform_finance`, `platform_readonly` (Migración `07_saas_multi_tenant_rbac.sql`).
- **Roles de Institución:** `school_admin`, `rector`, `vicerrector`, `secretary`, `teacher`, `inspector`, `counselor`, `student`, `parent`.
- **Verificación en Backend:** Funciones PL/pgSQL `SECURITY DEFINER` (`is_platform_admin()`, `has_tenant_permission()`).
- **Verificación en Frontend:** Store `useAuthStore` y helper `usePermissions` en `app/src/lib/permissions.js`.

**Estado:** `IMPLEMENTADO` (RBAC Granular en BD y Frontend).

---

### 1.3 Aislamiento Multi-Tenant & RLS (Row Level Security)
- **Separación de Datos:** Tabla `schools` / `tenants` con FK `school_id` inyectada en todas las tablas estructurales (`courses`, `subjects`, `quarters`, `students`, `course_subjects`, `grade_definitions`, `system_config`, `student_alerts`).
- **Isolation via RLS:** Re-estructurada en `migrations/11_secure_rls_policies.sql`. Cada usuario solo accede a datos donde `school_id = public.get_user_school_id()` O si posee permisos `is_platform_admin()`.
- **Prevención de Cross-Tenant Leakage:** Verificada contra endpoints REST PostgREST.

**Estado:** `IMPLEMENTADO` (Aislamiento por `school_id` y RLS).

---

### 1.4 Seguridad Frontend & Prevención OWASP Top 10
- **Prevención XSS:** Vue 3 interpola cadenas con escape automático de caracteres HTML (`{{ }}`). Sin uso de `v-html` en datos ingresados por usuarios.
- **Inyección SQL:** Imposible vía frontend dado que Supabase PostgREST utiliza consultas parametrizadas internamente.
- **Manejo de Secretos:** Exclusivamente la `VITE_SUPABASE_ANON_KEY` está presente en cliente (pública por diseño y restringida por RLS). La `service_role_key` **NUNCA** está expuesta en el código frontend.

**Estado:** `IMPLEMENTADO` (Prevención XSS/SQLi y Secrecy).

---

### 1.5 Cifrado & Comunicaciones
- **Tránsito (In-Transit):** Todo el tráfico HTTPS / TLS 1.3 gestionado por la infraestructura BaaS de Supabase.
- **Reposo (At-Rest):** Cifrado AES-256 a nivel de volumen de base de datos PostgreSQL gestionado por el proveedor BaaS.

**Estado:** `IMPLEMENTADO` (HTTPS/TLS y Cifrado en Reposo).

---

### 1.6 Auditoría, Monitoreo & Logs
- **Logs de Auditoría Inmutables:** Tabla `audit_log` y triggers en PL/pgSQL para cambios en calificaciones y usuarios.
- **Logs de Impersonación:** Tabla `impersonation_logs` y RPCs `start_impersonation_session` / `stop_impersonation_session`.

**Estado:** `IMPLEMENTADO` (Auditoría de eventos e impersonación).

---

### 1.7 Pasarela de Pagos
- **Transferencia Bancaria Directa:** `IMPLEMENTADO` (Método activo actual).
- **Kushki (Tarjetas de Crédito/Débito):** `PARCIAL / PRÓXIMAMENTE` (Arquitectura preparada en `subscriptions` y `payments`, pero SDK de producción aún no desplegado).

---

## 2. CLASIFICACIÓN RIGUROSA DE HALLAZGOS Y CAPACIDADES

| Capacidad / Característica | Estado Real | Visibilidad Comercial Permitida |
| :--- | :--- | :--- |
| Autenticación Segura (Supabase Auth JWT) | `IMPLEMENTADO` | Sí — Mencionar "Sesiones protegidas con tokens JWT cifrados" |
| Aislamiento Multi-Tenant (RLS PostgreSQL) | `IMPLEMENTADO` | Sí — Mencionar "Aislamiento nativo a nivel de base de datos (RLS)" |
| Control de Acceso por Roles (RBAC) | `IMPLEMENTADO` | Sí — Mencionar "Roles y permisos granulares configurables" |
| Registro de Auditoría Inmutable | `IMPLEMENTADO` | Sí — Mencionar "Trazabilidad completa y logs de auditoría" |
| Comunicación Cifrada HTTPS/TLS | `IMPLEMENTADO` | Sí — Mencionar "Conexión cifrada de extremo a extremo" |
| Copias de Seguridad (Backups) | `IMPLEMENTADO` | Sí — Mencionar "Respaldos periódicos de base de datos" |
| Pago con Tarjeta en Línea (Kushki) | `PARCIAL` | Sí — **Mención estricta:** "Pago con tarjeta próximamente mediante Kushki" |
| MFA / Autenticación de Doble Factor | `NO IMPLEMENTADO` | **PROHIBIDO MENCIONAR** |
| Certificaciones ISO 27001 / SOC 2 / PCI DSS | `DESCONOCIDO` | **PROHIBIDO MENCIONAR** |
| Soporte 24/7 Garantizado | `NO IMPLEMENTADO` | **PROHIBIDO MENCIONAR** (Usar horario laboral/atención funcional) |

---

**Conclusión:** La sección comercial y la nueva página pública `/planes` utilizarán exclusivamente las capacidades clasificadas como `IMPLEMENTADO` y `PARCIAL` (con la aclaración de "próximamente" para Kushki). No se alucinará ninguna certificación o funcionalidad inexistente.
