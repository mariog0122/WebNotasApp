import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { intelligenceService } from '../src/modules/intelligence/services/intelligenceService'
import { useIntelligenceStore } from '../src/modules/intelligence/stores/useIntelligenceStore'

describe('Intelligence Feature Flags & Rollout (Fase 5)', () => {
  beforeEach(() => {
    vi.restoreAllMocks()
    setActivePinia(createPinia())
  })

  it('checkModuleEnabled: deniega por defecto si el estado remoto no puede verificarse', async () => {
    const isEnabled = await intelligenceService.checkModuleEnabled({
      schoolId: '00000000-0000-0000-0000-000000000001',
      client: {
        rpc: vi.fn().mockResolvedValue({ data: null, error: new Error('remote unavailable') }),
      },
    })

    expect(typeof isEnabled).toBe('boolean')
    expect(isEnabled).toBe(false)
  })

  it('store.verifyFeatureFlag: actualiza reactivamente el estado isFeatureEnabled', async () => {
    vi.spyOn(intelligenceService, 'checkModuleEnabled').mockResolvedValue(false)
    const store = useIntelligenceStore()
    expect(store.isFeatureEnabled).toBe(false)

    const result = await store.verifyFeatureFlag('00000000-0000-0000-0000-000000000001')
    expect(result).toBe(false)
    expect(store.isFeatureEnabled).toBe(false)
  })

  it('resistencia a fallas: si no se provee schoolId, mantiene el módulo deshabilitado', async () => {
    const isEnabled = await intelligenceService.checkModuleEnabled({
      schoolId: null
    })

    expect(isEnabled).toBe(false)
  })
})
