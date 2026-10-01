import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const sidebarSource = readFileSync(resolve(__dirname, '../src/components/Sidebar.vue'), 'utf8')

describe('nombres visibles de módulos del menú', () => {
  it('usa etiquetas claras y regionalizables para los módulos nuevos', () => {
    for (const label of [
      'Asistencia Escolar',
      'Reportes Académicos',
      'Panel Docente',
      'Indicadores Institucionales',
      'Planificación Curricular IA',
      'Bienestar Estudiantil',
      'Administración Global',
    ]) {
      expect(sidebarSource).toContain(`name: '${label}'`)
    }
  })

  it('conserva las rutas y permisos de cada módulo', () => {
    for (const path of [
      '/attendance',
      '/reports',
      '/intelligence/cockpit',
      '/intelligence/impacto',
      '/planificacion-ia',
      '/alerts',
      '/superadmin',
    ]) {
      expect(sidebarSource).toContain(`path: '${path}'`)
    }
  })
})
