import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

describe('planning courses query', () => {
  it('does not select columns that courses does not have (courses.parallel)', () => {
    const source = readFileSync(new URL('../src/composables/useAIPlanning.js', import.meta.url), 'utf8')
    const coursesSelect = source.match(/from\('courses'\)\.select\('([^']+)'\)/)?.[1] || ''
    expect(coursesSelect).toContain('id')
    expect(coursesSelect).not.toMatch(/parallel/)
  })
})
