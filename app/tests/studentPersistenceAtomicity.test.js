import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

const readApp = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
const readWorkspace = (path) => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8')

describe('atomic student persistence', () => {
  it('saves students through one confirmed RPC after preparing private images', () => {
    const helper = readApp('src/lib/studentPersistence.js')
    expect(helper).toContain("rpc('save_student_record'")
    expect(helper).toContain('student_photo_url')
    expect(helper).toContain('representative_photo_url')
    expect(helper).toContain('El servidor no confirmó el guardado del estudiante.')
    expect(helper).toContain("storage.from('student-photos').remove")
  })

  it('removes direct student writes from both management screens', () => {
    for (const path of ['src/views/Students.vue', 'src/views/Courses.vue']) {
      const source = readApp(path)
      const saveBlock = source.slice(
        source.indexOf('const saveStudent = async'),
        source.indexOf('const deleteStudent = async'),
      )
      expect(saveBlock, path).toContain('saveStudentRecord')
      expect(saveBlock, path).not.toMatch(/\.from\(['"]students['"]\)/)
      expect(saveBlock, path).not.toContain('.insert(')
      expect(saveBlock, path).not.toContain('.update(')
    }
  })

  it('uses the authorized batch RPC for the course-modal deletion', () => {
    const courses = readApp('src/views/Courses.vue')
    const deleteBlock = courses.slice(
      courses.indexOf('const deleteStudent = async'),
      courses.indexOf('const normalizeHeader'),
    )
    expect(deleteBlock).toContain("rpc('delete_students_batch'")
    expect(deleteBlock).toContain('Number(data.deleted_count) !== 1')
    expect(deleteBlock).not.toMatch(/\.from\(['"]students['"]\)/)
  })

  it('validates tenant, permission, course, locked year, capacity and exact result server-side', () => {
    const migration = readWorkspace('supabase/migrations/20260919183000_atomic_student_persistence.sql')
    expect(migration).toContain('create or replace function public.save_student_record')
    expect(migration).toContain("public.has_tenant_permission('students.create')")
    expect(migration).toContain("public.has_tenant_permission('students.update')")
    expect(migration).toContain("public.has_tenant_permission('academic_year.update')")
    expect(migration).toContain('pg_advisory_xact_lock')
    expect(migration).toContain('Límite de estudiantes alcanzado')
    expect(migration).toContain("'STUDENT_CREATED'")
    expect(migration).toContain("'STUDENT_UPDATED'")
  })
})
