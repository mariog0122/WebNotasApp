import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

const courses = readFileSync(new URL('../src/views/Courses.vue', import.meta.url), 'utf8')
const students = readFileSync(new URL('../src/views/Students.vue', import.meta.url), 'utf8')
const migration = readFileSync(
  new URL('../../supabase/migrations/20260919170000_atomic_academic_bulk_operations.sql', import.meta.url),
  'utf8',
)

describe('atomic academic bulk operations', () => {
  it('deletes student selections and all tenant students through one confirmed RPC', () => {
    expect(students.match(/rpc\('delete_students_batch'/g)).toHaveLength(3)
    expect(students).toContain('p_delete_all: false')
    expect(students).toContain('p_delete_all: true')
    expect(students).toContain('Number(data.deleted_count) !== ids.length')

    const selectedBlock = students.slice(
      students.indexOf('const deleteSelectedStudents'),
      students.indexOf('const deleteAllStudents'),
    )
    expect(selectedBlock).not.toContain('for (let i = 0; i < ids.length')
    expect(selectedBlock).not.toContain("from('students').delete")
  })

  it('deletes one, selected or all visible-year courses through the atomic RPC', () => {
    expect(courses.match(/rpc\('delete_courses_batch'/g)).toHaveLength(3)
    expect(courses).toContain('const ids = courses.value.map(course => course.id)')
    expect(courses).toContain('del año lectivo seleccionado')
    expect(courses).toContain('Number(data.deleted_count) !== ids.length')

    const deleteBlock = courses.slice(
      courses.indexOf('const deleteSelectedCourses'),
      courses.indexOf('const fetchCourseStudents'),
    )
    expect(deleteBlock).not.toContain('for (let i = 0; i < ids.length')
    expect(deleteBlock).not.toContain("from('courses').delete")
  })

  it('requires a complete server confirmation and has no direct import fallback', () => {
    const importBlock = courses.slice(
      courses.indexOf('const importStudentsFromExcel'),
      courses.indexOf('// --- Course CRUD ---'),
    )

    expect(importBlock).toContain("rpc('import_students_batch'")
    expect(importBlock).toContain('Number(rpcRes.total) !== entries.length')
    expect(importBlock).not.toContain('Fallback to direct batch upsert')
    expect(importBlock).not.toContain("from('students').insert")
    expect(importBlock).not.toContain('for (const upd of toUpdate)')
  })

  it('validates tenant ownership, permissions, locked years and transaction results server-side', () => {
    expect(migration).toContain('create or replace function public.delete_students_batch')
    expect(migration).toContain('create or replace function public.delete_courses_batch')
    expect(migration).toContain("public.has_tenant_permission('students.delete')")
    expect(migration).toContain("public.has_tenant_permission('settings.manage')")
    expect(migration).toContain("public.has_tenant_permission('academic_year.update')")
    expect(migration).toContain('pg_advisory_xact_lock')
    expect(migration).toContain('if v_deleted <> v_target_count then')
    expect(migration).toContain('student_address = i.student_address')
    expect(migration).toContain('representative_alt_phone = i.representative_alt_phone')
  })
})
