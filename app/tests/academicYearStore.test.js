import { describe, expect, it } from 'vitest'
import fs from 'node:fs'
import path from 'node:path'
import { canManageAcademicYearLock, isInstitutionAdmin } from '../src/lib/permissions'

const root = path.resolve(import.meta.dirname, '..')
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8')

describe('Academic Year Unified Logic and Banner', () => {
  it('defines the centralized useAcademicYearStore with isLocked and toggleAcademicYearLock', async () => {
    const storeFile = read('src/stores/academicYear.js')
    expect(storeFile).toContain("defineStore('academicYear'")
    expect(storeFile).toContain('selectedYearId')
    expect(storeFile).toContain('selectedYearName')
    expect(storeFile).toContain('isCurrentYear')
    expect(storeFile).toContain('isLocked')
    expect(storeFile).toContain('toggleAcademicYearLock')
    expect(storeFile).toContain('fetchAcademicYears')
    expect(storeFile).toContain('setSelectedYearId')
    expect(storeFile).toContain('logreva-selected-academic-year')
  })

  it('correctly authorizes Superadmin, Admin, and Rector to lock/unlock academic year while denying teachers', () => {
    // Superadmin context
    const superadminCtx = { isPlatformAdmin: true, activeMembership: null, raw: { role: 'superadmin' } }
    expect(canManageAcademicYearLock(superadminCtx)).toBe(true)

    // School Admin context
    const adminCtx = { isPlatformAdmin: false, activeMembership: { role: 'school_admin' }, raw: {} }
    expect(canManageAcademicYearLock(adminCtx)).toBe(true)

    // Rector context
    const rectorCtx = { isPlatformAdmin: false, activeMembership: { role: 'rector' }, raw: {} }
    expect(canManageAcademicYearLock(rectorCtx)).toBe(true)

    // Legacy Admin profile
    const legacyAdminCtx = { isPlatformAdmin: false, activeMembership: null, raw: { role: 'admin' } }
    expect(canManageAcademicYearLock(legacyAdminCtx)).toBe(true)

    // Teacher context (Denied)
    const teacherCtx = { isPlatformAdmin: false, activeMembership: { role: 'teacher' }, raw: { role: 'teacher' } }
    expect(canManageAcademicYearLock(teacherCtx)).toBe(false)

    // Student context (Denied)
    const studentCtx = { isPlatformAdmin: false, activeMembership: { role: 'student' }, raw: { role: 'student' } }
    expect(canManageAcademicYearLock(studentCtx)).toBe(false)
  })

  it('creates the reusable AcademicYearBanner component with padlock lock control and confirmation modal', () => {
    const banner = read('src/components/ui/AcademicYearBanner.vue')
    expect(banner).toContain('useAcademicYearStore')
    expect(banner).toContain('canManageAcademicYearLock')
    expect(banner).toContain('selectedYearName')
    expect(banner).toContain('isCurrentYear')
    expect(banner).toContain('isLocked')
    expect(banner).toContain('showLockModal')
    expect(banner).toContain('handlePadlockClick')
    expect(banner).toContain('confirmToggleLock')
    expect(banner).toContain('Bloqueado')
    expect(banner).toContain('Año Lectivo en Curso')
    expect(banner).toContain('Una vez bloqueado los docentes no podrán realizar cambios')
    expect(banner).toContain('onYearChange')
  })

  it('integrates AcademicYearBanner in all platform modules', () => {
    const requiredModules = [
      'src/views/Dashboard.vue',
      'src/views/Courses.vue',
      'src/views/Grades.vue',
      'src/views/Reports.vue',
      'src/views/Students.vue',
      'src/views/Subjects.vue',
      'src/views/Families.vue',
      'src/views/Alerts.vue',
    ]

    for (const file of requiredModules) {
      const content = read(file)
      expect(content, `${file} debe incluir AcademicYearBanner`).toContain('AcademicYearBanner')
    }
  })

  it('includes persistent Academic Year indicator in MainLayout header', () => {
    const mainLayout = read('src/components/MainLayout.vue')
    expect(mainLayout).toContain('useAcademicYearStore')
    expect(mainLayout).toContain('academicYearStore.selectedYearName')
  })

  it('scopes courses in Courses, Grades, Reports, Families, Students, and Alerts to the active academic year', () => {
    const coursesView = read('src/views/Courses.vue')
    expect(coursesView).toContain('useAcademicYearStore')
    expect(coursesView).toContain('selectedAcademicYearName')
    expect(coursesView).toContain('isYearLocked')

    const gradesComposable = read('src/composables/useGradesPage.js')
    expect(gradesComposable).toContain('useAcademicYearStore')
    expect(gradesComposable).toContain("eq('academic_year', yearName)")
    expect(gradesComposable).toContain('isYearLocked')

    const reportsView = read('src/views/Reports.vue')
    expect(reportsView).toContain('useAcademicYearStore')
    expect(reportsView).toContain('academicYearStore.selectedYearName')

    const familiesView = read('src/views/Families.vue')
    expect(familiesView).toContain('useAcademicYearStore')
    expect(familiesView).toContain('academicYearStore.selectedYearName')

    const studentsView = read('src/views/Students.vue')
    expect(studentsView).toContain('useAcademicYearStore')
    expect(studentsView).toContain("eq('academic_year', yearName)")
    expect(studentsView).toContain('isYearLocked')

    const alertsView = read('src/views/Alerts.vue')
    expect(alertsView).toContain('useAcademicYearStore')
    expect(alertsView).toContain('academicYearStore.selectedYearName')
  })
})
