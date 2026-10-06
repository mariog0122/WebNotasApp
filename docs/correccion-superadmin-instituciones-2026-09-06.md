# CORRECCIÓN — GESTIÓN GLOBAL DE INSTITUCIONES

## Causa raíz

El listado de instituciones itera con la variable `t`, pero el botón de reactivación enviaba una variable inexistente llamada `tenant`. El manejador recibía `undefined`, caía en la validación de selección y mostraba el mensaje “Selecciona una institución antes de cambiar su estado”.

La misma función también conservaba como valor alternativo `selectedTenant`, un estado compartido por varios modales. Esto permitía que una acción global dependiera del último modal utilizado y creaba riesgo de actuar sobre una institución distinta a la fila pulsada.

## Flujo anterior

```text
Fila de Institución A
→ click Reactivar
→ executeStatusChange('active', tenant)
→ tenant no existe en el ámbito de la fila
→ fallback/validación sobre selectedTenant
→ mensaje de selección o riesgo de usar otro tenant
```

## Flujo corregido

```text
Fila de Institución A
→ click Reactivar
→ executeStatusChange('active', t)
→ targetInstitutionId = t.id
→ validación local de UUID y estado
→ RPC set_tenant_status(p_school_id = A)
→ autorización, bloqueo de fila e idempotencia en PostgreSQL
→ auditoría y actualización automática del listado
```

La suspensión usa `statusActionTarget`, dedicado exclusivamente a esa confirmación. `selectedTenant` se conserva para módulos, límites, pagos y facturas, donde sí representa el contexto del modal abierto.

## Archivos modificados

- `app/src/views/superadmin/TenantsTab.vue`
- `app/src/lib/superadminTenantStatus.js`
- `app/tests/superadminStatusRegression.test.js`
- `app/tests/billingOperations.test.js`
- `app/e2e/superadmin-tenant-status.spec.js`
- `supabase/migrations/20260907011738_harden_superadmin_tenant_status.sql`

## Acciones auditadas

| Acción | Origen del objetivo | Resultado |
|---|---|---|
| Acceder al espacio institucional | Fila `t` | Correcto; actualiza el contexto de navegación de forma explícita. |
| Reactivar/activar | Fila `t` | Corregido; usa siempre `t.id`. |
| Suspender/bloquear | Fila `t` → `statusActionTarget` | Corregido; confirmación y mutación usan el mismo objetivo. |
| Gestionar módulos | Fila `t` → modal | Correcto; RLS limita la escritura a administradores de plataforma. |
| Gestionar límites | Fila `t` → modal | Correcto; RLS limita la escritura a administradores de plataforma. |
| Registrar pago/renovar | Fila `t` → modal → RPC | Correcto; el `school_id` del modal se envía a la RPC autorizada. |
| Ver facturas | Fila `t` → consulta filtrada | El objetivo es explícito y no depende del contexto de navegación. |
| Descargar respaldo | Fila `t` | Correcto; todas las consultas se filtran por el ID recibido. |
| Eliminar institución | Fila `t` → confirmación → RPC | Reforzado; se eliminó el intento alternativo de borrado directo. |
| Crear institución | Asistente → Edge Function | Correcto; la función valida sesión y rol de plataforma. |
| Gestionar usuarios | Usuario/fila → Edge Function | Correcto; la función valida institución objetivo, membresía y permisos. |
| Restaurar JSON | Destino elegido en el modal | El mismo `targetSchoolId` se usa durante todo el flujo. |

## Seguridad

- `set_tenant_status` valida autenticación, rol de plataforma, UUID, existencia y estado permitido.
- La institución se bloquea con `FOR UPDATE` antes de mutar, evitando carreras sobre el mismo registro.
- Una solicitud repetida para el mismo estado responde `changed: false` sin duplicar actualizaciones ni registros de auditoría.
- Las transiciones escriben en `tenant_status_logs` y `audit_log` con actor, institución, estado anterior, estado nuevo, fecha y resultado.
- Se revocó `EXECUTE` a `PUBLIC` y `anon` para `set_tenant_status`, `delete_tenant` y `record_manual_payment`; solo `authenticated` y `service_role` pueden invocarlas, y las RPC mantienen validación interna de autorización.
- La interfaz valida el objetivo y presenta errores controlados sin mostrar detalles SQL o trazas internas.

## Multitenancy

La prueba crítica usa la Institución B como contexto activo y ejecuta Reactivar sobre la Institución A. La llamada contiene exclusivamente el ID de A, la fila A cambia a activa y B permanece intacta. El backend repite esta comprobación dentro de una transacción revertida.

## Concurrencia y experiencia de usuario

- El botón muestra actividad, queda deshabilitado durante la operación y bloquea dobles clics.
- El gestor deduplica una segunda solicitud idéntica mientras la primera sigue pendiente.
- La lista se vuelve a consultar después del éxito sin perder búsqueda, filtro ni pestaña actual.
- Suspender y eliminar conservan sus confirmaciones explícitas.
- Los mensajes de éxito describen la acción y la institución afectada.

## Tests ejecutados

- Unitarios: 37 archivos, 220 pruebas aprobadas.
- E2E: 18 pruebas aprobadas, incluidas reactivación a 390 px y 1366 px.
- Prueba transaccional de base de datos con `ROLLBACK`: autorización, institución inexistente, objetivo A/B e idempotencia aprobados.
- Verificación posterior al despliegue con `ROLLBACK`: objetivo A/B e idempotencia aprobados.
- Compilación Vite de producción: aprobada, 2282 módulos transformados.
- Presupuesto de bundle: aprobado para 75 recursos JS/CSS.
- `git diff --check`: sin errores de espacios o parches.

El proyecto no define comandos separados de lint o typecheck. La compilación de Vue/Vite y las suites disponibles se ejecutaron como controles efectivos del repositorio.

## Resultado

**PASS**

La migración `harden_superadmin_tenant_status` fue aplicada al proyecto Supabase vinculado. En producción, `anon_execute = false`, `public_execute = false` y `authenticated_execute = true` para las tres RPC administrativas auditadas.

## Problemas similares encontrados

- El borrado tenía un fallback directo sobre `schools` cuando fallaba la RPC. Se eliminó para conservar autorización, transacción y auditoría en el backend.
- Las RPC administrativas auditadas heredaban permiso de ejecución para `anon/PUBLIC`. Se restringieron.
- La implementación previa no era idempotente y registraba transiciones repetidas. Se corrigió.

## Riesgos pendientes

Los asesores de Supabase mantienen avisos históricos en otras áreas del esquema, como tablas con RLS sin políticas, funciones `SECURITY DEFINER` ajenas a este flujo e índices duplicados. No forman parte de la dependencia de selección institucional y requieren una migración separada para evitar cambios amplios sobre módulos que ya están en uso.
