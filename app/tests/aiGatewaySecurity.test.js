import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useInstitutionAISettings } from '../src/composables/useInstitutionAISettings'
import { EducationAIGateway } from '../src/lib/ai/EducationAIGateway'

const mocks = vi.hoisted(() => ({ from: vi.fn(), invoke: vi.fn(), rpc: vi.fn(), success: vi.fn(), error: vi.fn() }))
vi.mock('../src/lib/supabase', () => ({ supabase: { from: mocks.from, rpc: mocks.rpc, functions: { invoke: mocks.invoke } } }))
vi.mock('../src/stores/auth', () => ({ useAuthStore: () => ({ activeSchoolId: 'school-1', user: { id: 'teacher-1' } }) }))
vi.mock('vue-sonner', () => ({ toast: { success: mocks.success, error: mocks.error } }))

function query(result) {
  const chain = { then: (resolve) => Promise.resolve(result).then(resolve) }
  for (const name of ['select', 'eq', 'gte', 'maybeSingle', 'insert', 'upsert']) chain[name] = vi.fn(() => chain)
  return chain
}

beforeEach(() => { vi.clearAllMocks(); mocks.rpc.mockResolvedValue({ data: null, error: null }) })

describe('Configuración IA sin exponer claves', () => {
  it('lee metadatos explícitos y utiliza count de una respuesta HEAD', async () => {
    const cfg = query({ data: { has_api_key: true, monthly_quota_generations: 200 }, error: null })
    mocks.from.mockImplementation((table) => table === 'institution_ai_settings' ? cfg : query({ data: null, count: 73, error: null }))
    const state = useInstitutionAISettings()
    await state.fetchSettings()
    expect(state.usageStats.value.monthly_usage).toBe(73)
    expect(state.usageStats.value.usage_percentage).toBe(37)
    expect(state.settings.value.hasExistingKey).toBe(true)
    expect(cfg.select.mock.calls[0][0]).not.toContain('*')
    expect(cfg.select.mock.calls[0][0]).not.toContain('encrypted_api_key')
  })

  it.each(['institution_ai_settings', 'ai_usage_ledger'])('informa un fallo de carga de %s', async (failingTable) => {
    mocks.from.mockImplementation((table) => query({ data: null, count: 0, error: table === failingTable ? new Error('Sin acceso') : null }))
    const state = useInstitutionAISettings()
    await state.fetchSettings()
    expect(mocks.error).toHaveBeenCalled()
    expect(state.loading.value).toBe(false)
  })

  it('guarda mediante función y no inventa una clave cuando no existe', async () => {
    mocks.invoke.mockResolvedValue({ data: { has_api_key: false }, error: null })
    mocks.from.mockReturnValue(query({ error: null }))
    const state = useInstitutionAISettings()
    await state.saveSettings()
    expect(mocks.invoke).toHaveBeenCalledWith('education-ai', expect.objectContaining({ body: expect.objectContaining({ action: 'save_settings', schoolId: 'school-1' }) }))
    expect(mocks.from).not.toHaveBeenCalled()
    expect(state.settings.value.hasExistingKey).toBe(false)
  })

  it('prueba una clave guardada sin recuperarla ni llamar al proveedor desde el navegador', async () => {
    mocks.invoke.mockResolvedValue({ data: { success: true, message: 'Conexión verificada' }, error: null })
    const state = useInstitutionAISettings()
    state.settings.value.hasExistingKey = true
    await state.testConnection()
    expect(mocks.invoke).toHaveBeenCalledWith('education-ai', expect.objectContaining({ body: expect.objectContaining({ action: 'test_connection' }) }))
    expect(state.testResult.value.success).toBe(true)
  })
})

describe('Gateway de generación', () => {
  it('usa el proxy sin claves, preserva metadata del servidor y no duplica el ledger real', async () => {
    const result = { summary: { title: 'Plan real' }, _meta: { provider: 'openai', model: 'gpt-4o', isDemo: false } }
    mocks.invoke.mockResolvedValue({ data: result, error: null })
    const gateway = new EducationAIGateway({ schoolId: 'school-1', providerType: 'openai', isDemo: false, quality: 'alta_calidad' })
    const plan = await gateway.generatePlan({ topicTitle: 'Fracciones' })
    expect(mocks.invoke).toHaveBeenCalledWith('education-ai', expect.objectContaining({ body: expect.objectContaining({ action: 'generatePlan', schoolId: 'school-1', quality: 'alta_calidad' }) }))
    expect(plan._meta.model).toBe('gpt-4o')
    expect(plan._meta.isDemo).toBe(false)
    expect(mocks.from).not.toHaveBeenCalled()
  })
})
