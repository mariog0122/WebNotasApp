# Auditoría y corrección de Años Lectivos

Fecha: 2026-09-09  
Proyecto Supabase: `ykokuwkvplifbjxgdveu`  
Migración aplicada: `20260909034050 secure_academic_year_management`

## Diagnóstico confirmado

El botón **+ Nuevo Año** estaba condicionado por `v-if="isAdmin"`, pero `Courses.vue` no definía `isAdmin`. Vue lo resolvía como falso y ocultaba la acción a Rectoría y al Administrador institucional.

La política RLS de producción tenía un segundo defecto: autorizaba `INSERT`, `UPDATE` y `DELETE` por coincidencia de `school_id`, sin exigir un permiso administrativo. Un docente autenticado perteneciente a la institución podía intentar escrituras directas sobre `academic_years`.

También faltaban controles de integridad para `end_year > start_year`, la garantía de un único año vigente por institución, la columna `is_locked` utilizada por el cliente y el RPC `toggle_academic_year_lock` que el cliente ya invocaba.

## Corrección implementada

- Se definieron permisos semánticos `academic_year.read/create/update/activate/close/delete`.
- Rectoría y Administrador institucional reciben gestión completa; los demás roles conservan solo lectura.
- `Courses.vue` deriva la autorización del contexto calculado por PostgreSQL y vuelve a mostrar el botón autorizado.
- La creación usa `create_academic_year`; el cliente tenant no envía `school_id` y PostgreSQL lo obtiene desde `auth.uid()`.
- Solo el Superadministrador puede indicar una institución explícita.
- El RPC valida formato y rango, usa un bloqueo transaccional por institución y devuelve el mismo registro ante reintentos idénticos.
- Se añadieron restricciones de rango y nombre, unicidad por institución y un índice parcial que permite un solo año vigente.
- Se incorporaron RPC para activar, cerrar y bloquear, todos con autorización y aislamiento tenant.
- Un trigger registra creación, modificación y eliminación en `audit_log`.
- El formulario incluye validación visible, estado de guardado, bloqueo de doble envío y comportamiento móvil.
- Se retiraron todos los privilegios de tabla al rol `anon`; los RPC nuevos solo son ejecutables por `authenticated` y `service_role`.

## Matriz de aceptación

| Caso | Resultado | Evidencia |
|---|---|---|
| Rector crea en su institución | PASS | E2E y prueba SQL transaccional |
| Administrador institucional tiene `academic_year.create` | PASS | RBAC verificado en producción |
| Docente puede leer y no crear | PASS | RLS/RPC probado con rol `authenticated` |
| Manipulación de `school_id` por tenant | PASS | El RPC ignora el valor y usa la institución autenticada |
| Acceso cruzado a otra institución | PASS | Lectura y activación rechazadas en prueba SQL |
| Rango inválido | PASS | Validación cliente, RPC y `CHECK` de PostgreSQL |
| Nombre duplicado por institución | PASS | Restricción única e idempotencia del RPC |
| Un solo año vigente | PASS | Índice único parcial y bloqueo transaccional |
| Auditoría | PASS | Evento confirmado dentro de la transacción de prueba |
| Persistencia sin residuos de prueba | PASS | 8 registros antes y después; 0 eventos de fixture |
| Interfaz móvil 360 px | PASS | Playwright sin desbordamiento horizontal |
| Regresión general | PASS | 261 pruebas unitarias, 20 E2E y build de producción |

## Patrones similares resueltos

Los patrones de calificaciones, facturación, copia de cursos y los avisos accionables de Supabase fueron corregidos y probados posteriormente. La evidencia completa está en `docs/correccion-patrones-similares-2026-09-09.md`.

## Archivos principales

- `app/src/views/Courses.vue`
- `app/src/stores/academicYear.js`
- `app/src/lib/academicYears.js`
- `app/src/lib/permissions.js`
- `supabase/migrations/20260909032539_secure_academic_year_management.sql`
- `migrations/tests/38_academic_year_management_test.sql`
- `app/tests/academicYearManagement.test.js`
- `app/e2e/academic-year-management.spec.js`

Documentación oficial consultada: https://supabase.com/docs/guides/database/secure-data y https://supabase.com/docs/guides/local-development/testing/pgtap-extended

## Paquete para Hostinger

Archivo: `app/dist_20260909_anos_lectivos_seguro.zip`  
Tamaño: 671881 bytes  
Entradas verificadas: 92  
SHA-256: `0BFBFF4EB31025792656D5D77102A4E5E16DEE6F99D52C84620703AA91DD9A98`

El ZIP contiene `index.html`, `.htaccess`, `_headers`, `api/send-email.php`, recursos PWA y assets compilados directamente en la raíz del paquete.
