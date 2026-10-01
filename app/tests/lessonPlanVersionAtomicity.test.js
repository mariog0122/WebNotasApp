import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

const planning = readFileSync(new URL('../src/composables/useAIPlanning.js', import.meta.url), 'utf8')
const migration = readFileSync(
  new URL('../../supabase/migrations/20260919213000_atomic_lesson_plan_version_save.sql', import.meta.url),
  'utf8',
)

describe('atomic lesson plan version saving', () => {
  it('updates the plan and version history through one confirmed RPC', () => {
    expect(planning).toContain("rpc('save_lesson_plan_version'")
    expect(planning).toContain('data.history_saved !== true')
    expect(planning).not.toMatch(/from\('lesson_plans'\)[\s\S]{0,100}\.update\(/)
    expect(planning).not.toMatch(/from\('lesson_plan_versions'\)[\s\S]{0,100}\.insert\(/)
  })

  it('locks the row, rejects stale versions, and revokes both direct writes', () => {
    expect(migration).toContain('where id = p_plan_id for update')
    expect(migration).toContain("using errcode = '40001'")
    expect(migration).toContain('insert into public.lesson_plan_versions')
    expect(migration).toContain('revoke update on public.lesson_plans from authenticated')
    expect(migration).toContain('revoke insert on public.lesson_plan_versions from authenticated')
  })
})
