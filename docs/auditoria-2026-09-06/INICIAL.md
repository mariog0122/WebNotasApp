# Auditoría inicial — LOGREVA — 6 de septiembre de 2026

## Alcance y referencia inicial

Solicitud: auditar y corregir problemas demostrados conservando las funcionalidades existentes. La revisión comenzó con el árbol de trabajo limpio. No se han desplegado cambios ni alterado datos de negocio.

Aplicación Vue 3 / JavaScript, Vite 7, Tailwind 3, Pinia y TanStack Vue Query. Backend Supabase: PostgreSQL 17, Auth, Storage y cuatro Edge Functions locales. Proyecto vinculado y verificado: `webnotasEmilioIsaias` (`ykokuwkvplifbjxgdveu`).

## Mapa de arquitectura

- Frontend: router en `app/src/router/index.js`; `MainLayout`, `Sidebar`; vistas de acceso, dashboard, cursos, asignaturas, estudiantes, familias, notas, reportes, informes docentes, asistencia, alertas DECE, planificación IA, perfil y superadministración.
- Estado: stores de autorización, año lectivo y UI; composables de consultas, notas, asistencia, informes y planificación.
- Backend: API de datos/RPC Supabase; funciones de aprovisionamiento, invitación, gestión de usuarios y webhook Kushki. Relay PHP de correo en `app/public/api`.
- Datos: tablas académicas y de instituciones, membresías/RBAC, planes/suscripciones/pagos, auditoría, asistencia, informes y planificación IA. Migraciones históricas en dos directorios: `migrations` y `supabase/migrations`.
- Integraciones: proveedores Gemini/OpenAI, generación/exportación de documentos, WhatsApp, firma digital, correo y facturación.
- Entrega: GitHub Actions ejecuta tests, build, presupuesto de bundle y Playwright. PWA con service worker; caché académica persistente retirada en `main.js`.

## Evidencia inicial

| Comprobación | Resultado |
|---|---|
| `npm test -- --run` | 166 aprobadas, 2 fallidas, 29 archivos. Los fallos exigen imports de iconos antiguos en Sidebar; pendiente reemplazar la comprobación por evidencia de comportamiento. |
| `npm run build` | Aprobado; advertencia de chunk principal de 527,71 kB (161,74 kB gzip) y datos Browserslist antiguos. |
| Lint / typecheck | No existen scripts configurados; frontend JavaScript. No se presentan como aprobados. |
| `npm audit --json` | 86 entradas (83 altas, 3 bajas), agrupadas por dependencias transitivas de herramientas. Pendiente evaluar advisories raíz y exposición real. |
| Catálogo Supabase | Las tablas públicas consultadas tienen RLS. Esto no acredita que sus políticas sean suficientes. |
| Pruebas de navegador existentes | Cuatro pruebas concentradas en acceso, redirección anónima y planes. Faltan flujos autenticados de negocio. |

## Hallazgos antes de correcciones

### Alto — claves de proveedores IA disponibles en el cliente

`useInstitutionAISettings` guarda la clave sin cifrar en `encrypted_api_key`; `useAIPlanning` la consulta y los proveedores ejecutan llamadas directas desde el navegador. La política SELECT permite consultar la fila a miembros de la institución. El nombre de la columna no constituye cifrado. Debe preservarse la generación mediante una operación autorizada del servidor, sin devolver la clave al navegador.

### Alto — políticas de comprobantes sin delimitación institucional

Consulta de `pg_policies` confirmó lectura pública del bucket `billing-proofs`, INSERT para cualquier usuario autenticado y UPDATE sin comprobación de institución. Se revisarán bucket, rutas y consumidores antes de preparar una corrección coordinada.

### Alto — autorización académica demasiado amplia

Las políticas de `grades` aceptan cualquier usuario del mismo colegio y también `school_id IS NULL`, sin comprobar permisos de calificaciones. Las escrituras en `academic_years` incluyen condiciones OR que permiten administrar otro colegio cuando se posee `settings.manage`. Pendiente comprobar con transacciones aisladas y distinguir autorización de integridad impuesta por triggers.

### Alto — secreto de correo fijo en código

El relay PHP y dos Edge Functions contienen un secreto compartido constante. Su sustitución requiere configuración coordinada en ambos servidores; no se reproducirá el valor en informes.

### Medio — controles de consumo y fecha

La consulta de consumo IA usa `head: true` pero lee `data` en lugar de `count`, por lo que muestra cero. Asistencia e informes calculan fechas civiles con UTC; deben comprobarse límites de día en la zona institucional.

### Pendientes de comprobación

Integridad referencial, permisos por rol, aislamiento mediante API/Storage, estado real de funciones desplegadas, responsive autenticado, accesibilidad, errores de red/sesión, rendimiento, recuperación, exportaciones y correo. Los avisos del asesor Supabase se evaluarán individualmente: RPC con SECURITY DEFINER y RLS sin políticas pueden ser intencionales.

## Plan de corrección

- [ ] P0/P1: reproducir y acotar accesos indebidos; preparar cambios mínimos de políticas con regresión positiva y negativa.
- [ ] P1: proteger secretos de IA y correo conservando los contratos funcionales.
- [ ] P2: corregir consumo y fechas solo tras reproducción.
- [ ] P2: validar navegación, regresión, responsive y controles accesibles; corregir pruebas obsoletas sin ocultar errores.
- [ ] P2: evaluar dependencias y presupuesto de bundle sin actualizaciones mayores automáticas.
- [ ] Entregar informe final con resultados reales, cambios, despliegues pendientes y limitaciones.

## Criterio de evaluación

No se asignan puntuaciones arbitrarias ni se declara producción validada por el mero hecho de compilar. El informe final separará evidencia estática, pruebas con respuestas simuladas y comprobaciones contra la base real. Las operaciones que envíen mensajes a personas no se ejecutarán durante las pruebas.
