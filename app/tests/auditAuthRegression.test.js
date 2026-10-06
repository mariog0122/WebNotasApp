import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { effectScope, nextTick, ref } from 'vue'

const mock = vi.hoisted(() => ({
  from: vi.fn(), rpc: vi.fn(), listener: null,
  getSession: vi.fn(), signInWithPassword: vi.fn(), signOut: vi.fn(),
}))

vi.mock('../src/lib/supabase', () => ({ supabase: {
  from: mock.from, rpc: mock.rpc,
  auth: {
    getSession: mock.getSession,
    signInWithPassword: mock.signInWithPassword,
    signOut: mock.signOut,
    onAuthStateChange: (fn) => { mock.listener = fn; return { data: {} } },
  },
} }))
vi.mock('../src/lib/storageUtils', () => ({
  normalizeStoragePath: () => '', resolvePrivateImageUrl: async () => '',
}))
vi.mock('../src/stores/academicYear', () => ({
  useAcademicYearStore: () => ({ isLocked: false, selectedYearName: '2026-2027' }),
}))
vi.mock('../src/composables/useNetwork', () => ({ useNetwork: () => ({ isOnline: ref(true) }) }))
vi.mock('vue-sonner', () => ({ toast: { error: vi.fn(), success: vi.fn(), warning: vi.fn(), info: vi.fn() } }))
vi.mock('@tanstack/vue-query', () => ({ useQuery: (options) => options }))

import { useAuthStore } from '../src/stores/auth'
import { useGradesPage } from '../src/composables/useGradesPage'
import { createAuthorizationContext } from '../src/lib/permissions'

const deferred = () => {
  let resolve
  const promise = new Promise((r) => { resolve = r })
  return { promise, resolve }
}
const chain = (response) => {
  const q = { then: (resolve, reject) => Promise.resolve(typeof response === 'function' ? response() : response).then(resolve, reject) }
  for (const method of ['select', 'eq', 'in', 'or', 'order', 'range', 'maybeSingle']) q[method] = () => q
  return q
}
const context = (userId) => ({
  user_id: userId, default_school_id: 'school-1',
  memberships: [{ school_id: 'school-1', role: 'school_admin', permissions: ['grades.read', 'students.read'] }],
})
let scope

beforeEach(() => {
  vi.clearAllMocks()
  vi.useFakeTimers()
  setActivePinia(createPinia())
  mock.signOut.mockResolvedValue({ error: null })
  mock.rpc.mockImplementation(async (name) => name === 'get_my_access_context'
    ? { data: context('user-1'), error: null }
    : { data: { success: true }, error: null })
})
afterEach(() => {
  scope?.stop()
  scope = null
  vi.clearAllTimers()
  vi.useRealTimers()
})

const setupGrades = async (level = 'MEDIA', records = []) => {
  const auth = useAuthStore()
  auth.user = { id: 'user-1' }
  auth.profile = { id: 'user-1', school_id: 'school-1' }
  auth.accessContext = createAuthorizationContext(context('user-1'))
  const database = { records }
  mock.from.mockImplementation((table) => chain(() => {
    const rows = {
      students: [{ id: 'student-1', full_name: 'Estudiante sintético' }],
      course_subjects: [{ id: 'link-1', subject_id: 'subject-1', subjects: { name: 'Materia sintética' } }],
      grade_definitions: [{ id: 'definition-1', category: 'INDIVIDUAL', name: 'Lección', sort_order: 1 }],
      grades: database.records,
      qualitative_grades: database.records,
    }
    return { data: rows[table] || [], error: table === 'grades' ? database.error || null : null }
  }))
  scope = effectScope()
  const page = scope.run(() => useGradesPage())
  page.courses = [{ id: 'course-1', level, name: 'Curso sintético' }]
  page.selectedCourse = 'course-1'
  page.selectedQuarter = 'quarter-1'
  await nextTick()
  await vi.advanceTimersByTimeAsync(0)
  return { page, database }
}

describe('audit: grade persistence regression', () => {
  it('invalidates the open qualitative sheet when the period changes', async () => {
    const { page, database } = await setupGrades('ELEMENTAL', [{ student_id: 'student-1', score_text: 'A+' }])
    const subject = page.subjects[0]
    await page.openGradeSheet(subject)
    expect(page.qualitativeScores['student-1']).toBe('A+')
    database.records = []
    page.selectedQuarter = 'quarter-2'
    await nextTick()
    await vi.advanceTimersByTimeAsync(0)

    // A safe transition may close the sheet, or reload it with the new period.
    expect(page.activeSubjectId === null || page.qualitativeScores['student-1'] !== 'A+').toBe(true)
  })

  it('keeps a deleted numeric grade blank after closing and reopening the sheet', async () => {
    const { page, database } = await setupGrades('MEDIA', [{ student_id: 'student-1', grade_definition_id: 'definition-1', score: 8 }])
    const subject = page.subjects[0]
    await page.openGradeSheet(subject)
    page.grades['student-1']['definition-1'] = ''
    await page.saveCurrentGrades()
    expect(mock.rpc).toHaveBeenCalledWith('save_grade_batch', expect.objectContaining({
      p_deletes: [{ student_id: 'student-1', grade_definition_id: 'definition-1' }],
    }))
    database.records = []
    await page.openGradeSheet(subject)
    await page.openGradeSheet(subject)
    expect(page.grades['student-1']['definition-1'] || '').toBe('')
  })

  it('refuses to save cached grades after a failed reload', async () => {
    const { page, database } = await setupGrades('MEDIA', [{ student_id: 'student-1', grade_definition_id: 'definition-1', score: 8 }])
    const subject = page.subjects[0]
    await page.openGradeSheet(subject)
    await page.openGradeSheet(subject)
    database.error = new Error('Network failure')
    await page.openGradeSheet(subject)
    mock.rpc.mockClear()
    await page.saveCurrentGrades()
    expect(mock.rpc).not.toHaveBeenCalledWith('save_grade_batch', expect.anything())
  })

  it('keeps the current period and unsaved changes when a teacher attempts to switch', async () => {
    const { page } = await setupGrades('MEDIA', [])
    await page.openGradeSheet(page.subjects[0])
    page.grades['student-1']['definition-1'] = 9
    page.selectedQuarter = 'quarter-2'
    await nextTick()
    expect(page.selectedQuarter).toBe('quarter-1')
    expect(page.grades['student-1']['definition-1']).toBe(9)
  })
})

describe('audit: identity transitions', () => {
  it('does not associate the previous pending profile with the next signed-in user', async () => {
    const previousProfile = deferred()
    mock.signInWithPassword.mockImplementation(async ({ email }) => ({ data: { user: { id: email } }, error: null }))
    mock.from.mockReturnValueOnce(chain(previousProfile.promise))
      .mockReturnValue(chain({ data: { id: 'user-b', school_id: 'school-1', role: 'teacher' }, error: null }))
    mock.rpc.mockResolvedValue({ data: context('user-b'), error: null })
    const auth = useAuthStore()
    const firstLogin = auth.signIn('user-a', 'synthetic-password')
    await Promise.resolve()
    mock.listener('SIGNED_OUT', null)
    const secondLogin = auth.signIn('user-b', 'synthetic-password')
    await Promise.resolve()
    previousProfile.resolve({ data: { id: 'user-a', school_id: 'school-1', role: 'teacher' }, error: null })
    await Promise.allSettled([firstLogin, secondLogin])
    expect(auth.user?.id).toBe('user-b')
    expect(auth.profile?.id).toBe('user-b')
    expect(auth.accessContext.userId).toBe('user-b')
  })

  it('keeps the local identity when remote sign-out fails so logout is not falsely reported', async () => {
    const auth = useAuthStore()
    auth.user = { id: 'user-1' }
    auth.profile = { id: 'user-1', school_id: 'school-1' }
    mock.signOut.mockResolvedValue({ error: new Error('Network unavailable') })
    await expect(auth.signOut()).rejects.toThrow('Network unavailable')
    expect(auth.user.id).toBe('user-1')
    expect(auth.profile.id).toBe('user-1')
  })
})
