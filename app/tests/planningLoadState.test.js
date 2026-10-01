import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8')

describe('estado de carga del módulo de Planificación IA', () => {
  const composable = read('../src/composables/useAIPlanning.js')
  const view = read('../src/views/AIPlanning.vue')

  it('arranca cargando para no parpadear el aviso de módulo desactivado al entrar', () => {
    expect(composable).toMatch(/const loading = ref\(true\)/)
  })

  it('distingue un error de carga de un módulo desactivado y permite reintentar', () => {
    expect(composable).toContain("const loadError = ref('')")
    expect(composable).toMatch(/loadError\.value = err\?\.message/)
    expect(composable).toMatch(/return \{\s*loading,\s*loadError,/)
    expect(view).toContain('v-if="loadError && !loading"')
    expect(view).toContain('@click="fetchInitialData"')
  })

  it('solo muestra el paywall cuando ya terminó de cargar y no hubo error', () => {
    expect(view).toMatch(/const showPaywall = computed\(\(\) => \(\s*!loading\.value &&\s*!loadError\.value/)
    expect(view).toContain('v-if="showPaywall"')
  })

  it('muestra estados legibles en vez de valores crudos de la base de datos', () => {
    expect(view).toContain("en_revision: 'En revisión'")
    expect(view).toContain('statusLabels[p.status]')
  })
})
