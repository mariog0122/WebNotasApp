# Runbook operativo de EduCore

Este documento define el mínimo operativo antes de admitir instituciones de pago. No sustituye los respaldos administrados del proveedor: los complementa con una copia lógica verificable.

## Objetivos

- RPO objetivo: 24 horas como máximo para la copia lógica externa. Antes de vender, confirmar en el panel de Supabase la frecuencia y retención del respaldo administrado contratado.
- RTO objetivo: 4 horas para restaurar la base, desplegar el frontend validado y comprobar acceso de un administrador, un docente y un tenant suspendido.
- Propietario: Platform Owner. Suplente: Platform Admin designado.

## Respaldo semanal

1. Instalar las herramientas cliente de PostgreSQL compatibles con el servidor.
2. Definir `SUPABASE_DB_URL` solo en la sesión segura del operador.
3. Ejecutar `./scripts/backup.ps1`.
4. Confirmar que existen el `.dump` y su manifiesto `.sha256`.
5. Copiar ambos a almacenamiento cifrado fuera del proyecto Supabase, con retención mínima de 90 días.
6. Registrar fecha, operador, tamaño y checksum en el registro operativo.

Las credenciales y los respaldos nunca se suben a Git. La carpeta `backups/` está ignorada.

## Simulacro mensual de restauración

1. Crear una base PostgreSQL temporal y vacía, aislada de producción.
2. Definir `RESTORE_DATABASE_URL` apuntando exclusivamente a esa base.
3. Ejecutar:

   ```powershell
   ./scripts/restore-drill.ps1 -BackupPath ./backups/webnotas-AAAAMMDDTHHMMSSZ.dump -AcknowledgeNonProductionTarget
   ```

4. Confirmar checksum, restauración sin errores y conteos de `schools`, `students` y `grades`.
5. Ejecutar las pruebas SQL de `migrations/tests/` sobre el entorno temporal.
6. Destruir la base temporal y registrar duración total contra el RTO.

## Incidente y recuperación

1. Congelar cambios y registrar hora de detección.
2. Determinar si el problema es de aplicación, autenticación, storage o datos.
3. Para corrupción de datos, seleccionar el respaldo anterior al incidente y documentar la pérdida máxima frente al RPO.
4. Restaurar primero en un entorno temporal, ejecutar verificaciones y obtener aprobación del Platform Owner.
5. Restaurar o promover el entorno verificado según el procedimiento del proveedor.
6. Validar login, aislamiento tenant, lectura de notas, cobro y suspensión antes de reabrir el servicio.
7. Publicar informe de causa raíz y acciones preventivas.

Los umbrales, presupuesto de error y escalones de prueba de carga se mantienen en `docs/SLO_AND_CAPACITY.md`.

## Telemetría de errores del navegador

- Los errores autenticados se agrupan en `client_error_events` por una huella SHA-256 calculada en el navegador.
- No se transmiten mensajes, stack traces, parámetros de URL ni identificadores embebidos en rutas. Se registran únicamente huella, categoría, código técnico, origen, ruta normalizada, versión y marcas de tiempo.
- Un trigger fija `user_id` y `school_id` desde el JWT, limita cada usuario a 20 eventos por minuto y corrige fechas fuera de una ventana razonable.
- Solo Platform Admin puede consultar eventos; `anon` no puede insertar y los usuarios autenticados no pueden modificarlos ni eliminarlos.
- El panel de salud muestra conteos de 15 minutos y 24 horas. Cualquier evento reciente degrada el indicador; 20 o más en 15 minutos lo marcan como caído y requieren abrir incidente.
- La tarea `purge-client-error-events` elimina diariamente registros con más de 90 días.

Para correlacionar un incidente se usa la huella, la versión y la ruta. Los detalles personales no deben añadirse manualmente a esta tabla.
