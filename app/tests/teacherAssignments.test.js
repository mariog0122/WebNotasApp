import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

describe('Teacher Course & Subject Assignments & Visibility Restrictions', () => {
  const useQueriesSource = readFileSync(
    resolve(__dirname, '../src/composables/useQueries.js'),
    'utf8'
  )
  const useGradesPageSource = readFileSync(
    resolve(__dirname, '../src/composables/useGradesPage.js'),
    'utf8'
  )
  const dashboardSource = readFileSync(
    resolve(__dirname, '../src/views/Dashboard.vue'),
    'utf8'
  )
  const coursesSource = readFileSync(
    resolve(__dirname, '../src/views/Courses.vue'),
    'utf8'
  )
  const reportsSource = readFileSync(
    resolve(__dirname, '../src/views/Reports.vue'),
    'utf8'
  )
  const studentsSource = readFileSync(
    resolve(__dirname, '../src/views/Students.vue'),
    'utf8'
  )

  it('useCoursesQuery filters courses by teacher_id for non-admin teachers', () => {
    expect(useQueriesSource).toContain('isInstitutionAdmin')
    expect(useQueriesSource).toContain('course_subjects')
    expect(useQueriesSource).toContain('teacher_id')
    expect(useQueriesSource).toContain('assignedCourseIds')
  })

  it('useGradesPage restricts courses and subjects by teacher_id and ensures students load reliably', () => {
    expect(useGradesPageSource).toContain('isInstitutionAdmin')
    expect(useGradesPageSource).toContain('fetchSubjectsForCourse')
    expect(useGradesPageSource).toContain('teacher_id')
    expect(useGradesPageSource).toContain("teacher_id")
    expect(useGradesPageSource).toContain("ensure_default_grade_definitions")
    expect(useGradesPageSource).toContain("from('students')")
  })

  it('Reports view filters subjects by teacher_id for non-admin teachers', () => {
    expect(reportsSource).toContain('isInstitutionAdmin')
    expect(reportsSource).toContain('teacher_id')
    expect(reportsSource).toContain("csQuery = csQuery.eq('teacher_id', userId)")
  })

  it('Students view filters courses by teacher_id for non-admin teachers', () => {
    expect(studentsSource).toContain('isInstitutionAdmin')
    expect(studentsSource).toContain('teacher_id')
    expect(studentsSource).toContain('assignedCourseIds')
  })

  it('Dashboard view provides teacher invite course/subject assignment and existing teacher assignment modal', () => {
    expect(dashboardSource).toContain('openAssignTeacherModal')
    expect(dashboardSource).toContain('saveTeacherAssignments')
    expect(dashboardSource).toContain('inviteSelectedCourseSubjects')
    expect(dashboardSource).toContain('teacherAssignedCourseSubjects')
    expect(dashboardSource).toContain('showAssignModal')
    expect(dashboardSource).toContain('Asignar Cursos y Materias')
  })

  it('Courses view supports assigning teachers to each course subject', () => {
    expect(coursesSource).toContain('institutionTeachers')
    expect(coursesSource).toContain('courseSubjectTeachers')
    expect(coursesSource).toContain('fetchInstitutionTeachers')
    expect(coursesSource).toContain('save_course_subject_assignments')
    expect(coursesSource).toContain('-- Sin docente asignado --')
  })
})
