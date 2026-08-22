# P0 Production Security Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminar la exposición anónima y cruzada entre instituciones, bloquear flujos de identidad inseguros, retirar caché privada del service worker y corregir el cálculo académico que falla en pruebas.

**Architecture:** La autorización queda centralizada en PostgreSQL mediante RLS y funciones auxiliares `SECURITY DEFINER` endurecidas. El frontend conserva únicamente controles de experiencia de usuario: nunca crea perfiles o roles y no simula identidades. Los archivos sensibles pasan a buckets privados y se consumen con URLs firmadas de corta duración.

**Tech Stack:** Vue 3, Pinia, Vue Router, Vite/Vitest, Supabase Auth/Postgres/Storage, SQL migrations.

---

### Task 1: Crear pruebas de regresión P0

**Files:**
- Create: `app/tests/securityConfig.test.js`
- Modify: `app/tests/reporting.test.js` only if an extra edge case is needed

**Steps:**
1. Add source-level invariants proving that the PWA config does not cache Supabase responses, auth does not insert fallback profiles, the login view has no public registration, and the privacy copy makes no absolute isolation claim.
2. Keep the existing failing interdisciplinary-project test as the RED test for the calculation defect.
3. Run `npm test -- --run`; expect security tests to fail before implementation and the reporting test to remain red.

### Task 2: Endurecer autenticación y navegación

**Files:**
- Modify: `app/src/stores/auth.js`
- Modify: `app/src/router/index.js`
- Modify: `app/src/views/Login.vue`
- Modify: `app/src/components/MainLayout.vue`
- Modify: `app/src/views/superadmin/TenantsTab.vue`

**Steps:**
1. Replace profile auto-provisioning with a `PROFILE_NOT_PROVISIONED` access error and keep `profile` null.
2. Require both an authenticated user and an authorized profile on every protected route.
3. Remove public sign-up controls and calls from the login screen.
4. Remove the client-side impersonation state, banner and action until a server-issued scoped session exists.
5. Run the focused security tests.

### Task 3: Eliminar caché persistente de datos Supabase

**Files:**
- Modify: `app/vite.config.js`
- Modify: `app/src/main.js`

**Steps:**
1. Delete Supabase `runtimeCaching` from Workbox.
2. Delete the legacy `supabase-api-cache` browser cache during application bootstrap.
3. Keep static PWA precaching and automatic service-worker updates.
4. Run `npm test -- --run` and `npm run build`.

### Task 4: Corregir el cálculo de proyecto interdisciplinario

**Files:**
- Modify: `app/src/lib/reporting.js`

**Steps:**
1. When the subject participates in the interdisciplinary project, replace the grade of its summative project definition with `projectAverage`.
2. Preserve the current calculation for ordinary subjects or when no project average exists.
3. Run `npm test -- --run`; expect all reporting tests to pass.

### Task 5: Corregir declaraciones de privacidad

**Files:**
- Modify: `app/src/views/Privacy.vue`

**Steps:**
1. Replace the unverifiable absolute isolation statement with factual language about authenticated access, RLS and periodic verification.
2. Avoid guarantees such as “ningún tercero” or “estrictamente aislados”.
3. Run the security source tests.

### Task 6: Crear la migración de seguridad de base de datos

**Files:**
- Create: `migrations/12_p0_security_lockdown.sql`
- Create: `migrations/tests/12_p0_security_lockdown_test.sql`

**Steps:**
1. Drop every existing policy on the protected application tables so permissive policies cannot combine with new ones.
2. Recreate `is_platform_admin`, `get_user_school_id`, `has_tenant_permission` and grade/tenant predicates with fixed `search_path`, active-membership checks and explicit grants.
3. Revoke application RPC execution from `PUBLIC` and `anon`; grant only the minimum authenticated entry points whose bodies perform authorization.
4. Add separate SELECT/INSERT/UPDATE/DELETE policies for profiles, tenant/RBAC/billing, academic data, alerts and audit logs.
5. Prevent grade writes unless the actor is a platform admin, tenant administrator or the teacher assigned to the course-subject.
6. Create SQL assertions for anonymous denial, same-tenant access, foreign-tenant denial and privilege-escalation denial, rolling back fixtures.
7. Inspect the resulting SQL before any production application.

### Task 7: Privatizar archivos sensibles

**Files:**
- Modify: `migrations/12_p0_security_lockdown.sql`
- Modify: `app/src/lib/studentUtils.js`
- Modify: `app/src/views/Students.vue`
- Modify: `app/src/views/Courses.vue`
- Modify: `app/src/views/Profile.vue`

**Steps:**
1. Make `student-photos`, `profile-photos` and institution assets private.
2. Restrict Storage objects by tenant-owned path or row ownership and authenticated role.
3. Validate image MIME type and a conservative maximum size before upload.
4. Store object paths rather than newly generated public URLs and resolve display URLs with short-lived signed URLs; retain a compatibility resolver for existing stored public URLs.
5. Run unit tests and build.

### Task 8: Aplicar y verificar la migración en Supabase

**Files:**
- Verify: `migrations/12_p0_security_lockdown.sql`
- Verify: `migrations/tests/12_p0_security_lockdown_test.sql`

**Steps:**
1. Apply the reviewed migration with Supabase migration tooling.
2. Run SQL assertions and an anonymous REST count check; expect zero visible rows for every protected table.
3. Re-run Supabase security and performance advisors; confirm the anonymous leakage and multiple permissive-policy findings are removed or materially reduced.
4. Confirm the existing tenant can still read its own data while foreign-tenant fixtures remain invisible.

### Task 9: Verificación final

**Files:**
- Modify: `SAAS_PRODUCTION_AUDIT.md` with an implementation appendix

**Steps:**
1. Run `npm test -- --run`, `npm run build`, and `npx playwright test`.
2. Repeat the anonymous API probes without downloading row bodies.
3. Record completed P0 items, remaining P1-P3 risks and any intentionally deferred compatibility work.
4. Stop the temporary development server and report exact verification evidence.
