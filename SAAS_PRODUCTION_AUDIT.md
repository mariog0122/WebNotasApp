# Executive Summary

**Fecha de corte:** 8 de agosto de 2026  
**Producto auditado:** EduCore / WebNotas  
**Frontend principal verificado:** `app/` (Vue 3 + Vite)  
**Backend verificado:** Supabase/PostgreSQL, proyecto `webnotasEmilioIsaias`  
**Método:** revisión de código y SQL, consultas de metadatos a la base real, Supabase Advisors, prueba REST anónima, tests unitarios, E2E, build y revisión visual automatizada en 11 resoluciones.

## Estado actual

**RIESGO — NO VENDIBLE.** La aplicación no debe recibir una segunda institución ni datos reales adicionales en el estado actual. La API REST permite a un cliente anónimo consultar conteos y, por las políticas RLS desplegadas, leer filas de tablas privadas como estudiantes, perfiles, cursos, asignaturas y calificaciones. Las políticas permisivas se acumulan y se combinan con `OR`, por lo que las políticas nuevas de aislamiento no neutralizan las antiguas.

La base real contiene una sola institución, un perfil y un estudiante. Por ello no se ejecutó una prueba destructiva con dos colegios reales. Aun así, la exposición anónima quedó verificada de extremo a extremo y el SQL desplegado demuestra que un usuario autenticado tampoco queda correctamente limitado por institución o rol.

El frontend compila, el E2E de redirección sin sesión pasa y varias piezas de UX móvil están bien encaminadas. Sin embargo, una prueba académica falla, el guardado de notas no es transaccional, los límites comerciales no están desplegados ni aplicados, Kushki no existe, no hay historial de migraciones registrado y no hay evidencia verificable de backups/restores, CI/CD, observabilidad, RPO o RTO.

## Production Readiness Score

| Área | Puntaje / 100 | Estado |
|---|---:|---|
| Arquitectura | 50 | PARCIAL |
| Base de datos | 45 | RIESGO |
| Seguridad | 10 | RIESGO |
| Multi-tenancy | 10 | RIESGO |
| Funcionalidad | 55 | PARCIAL |
| UX | 70 | PARCIAL |
| Responsive | 65 | PARCIAL |
| Performance | 50 | PARCIAL |
| DevOps | 20 | NO IMPLEMENTADO |
| Testing | 25 | PARCIAL |
| Observabilidad | 15 | NO IMPLEMENTADO |
| Operación SaaS | 25 | PARCIAL |
| Comercialización | 30 | RIESGO |

**PRODUCTION READINESS SCORE: 36/100 — NO VENDIBLE.**

## ¿Se puede vender?

**No.** Solo podría evaluarse como piloto interno y sin datos sensibles después de cerrar todos los P0 y repetir pruebas con dos tenants independientes. Venderlo hoy expondría datos educativos y contradiría afirmaciones públicas de privacidad y aislamiento.

# Evidencia ejecutada

| Prueba | Resultado | Clasificación |
|---|---|---|
| REST Supabase con clave pública, `GET ...?select=id&limit=0`, `Prefer: count=exact` | `students */1`, `grades */7`, `profiles */1`, `courses */9`, `subjects */7` | VERIFICADO — CRITICAL |
| Base real | 1 colegio, 1 perfil, 1 estudiante, 7 notas, 9 cursos, 7 asignaturas | VERIFICADO |
| Integridad cross-tenant existente | 0 inconsistencias detectadas en los datos actuales | VERIFICADO, pero solo existe 1 tenant |
| Asignación docente | 21/21 filas de `course_subjects` tienen `teacher_id NULL` | VERIFICADO — HIGH |
| Supabase Security Advisor | 58 avisos: 10 INFO, 48 WARN | VERIFICADO |
| Supabase Performance Advisor | 354 avisos: 38 FK sin índice, 58 `auth_rls_initplan`, 235 políticas permisivas múltiples, 20 índices sin uso, 3 duplicados | VERIFICADO |
| Historial de migraciones Supabase | 0 migraciones registradas | VERIFICADO — HIGH |
| Unit tests | 35 pasan, 1 falla (`reporting.test.js:92`, esperado 10, recibido 7.5) | VERIFICADO — HIGH |
| E2E | 1/1 pasa: `/grades` redirige a `/login` sin sesión | VERIFICADO |
| Build | `vite build` exit 0; precache PWA ~2.4 MiB | VERIFICADO |
| Dependencias de producción | 6 vulnerabilidades: 5 HIGH, 1 MODERATE | VERIFICADO — HIGH |
| Responsive público | 44 combinaciones; overflow en `/planes` a 320 y 360 px | VERIFICADO — MEDIUM |
| Rutas privadas visuales | Solo redirección sin sesión; no se usaron credenciales reales | NO VERIFICABLE |

# Hallazgos críticos

| ID | Severidad | Área | Problema | Evidencia | Impacto | Corrección |
|---|---|---|---|---|---|---|
| SEC-001 | CRITICAL | Datos / RLS | Tablas educativas legibles sin autenticación | REST anónimo devolvió conteos reales; políticas `SELECT true` en `students`, `grades`, `profiles`, `courses`, `subjects` | Fuga de datos personales y académicos | Eliminar todas las políticas heredadas, crear políticas explícitas por rol/tenant y probar anon/authenticated |
| SEC-002 | CRITICAL | Multi-tenant | Políticas de escritura para cualquier autenticado y políticas permisivas acumuladas | Base real: `students_write`, `grades_write`, `courses_write`, etc.; 235 avisos de políticas múltiples | Lectura/modificación/eliminación cross-tenant e IDOR | Reemplazar todo el conjunto RLS; no añadir políticas sobre las actuales |
| SEC-003 | CRITICAL | Storage | Fotos de estudiantes/institución son públicas y la escritura no está aislada por tenant | `getPublicUrl()` en `app/src/lib/studentUtils.js:110`; políticas Storage públicas o para cualquier autenticado | Exposición de imágenes y sobrescritura entre instituciones | Buckets privados, rutas prefijadas por tenant, validación RLS y URLs firmadas |
| SEC-004 | HIGH | RPC | Funciones `SECURITY DEFINER` ejecutables por `anon`; `search_path` mutable | 48 WARN del Security Advisor; incluye `provision_tenant_wizard`, `invite_teacher_by_email`, copias de años e impersonación | Superficie de escalación y ejecución privilegiada | `REVOKE EXECUTE FROM PUBLIC, anon`; grants mínimos; `SET search_path`; mover funciones privilegiadas a esquema privado cuando aplique |
| SEC-005 | HIGH | PWA / privacidad | Service Worker cachea cualquier respuesta Supabase durante 7 días | `app/vite.config.js:23-35` | Datos autenticados pueden persistir y reaparecer en dispositivos compartidos; información obsoleta | No cachear API/auth/storage privados; precache solo de assets estáticos |
| AUTH-001 | HIGH | Auth / onboarding | Si falta perfil, el frontend crea automáticamente un perfil `teacher` sin colegio | `app/src/stores/auth.js:82-125` | Usuarios auto-registrados inconsistentes; bypass del proceso de invitación | Desactivar bootstrap cliente; crear perfiles mediante flujo backend controlado/invitación |
| AUTH-002 | HIGH | Impersonación | La UI reemplaza el perfil local, pero el JWT sigue siendo del superadmin | `app/src/stores/auth.js:138-170` | Acciones aparentan ser de tenant pero se ejecutan con privilegios globales | Retirar la función hasta disponer de sesión delegada segura o modo soporte solo lectura en backend |
| LEGAL-001 | CRITICAL | Comercial / privacidad | La política pública afirma aislamiento estricto que es falso | `app/src/views/Privacy.vue:18` frente a SEC-001 | Representación comercial falsa y riesgo contractual | Retirar afirmación inmediatamente; revisión jurídica posterior |

# Base de datos

## Estructura e integridad

- **VERIFICADO:** PostgreSQL/Supabase con RLS habilitado en 29 tablas públicas.
- **VERIFICADO:** las entidades principales tienen PK y la mayoría de relaciones poseen FK.
- **VERIFICADO:** `grades` tiene `CHECK score 0..10` y unique `(student_id, grade_definition_id)`, compatible con `upsert` insert/update.
- **VERIFICADO:** los datos actuales no presentan cruces de colegio en estudiantes, curso-asignatura, definiciones, notas o alertas.
- **PARCIAL:** 21/21 asignaciones curso-asignatura carecen de docente. No es corrupción referencial, pero impide validar permisos docentes y el flujo académico completo.
- **RIESGO:** muchas columnas `school_id` siguen siendo nullable; el aislamiento depende de triggers y RLS, no de invariantes completas.
- **RIESGO:** operaciones críticas del frontend son secuenciales y no atómicas.

## Índices

- **RIESGO:** 38 foreign keys sin índice de cobertura, incluyendo `school_id` en tablas frecuentes.
- **RIESGO:** índices duplicados en `grades.grade_definition_id`, `grades.student_id` y `students.course_id`.
- **PARCIAL:** existen índices útiles para notas, búsquedas de estudiantes y alertas, pero faltan índices tenant-first en varias rutas frecuentes.

## RLS

- **RIESGO CRÍTICO:** RLS está habilitado, pero las políticas desplegadas son incompatibles y acumulativas.
- La migración local `migrations/11_secure_rls_policies.sql` no elimina los nombres realmente presentes (`students_read`, `students_write`, `Anyone can read students`, etc.).
- La migración 11 tampoco impone permisos granulares: su `FOR ALL` permite cualquier operación a todo usuario autenticado del tenant.
- Alertas DECE requieren políticas separadas de mínimo privilegio; no deben compartir el acceso genérico académico.

## Migraciones

- **RIESGO:** Supabase reporta cero migraciones registradas.
- Los archivos `02`–`11` existen localmente, pero la base real no coincide con todos ellos; por ejemplo, `tenant_features` y `tenant_limits` no existen.
- No se demostró que una base nueva pueda recrearse desde cero.
- No existe rollback documentado ni prueba automatizada de migraciones.

## Backups y restore

- **NO VERIFICABLE:** no se obtuvo evidencia de frecuencia, retención, cifrado ni ubicación de backups.
- **NO VERIFICABLE:** no existe procedimiento de restore probado en el repositorio.
- RPO y RTO no están definidos.

# Seguridad

## Autenticación

- **VERIFICADO:** Supabase Auth, persistencia local, refresh token y recuperación de contraseña están conectados.
- **PARCIAL:** logout y expiración se manejan en cliente.
- **NO VERIFICABLE:** MFA, invalidación administrativa de sesiones, configuración de expiración JWT y rate limiting efectivo.
- **RIESGO:** la pantalla ofrece registro público de docentes, pero el alta institucional controlada no está cerrada.

## Autorización

- **PARCIAL:** router Vue oculta/redirige rutas por `admin` y `superadmin` (`app/src/router/index.js`).
- **RIESGO:** el mapa de permisos en `app/src/lib/permissions.js` es frontend; la base no lo hace cumplir correctamente.
- **RIESGO:** períodos bloqueados tienen lógica/política histórica, pero políticas abiertas posteriores la anulan.
- **RIESGO DECE:** cualquier autenticado puede escribir `student_alerts` por una política desplegada.

## Secretos

- **VERIFICADO:** `.env.local` y `PassSupabase*.txt` están ignorados; no están rastreados.
- **VERIFICADO:** los scripts administrativos leen `SUPABASE_SERVICE_KEY` desde entorno y no la incluyen hardcodeada.
- **PARCIAL:** no se auditó el historial Git completo ni la rotación de claves.

## Headers

- **NO VERIFICABLE:** no hay URL/hosting de producción identificados para comprobar CSP, HSTS, clickjacking, Referrer-Policy o Permissions-Policy.
- **NO IMPLEMENTADO en repositorio:** no existe configuración de headers de producción.

## Archivos

- **RIESGO:** la subida de fotos confía en nombre/extensión, no valida tamaño ni MIME real (`app/src/lib/studentUtils.js:98-114`).
- **RIESGO:** se usan URLs públicas para fotos de estudiantes y representantes.
- **RIESGO:** `xlsx@0.18.5` tiene advisories HIGH y no dispone de fix vía el registro npm usado.

## Auditoría y logs

- **PARCIAL:** existen `audit_log` e `impersonation_logs`.
- **RIESGO:** no se verificaron triggers de auditoría para cambios reales de notas; la base solo mostró triggers de asignación `school_id`.
- **RIESGO:** numerosos `console.log/error/warn` son el mecanismo actual de diagnóstico del frontend.
- **NO IMPLEMENTADO:** error tracking, métricas, alertas y logs centralizados de frontend.

# Funcionalidad

| Módulo | Estado | Evidencia / limitación |
|---|---|---|
| Login / logout | PARCIAL | Login y guard existen; E2E de redirección pasa; no se probó credencial real |
| Recuperación de contraseña | PARCIAL | Código conectado; entrega de email no verificada |
| Dashboard | PARCIAL | Existe; no se recorrió autenticado |
| Cursos | PARCIAL | CRUD existe; 9 filas reales; borrado definitivo y errores no transaccionales |
| Paralelos | PARCIAL | Embebidos en curso/nombre; no hay entidad claramente independiente |
| Asignaturas | PARCIAL | CRUD y asignación existen; 21 asignaciones sin docente |
| Estudiantes | PARCIAL | CRUD, importación y PDF; 1 fila real; borrado masivo definitivo |
| Familias | PARCIAL | Vista/reportes; no hay modelo de cuentas de representantes verificado |
| Docentes | NO IMPLEMENTADO/PARCIAL | Perfiles y `teacher_id`; no hay flujo E2E completo validado |
| Calificaciones | RIESGO | Upsert soporta INSERT/UPDATE, pero falla un test de proyecto y guardado delete+upsert no es atómico |
| Bloqueo de períodos | RIESGO | Campo `is_locked` existe, pero RLS permisivo permite saltarlo |
| Actas | NO IMPLEMENTADO/PARCIAL | Reportes/PDF existen; no hay módulo/transacción de acta publicada verificada |
| Reportes | PARCIAL | Código PDF/Excel; no probado con gran volumen ni segundo tenant |
| Alertas DECE | RIESGO | CRUD existe; permisos backend insuficientes |
| Perfil | PARCIAL | Edición y foto; storage público |
| Usuarios / roles | RIESGO | Dos modelos de roles coexistentes (legacy y RBAC); base/frontend no están alineados |
| Super Admin | PARCIAL | UI y RPCs; impersonación insegura; tablas/fallbacks no desplegados |
| Colegios | PARCIAL | Una institución real; alta no probada E2E |
| Planes | RIESGO | Base: trial/basic/pro/enterprise con precios distintos; landing: 500/1000/2000 |
| Suscripciones | PARCIAL | Tabla y una suscripción active; sin automatización de cobro |
| Kushki | NO IMPLEMENTADO | Sin SDK, backend, tokenización ni webhook |
| Soporte | PARCIAL | Contenido comercial/contacto; sin tickets ni SLA verificable |

# Transacciones y concurrencia

- `saveGrades` primero borra y luego hace upsert (`app/src/composables/useGradesPage.js:897-900`); si la segunda operación falla quedan notas eliminadas.
- La importación Excel inserta lote y luego actualiza fila a fila (`app/src/views/Courses.vue:672-679`); una falla produce importación parcial.
- Crear/editar estudiante y subir dos fotos usa varias operaciones (`app/src/views/Students.vue:381-415`) sin compensación.
- Los controles `isSaving` previenen doble clic local, pero no aportan versionado optimista ni detección de sobrescritura entre docentes.
- No se ejecutaron pruebas con dos docentes simultáneos por falta de cuentas/fixtures autorizados.

# Responsive y accesibilidad

## Responsive

- **VERIFICADO:** `/login`, `/planes`, `/terminos` y `/privacidad` se evaluaron en 320×568, 360×800, 375×812, 390×844, 430×932, 768×1024, 1024×768, 1366×768, 1440×900, 1920×1080 y 2560×1440.
- **VERIFICADO:** login sin overflow en las 11 resoluciones.
- **RIESGO:** `/planes` mide 364 px en viewports de 320 y 360 px; hay scroll horizontal de página.
- **NO VERIFICABLE:** todas las rutas autenticadas en las 11 resoluciones, porque no se usaron credenciales reales.
- **PARCIAL:** el layout principal implementa drawer móvil y targets de 44 px en el menú.

## Accesibilidad

- **RIESGO:** inputs del login tienen labels visuales sin `for`/`id`; Playwright detectó 2/2 sin asociación.
- **RIESGO:** `/planes` tiene un botón sin nombre accesible.
- **RIESGO:** se detectaron targets menores de 24 px en login, landing y páginas legales.
- **RIESGO:** no hay landmark `<main>` en las rutas públicas revisadas.
- **PARCIAL:** idioma `es`, `alt` de imagen principal y varios `aria-label` existen.
- **NO VERIFICABLE:** lector de pantalla, NVDA/TalkBack, alto contraste y zoom al 200%.
- No se afirma cumplimiento WCAG 2.2 AA.

# Performance

- Build: chunk principal 449.85 kB (138.41 kB gzip), `Courses` 371.12 kB (124.06 kB gzip), CSS principal 115.66 kB.
- PWA precache: ~2.4 MiB.
- `xlsx` contribuye a peso y vulnerabilidades; debe aislarse o reemplazarse.
- 38 FK carecen de índice de cobertura; faltan varios índices tenant-first.
- Se detectaron índices duplicados.
- **NO VERIFICABLE:** LCP, INP y CLS de producción; no existe URL de despliegue ni RUM.

# SaaS

## Planes y límites

- Landing: Implementación USD 350; Plan 500 USD 89; Plan 1000 USD 129; Plan 2000 USD 179; anual 10 mensualidades.
- Base real: trial USD 0, basic USD 29.99, pro USD 79.99, enterprise USD 199.99.
- **RIESGO:** catálogo comercial y base de datos no coinciden.
- `tenant_limits` y `tenant_features` no existen en la base real.
- No hay trigger/RPC que impida superar estudiantes; los límites son no implementados.

## Suscripciones y pagos

- `plans`, `subscriptions` y `payments` existen.
- No existen `invoices`, `payment_events`, `subscription_history` ni `webhook_events`.
- Kushki no está integrado.
- No hay idempotencia, firma, reintentos ni manejo de eventos fuera de orden.
- No existe integración SRI verificada.

## Trial y suspensión

- Estados de tenant existen como enum y hay historial de estado.
- No se verificó enforcement de suspensión en toda la API; el router no bloquea por estado del colegio.
- El trial de 15 días se anuncia comercialmente, pero no hay fecha/expiración automática verificada.

# Infraestructura

- **VERIFICADO:** Supabase activo y saludable en `us-west-2`, PostgreSQL 17.
- **NO VERIFICABLE:** proveedor de hosting frontend, DNS, CDN, HTTPS final y entorno de producción.
- **NO IMPLEMENTADO:** pipeline CI/CD en el repositorio.
- **NO IMPLEMENTADO:** scripts `lint` y `typecheck` en el frontend Vue.
- **NO VERIFICABLE:** rollback de despliegue.
- **NO VERIFICABLE:** política de backups/restore.
- **NO IMPLEMENTADO:** health check externo; `HealthTab.vue` solo hace consultas desde cliente.

# Testing

- Unit: 36 pruebas; 1 falla en cálculo académico.
- E2E: 1 escenario, únicamente redirección sin sesión.
- No hay tests de integración DB/RLS, dos tenants, roles, límites, suspensión, webhooks o restore.
- No hay pruebas de carga ni concurrencia.
- No existe cobertura publicada ni umbral en CI.

# Riesgos comerciales

1. Datos académicos y personales accesibles anónimamente.
2. Política de privacidad contiene afirmaciones técnicamente falsas.
3. Precios/planes de la base no coinciden con la oferta comercial.
4. No se aplican límites de plan.
5. No existe cobro Kushki ni facturación automatizada.
6. No hay evidencia de backups restaurables ni operación con SLA.
7. Suite de pruebas académicas no está verde.
8. No hay proceso reproducible de migración/CI/CD.

# Roadmap de corrección

## P0 — Antes de vender

1. Cerrar inmediatamente acceso anónimo y políticas RLS permisivas.
2. Aplicar autorización tenant + rol por SELECT/INSERT/UPDATE/DELETE, con políticas DECE separadas.
3. Revocar ejecución pública de funciones privilegiadas y fijar `search_path`.
4. Hacer privados los buckets con datos personales y aislar rutas por tenant.
5. Eliminar caché PWA de Supabase/API y limpiar caches previos.
6. Retirar la afirmación falsa de aislamiento de la política pública.
7. Deshabilitar bootstrap de perfiles desde cliente y la impersonación insegura.
8. Corregir el test/cálculo interdisciplinario y dejar la suite verde.
9. Añadir pruebas RLS reproducibles para anon, tenant A, tenant B, docente, admin y DECE.
10. Verificar que no haya exposición anónima después del despliegue.

## P1 — Antes del primer cliente

1. Desplegar catálogo comercial correcto y enforcement real de límites.
2. Hacer transaccionales notas, importación, matrícula y alta de institución.
3. Completar asignaciones docentes y probar flujo académico E2E.
4. Implementar suspensión backend y trial de 15 días.
5. Validar archivos por tamaño/MIME, reportar importaciones parciales y sustituir `xlsx` vulnerable.
6. Definir y probar backup/restore, RPO y RTO.
7. CI con lint, tests, build, migraciones y E2E crítico.
8. Revisar términos/privacidad con asesoría jurídica.

## P2 — Primeros 30 días

1. Corregir accesibilidad y overflow móvil.
2. Añadir observabilidad, error tracking, métricas y health checks.
3. Optimizar índices con `EXPLAIN (ANALYZE, BUFFERS)` sobre consultas reales.
4. Reducir bundle y carga diferida de Excel/PDF.
5. Ampliar pruebas CRUD, errores, grandes volúmenes y concurrencia.

## P3 — Escalamiento

1. Kushki con tokenización, backend, firma, idempotencia y reintentos.
2. Facturación/invoices y conciliación.
3. Pruebas de carga y objetivos de capacidad.
4. SLO/SLA, alertas y ejercicios de recuperación.
5. Impersonación delegada segura, temporal y auditada, si sigue siendo necesaria.

# Criterio de aceptación pendiente

El sistema no podrá marcarse listo hasta demostrar: 0 CRITICAL conocidas, prueba real de dos tenants sin fuga, roles backend, notas y actas críticas en verde, restore probado, mobile/desktop autenticado, build/tests/CI exitosos, observabilidad mínima y despliegue/migraciones reproducibles.

# Limitaciones de esta auditoría

- Solo hay un tenant real; no se crearon datos ni usuarios adicionales durante la fase de auditoría.
- No se proporcionó URL de producción ni credenciales de prueba por rol.
- No se ejecutaron operaciones destructivas, pagos, emails ni restores.
- No se afirma capacidad, SLA, cumplimiento legal ni WCAG sin pruebas adicionales.

# Apéndice de remediación P0 — 8 de agosto de 2026

Este apéndice registra cambios posteriores a la fotografía original de la auditoría. Los hallazgos anteriores se conservan para trazabilidad.

## P0 completado

- Aplicadas en Supabase las migraciones administradas `p0_security_lockdown` y `p0_rpc_hardening`.
- Reemplazadas todas las políticas permisivas de las 29 tablas públicas por políticas explícitas `authenticated`, separadas por operación.
- Verificado por prueba transaccional: lectura del tenant propio, denegación del tenant extranjero, rechazo de escritura cruzada y cero filas para `anon`.
- Verificado por REST `HEAD` con la clave pública: `students`, `grades`, `profiles`, `courses`, `subjects` y `student_alerts` devuelven `Content-Range: */0`.
- Cero políticas para `anon/public`, cero políticas públicas con condición `true` y cero funciones `SECURITY DEFINER` ejecutables por `anon`.
- Las RPC de inicio/fin de impersonación ya no son ejecutables por usuarios autenticados; el frontend de impersonación fue retirado.
- Los buckets `institution-assets`, `student-photos` y `profile-photos` son privados, con rutas nuevas por tenant/usuario, validación JPEG/PNG/WebP de hasta 5 MB y URLs firmadas de una hora.
- Eliminada la caché de respuestas Supabase del service worker y la persistencia semanal de Vue Query en IndexedDB; el arranque limpia la caché heredada.
- Eliminados el registro público, la creación automática de perfiles `teacher` y el flujo heredado de vinculación por email.
- Corregido el cálculo de proyecto interdisciplinario y sustituida la afirmación absoluta de privacidad.
- Suite local: **44/44 pruebas unitarias pasan**; build de producción correcto.

## Resultado de advisors después del P0

- Seguridad: de **58** avisos a **18**. Los 16 avisos `authenticated_security_definer_function_executable` restantes corresponden a predicados RLS/RPC intencionales que validan identidad y permiso internamente; quedan como deuda para mover helpers a un esquema no expuesto. También permanecen `pg_trgm` en `public` y la protección de contraseñas filtradas desactivada.
- Rendimiento: de **354** avisos a **61**. Desaparecieron los 235 avisos de políticas permisivas múltiples y los 58 avisos de `auth_rls_initplan`; permanecen índices/FK para optimización P2.

## Estado comercial actualizado

El **P0 técnico de confidencialidad está cerrado**, pero el producto global sigue **NO VENDIBLE** hasta completar como mínimo P1: cobro/facturación real, enforcement de planes, operaciones académicas transaccionales, CI/CD, backup/restore probado, asignación docente completa y pruebas autenticadas por rol en navegadores reales.

# Apéndice de remediación P1–P2 — 9 de agosto de 2026

Este apéndice actualiza la evidencia técnica posterior al P0 sin borrar la fotografía histórica del informe.

## P1 implementado

- Catálogo comercial unificado en base y frontend: planes de 500, 1000 y 2000 estudiantes, ciclo mensual/anual, prueba de 15 días e implementación de USD 350.
- Límite de estudiantes aplicado dentro de la base con bloqueo transaccional; el máximo contratado no puede alterarse al margen del plan.
- Ciclo de suscripción implementado para `trial`, `active`, `past_due`, `grace_period`, `suspended`, `cancelled` y `archived`, con tarea programada y bloqueo backend.
- Importación de estudiantes, matrícula y guardado de notas numéricas/cualitativas migrados a RPC transaccionales.
- Altas, cambios y eliminaciones de supletorios migrados a una sola RPC transaccional; las escrituras directas quedaron revocadas y el lote completo se valida antes de modificar el acta.
- Asignaciones curso–asignatura–docente guardadas atómicamente y protegidas contra eliminación cuando ya existen datos académicos.
- Alta segura de instituciones e invitación de docentes mediante Edge Functions con JWT, comprobación de rol/tenant y auditoría.
- Cobranza manual operativa con registro de pagos, referencia, precio acordado, estado de implementación e historial de estado del tenant.
- CI reproducible con pruebas, build y presupuesto de bundle; scripts documentados de backup/restore y health check de plataforma.

## P2 técnico completado

- Corregido el overflow comercial a 360 px y añadida prueba Playwright móvil; controles visibles con nombre accesible.
- Añadidos salto a contenido, landmark principal, estados ARIA de navegación, foco visible global, movimiento reducido, diálogos semánticos y enlaces de navegación utilizables con teclado.
- Eliminadas imágenes decorativas remotas y hojas de fuentes de terceros que bloqueaban renderizado.
- Eliminado `xlsx@0.18.5`; importación `.xlsx` bajo demanda con `read-excel-file`, límite de 5 MB y exclusión del parser opcional del precache PWA.
- Compilación del 9 de agosto: chunk principal **133.8 KiB gzip** con umbral CI de 150 KiB; CSS principal **19.3 KiB gzip** con umbral de 50 KiB.
- Creados 40 índices de cobertura de FK, retirados 3 índices duplicados, consolidadas políticas SELECT duplicadas y movida `pg_trgm` al esquema `extensions`.
- Advisors de rendimiento reducidos a avisos informativos de índices todavía no usados; no permanecen avisos de FK sin índice, políticas múltiples ni índices duplicados.
- Observabilidad autenticada centralizada mediante `client_error_events`: sin mensajes, stack traces, parámetros de URL ni identificadores de rutas; identidad impuesta por trigger, RLS forzado, límite de 20 eventos por usuario/minuto, retención automática de 90 días y métrica integrada en el panel de salud.
- Medición `EXPLAIN (ANALYZE, BUFFERS)` sobre datos reales: estudiantes **0.203 ms**, asignaciones docentes **2.173 ms**, libro de notas **3.364 ms** y suscripción/pagos **2.635 ms**. No hubo lecturas de disco ni archivos temporales en estas ejecuciones.
- Verificación local final: **68/68 pruebas**, build correcto, presupuesto de recursos aprobado, prueba Playwright móvil aprobada y **0 vulnerabilidades npm de producción**.

## Límites de la evidencia P2

Los tiempos anteriores prueban planes correctos sobre el volumen actual, que es pequeño; no acreditan capacidad a escala. La prueba de carga, concurrencia multiusuario y objetivos de capacidad pertenecen a P3. Las rutas autenticadas aún requieren validación en navegador con cuentas controladas de cada rol.

## Estado comercial actualizado

La base técnica para un piloto controlado está sustancialmente implementada, pero todavía no se declara el producto vendible. Permanecen como puertas externas o P3: restore real cronometrado, prueba autenticada de dos tenants/roles en navegador, protección de contraseñas filtradas en Supabase, revisión jurídica y activación/certificación del medio de pago. La facturación manual puede sostener un piloto únicamente si el proceso comercial la acepta por escrito; el backend de eventos Kushki ya está implementado, pero el checkout y el comercio todavía no están activos.

# Apéndice P3 en curso — 9 de agosto de 2026

## Facturación y conciliación implementadas

- Migración `p3_billing_ledger` aplicada en Supabase con `invoices`, `invoice_payment_allocations` y `payment_events`, todas con RLS.
- Todo pago completado con número de factura crea o concilia factura dentro de la misma transacción.
- Los eventos de proveedor son únicos por proveedor/referencia y un replay con contenido distinto se rechaza.
- RPC de ingestión y finalización disponibles exclusivamente para `service_role`; usuarios anónimos y autenticados no pueden ejecutarlas.
- Prueba transaccional en Supabase aprobada: pago manual, factura pagada, asignación, evento original, duplicado idempotente, replay alterado rechazado y rollback total.
- SuperAdmin puede consultar las últimas 50 facturas conciliadas por institución desde una interfaz adaptable a móvil.

## Backend Kushki implementado; activación comercial pendiente

- Edge Function `kushki-webhook` versión 5 desplegada con `verify_jwt=false` porque aplica autenticación HMAC propia del proveedor.
- Comprueba `X-Kushki-Key`, `X-Kushki-Id` y `X-Kushki-Signature` en tiempo constante, limita el cuerpo a 256 KiB y no almacena el cuerpo completo ni datos de tarjeta.
- La migración `p3_kushki_event_processing` procesa `SALE/APPROVAL` de forma idempotente, exige `school_id`, `invoice_number`, USD e importe exacto, concilia la factura y activa la suscripción dentro de una sola transacción. Los rechazos se registran sin crear pagos.
- La migración `p3_kushki_refunds` procesa `REFUND` y `VOID`, evita sobredevoluciones, admite devolución parcial y total, actualiza pago/factura y aplica siete días de gracia únicamente cuando se devuelve por completo el período vigente.
- Las pruebas SQL transaccionales validaron aprobación, duplicado, rechazo, devolución total, anulación rechazada y rollback; el conteo vivo posterior permanece en cero pagos, facturas, eventos y devoluciones de prueba.
- Falta configurar Merchant ID y firma del webhook, ejecutar UAT y elegir la modalidad comercial habilitada por Kushki. Mientras falten secretos, el endpoint responde 503 para evitar aceptar eventos sin persistirlos; este comportamiento fue verificado contra la versión 5 desplegada.
- El checkout/cobro recurrente no se declara implementado; depende de afiliación, credenciales y certificación del proveedor.

## SLO y capacidad preparados, no acreditados

- Definidos SLO piloto: 99.5% de disponibilidad, lectura académica p95 ≤ 800 ms, escritura p95 ≤ 1.5 s, error < 1% y webhook p95 ≤ 500 ms.
- Añadida herramienta de carga sin dependencias, limitada a GET/HEAD, con confirmación explícita, timeout, concurrencia acotada y evaluación p50/p95/p99.
- La protección fue comprobada: sin `LOAD_TEST_ACKNOWLEDGE` la herramienta se cancela antes de generar tráfico.
- No existe aún staging autorizado ni datos sintéticos suficientes para acreditar capacidad; por tanto P3C y la puerta final permanecen pendientes.
- Cierre de regresión vigente: **80/80 pruebas**, **2/2 E2E** —incluida la vista de precios móvil—, build correcto, presupuesto de bundle aprobado (entrada principal 134.6 KiB gzip de 150 KiB) y **0 vulnerabilidades npm de producción**.
- Advisors posteriores a las migraciones 25 y 26: seguridad conserva 26 advertencias de funciones `SECURITY DEFINER` autenticadas intencionales y la protección de contraseñas filtradas pendiente; rendimiento queda en 56 avisos `INFO`, todos por índices aún no usados y sin FK sin cobertura.

## Observabilidad reforzada después de P3

- Migraciones `p2_client_observability` y `p2_client_observability_indexes` aplicadas y registradas en Supabase, incluida la cobertura de la FK/consulta de rate limit por usuario.
- La prueba SQL viva acreditó identidad server-side, RLS, lectura exclusiva de Platform Admin, rechazo anónimo, límite de 20 eventos/minuto, métrica de salud y rollback total.
- Estado vivo posterior: cero eventos de fixture, RLS forzado, tarea de retención activa, `anon` sin `INSERT` y `authenticated` sin `UPDATE`.
- Antes del cierre de supletorios, Security Advisor conservaba los mismos 27 avisos previos y no había añadido hallazgos; Performance Advisor quedó en 59 avisos `INFO`, todos por índices sin uso todavía y sin FK descubiertas.

## Integridad del cierre académico reforzada

- Migración `p1_atomic_supplementary_scores` aplicada y registrada en Supabase.
- `save_supplementary_batch` valida tenant, permiso de notas y administración, curso, rango 0–10, tamaño, duplicados y contradicciones antes de ejecutar altas y borrados en una única transacción.
- Se revocaron `INSERT`, `UPDATE` y `DELETE` directos sobre `supplementary_exams` para `anon` y `authenticated`; solo la RPC autenticada puede escribir.
- La prueba SQL viva acreditó alta, rechazo de escritura directa, rollback completo de un lote inválido y borrado atómico.
- Estado actual de advisors: 28 avisos de seguridad —27 RPC `SECURITY DEFINER` autenticadas e intencionales, incluida esta operación atómica, más la protección de contraseñas filtradas pendiente— y 59 avisos informativos de índices sin uso.

## Cabeceras de despliegue preparadas

- Añadidas configuraciones equivalentes en `app/vercel.json` y `app/public/_headers` para CSP, HSTS, `nosniff`, anti-iframe, Referrer Policy, Permissions Policy y aislamiento del opener.
- La CSP no permite `unsafe-eval`, restringe conexiones a Supabase y mantiene bloqueados objetos e iframes; los dominios Kushki deberán habilitarse de forma mínima cuando se confirme la modalidad.
- El JSON de Vercel fue parseado correctamente y el build contiene `dist/_headers` con CSP y sin `unsafe-eval`.
- La presencia y eficacia de las cabeceras quedó comprobada posteriormente sobre el despliegue Hostinger.

## Despliegue Hostinger actualizado y verificado

- URL suministrada: `https://sandybrown-alpaca-347737.hostingersite.com/login`.
- `/`, `/login`, `/planes` y una ruta inexistente devuelven 200 con el fallback SPA, por lo que el enrutamiento profundo actual funciona.
- El sitio publicado referencia `assets/index-DZpjXazj.js`; el build vigente referencia `assets/index-DZYX11v_.js`. El bundle remoto no contiene `client_error_events`, `save_supplementary_batch` ni el ledger de eventos de pago, confirmando que es anterior a las remediaciones finales.
- En producción solo se observó `Content-Security-Policy: upgrade-insecure-requests`; faltan HSTS, anti-iframe, `nosniff`, Referrer Policy y Permissions Policy.
- `app/public/.htaccess` fue ampliado para Hostinger Web/Cloud con HTTPS, fallback Vue, cabeceras y políticas diferenciadas de caché. El archivo está presente dentro de `app/dist/.htaccess`.
- Paquete preparado: `hostinger-deploy-20260809-ready.zip`, 38 entradas, 1,420,579 bytes, SHA-256 `A9CD8F86B0A1155D9C6192347226B1533D0759D6A36A40CE663D2E4791183D01`; contiene `index.html`, `.htaccess` y el asset principal vigente.
- Regresión previa al paquete: **81/81 pruebas**, **2/2 E2E**, build y presupuesto de bundle aprobados.
- Después de reemplazar `public_html`, Hostinger sirve `assets/index-DZYX11v_.js` en `/`, `/login`, `/planes` y `/grades`, todas con 200 y fallback SPA correcto.
- Se verificaron por HTTPS CSP completa, HSTS, `DENY`, `nosniff`, Referrer Policy, Permissions Policy, COOP y `Cache-Control: no-store` para HTML.
- Playwright remoto contra Hostinger: **2/2 E2E** aprobadas —redirección de ruta protegida y precios móvil sin overflow—. La puerta técnica de despliegue queda cerrada.
- El subdominio gratuito `hostingersite.com` sigue siendo temporal y no constituye identidad comercial propia.

## Puertas que faltan para declarar el producto vendible

| Puerta | Evidencia exigida | Dependencia actual |
|---|---|---|
| Kushki UAT | Aprobación, rechazo, reintento, refund y void conciliados contra la Consola; p95 del webhook dentro del SLO | Afiliación, modalidad y secretos configurados directamente por el propietario del comercio |
| Capacidad | Ensayo autorizado con datos sintéticos, 20 usuarios concurrentes, 500 solicitudes, 0 errores y p95 dentro del objetivo | URL Hostinger disponible; falta autorización expresa de carga y datos sintéticos |
| Restore | Backup válido restaurado en una base temporal, pruebas SQL aprobadas y duración menor a cuatro horas | Cliente PostgreSQL, URL temporal y backup real |
| Aislamiento autenticado | Recorrido de administrador/docente en dos tenants y tenant suspendido sin cruce de datos | Cuentas controladas o invitaciones de prueba |
| Auth | Advisor sin `auth_leaked_password_protection` | Activar protección de contraseñas filtradas en el panel de Supabase |
| Legal/fiscal | Términos, privacidad, tratamiento de datos educativos, comprobantes y obligaciones SRI aprobados | Revisión profesional aplicable a Ecuador |
| Marca/dominio | Marca diferenciada, dominio propio, DNS/SSL y redirección desde el host temporal | `EduCore` ya es usado por múltiples plataformas escolares; falta decidir una marca distinguible antes de comprar |

Hasta cerrar esas seis evidencias, el estado correcto es **listo para piloto controlado con facturación manual**, no venta general ni cobro automático.
