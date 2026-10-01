# Auditoría de roles y recuperación funcional — LOGREVA

Fecha: 10 de agosto de 2026  
Proyecto Supabase auditado: `webnotasEmilioIsaias`  
Estado: correcciones de base de datos aplicadas; frontend y Edge Function preparados para publicación.

## Resultado ejecutivo

La información académica no había sido eliminada y el superadministrador no estaba bloqueado por RLS. El usuario propietario podía leer globalmente las tablas críticas. El fallo principal era una inconsistencia de integridad: las siete calificaciones existentes apuntaban a una definición válida, pero sus columnas directas `course_subject_id` y `quarter_id` no coincidían con esa definición.

Se repararon las siete filas, se impidió que el problema vuelva a ocurrir mediante un trigger privado y se establecieron restricciones `NOT NULL`. Después de la migración existen cero dimensiones nulas y cero discrepancias.

La segunda causa era arquitectónica: PostgreSQL ya tenía RBAC canónico, pero el router, el menú y varias vistas decidían el acceso con `profiles.role`. El frontend ahora obtiene un contexto de autorización RLS-aware desde PostgreSQL, deniega por defecto y presenta únicamente las rutas y acciones permitidas.

## Causas raíz comprobadas

### 1. Dimensiones de calificación desincronizadas

`save_grade_batch` validaba la relación mediante `grade_definitions`, pero escribía únicamente `student_id`, `grade_definition_id` y `score`. Las columnas directas de materia/curso y periodo quedaban nulas o heredaban valores incoherentes.

Consecuencia: las consultas basadas en `grade_definition_id` podían mostrar notas, mientras que las rutas de autorización que validaban las dimensiones directas podían rechazar actualizaciones institucionales.

Corrección aplicada:

- reparación de filas existentes desde `grade_definitions`;
- trigger privado `private.synchronize_grade_dimensions_from_definition`;
- validación de mismo tenant y mismo curso entre estudiante y definición;
- `NOT NULL` en `student_id`, `grade_definition_id`, `course_subject_id` y `quarter_id`.

### 2. Dos fuentes de verdad para autorización

La base usaba `user_platform_roles`, `tenant_memberships`, `tenant_roles`, `role_permissions` y RLS. El navegador usaba comparaciones como `profile.role === 'superadmin'` y una matriz estática que incluso permitía al docente crear y editar estudiantes, contrario al backend.

Corrección aplicada:

- RPC `get_my_access_context()` con `SECURITY INVOKER` y `search_path` fijado;
- contexto canónico en Pinia;
- permisos por códigos reales, por ejemplo `students.read`, `grades.update` y `reports.read`;
- router, menú, dashboard y perfil conectados al mismo contexto;
- pantalla 403 explícita;
- acciones de estudiantes ocultas y protegidas también en sus handlers;
- eliminación del rol docente como fallback implícito.

### 3. Riesgo de mezcla visual para el propietario global

RLS permite correctamente al propietario global leer todos los tenants. Varias consultas institucionales no incluían un filtro explícito, por lo que al crecer a varias instituciones la UI podía mezclar resultados aunque la autorización fuera válida.

Corrección preparada:

- `activeSchoolId` validado y persistido por usuario;
- acción “Abrir espacio institucional” desde la consola SaaS;
- filtros `school_id` en consultas académicas principales;
- `school_id` explícito en nuevas escrituras, importaciones y activos de almacenamiento.

### 4. Invitaciones ligadas al perfil heredado

La Edge Function de invitación obtenía siempre la institución desde `callerProfile.school_id`. Esto impedía que el propietario global trabajara con el tenant seleccionado y mantenía una decisión de autorización basada en roles heredados.

Corrección preparada:

- el cliente envía el tenant activo;
- la función valida `is_platform_admin()` y `has_tenant_permission('users.invite')`;
- un administrador institucional solo puede invitar en su propio tenant;
- el propietario de plataforma puede elegir un tenant activo;
- la clave de servicio permanece únicamente dentro de la Edge Function.

## Matriz funcional verificada

| Actor | Alcance | Resultado comprobado |
|---|---|---|
| Propietario de plataforma | Global | Conserva acceso aunque no tenga membresía tenant y puede leer otros tenants |
| Administrador institucional | Su institución | Puede leer y crear estudiantes dentro de su tenant; no ve estudiantes de otro tenant |
| Docente | Asignaciones y permisos concedidos | Puede leer estudiantes, leer/crear/actualizar notas y leer/exportar reportes; no puede crear, actualizar ni eliminar estudiantes |
| Usuario sin permiso de ruta | Ninguno | Recibe pantalla 403; no se simula acceso desde el frontend |

RLS sigue siendo la autoridad final. No se desactivó RLS, no se añadieron mocks y no se expuso `service_role` al navegador.

## Estado de datos después de la reparación

| Entidad | Cantidad |
|---|---:|
| Instituciones | 2 |
| Estudiantes | 1 |
| Cursos | 9 |
| Asignaturas | 7 |
| Definiciones de calificación | 190 |
| Calificaciones | 7 |
| Dimensiones de nota nulas | 0 |
| Dimensiones de nota inconsistentes | 0 |

El estudiante demo, sus cursos, materias, periodos, definiciones y siete calificaciones permanecen vinculados. La segunda institución existente no fue modificada ni eliminada.

## Migraciones aplicadas en Supabase

- `20260810174859_p1_grade_dimension_integrity`
- `20260810174904_p1_canonical_access_context`

Las migraciones locales fuente están en:

- `supabase/migrations/20260810155318_p1_grade_dimension_integrity.sql`
- `supabase/migrations/20260810162721_p1_canonical_access_context.sql`

## Evidencia de verificación

- Suite Vitest: 15 archivos, 99 pruebas aprobadas.
- Playwright: 4 pruebas end-to-end aprobadas en Chromium.
- Build Vite de producción: aprobado, 2.047 módulos transformados.
- Prueba SQL de integridad de notas: aprobada después de migrar.
- Prueba SQL de contexto canónico: aprobada después de migrar.
- Matriz SQL superadmin/admin/docente y tenant A/B: aprobada con rollback.
- Datos finales: 0 notas con dimensiones nulas o inconsistentes.

Archivos de prueba relevantes:

- `app/tests/authorization.test.js`
- `app/tests/authorizationIntegration.test.js`
- `app/tests/secureProvisioning.test.js`
- `migrations/tests/17_p1_role_matrix_test.sql`
- `migrations/tests/30_p1_grade_dimension_integrity_test.sql`
- `migrations/tests/31_p1_access_context_test.sql`

## Asesores de Supabase

El asesor de seguridad no reportó un error causado por las migraciones nuevas. Reportó 28 advertencias existentes:

- funciones `SECURITY DEFINER` públicas ejecutables por usuarios autenticados: son helpers RLS y endpoints RPC históricos; requieren una auditoría individual posterior antes de moverlos o revocar permisos, porque una revocación masiva rompería políticas y operaciones legítimas;
- protección de contraseñas filtradas desactivada: debe habilitarse desde la configuración de Auth de Supabase.

El asesor de rendimiento reportó 47 índices sin uso. Son avisos informativos en una base joven; no deben eliminarse sin estadísticas representativas de producción.

## Publicación pendiente

La base de datos ya está migrada. El sitio actualmente publicado en Hostinger todavía no contiene el frontend corregido y la Edge Function `invite-tenant-user` todavía debe desplegarse.

Paquete preparado para Hostinger:

`hostinger-deploy-20260810-rbac-grade-integrity.zip`

Después de publicar deben ejecutarse estas comprobaciones con cuentas reales:

1. superadmin: iniciar sesión, abrir cada institución desde la consola y confirmar que cambia el contexto;
2. administrador institucional: estudiantes, periodos, docentes y reportes de su tenant;
3. docente: calificaciones y reportes permitidos; acciones CRUD de estudiantes ausentes;
4. navegación directa a una ruta prohibida: respuesta visual 403;
5. guardar una nota y confirmar persistencia tras recargar;
6. generar libreta/acta del estudiante demo.

## Criterio de salida comercial

La reparación de datos y autorización crítica está completa. Para declarar esta versión publicada y vendible todavía se requiere:

- desplegar el ZIP nuevo en Hostinger;
- desplegar la Edge Function actualizada;
- ejecutar el smoke test autenticado de los tres roles;
- habilitar protección de contraseñas filtradas en Supabase Auth;
- conectar el dominio comercial definitivo y verificar HTTPS, redirecciones y correo de invitación.
