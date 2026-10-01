import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

describe('production operations readiness', () => {
  it('gates changes with install, unit, build and browser checks', () => {
    const workflow = readFileSync(
      new URL('../../.github/workflows/ci.yml', import.meta.url),
      'utf8',
    )

    expect(workflow).toContain('npm ci')
    expect(workflow).toContain('npm run test')
    expect(workflow).toContain('npm run build')
    expect(workflow).toContain('npm run test:e2e')
  })

  it('shows measured platform health instead of hardcoded green services', () => {
    const source = readFileSync(
      new URL('../src/views/superadmin/HealthTab.vue', import.meta.url),
      'utf8',
    )

    expect(source).toContain("rpc('get_platform_health'")
    expect(source).not.toMatch(/status:\s*'Operational'/)
  })

  it('documents recovery objectives and a restore drill', () => {
    const runbook = readFileSync(
      new URL('../../docs/OPERATIONS_RUNBOOK.md', import.meta.url),
      'utf8',
    )

    expect(runbook).toContain('RPO')
    expect(runbook).toContain('RTO')
    expect(runbook).toContain('restore-drill.ps1')
  })

  it('defines measurable SLOs and an explicit opt-in load test', () => {
    const packageJson = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8'))
    const loadTest = readFileSync(new URL('../scripts/load-test.mjs', import.meta.url), 'utf8')
    const slo = readFileSync(new URL('../../docs/SLO_AND_CAPACITY.md', import.meta.url), 'utf8')

    expect(packageJson.scripts['test:load']).toBe('node scripts/load-test.mjs')
    expect(loadTest).toContain('LOAD_TEST_ACKNOWLEDGE')
    expect(loadTest).toContain('p95')
    expect(loadTest).toContain('AbortSignal.timeout')
    expect(slo).toContain('99.5%')
    expect(slo).toContain('p95')
    expect(slo).toContain('presupuesto de error')
  })
})
