import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

const modal = readFileSync(new URL('../src/components/grades/StudentRecoveryModal.vue', import.meta.url), 'utf8')
const planning = readFileSync(new URL('../src/composables/useAIPlanning.js', import.meta.url), 'utf8')
const migration = readFileSync(
  new URL('../../supabase/migrations/20260919210000_atomic_student_support_plan_creation.sql', import.meta.url),
  'utf8',
)

describe('student support plan persistence', () => {
  it('uses the real schema and one confirmed RPC from both creation flows', () => {
    expect(modal).toContain("rpc('create_student_support_plan'")
    expect(planning).toContain("rpc('create_student_support_plan'")
    expect(modal).toContain('@click="saveToDatabase"')
    expect(modal).toContain('No se pudo guardar el plan')
    expect(modal).not.toContain("subject_name: props.subjectName")
    expect(modal).not.toContain('content: generatedContent.value')
    expect(planning).not.toMatch(/from\('student_support_plans'\)[\s\S]{0,120}\.insert\(/)
  })

  it('validates tenant relationships and revokes direct browser inserts', () => {
    expect(migration).toContain('public.can_access_lesson_plan(p_school_id, v_teacher_id)')
    expect(migration).toContain('s.id = p_student_id')
    expect(migration).toContain('cs.school_id = p_school_id')
    expect(migration).toContain('revoke insert on public.student_support_plans from authenticated')
  })
})
