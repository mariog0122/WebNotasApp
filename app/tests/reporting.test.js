import { describe, it, expect } from 'vitest'
import {
  groupBy,
  getQuarterOrder,
  getPeriodLabel,
  computeProjectAverage,
  computeSubjectTotal
} from '../src/lib/reporting'

describe('reporting.js', () => {
  describe('groupBy', () => {
    it('debería agrupar correctamente un array de objetos', () => {
      const items = [
        { id: 1, type: 'A' },
        { id: 2, type: 'B' },
        { id: 3, type: 'A' }
      ]
      const result = groupBy(items, i => i.type)
      expect(result.get('A').length).toBe(2)
      expect(result.get('B').length).toBe(1)
    })
  })

  describe('getQuarterOrder', () => {
    it('debería retornar el orden numérico de un periodo', () => {
      expect(getQuarterOrder('Primer Trimestre')).toBe(1)
      expect(getQuarterOrder('2do Quimestre')).toBe(2)
      expect(getQuarterOrder('Tercer Trimestre')).toBe(3)
      expect(getQuarterOrder('Desconocido')).toBe(99)
    })
  })

  describe('getPeriodLabel', () => {
    it('debería formatear correctamente etiquetas de trimestres y quimestres', () => {
      expect(getPeriodLabel('Primer Quimestre')).toBe('1Q')
      expect(getPeriodLabel('Segundo Trimestre')).toBe('2T')
      expect(getPeriodLabel('Tercer Trimestre')).toBe('3T')
    })
  })

  describe('computeProjectAverage', () => {
    it('debería retornar null si no hay materias seleccionadas', () => {
      expect(computeProjectAverage({}, [], 'stu1')).toBeNull()
      expect(computeProjectAverage({}, null, 'stu1')).toBeNull()
    })

    it('debería calcular el promedio de proyectos ignorando valores NaN', () => {
      const grades = {
        stu1: { sub1: 10, sub2: 8, sub3: 'abc' }
      }
      // Average of 10 and 8 is 9
      expect(computeProjectAverage(grades, ['sub1', 'sub2', 'sub3'], 'stu1')).toBe(9)
    })
  })

  describe('computeSubjectTotal', () => {
    const definitions = [
      { id: 'd1', category: 'INDIVIDUAL', name: 'Lecciones' },
      { id: 'd2', category: 'GRUPAL', name: 'Exposición' },
      { id: 'd3', category: 'SUMATIVA', name: 'Proyecto' },
      { id: 'd4', category: 'SUMATIVA', name: 'Examen' }
    ]

    it('debería calcular el total formateando el 70% formativo y 30% sumativo', () => {
      const studentGrades = {
        d1: 10,
        d2: 8, // formative = (10+8)/2 = 9. 9 * 0.7 = 6.3
        d3: 10,
        d4: 10 // summative = 10. 10 * 0.3 = 3.0
      }
      
      const result = computeSubjectTotal(definitions, studentGrades, null, false)
      expect(result.avgIndividual).toBe(10)
      expect(result.avgGroup).toBe(8)
      expect(result.avgFormative).toBe(9)
      expect(result.weightedFormative).toBe(6.3)
      expect(result.weightedSummative).toBe(3.0)
      expect(result.total).toBe(9.3)
    })

    it('debería sobrescribir la nota del proyecto si es una materia interdisciplinaria', () => {
      const studentGrades = {
        d1: 10,
        d2: 10, // formative = 10. 10 * 0.7 = 7
        d3: 5, // Proyecto original: 5. Pero será sobrescrito por projectAverage = 10
        d4: 10 // summative = (10+10)/2 = 10. 10 * 0.3 = 3
      }
      
      // projectAverage = 10, subjectIsProject = true
      const result = computeSubjectTotal(definitions, studentGrades, 10, true)
      
      expect(result.avgSum).toBe(10)
      expect(result.total).toBe(10)
    })

    it('debería retornar null en promedios si faltan datos', () => {
      const result = computeSubjectTotal(definitions, {}, null, false)
      expect(result.total).toBeNull()
      expect(result.avgFormative).toBeNull()
    })
  })
})
