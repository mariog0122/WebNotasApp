import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

const courses = readFileSync(new URL('../src/views/Courses.vue', import.meta.url), 'utf8')
const dashboard = readFileSync(new URL('../src/views/Dashboard.vue', import.meta.url), 'utf8')
const migration = readFileSync(
  new URL('../../supabase/migrations/20260919163000_atomic_teacher_course_subject_assignments.sql', import.meta.url),
  'utf8',
)

describe('course subject assignments', () => {
  it('never bypasses the atomic course assignment RPC', () => {
    const saveBlock = courses.slice(courses.indexOf('const saveCourseSubjects = async'), courses.indexOf('</script>'))
    expect(saveBlock).toContain("rpc('save_course_subject_assignments'")
    expect(saveBlock).toContain('La base de datos no confirmó todas las asignaciones del curso.')
    expect(saveBlock).not.toContain("rpc('sync_course_subject_assignments'")
    expect(saveBlock).not.toContain("from('course_subjects').upsert")
  })

  it('uses one atomic RPC for teacher assignment selections and confirms the result', () => {
    expect(dashboard).toContain("rpc('set_teacher_course_subject_assignments'")
    expect(dashboard).toContain('La base de datos no confirmó todas las asignaciones docentes.')
    expect(dashboard).not.toMatch(/from\('course_subjects'\)[\s\S]{0,180}\.update\(\{ teacher_id:/)
  })

  it('validates permission, target teacher and every course subject in the database', () => {
    expect(migration).toContain("public.has_tenant_permission('users.manage')")
    expect(migration).toContain("tr.name = 'teacher'")
    expect(migration).toContain('cs.school_id = p_school_id')
    expect(migration).toContain('p_selected_ids <@ p_scope_ids')
    expect(migration).toContain('pg_advisory_xact_lock')
  })
})
