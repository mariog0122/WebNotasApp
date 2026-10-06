import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

const courses = readFileSync(new URL('../src/views/Courses.vue', import.meta.url), 'utf8')
const migration = readFileSync(
  new URL('../../supabase/migrations/20260919193000_secure_course_persistence.sql', import.meta.url),
  'utf8',
)

describe('secure course persistence', () => {
  it('creates and updates through one server-confirmed RPC', () => {
    const block = courses.slice(
      courses.indexOf('const saveCourse = async'),
      courses.indexOf('const deleteCourse = async'),
    )
    expect(block).toContain("rpc('save_course_record'")
    expect(block).toContain('El servidor no confirmó el guardado del curso.')
    expect(block).not.toContain("from('courses')")
    expect(block).not.toContain('dupQuery')
  })

  it('validates tenant, permissions, year locks and duplicates in PostgreSQL', () => {
    expect(migration).toContain('create or replace function public.save_course_record')
    expect(migration).toContain("public.has_tenant_permission('courses.create')")
    expect(migration).toContain("public.has_tenant_permission('courses.update')")
    expect(migration).toContain("public.has_tenant_permission('academic_year.update')")
    expect(migration).toContain('pg_advisory_xact_lock')
    expect(migration).toContain('DUPLICATE_COURSE_NAME')
    expect(migration).toContain('revoke insert, update on public.courses from authenticated')
  })
})
