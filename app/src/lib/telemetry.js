const allowedSources = new Set(['vue', 'window', 'unhandledrejection', 'other'])
const allowedErrorNames = new Set([
  'Error',
  'TypeError',
  'RangeError',
  'ReferenceError',
  'SyntaxError',
  'URIError',
  'EvalError',
  'AggregateError',
  'DOMException',
])
const recentFingerprints = new Map()
const duplicateWindowMs = 60_000

const compactIdentifier = (value, fallback) => {
  const compact = String(value || '')
    .trim()
    .replace(/[^a-zA-Z0-9_.:-]/g, '_')
    .slice(0, 80)
  return compact || fallback
}

const sha256 = async (value) => {
  const bytes = new TextEncoder().encode(value)
  const digest = await globalThis.crypto.subtle.digest('SHA-256', bytes)
  return Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('')
}

export const sanitizeRoute = (value) => {
  try {
    const url = new URL(String(value || '/'), 'https://telemetry.invalid')
    const path = url.pathname
      .split('/')
      .map(segment => (
        /^\d+$/.test(segment)
        || /^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(segment)
        || segment.length > 32
          ? ':id'
          : segment
      ))
      .join('/')
    return path.slice(0, 256) || '/'
  } catch {
    return '/'
  }
}

export const buildClientErrorEvent = async (error, options = {}) => {
  const normalized = error instanceof Error ? error : new Error(String(error || 'Unknown error'))
  const candidateName = compactIdentifier(normalized.name, 'Error')
  const errorName = allowedErrorNames.has(candidateName) ? candidateName : 'Error'
  const candidateCode = String(error?.code || '').trim()
  const errorCode = /^[A-Z0-9][A-Z0-9_.:-]{0,79}$/.test(candidateCode)
    ? candidateCode
    : errorName
  const source = allowedSources.has(options.source) ? options.source : 'other'
  const route = sanitizeRoute(options.route ?? globalThis.location?.href ?? '/')
  const release = compactIdentifier(options.release, 'unknown')

  // El mensaje y el stack participan únicamente en el hash local. Nunca salen del navegador.
  const fingerprint = await sha256([
    errorName,
    errorCode,
    normalized.message,
    normalized.stack,
  ].join('|'))

  return {
    fingerprint,
    error_name: errorName,
    error_code: errorCode,
    source,
    route,
    release,
    occurred_at: new Date().toISOString(),
  }
}

export const reportClientError = async (client, error, options = {}) => {
  try {
    const event = await buildClientErrorEvent(error, options)
    const now = Date.now()
    const lastSeen = recentFingerprints.get(event.fingerprint) || 0
    if (now - lastSeen < duplicateWindowMs) return true

    recentFingerprints.set(event.fingerprint, now)
    if (recentFingerprints.size > 100) {
      for (const [fingerprint, timestamp] of recentFingerprints) {
        if (now - timestamp >= duplicateWindowMs) recentFingerprints.delete(fingerprint)
      }
    }

    const { error: persistenceError } = await client.from('client_error_events').insert(event)
    if (persistenceError) {
      recentFingerprints.delete(event.fingerprint)
      return false
    }
    return true
  } catch {
    return false
  }
}

export const installErrorTelemetry = (app, client, options = {}) => {
  const capture = (error, source) => {
    void reportClientError(client, error, { ...options, source })
  }

  app.config.errorHandler = (error) => {
    capture(error, 'vue')
    console.error('[Vue error]', error)
  }

  if (typeof globalThis.addEventListener === 'function') {
    globalThis.addEventListener('error', event => capture(event.error || event.message, 'window'))
    globalThis.addEventListener('unhandledrejection', event => capture(event.reason, 'unhandledrejection'))
  }
}
