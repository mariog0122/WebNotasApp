import { describe, it, expect } from 'vitest'
import { intelligenceService } from '../src/modules/intelligence/services/intelligenceService'

describe('Intelligence Impact Analytics & Longitudinal Passport (Fase 4)', () => {
  it('fetchImpactAnalytics: exige una institución activa', async () => {
    await expect(intelligenceService.fetchImpactAnalytics({ schoolId: null }))
      .rejects.toThrow('No hay una institución activa para consultar los indicadores.')
  })

  it('fetchStudentLongitudinalPassport: exige estudiante e institución', async () => {
    await expect(intelligenceService.fetchStudentLongitudinalPassport({
      studentId: null,
      schoolId: 'school-1'
    })).rejects.toThrow('Estudiante e institución son obligatorios para consultar el pasaporte.')
  })

  it('rechaza también el pasaporte cuando falta la institución', async () => {
    await expect(intelligenceService.fetchStudentLongitudinalPassport({
      studentId: 'student-1',
      schoolId: null
    })).rejects.toThrow('Estudiante e institución son obligatorios para consultar el pasaporte.')
  })
})
