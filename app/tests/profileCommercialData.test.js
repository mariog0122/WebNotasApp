import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

const profile = readFileSync(new URL('../src/views/Profile.vue', import.meta.url), 'utf8')

describe('profile commercial data', () => {
  it('fails closed and never invents a plan, price, or student limit', () => {
    expect(profile).toContain('const subscriptionError = ref')
    expect(profile).toContain('.find(result => result.error)')
    expect(profile).toContain('No se pudo cargar la suscripción:')
    expect(profile).toContain('Sin plan asignado')
    expect(profile).toContain('Sin límite asignado')
    expect(profile).not.toContain("|| 'Plan Institucional Estándar'")
    expect(profile).not.toMatch(/\?\?\s*89/)
    expect(profile).not.toMatch(/\?\?\s*500/)
  })
})
