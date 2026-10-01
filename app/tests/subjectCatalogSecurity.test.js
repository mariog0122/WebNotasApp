import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

const service = readFileSync(new URL('../src/services/academicService.js', import.meta.url), 'utf8')
const courses = readFileSync(new URL('../src/views/Courses.vue', import.meta.url), 'utf8')
const migration = readFileSync(
  new URL('../../supabase/migrations/20260919194500_secure_subject_catalog.sql', import.meta.url),
  'utf8',
)

describe('secure subject catalog', () => {
  it('uses confirmed RPCs for create, update, delete and import', () => {
    expect(service).toContain("rpc('save_subject_record'")
    expect(service).toContain("rpc('delete_subject_record'")
    expect(service).toContain("rpc('import_subjects_batch'")
    expect(service).not.toContain("from('subjects')")
    expect(service).not.toContain('deleteStudentsBatch')
    expect(service).not.toContain('deleteCoursesBatch')
    expect(service).not.toContain('updateQuarter')
    expect(courses).toContain("rpc('import_subjects_batch'")
    expect(courses).not.toContain("from('subjects').insert")
  })

  it('protects tenant ownership, duplicates and linked academic history', () => {
    expect(migration).toContain('create or replace function public.save_subject_record')
    expect(migration).toContain('create or replace function public.import_subjects_batch')
    expect(migration).toContain('create or replace function public.delete_subject_record')
    expect(migration).toContain("public.has_tenant_permission('subjects.create')")
    expect(migration).toContain("public.has_tenant_permission('subjects.update')")
    expect(migration).toContain("public.has_tenant_permission('subjects.delete')")
    expect(migration).toContain('La asignatura sigue vinculada a uno o más cursos')
    expect(migration).toContain('revoke insert, update, delete on public.subjects from authenticated')
  })
})
