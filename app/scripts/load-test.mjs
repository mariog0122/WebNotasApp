import { performance } from 'node:perf_hooks'

const acknowledgement = 'I_UNDERSTAND_THIS_GENERATES_TRAFFIC'
if (process.env.LOAD_TEST_ACKNOWLEDGE !== acknowledgement) {
  console.error(`Carga cancelada. Define LOAD_TEST_ACKNOWLEDGE=${acknowledgement} solo para un entorno autorizado.`)
  process.exit(2)
}

const target = process.env.LOAD_TEST_URL
if (!target) {
  console.error('LOAD_TEST_URL es obligatorio.')
  process.exit(2)
}

let targetUrl
try {
  targetUrl = new URL(target)
} catch {
  console.error('LOAD_TEST_URL no es una URL válida.')
  process.exit(2)
}
if (!['http:', 'https:'].includes(targetUrl.protocol)) {
  console.error('LOAD_TEST_URL debe usar HTTP o HTTPS.')
  process.exit(2)
}

const integer = (name, fallback, min, max) => {
  const value = Number.parseInt(process.env[name] || String(fallback), 10)
  if (!Number.isInteger(value) || value < min || value > max) {
    console.error(`${name} debe estar entre ${min} y ${max}.`)
    process.exit(2)
  }
  return value
}

const requests = integer('LOAD_TEST_REQUESTS', 100, 1, 5000)
const concurrency = integer('LOAD_TEST_CONCURRENCY', 5, 1, 100)
const timeoutMs = integer('LOAD_TEST_TIMEOUT_MS', 10000, 100, 60000)
const p95BudgetMs = integer('LOAD_TEST_P95_BUDGET_MS', 800, 1, 60000)
const errorBudgetPercent = Number.parseFloat(process.env.LOAD_TEST_ERROR_BUDGET_PERCENT || '1')
const bearer = process.env.LOAD_TEST_BEARER || ''
const method = (process.env.LOAD_TEST_METHOD || 'GET').toUpperCase()

if (!['GET', 'HEAD'].includes(method)) {
  console.error('LOAD_TEST_METHOD solo admite GET o HEAD para evitar escrituras accidentales.')
  process.exit(2)
}
if (!Number.isFinite(errorBudgetPercent) || errorBudgetPercent < 0 || errorBudgetPercent > 100) {
  console.error('LOAD_TEST_ERROR_BUDGET_PERCENT debe estar entre 0 y 100.')
  process.exit(2)
}

const durations = []
const statusCounts = new Map()
let failures = 0
let cursor = 0

const worker = async () => {
  while (cursor < requests) {
    cursor += 1
    const started = performance.now()
    try {
      const response = await fetch(targetUrl, {
        method,
        headers: bearer ? { Authorization: `Bearer ${bearer}` } : {},
        cache: 'no-store',
        redirect: 'follow',
        signal: AbortSignal.timeout(timeoutMs),
      })
      if (method !== 'HEAD') await response.arrayBuffer()
      const elapsed = performance.now() - started
      durations.push(elapsed)
      statusCounts.set(response.status, (statusCounts.get(response.status) || 0) + 1)
      if (!response.ok) failures += 1
    } catch {
      durations.push(performance.now() - started)
      failures += 1
      statusCounts.set('network_error', (statusCounts.get('network_error') || 0) + 1)
    }
  }
}

const startedAt = performance.now()
await Promise.all(Array.from({ length: Math.min(concurrency, requests) }, worker))
const elapsedMs = performance.now() - startedAt
durations.sort((left, right) => left - right)

const percentile = (value) => {
  const index = Math.min(durations.length - 1, Math.max(0, Math.ceil(value * durations.length) - 1))
  return Number(durations[index].toFixed(1))
}

const errorRate = Number(((failures / requests) * 100).toFixed(2))
const summary = {
  target: `${targetUrl.origin}${targetUrl.pathname}`,
  method,
  requests,
  concurrency,
  throughput_rps: Number((requests / (elapsedMs / 1000)).toFixed(2)),
  latency_ms: {
    min: Number(durations[0].toFixed(1)),
    p50: percentile(0.5),
    p95: percentile(0.95),
    p99: percentile(0.99),
    max: Number(durations.at(-1).toFixed(1)),
  },
  failures,
  error_rate_percent: errorRate,
  status_counts: Object.fromEntries(statusCounts),
  budgets: { p95_ms: p95BudgetMs, error_rate_percent: errorBudgetPercent },
}

console.log(JSON.stringify(summary, null, 2))

if (summary.latency_ms.p95 > p95BudgetMs || errorRate > errorBudgetPercent) {
  console.error('Resultado fuera de los presupuestos definidos.')
  process.exit(1)
}
