# Activación de Kushki — EduCore

Estado actual: el receptor `kushki-webhook` versión 5 está desplegado y la base procesa ventas, devoluciones y anulaciones de forma idempotente, pero el checkout y el comercio todavía no están activados. No se deben ofrecer cobros automáticos hasta completar esta lista con credenciales UAT y certificación del proveedor.

## Arquitectura implementada

1. Kushki envía el `POST` a la Edge Function pública `kushki-webhook`.
2. La función exige `X-Kushki-Key`, `X-Kushki-Id` y `X-Kushki-Signature`.
3. Se verifica HMAC-SHA256 sobre `cuerpo.timestamp` y se compara en tiempo constante.
4. El cuerpo completo solo se usa en memoria para firma y hash; la base recibe un resumen sin datos de tarjeta.
5. `ingest_payment_event` hace idempotente cada referencia + tipo + estado y rechaza un replay cuyo hash no coincida.
6. `SALE/APPROVAL` exige tenant y factura conocidos, moneda USD e importe exacto; luego crea el pago, concilia la factura y activa la suscripción en una sola transacción.
7. `REFUND` y `VOID` se vinculan con la venta original, impiden sobredevoluciones y actualizan factura/pago. Una devolución total del período vigente mueve la suscripción a siete días de gracia; una parcial no corta el acceso.
8. Los eventos rechazados o no soportados se cierran sin crear movimientos financieros.

La implementación sigue la documentación oficial de [webhooks y firma](https://docs.kushki.com/ec/notifications/overview/) y las [recomendaciones de idempotencia y respuesta rápida](https://docs.kushki.com/ec/notifications/recommendations/).

## Secretos obligatorios

Configurar en Supabase Edge Functions, nunca en `.env` del frontend ni en Git:

- `KUSHKI_MERCHANT_ID`: valor esperado del encabezado `X-Kushki-Key`.
- `KUSHKI_WEBHOOK_SIGNATURE`: secreto obtenido en Consola → Desarrolladores → Webhooks.

`SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` son secretos administrados por Supabase para la función. La clave privada de la API Kushki solo será necesaria cuando se implemente la creación de cobros desde backend.

## Decisión comercial pendiente

Kushki debe confirmar por escrito qué modalidad habilita para el comercio ecuatoriano:

- Checkout alojado / botón de pago: menor alcance PCI y redirección a una experiencia controlada por Kushki, pero la documentación indica que se habilita bajo solicitud y no ofrece recurrencia directa.
- Tarjeta con Hosted Fields/Kajita y cargo backend: requiere clave pública en el navegador y clave privada solo en backend.
- Suscripción recurrente: requiere afiliación y condiciones específicas del comercio; no debe asumirse disponible.

Referencias: [checkout alojado](https://docs.kushki.com/ec/en/payment-forms-and-buttons/payment-button/overview/), [pago único con tarjeta](https://docs.kushki.com/ec/en/card-payments/one-step-payments/accept-a-payment/) y [suscripción recurrente](https://docs.kushki.com/ec/en/recurring-payments/scheduled-payments/subscribe-a-card/).

## Prueba UAT obligatoria

1. Obtener Merchant ID, clave pública/privada UAT y firma del webhook.
2. Configurar secretos y registrar la URL de la función en la Consola Kushki.
3. Simular conexión desde Desarrolladores → Webhooks.
4. Enviar una aprobación UAT y confirmar un solo `payment_event` aunque Kushki reintente.
5. Repetir exactamente el evento: debe responder 200 y marcar `duplicate: true`.
6. Alterar el cuerpo manteniendo la referencia: debe ser rechazado como replay inconsistente.
7. Ejecutar aprobación, rechazo, timeout, refund y void según la modalidad contratada.
8. Confirmar que el webhook responde dentro de 500 ms p95 y que no existen PAN, CVV ni tokens de tarjeta en logs/base.
9. Conciliar importe, moneda, tenant, factura y referencia contra la Consola Kushki.
10. Solo después habilitar producción y repetir una transacción real de importe mínimo con devolución.

## Puerta de producción

No activar el botón ni anunciar cobro automático mientras falte cualquiera de estos puntos:

- contrato/afiliación Kushki aprobado;
- modalidad de integración confirmada;
- secretos UAT y producción separados;
- eventos UAT aprobados/rechazados/refund/void confirmados contra la Consola Kushki;
- prueba de reintentos e idempotencia;
- conciliación financiera y responsable operativo;
- revisión de privacidad, términos, comprobante fiscal y obligaciones SRI.

El webhook desplegado devuelve `503 Webhook no configurado` mientras falten los secretos, de forma que Kushki reintente y no se pierdan eventos silenciosamente.
