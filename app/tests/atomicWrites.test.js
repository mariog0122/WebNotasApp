import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

describe('atomic academic writes', () => {
  it('imports an entire student batch through one transactional RPC', () => {
    const source = readFileSync(
      new URL('../src/views/Courses.vue', import.meta.url),
      'utf8',
    )

    expect(source).toContain("rpc('import_students_batch'")
    expect(source).toContain("accept=\".csv,.xlsx,.xls,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-excel\"")
    expect(source).toContain('5 * 1024 * 1024')
  })

  it('saves numeric and qualitative grade batches transactionally', () => {
    const source = readFileSync(
      new URL('../src/composables/useGradesPage.js', import.meta.url),
      'utf8',
    )

    expect(source).toContain("rpc('save_grade_batch'")
    expect(source).toContain("rpc('save_qualitative_grade_batch'")
  })

  it('assigns subjects and teachers through one guarded RPC', () => {
    const source = readFileSync(
      new URL('../src/views/Courses.vue', import.meta.url),
      'utf8',
    )
    const sql = readFileSync(
      new URL('../../migrations/22_p1_atomic_teacher_assignments.sql', import.meta.url),
      'utf8',
    )

    expect(source).toContain("rpc('save_course_subject_assignments'")
    expect(source).toContain('teacher_id')
    expect(sql).toContain('COURSE_SUBJECT_HAS_ACADEMIC_DATA')
    expect(sql).toContain('INVALID_ASSIGNED_TEACHER')
  })

  it('saves supplementary scores and removals in one authorized transaction', () => {
    const source = readFileSync(
      new URL('../src/views/Reports.vue', import.meta.url),
      'utf8',
    )
    const sql = readFileSync(
      new URL('../../migrations/29_p1_atomic_supplementary_scores.sql', import.meta.url),
      'utf8',
    )

    expect(source).toContain("rpc('save_supplementary_batch'")
    expect(source).not.toMatch(/from\(['"]supplementary_exams['"]\)\.upsert/)
    expect(sql).toContain('CREATE OR REPLACE FUNCTION public.save_supplementary_batch')
    expect(sql).toContain("public.has_tenant_permission('grades.update')")
    expect(sql).toContain('INVALID_SUPPLEMENTARY_TARGET')
    expect(sql).toContain('SUPPLEMENTARY_SCORE_OUT_OF_RANGE')
    expect(sql).toContain('REVOKE ALL ON FUNCTION public.save_supplementary_batch(jsonb, jsonb) FROM PUBLIC, anon')
  })
})
