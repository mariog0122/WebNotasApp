import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { COMMERCIAL_PLANS, getPlan, getPlanPrice } from '../src/lib/commercialPlans'

describe('commercial plan contract', () => {
  it('matches the three plans advertised publicly', () => {
    expect(COMMERCIAL_PLANS).toHaveLength(3)
    expect(getPlan('institutional_500')).toMatchObject({
      monthlyPrice: 89,
      annualPrice: 890,
      maxStudents: 500,
    })
    expect(getPlan('institutional_1000')).toMatchObject({
      monthlyPrice: 129,
      annualPrice: 1290,
      maxStudents: 1000,
    })
    expect(getPlan('institutional_2000')).toMatchObject({
      monthlyPrice: 179,
      annualPrice: 1790,
      maxStudents: 2000,
    })
  })

  it('derives prices from plan and billing cycle', () => {
    expect(getPlanPrice('institutional_500', 'monthly')).toBe(89)
    expect(getPlanPrice('institutional_500', 'yearly')).toBe(890)
    expect(getPlanPrice('missing', 'monthly')).toBeNull()
  })

  it('does not let the provisioning wizard edit or submit a negotiated price', () => {
    const wizardSource = readFileSync(
      new URL('../src/views/superadmin/WizardTab.vue', import.meta.url),
      'utf8',
    )

    expect(wizardSource).not.toMatch(/v-model="form\.price"/)
    expect(wizardSource).not.toContain('p_price: parseFloat')
  })

  it('uses the shared catalog and sends trial requests to sales', () => {
    const pricingSource = readFileSync(
      new URL('../src/views/Pricing.vue', import.meta.url),
      'utf8',
    )

    expect(pricingSource).toContain('COMMERCIAL_PLANS')
    expect(pricingSource).not.toContain("isAnnual ? '890' : '89'")
    expect(pricingSource).not.toMatch(/<router-link[^>]+to="\/login"[^>]*>[\s\S]{0,160}Probar/)
  })

  it('renders plan-backed limits without allowing student-cap overrides', () => {
    const tenantsSource = readFileSync(
      new URL('../src/views/superadmin/TenantsTab.vue', import.meta.url),
      'utf8',
    )
    const hardeningSql = readFileSync(
      new URL('../../migrations/21_p2_plan_limit_integrity.sql', import.meta.url),
      'utf8',
    )

    expect(tenantsSource).toContain('v-if="showLimitsModal"')
    expect(tenantsSource).toContain('aria-labelledby="limits-dialog-title"')
    expect(tenantsSource).not.toMatch(/v-model(?:\.number)?="tenantLimits\.max_students"/)
    expect(hardeningSql).toContain('PLAN_STUDENT_LIMIT_IMMUTABLE')
    expect(hardeningSql).toContain('before insert or update of max_students')
  })
})
