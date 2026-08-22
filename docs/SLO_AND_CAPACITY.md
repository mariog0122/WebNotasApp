# SLO y capacidad — piloto de EduCore

Estos objetivos son la puerta operativa para un piloto pago. No constituyen todavía un SLA contractual ni una afirmación de capacidad: deben medirse en un entorno equivalente a producción durante al menos 30 días.

## Indicadores y objetivos

| Indicador | SLO inicial | Ventana | Alerta |
|---|---:|---:|---:|
| Disponibilidad de login y rutas autenticadas | 99.5% | 30 días | dos fallos consecutivos en 5 minutos |
| Lecturas académicas | p95 ≤ 800 ms | 15 minutos | p95 > 1.2 s durante 10 minutos |
| Escrituras de notas/matrícula | p95 ≤ 1.5 s | 15 minutos | p95 > 2.5 s durante 10 minutos |
| Error de solicitudes | < 1% | 15 minutos | ≥ 2% durante 5 minutos |
| Recepción del webhook Kushki | p95 ≤ 500 ms | 15 minutos | cualquier 5xx o firma válida rechazada |
| Tarea de ciclo de suscripción | 100% antes de 15 minutos | diaria | ejecución ausente o fallida |
| Errores no controlados del navegador | 0 sostenidos | 15 minutos | ≥ 1 degrada; ≥ 20 abre incidente crítico |

Para un SLO de 99.5%, el presupuesto de error mensual aproximado es 3 h 39 min. Al consumir 50% se congelan cambios no esenciales; al consumir 100% solo se permiten correcciones de confiabilidad y seguridad.

## Objetivos de recuperación

- RPO: 24 horas para la copia lógica externa, sujeto a confirmar el respaldo administrado contratado en Supabase.
- RTO: 4 horas, incluyendo restauración, migraciones, frontend y comprobación por rol.
- El simulacro real y cronometrado sigue siendo obligatorio antes de declarar el producto vendible.

## Prueba de carga

La herramienta solo admite `GET` o `HEAD`, exige confirmación explícita y nunca imprime el bearer. Debe apuntar a un entorno de ensayo autorizado con datos sintéticos.

```powershell
$env:LOAD_TEST_URL='https://staging.example.com/health'
$env:LOAD_TEST_ACKNOWLEDGE='I_UNDERSTAND_THIS_GENERATES_TRAFFIC'
$env:LOAD_TEST_REQUESTS='500'
$env:LOAD_TEST_CONCURRENCY='20'
npm run test:load
```

Para una ruta autenticada se puede definir `LOAD_TEST_BEARER` únicamente en la sesión segura. Nunca se guarda el token en archivos o CI. Los umbrales se ajustan con `LOAD_TEST_P95_BUDGET_MS` y `LOAD_TEST_ERROR_BUDGET_PERCENT`.

## Escalones de capacidad

1. Ensayo: 20 usuarios concurrentes, 500 solicitudes, 0 errores y p95 dentro del SLO.
2. Piloto: 50 usuarios concurrentes durante 15 minutos, combinando lectura y fixtures de escritura desechables.
3. Venta general: 100 usuarios concurrentes durante 30 minutos y prueba separada de importación de 2.000 estudiantes.
4. Cada escalón requiere monitorear CPU, conexiones, bloqueos, memoria, latencia de base y errores de Edge Functions.

No se avanza de escalón si hay pérdida de datos, respuestas cruzadas entre tenants, deadlocks, más de 1% de error o p95 fuera del objetivo.

## Respuesta y evidencia

- Registrar fecha, commit, entorno, volumen, concurrencia, p50/p95/p99, tasa de error y capturas de métricas.
- Abrir incidente si una alerta supera su ventana y enlazar causa raíz, impacto y corrección.
- Revisar los SLO mensualmente durante el piloto; un SLA comercial solo se publica después de disponer de datos reales y respaldo jurídico.
