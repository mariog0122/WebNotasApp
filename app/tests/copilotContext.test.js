import { beforeEach, describe, expect, it, vi } from 'vitest'
import { reactive, nextTick } from 'vue'
import { renderComponent } from './helpers/renderComponent'
import Copilot from '../src/components/copilot/LogrevaFloatingCopilot.vue'

const harness = vi.hoisted(() => ({ auth: null, year: null, calls: [], run: vi.fn() }))
vi.mock('../src/stores/auth', () => ({ useAuthStore: () => harness.auth }))
vi.mock('../src/stores/academicYear', () => ({ useAcademicYearStore: () => harness.year }))
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }))
vi.mock('../src/components/copilot/LogrevaBotAvatar.vue', () => ({ default: { render: () => null } }))
vi.mock('../src/lib/ai/agents/LogrevaCopilotOrchestrator', () => ({
  LogrevaCopilotOrchestrator: class {
    constructor(options) { harness.calls.push(options) }
    processQuery(query) { return harness.run(query) }
    setRole() {}
  },
}))
beforeEach(() => {
  harness.auth = reactive({ activeSchoolId: 'a', user: { id: 'u' }, accessContext: { userId: 'u', activeSchoolId: 'a' } })
  harness.year = reactive({ selectedYearName: '2026-2027' })
  harness.calls = []
  harness.run.mockReset()
})
describe('copilot context isolation', () => {
  it('drops an in-flight answer after switching institutions and clears previous messages', async () => {
    let resolve
    harness.run.mockImplementationOnce(() => new Promise(r => { resolve = r }))
    const view = renderComponent(Copilot)
    try {
      view.state.inputQuery = 'asistencia'
      const pending = view.state.handleSubmit()
      harness.auth.activeSchoolId = 'b'
      harness.auth.accessContext = { userId: 'u', activeSchoolId: 'b' }
      await nextTick()
      resolve({ message: 'DATOS PRIVADOS COLEGIO A', data: [{ student: 'Sintético A' }] })
      await pending
      expect(JSON.stringify(view.state.conversation)).not.toContain('COLEGIO A')
      harness.run.mockResolvedValueOnce({ message: 'Respuesta B' })
      view.state.inputQuery = 'cursos'
      await view.state.handleSubmit()
      expect(harness.calls.at(-1)).toMatchObject({ schoolId: 'b', academicYear: '2026-2027', accessContext: { activeSchoolId: 'b' } })
    } finally { view.unmount() }
  })
  it('clears history on year change and logout', async () => {
    harness.run.mockResolvedValue({ message: 'RESPUESTA DEL AÑO ANTERIOR' })
    const view = renderComponent(Copilot)
    try {
      view.state.inputQuery = 'cursos'
      await view.state.handleSubmit()
      harness.year.selectedYearName = '2027-2028'
      await nextTick()
      expect(JSON.stringify(view.state.conversation)).not.toContain('AÑO ANTERIOR')
      view.state.inputQuery = 'cursos'
      await view.state.handleSubmit()
      harness.auth.user = null
      await nextTick()
      expect(JSON.stringify(view.state.conversation)).not.toContain('AÑO ANTERIOR')
    } finally { view.unmount() }
  })

  it('allows dismissing and summoning the assistant correctly', () => {
    const view = renderComponent(Copilot)
    try {
      expect(view.state.isDismissed).toBe(false)
      view.state.dismissCopilot()
      expect(view.state.isDismissed).toBe(true)
      view.state.summonCopilot()
      expect(view.state.isDismissed).toBe(false)
    } finally { view.unmount() }
  })

  it('toggles summon or open when Alt+A shortcut is pressed', () => {
    const view = renderComponent(Copilot)
    try {
      view.state.isDismissed = true
      const preventDefault = vi.fn()
      view.state.handleGlobalKey({ altKey: true, key: 'a', preventDefault })
      expect(preventDefault).toHaveBeenCalled()
      expect(view.state.isDismissed).toBe(false)

      // Now with isDismissed = false, Alt+A toggles isOpen
      expect(view.state.isOpen).toBe(false)
      view.state.handleGlobalKey({ altKey: true, key: 'A', preventDefault })
      expect(view.state.isOpen).toBe(true)
    } finally { view.unmount() }
  })
})
