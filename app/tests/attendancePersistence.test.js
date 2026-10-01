import { beforeEach, afterEach, describe, expect, it, vi } from 'vitest'
import { effectScope, nextTick } from 'vue'
import { useAttendance } from '../src/composables/useAttendance'
import { supabase } from '../src/lib/supabase'
import { toast } from 'vue-sonner'

vi.mock('vue', async () => ({ ...await vi.importActual('vue'), onMounted: vi.fn() }))
vi.mock('../src/lib/supabase', () => ({ supabase: { from: vi.fn(), rpc: vi.fn() } }))
vi.mock('../src/stores/auth', () => ({ useAuthStore: () => ({ activeSchoolId: 'school-a', user: { id: 'user-a' }, accessContext: {} }) }))
vi.mock('../src/stores/academicYear', () => ({ useAcademicYearStore: () => ({ selectedYearName: '2026-2027' }) }))
vi.mock('vue-sonner', () => ({ toast: { success: vi.fn(), error: vi.fn(), info: vi.fn() } }))
let scope, state, responses, writes
beforeEach(async () => {
  vi.clearAllMocks()
  writes = []
  responses = {
    students: { data: [{ id: 'student-a', full_name: 'Alumno sintético' }], error: null },
    attendance_records: { data: [{ student_id: 'student-a', status: 'falta_injustificada' }], error: null },
  }
  supabase.from.mockImplementation(table => {
    const q = { then: (resolve, reject) => Promise.resolve(typeof responses[table] === 'function' ? responses[table]() : responses[table] || { data: [], error: null }).then(resolve,reject) }
    for (const op of ['select','eq','or','is','in','order']) q[op] = () => q
    q.upsert = q.update = payload => { writes.push(payload); return q }
    return q
  })
  supabase.rpc.mockResolvedValue({ data: { success: true, saved_count: 1, updated_count: 1 }, error: null })
  scope = effectScope()
  state = scope.run(() => useAttendance())
  state.activeTab.value = 'justifications'
  state.selectedCourse.value = 'course-a'
  await nextTick()
})
afterEach(() => scope.stop())
describe('attendance loading and persistence', () => {
  it('does not expose a roll call as all present when attendance failed to load', async () => {
    responses.attendance_records = { data: null, error: new Error('offline') }
    await state.fetchRollCallData()
    expect(state.students.value).toEqual([])
    await state.saveAttendanceRollCall()
    expect(supabase.rpc).not.toHaveBeenCalled()
    expect(toast.success).not.toHaveBeenCalled()
  })
  it('preserves a recorded absence and confirms a successful RPC', async () => {
    await state.fetchRollCallData()
    expect(state.rollCallState['student-a'].status).toBe('falta_injustificada')
    await state.saveAttendanceRollCall()
    expect(supabase.rpc).toHaveBeenCalledWith('save_attendance_batch',expect.objectContaining({ p_records: [expect.objectContaining({ status: 'falta_injustificada' })] }))
    expect(toast.success).toHaveBeenCalled()
  })
  it('never bypasses a rejected save RPC with a direct table write', async () => {
    await state.fetchRollCallData()
    supabase.rpc.mockResolvedValue({ data: null, error: new Error('denied') })
    await state.saveAttendanceRollCall()
    expect(writes).toEqual([])
    expect(toast.success).not.toHaveBeenCalled()
  })
  it('rejects an unconfirmed save instead of announcing success', async () => {
    await state.fetchRollCallData()
    supabase.rpc.mockResolvedValue({ data: null, error: null })
    await state.saveAttendanceRollCall()
    expect(toast.success).not.toHaveBeenCalled()
  })
  it('prevents saving old students after changing the course', async () => {
    await state.fetchRollCallData()
    state.selectedCourse.value = 'course-b'
    await state.saveAttendanceRollCall()
    expect(supabase.rpc).not.toHaveBeenCalled()
  })
  it('never bypasses a rejected justification RPC with a direct update', async () => {
    state.selectedJustificationStudent.value = { id: 'student-a' }
    state.selectedDatesToJustify.value = ['2026-09-10']
    state.justificationReason.value = 'Motivo sintético'
    supabase.rpc.mockResolvedValue({ data: null, error: new Error('denied') })
    await state.submitJustification()
    expect(writes).toEqual([])
    expect(toast.success).not.toHaveBeenCalled()
  })
  it('discards an earlier request that resolves after a new course loaded', async () => {
    let resolveOld
    responses.students = () => new Promise(resolve => { resolveOld = resolve })
    const oldRequest = state.fetchRollCallData()
    await Promise.resolve(); await Promise.resolve()
    state.selectedCourse.value = 'course-b'
    responses.students = { data: [{ id: 'student-b', full_name: 'Alumno B' }], error: null }
    responses.attendance_records = { data: [], error: null }
    await state.fetchRollCallData()
    resolveOld({ data: [{ id: 'student-a', full_name: 'Alumno A' }], error: null })
    await oldRequest
    expect(state.students.value.map(s => s.id)).toEqual(['student-b'])
  })
})
