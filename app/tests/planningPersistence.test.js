import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useAIPlanning } from '../src/composables/useAIPlanning'

const mock = vi.hoisted(() => ({ from: vi.fn(), rpc: vi.fn(), success: vi.fn(), error: vi.fn(), warning: vi.fn() }))
vi.mock('../src/lib/supabase', () => ({ supabase: { from: mock.from, rpc: mock.rpc } }))
vi.mock('../src/stores/auth', () => ({ useAuthStore: () => ({ activeSchoolId: 'school', user: { id: 'teacher' }, profile: { school_id: 'school' } }) }))
vi.mock('../src/stores/academicYear', () => ({ useAcademicYearStore: () => ({ selectedYearName: '2026-2027' }) }))
vi.mock('vue-sonner', () => ({ toast: { success: mock.success, error: mock.error, warning: mock.warning } }))
vi.mock('../src/lib/ai/EducationAIGateway', () => ({ EducationAIGateway: class {
  async generatePlan() { return { summary: { title: 'Plan sintético' }, _meta: { isDemo: true } } }
  async generateResource() { return { title: 'Recurso sintético' } }
  async generateStudentSupport() { return { weekly_plan: [] } }
} }))
const chain = result => {
  const q = { then: (resolve, reject) => Promise.resolve(result).then(resolve, reject) }
  for (const key of ['select', 'eq', 'maybeSingle', 'single', 'insert', 'update', 'delete', 'order']) q[key] = () => q
  return q
}
beforeEach(() => {
  vi.clearAllMocks()
  mock.from.mockImplementation(table => chain(table === 'institution_ai_settings'
    ? { data: { mode: 'demo', provider: 'gemini', has_api_key: false }, error: null }
    : { data: null, error: new Error('Persistencia rechazada') }))
  mock.rpc.mockResolvedValue({ data: null, error: new Error('Persistencia rechazada') })
})
describe('planning never reports persistence after a rejected database operation', () => {
  it('does not invent a local plan after a failed insert', async () => {
    const state = useAIPlanning()
    state.moduleAccess.value.module_enabled = true
    await state.generatePlanWithAI()
    expect(state.lessonPlans.value).toEqual([])
    expect(state.activePlan.value).toBeNull()
    expect(mock.error).toHaveBeenCalled()
    expect(mock.success).not.toHaveBeenCalled()
  })
  it('does not duplicate a plan locally after a failed insert', async () => {
    const state = useAIPlanning()
    await state.duplicatePlan({ id: 'existing', title: 'Plan' })
    expect(state.lessonPlans.value).toEqual([])
    expect(mock.error).toHaveBeenCalled()
  })
  it('keeps a plan visible when deletion fails', async () => {
    const state = useAIPlanning()
    state.lessonPlans.value = [{ id: 'existing', title: 'Plan' }]
    await state.deletePlan('existing')
    expect(state.lessonPlans.value).toHaveLength(1)
    expect(mock.success).not.toHaveBeenCalled()
  })
  it('does not advance the version when saving fails', async () => {
    const state = useAIPlanning()
    state.activePlan.value = { id: 'existing', version: 1 }
    await state.saveActivePlan()
    expect(state.activePlan.value.version).toBe(1)
    expect(mock.success).not.toHaveBeenCalled()
  })
  it('does not invent a teaching resource after a failed insert', async () => {
    const state = useAIPlanning()
    state.activePlan.value = { id: 'existing' }
    await state.createResource('rubrica')
    expect(state.activeResources.value).toEqual([])
    expect(mock.success).not.toHaveBeenCalled()
  })
  it('does not invent a student support plan after a failed insert', async () => {
    const state = useAIPlanning()
    state.activePlan.value = { id: 'existing' }
    await state.createStudentSupport('student', {})
    expect(state.activeSupportPlans.value).toEqual([])
    expect(mock.success).not.toHaveBeenCalled()
  })
})

describe('confirmed planning writes preserve normal behavior', () => {
  function database({ versionSaveFails = false } = {}) {
    const writes = []
    mock.rpc.mockImplementation(async (name, args) => {
      writes.push({ table: `rpc:${name}`, method: 'rpc', payload: args })
      if (name === 'save_lesson_plan_version') {
        if (versionSaveFails) return { data: null, error: new Error('Atomic version save failed') }
        const version = (args.p_expected_version || 1) + 1
        return {
          data: {
            success: true,
            history_saved: true,
            version,
            plan: { ...args.p_payload, id: args.p_plan_id, version },
          },
          error: null,
        }
      }
      return { data: null, error: new Error('Unexpected RPC') }
    })
    mock.from.mockImplementation(table => {
      if (table === 'institution_ai_settings') return chain({ data: { mode: 'demo', provider: 'gemini', has_api_key: false }, error: null })
      let payload
      const q = { then: (resolve, reject) => {
        return Promise.resolve({ data: payload === 'delete' ? [{ id: 'persisted' }] : { ...payload, id: 'persisted' }, error: null }).then(resolve, reject)
      } }
      for (const method of ['select', 'single', 'eq']) q[method] = () => q
      for (const method of ['insert', 'update', 'delete']) q[method] = value => {
        payload = method === 'delete' ? 'delete' : value
        writes.push({ table, method, payload })
        return q
      }
      return q
    })
    return writes
  }

  it('displays the persisted plan with the selected academic year and verified teacher', async () => {
    const writes = database()
    const state = useAIPlanning()
    state.moduleAccess.value.module_enabled = true
    await state.generatePlanWithAI()
    expect(state.activePlan.value).toMatchObject({ id: 'persisted', academic_year: '2026-2027', teacher_id: 'teacher' })
    expect(state.lessonPlans.value).toHaveLength(1)
    expect(writes[0].payload.academic_year).toBe('2026-2027')
    expect(mock.success).toHaveBeenCalledTimes(1)
  })

  it('saves the matching version in the plan and its history snapshot', async () => {
    const writes = database()
    const state = useAIPlanning()
    state.activePlan.value = { id: 'persisted', version: 1, status: 'borrador' }
    expect(await state.saveActivePlan()).toBe(true)
    expect(state.activePlan.value.version).toBe(2)
    expect(writes.find(item => item.table === 'rpc:save_lesson_plan_version').payload).toMatchObject({
      p_plan_id: 'persisted', p_expected_version: 1, p_payload: { id: 'persisted', version: 2 },
    })
  })

  it('keeps the local version unchanged when the atomic plan and history save fails', async () => {
    database({ versionSaveFails: true })
    const state = useAIPlanning()
    state.activePlan.value = { id: 'persisted', version: 1, status: 'borrador' }
    expect(await state.saveActivePlan()).toBe(false)
    expect(state.activePlan.value.version).toBe(1)
    expect(mock.warning).not.toHaveBeenCalled()
    expect(mock.error).toHaveBeenCalledTimes(1)
  })

  it('removes a plan only after the server confirms its deletion', async () => {
    database()
    const state = useAIPlanning()
    state.lessonPlans.value = [{ id: 'persisted' }]
    await state.deletePlan('persisted')
    expect(state.lessonPlans.value).toEqual([])
    expect(mock.success).toHaveBeenCalledTimes(1)
  })
})
