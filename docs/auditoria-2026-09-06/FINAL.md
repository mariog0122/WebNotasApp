# Auditoría integral — resultado y salida segura

Fecha: 6 de septiembre de 2026. Alcance: aplicación, rutas protegidas, sesión, notas, asistencia, informes, planificación con IA, comprobantes de facturación, correo y Supabase.

## Estado real

Se prepararon correcciones conservadoras y pruebas de regresión. Se aplicó únicamente la migración de permiso del monitor de salud: permite invocarlo a usuarios autenticados, mantiene bloqueados a `anon` y `public`, y la función conserva su comprobación interna de superadministrador. No se publicaron archivos, Edge Functions ni las demás migraciones, y no se modificaron datos de negocio ni se enviaron mensajes.

Una consulta de solo lectura al proyecto activo confirmó que las correcciones de almacenamiento e IA no están desplegadas: `billing-proofs` continúa público; no existen la columna `has_api_key`, el RPC `reserve_education_ai_usage` ni la política `billing_proofs_select` de esta auditoría. El permiso del monitor de salud sí fue comprobado tras aplicarlo. El indicador `grades_select` ya existía antes, por lo que no permite identificar por sí solo una publicación.

## Problemas demostrados y correcciones preparadas

| Área | Evidencia inicial | Corrección preparada |
|---|---|---|
| Claves IA | La configuración entregaba la clave al navegador y los proveedores se llamaban desde el cliente. | Función `education-ai` autenticada, clave leída solo por el servidor, metadatos de configuración sin clave y reserva de cuota atómica. |
| Aislamiento IA | El RPC de contexto aceptaba un identificador institucional ajeno. | Guarda de pertenencia institucional y pruebas de denegación. |
| Comprobantes | `billing-proofs` era público y sus políticas no limitaban institución. | Bucket privado, ruta `receipts/<escuela>_<archivo>`, tipo/tamaño permitidos y URLs firmadas. |
| Notas y año lectivo | Las pruebas de rol permitieron una nota para estudiante ajeno, nota mayor a 10, lectura sin `grades.read` y edición de año por docente. | Políticas por permiso e institución, trigger de consistencia estudiante/curso/período/escuela y rango 0–10. |
| Sesiones y formularios | Una respuesta tardía podía mezclar el perfil anterior con el nuevo; algunos flujos mostraban guardado aun con persistencia fallida. | Versión de identidad, invalidación de cargas pendientes y confirmación de escritura antes de actualizar la interfaz. |
| Fechas | Asistencia e informes usaban fecha UTC en vez de la zona de la institución. | Fecha civil por zona horaria institucional y pruebas en límites de mes. |
| Correo | El relay y las funciones contenían un secreto fijo. | Secreto tomado de `LOGREVA_MAILER_SECRET`; el relay rechaza solicitudes si no está configurado. |
| Navegación y carga | La navegación mostraba módulos sin comprobar todos los permisos; el paquete inicial excedía el presupuesto. | Navegación alineada con permisos/rutas y carga diferida del panel; paquete inicial 137,0 KiB gzip frente a límite de 150 KiB. |

Los archivos de datos y SQL reproducible están en [database-regression.sql](/D:/PROGRAMACION/PROGRAMAS%20HECHOS/NUEVOS%20ARCHIVOS%20DE%20ESCRITORIO%2014-02-2026/webnotas/docs/auditoria-2026-09-06/database-regression.sql), [database-results.json](/D:/PROGRAMACION/PROGRAMAS%20HECHOS/NUEVOS%20ARCHIVOS%20DE%20ESCRITORIO%2014-02-2026/webnotas/docs/auditoria-2026-09-06/database-results.json) y [supabase-advisors.json](/D:/PROGRAMACION/PROGRAMAS%20HECHOS/NUEVOS%20ARCHIVOS%20DE%20ESCRITORIO%2014-02-2026/webnotas/docs/auditoria-2026-09-06/supabase-advisors.json).

## Verificación realizada

| Comprobación | Resultado |
|---|---|
| Pruebas unitarias | 35 archivos, 211 pruebas aprobadas. |
| Compilación de producción | Aprobada. |
| Presupuesto de recursos | Aprobado para 75 recursos; entrada principal 137,0 KiB gzip / límite 150 KiB. |
| Verificación de Edge Function | `deno check` aprobada para `education-ai`. |
| Navegador sobre paquete de producción | 16 de 16 pruebas Chromium aprobadas, con API e identidades sintéticas aisladas. Incluye 320, 360, 390, 768, 1366 y 1920 píxeles. |
| RLS e integridad de candidatos | 19 de 19 comprobaciones aprobadas dentro de una transacción que terminó con `ROLLBACK`. |
| Dependencias de producción | `npm audit --omit=dev`: 0 vulnerabilidades. |

Las pruebas de navegador no usan cuentas, datos ni API reales. La prueba de base usa identidades y registros sintéticos y revierte la transacción. Por tanto, confirman contratos y regresiones, no sustituyen una prueba de humo posterior al despliegue.

## Pendientes antes de publicar

No es seguro desplegar las correcciones de IA, almacenamiento y correo por partes. Deben ir juntas, en una ventana coordinada:

1. Configurar el mismo secreto aleatorio `LOGREVA_MAILER_SECRET` en Supabase y en el entorno PHP de Hostinger. No guardarlo en el repositorio.
2. Publicar la función `education-ai` y las dos migraciones de esta auditoría: [IA](/D:/PROGRAMACION/PROGRAMAS%20HECHOS/NUEVOS%20ARCHIVOS%20DE%20ESCRITORIO%2014-02-2026/webnotas/supabase/migrations/20260906185903_secure_institution_ai_gateway.sql) y [académico/almacenamiento](/D:/PROGRAMACION/PROGRAMAS%20HECHOS/NUEVOS%20ARCHIVOS%20DE%20ESCRITORIO%2014-02-2026/webnotas/supabase/migrations/20260906192127_audit_academic_and_storage_access.sql).
3. Publicar conjuntamente el frontend y el relay PHP. La interfaz nueva espera la función y las políticas nuevas; las políticas nuevas esperan rutas de comprobante y URLs firmadas del frontend.
4. Validar con una cuenta de prueba de cada rol: lectura/escritura de notas, comprobante propio, generación IA, cierre de período, alta de institución y correo. No enviar correos a personas durante esa prueba.

La revisión de Supabase todavía informa avisos históricos: siete tablas con RLS sin políticas (fallan cerradas, pero requieren decidir su acceso), tres funciones con `search_path` mutable, funciones `SECURITY DEFINER` ejecutables por roles expuestos, protección contra contraseñas filtradas desactivada y oportunidades de índices. Se documentan como trabajo posterior porque no es responsable modificar políticas o índices de todo el sistema sin reproducir cada flujo afectado.

## Dependencias

El análisis completo cuenta 86 avisos de herramientas de desarrollo (83 altos y 3 bajos), principalmente la cadena de construcción PWA/Babel. Las dependencias de ejecución no tienen vulnerabilidades según `npm audit --omit=dev`. No se ejecutó una actualización masiva automática: puede cambiar el compilador y la PWA, y necesita una tarea separada con sus pruebas.
