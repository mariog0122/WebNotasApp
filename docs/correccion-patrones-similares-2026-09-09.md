# Corrección de patrones similares

Fecha: 2026-09-09  
Proyecto Supabase: `ykokuwkvplifbjxgdveu`

## Resultado

Se corrigieron en orden todos los patrones accionables detectados durante la auditoría de Años Lectivos:

1. Las escrituras de calificaciones exigen permiso, asignación docente y período desbloqueado.
2. Los comprobantes de pago son privados, están aislados por institución y solo se registran con `billing.manage`.
3. Las dos firmas de copia de cursos validan permisos y pertenencia de ambos años a la misma institución.
4. La firma antigua de copia dejó de usar la columna inexistente `courses.section`.
5. Se restauraron políticas RLS faltantes en facturas, eventos financieros, telemetría e historial de planificación.
6. Se retiró la ejecución anónima de 13 funciones `SECURITY DEFINER`.
7. Se fijó el `search_path` de tres funciones trigger.
8. Se eliminaron políticas duplicadas, incluido un bypass que permitía a docentes crear cursos sin `settings.manage`.
9. Se retiraron índices idénticos y se añadieron los 17 índices de claves foráneas señalados por el asesor.
10. Las políticas señaladas dejaron de recalcular `auth.uid()` por cada fila.

## Migraciones aplicadas en producción

- `20260909140725 harden_grades_authorization`
- `20260909150250 harden_billing_proof_access`
- `20260909160733 harden_course_copy_authorization`
- `20260909171620 resolve_security_advisor_warnings`
- `20260909174146 consolidate_policies_and_indexes`
- `20260909180355 optimize_rls_and_foreign_keys`

## Verificación

| Comprobación | Resultado |
|---|---|
| Pruebas unitarias | 261 PASS |
| Pruebas E2E Chromium | 20 PASS |
| Compilación Vite de producción | PASS |
| Presupuesto del paquete | 78 recursos PASS |
| Pruebas SQL 38 a 44 en producción | 7 suites PASS |
| `git diff --check` | PASS |
| Avisos de acceso anónimo a funciones | 0 |
| Tablas RLS sin políticas | 0 |
| Funciones con `search_path` mutable | 0 |
| Políticas permisivas duplicadas | 0 |
| Índices duplicados | 0 |
| Claves foráneas sin índice | 0 |
| Políticas con `auth.uid()` por fila | 0 |

El asesor conserva avisos sobre RPC autenticados con `SECURITY DEFINER`. Son puntos de entrada y auxiliares RLS intencionales con validación interna de identidad, permiso y tenant. También conserva el ajuste opcional de Supabase Auth para bloquear contraseñas filtradas y avisos informativos de índices todavía sin uso.

## Archivos principales

- `supabase/migrations/20260909140502_harden_grades_authorization.sql`
- `supabase/migrations/20260909143412_harden_billing_proof_access.sql`
- `supabase/migrations/20260909155901_harden_course_copy_authorization.sql`
- `supabase/migrations/20260909165234_resolve_security_advisor_warnings.sql`
- `supabase/migrations/20260909172714_consolidate_policies_and_indexes.sql`
- `supabase/migrations/20260909174316_optimize_rls_and_foreign_keys.sql`
- `migrations/tests/39_grades_authorization_regression_test.sql`
- `migrations/tests/40_billing_proof_authorization_regression_test.sql`
- `migrations/tests/41_course_copy_authorization_regression_test.sql`
- `migrations/tests/42_security_advisor_regression_test.sql`
- `migrations/tests/43_policy_and_index_consolidation_test.sql`
- `migrations/tests/44_rls_and_foreign_key_performance_test.sql`
- `app/src/views/Profile.vue`
- `app/tests/securityPatternsRegression.test.js`

## Paquete para Hostinger

Archivo: `app/dist_20260909_patrones_seguridad_final.zip`  
Tamaño: 670547 bytes  
Entradas verificadas: 89  
SHA-256: `7978C849A488342944D0795BF815CCAEA5668D7E534A7A7C201037ADECF44ED3`

El ZIP contiene `index.html`, `.htaccess`, `_headers`, `api/send-email.php`, el manifiesto PWA, el service worker y los assets compilados directamente en la raíz.
