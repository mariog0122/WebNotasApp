import { describe, expect, it, vi } from 'vitest'
import { academicService } from '../src/services/academicService'
import { tenantService } from '../src/services/tenantService'

describe('Service Layer — Academic & Tenant Services', () => {
  it('validates input parameters before executing database calls in academicService', async () => {
    await expect(academicService.createSubject({ name: '', school_id: 'school-123' })).rejects.toThrow(
      'El nombre de la asignatura no puede estar vacío.'
    )
    await expect(academicService.createSubject({ name: 'Matemáticas', school_id: null })).rejects.toThrow(
      'No hay una institución activa seleccionada.'
    )
    await expect(academicService.updateSubject(null, { name: 'Matemáticas' })).rejects.toThrow(
      'ID de asignatura inválido.'
    )
    await expect(academicService.deleteSubject(null)).rejects.toThrow(
      'ID de asignatura inválido.'
    )
    await expect(academicService.importSubjectsBatch([])).rejects.toThrow(
      'No hay asignaturas válidas para importar.'
    )
    expect(academicService.deleteStudentsBatch).toBeUndefined()
    expect(academicService.deleteCoursesBatch).toBeUndefined()
    expect(academicService.updateQuarter).toBeUndefined()
  })

  it('validates tenant IDs in tenantService operations', async () => {
    await expect(tenantService.fetchFeatures(null)).rejects.toThrow('ID de institución requerido.')
    await expect(tenantService.saveFeatures(null, {})).rejects.toThrow('ID de institución requerido.')
    await expect(tenantService.fetchLimits(null)).rejects.toThrow('ID de institución requerido.')
    await expect(tenantService.saveLimits(null, {})).rejects.toThrow('ID de institución requerido.')
  })
})
