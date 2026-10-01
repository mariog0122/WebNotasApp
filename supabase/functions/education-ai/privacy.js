const SENSITIVE_KEYS = new Set([
  'id', 'studentid', 'studentname', 'fullname', 'firstname', 'lastname',
  'cedula', 'studentcedula', 'representativecedula', 'email', 'studentemail',
  'phone', 'studentphone', 'representativephone', 'representativealtphone',
])

const NAME_KEYS = new Set(['studentname', 'fullname', 'firstname', 'lastname'])

const INJECTION_PATTERNS = [
  /ignora\s+(?:todas?\s+)?(?:las\s+)?(?:instrucciones|reglas|órdenes)\s+anteriores/i,
  /ignore\s+(?:all\s+)?(?:previous\s+)?instructions/i,
  /revela\s+(?:tu\s+)?(?:system\s+prompt|instrucciones\s+del\s+sistema)/i,
  /show\s+(?:your\s+)?system\s+(?:prompt|instructions)/i,
  /(?:dan\s+mode|jailbreak)/i,
  /<script\b[^>]*>/i,
  /javascript\s*:/i,
]

const normalizeKey = key => String(key).replace(/[^a-z0-9]/gi, '').toLowerCase()
const escapeRegExp = value => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

function visitStrings(value, visitor, depth = 0) {
  if (depth > 8) throw new Error('Payload nesting limit exceeded')
  if (typeof value === 'string') return visitor(value)
  if (Array.isArray(value)) {
    if (value.length > 100) throw new Error('Payload array limit exceeded')
    for (const item of value) visitStrings(item, visitor, depth + 1)
    return
  }
  if (value && typeof value === 'object') {
    const entries = Object.entries(value)
    if (entries.length > 100) throw new Error('Payload object limit exceeded')
    for (const [, item] of entries) visitStrings(item, visitor, depth + 1)
  }
}

function collectKnownNames(value, names, depth = 0) {
  if (depth > 8 || !value || typeof value !== 'object') return
  if (Array.isArray(value)) {
    for (const item of value.slice(0, 100)) collectKnownNames(item, names, depth + 1)
    return
  }
  for (const [key, item] of Object.entries(value).slice(0, 100)) {
    if (NAME_KEYS.has(normalizeKey(key)) && typeof item === 'string' && item.trim().length >= 3) names.add(item.trim())
    collectKnownNames(item, names, depth + 1)
  }
}

function redactText(value, knownNames) {
  if (value.length > 10_000) throw new Error('Payload string limit exceeded')
  let sanitized = value
  for (const name of knownNames) {
    sanitized = sanitized.replace(new RegExp(escapeRegExp(name), 'gi'), '[ESTUDIANTE_REDACTADO]')
  }
  return sanitized
    .replace(/\b[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\b/gi, '[ID_REDACTADO]')
    .replace(/[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/gi, '[CORREO_REDACTADO]')
    .replace(/(?:\+?593\s?9\d{8}|\b09\d{8}\b)/g, '[TELEFONO_REDACTADO]')
    .replace(/\b\d{10}\b/g, '[IDENTIFICACION_REDACTADA]')
    .replace(/\b(?:sk-[a-z0-9_-]{16,}|AIza[a-z0-9_-]{20,}|Bearer\s+[a-z0-9._-]{16,})\b/gi, '[SECRETO_REDACTADO]')
    .replace(/(?:diagn[oó]stico\s+cl[ií]nico|informe\s+psicol[oó]gico|medicaci[oó]n|historia\s+cl[ií]nica)\s*:\s*[^.,;\n]+/gi, '[DATOS_CLINICOS_REDACTADOS]')
}

function sanitize(value, knownNames, depth = 0) {
  if (depth > 8) throw new Error('Payload nesting limit exceeded')
  if (value === null || typeof value === 'boolean') return value
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new Error('Invalid number')
    return value
  }
  if (typeof value === 'string') return redactText(value, knownNames)
  if (Array.isArray(value)) {
    if (value.length > 100) throw new Error('Payload array limit exceeded')
    return value.map(item => sanitize(item, knownNames, depth + 1))
  }
  if (!value || typeof value !== 'object') throw new Error('Invalid payload value')
  const entries = Object.entries(value)
  if (entries.length > 100) throw new Error('Payload object limit exceeded')
  return Object.fromEntries(entries.map(([key, item]) => {
    const normalized = normalizeKey(key)
    if (SENSITIVE_KEYS.has(normalized) && item !== null && item !== undefined) {
      return [key, NAME_KEYS.has(normalized) ? '[ESTUDIANTE_REDACTADO]' : '[DATO_REDACTADO]']
    }
    return [key, sanitize(item, knownNames, depth + 1)]
  }))
}

export function sanitizeEducationAIInput(input) {
  try {
    visitStrings(input, text => {
      if (INJECTION_PATTERNS.some(pattern => pattern.test(text))) throw new Error('Prompt injection detected')
    })
    const knownNames = new Set()
    collectKnownNames(input, knownNames)
    return { ok: true, value: sanitize(input, knownNames) }
  } catch {
    return { ok: false, error: 'Los datos de generación contienen información o instrucciones no permitidas.' }
  }
}
