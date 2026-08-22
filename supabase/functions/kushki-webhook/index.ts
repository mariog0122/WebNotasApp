import { createClient } from 'npm:@supabase/supabase-js@2.49.8'

const encoder = new TextEncoder()
const maxBodyBytes = 256 * 1024

const respond = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  })

const hex = (bytes: ArrayBuffer) =>
  Array.from(new Uint8Array(bytes), (byte) => byte.toString(16).padStart(2, '0')).join('')

const hmacSha256 = async (secret: string, value: string) => {
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  return hex(await crypto.subtle.sign('HMAC', key, encoder.encode(value)))
}

const sha256 = async (value: string) =>
  hex(await crypto.subtle.digest('SHA-256', encoder.encode(value)))

const constantTimeEqual = (left: string, right: string) => {
  if (left.length !== right.length) return false
  let difference = 0
  for (let index = 0; index < left.length; index += 1) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index)
  }
  return difference === 0
}

const asText = (value: unknown) => typeof value === 'string' ? value.trim() : ''
const asRecord = (value: unknown): Record<string, unknown> =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return respond({ success: false, message: 'Método no permitido.' }, 405)

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const webhookSignature = Deno.env.get('KUSHKI_WEBHOOK_SIGNATURE') ?? ''
  const merchantId = Deno.env.get('KUSHKI_MERCHANT_ID') ?? ''

  if (!supabaseUrl || !serviceRoleKey || !webhookSignature || !merchantId) {
    console.error('kushki-webhook is not configured')
    return respond({ success: false, message: 'Webhook no configurado.' }, 503)
  }

  const kushkiSignature = req.headers.get('x-kushki-signature')?.trim().toLowerCase() ?? ''
  const kushkiId = req.headers.get('x-kushki-id')?.trim() ?? ''
  const kushkiKey = req.headers.get('x-kushki-key')?.trim() ?? ''

  if (!kushkiSignature || !kushkiId || !constantTimeEqual(kushkiKey, merchantId)) {
    return respond({ success: false, message: 'Firma no válida.' }, 401)
  }

  const declaredLength = Number.parseInt(req.headers.get('content-length') || '0', 10)
  if (Number.isFinite(declaredLength) && declaredLength > maxBodyBytes) {
    return respond({ success: false, message: 'Cuerpo no válido.' }, 413)
  }

  const rawBody = await req.text()
  if (!rawBody || encoder.encode(rawBody).byteLength > maxBodyBytes) {
    return respond({ success: false, message: 'Cuerpo no válido.' }, 413)
  }

  const expectedSignature = await hmacSha256(webhookSignature, `${rawBody}.${kushkiId}`)
  if (!constantTimeEqual(kushkiSignature, expectedSignature)) {
    return respond({ success: false, message: 'Firma no válida.' }, 401)
  }

  let body: Record<string, unknown>
  try {
    body = asRecord(JSON.parse(rawBody))
  } catch {
    return respond({ success: false, message: 'JSON no válido.' }, 400)
  }

  const transactionId = asText(body.transaction_id) || asText(body.transactionId)
  const ticketNumber = asText(body.ticket_number) || asText(body.ticketNumber)
  const transactionReference = asText(body.transaction_reference) || asText(body.transactionReference)
  const status = (asText(body.transaction_status) || asText(body.status) || 'unknown').toUpperCase()
  const transactionType = (asText(body.transaction_type) || asText(body.transactionType) || 'transaction').toLowerCase()
  const stableReference = transactionId || ticketNumber || transactionReference

  if (!stableReference) {
    return respond({ success: false, message: 'Evento sin referencia transaccional.' }, 422)
  }

  const amount = asRecord(body.amount)
  const metadata = asRecord(body.metadata)
  const amountParts = ['subtotalIva0', 'subtotalIva', 'iva', 'ice']
    .map((key) => amount[key])
    .filter((value): value is number => typeof value === 'number' && Number.isFinite(value))
  const computedTotal = typeof body.totalAmount === 'number' && Number.isFinite(body.totalAmount)
    ? body.totalAmount
    : amountParts.length > 0
      ? amountParts.reduce((sum, value) => sum + value, 0)
      : null
  const created = typeof body.created === 'number' && Number.isFinite(body.created)
    ? body.created > 10_000_000_000
      ? Math.floor(body.created / 1000)
      : body.created
    : null
  const payloadSummary = {
    transaction_id: transactionId || null,
    ticket_number: ticketNumber || null,
    transaction_reference: transactionReference || null,
    transaction_type: transactionType,
    transaction_status: status,
    currency: asText(body.currency_code) || asText(body.currencyCode) || asText(body.currency) || asText(amount.currency) || null,
    created,
    sale_transaction_reference: asText(body.sale_transaction_reference) || asText(body.saleTransactionReference) || null,
    sale_ticket_number: asText(body.sale_ticket_number) || asText(body.saleTicketNumber) || null,
    amount: {
      subtotal_iva_0: typeof amount.subtotalIva0 === 'number' ? amount.subtotalIva0 : null,
      subtotal_iva: typeof amount.subtotalIva === 'number' ? amount.subtotalIva : null,
      iva: typeof amount.iva === 'number' ? amount.iva : null,
      ice: typeof amount.ice === 'number' ? amount.ice : null,
      total: computedTotal,
    },
    metadata: {
      school_id: asText(metadata.school_id) || null,
      invoice_number: asText(metadata.invoice_number) || null,
    },
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data, error } = await adminClient.rpc('ingest_payment_event', {
    p_provider: 'kushki',
    p_provider_event_id: `${stableReference}:${transactionType}:${status}`,
    p_event_type: `${transactionType}.${status.toLowerCase()}`,
    p_payload_hash: await sha256(rawBody),
    p_payload_summary: payloadSummary,
  })

  if (error) {
    console.error('kushki-webhook persistence failed', error.code ?? 'unknown')
    return respond({ success: false, message: 'No fue posible registrar el evento.' }, 500)
  }

  const processingResponse = ['refund', 'void'].includes(transactionType)
    ? await adminClient.rpc('process_kushki_refund_event', { p_event_id: data?.event_id })
    : await adminClient.rpc('process_kushki_payment_event', { p_event_id: data?.event_id })
  const { data: processing, error: processingError } = processingResponse
  if (processingError) {
    if (data?.event_id) {
      await adminClient.rpc('complete_payment_event', {
        p_event_id: data.event_id,
        p_status: 'failed',
        p_error_message: processingError.code || 'PROCESSING_FAILED',
      })
    }
    console.error('kushki-webhook processing failed', processingError.code ?? 'unknown')
    return respond({ success: false, message: 'No fue posible procesar el evento.' }, 500)
  }

  return respond({
    success: true,
    duplicate: data?.duplicate === true || processing?.duplicate === true,
    status: processing?.status,
  })
})
